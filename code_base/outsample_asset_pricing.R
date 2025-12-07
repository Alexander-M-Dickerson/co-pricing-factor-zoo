#' Out-of-Sample Asset Pricing
#'
#' Computes out-of-sample pricing metrics for a new cross-section of portfolio returns
#' using in-sample risk prices from IS_AP object.
#'
#' @param R_oss Data frame with 'date' column and portfolio returns (out-of-sample)
#' @param IS_AP IS_AP object from run_bayesian_mcmc() containing lambdas, weights, etc.
#' @param f1 Data frame or matrix of non-traded factors (with or without 'date' column)
#' @param f2 Data frame or matrix of traded factors (with or without 'date' column)
#' @param fac_freq Data frame or matrix of frequentist factors (with or without 'date' column)
#' @param frequentist_models Named list of frequentist model specifications
#' @param kns_out KNS estimation output (nested structure with $combined, $f2_only)
#' @param rp_out RP-PCA estimation output (nested structure with $combined, $f2_only)
#' @param pca_out PCA estimation output (nested structure with $combined, $f2_only, or NULL)
#' @param intercept Logical, whether models include intercept
#' @param date_start Start date for OOS period (YYYY-MM-DD) or NULL
#' @param date_end End date for OOS period (YYYY-MM-DD) or NULL
#' @param verbose Print progress messages?
#'
#' @return Data frame with pricing metrics (RMSEdm, MAPEdm, R2OLS, R2GLS) for all models
#'
#' @details
#' The function:
#' 1. Validates and aligns R_oss dates with factor data
#' 2. Extracts lambdas from IS_AP for all models
#' 3. Computes expected returns using OOS correlations with IS factors
#' 4. Calculates pricing errors and metrics
#'
#' For OOS pricing, we use the IS period factors directly (not reconstructed):
#' - f1, f2, fac_freq: observed factors in OOS period
#' - KNS/RP-PCA/PCA: IS period PC factors (kns_PCs, RP-PCA factors)
#' - Optimal portfolios: formed using IS period weights applied to OOS returns
#' 
#' R_oss represents the test assets we're PRICING (left-hand side), and we
#' compute correlations between R_oss and the IS factors to get expected returns.
#'
#' Models included:
#' - BMA (4 shrinkage levels)
#' - Frequentist models (user-specified)
#' - Bayesian-selected (Top, Top-MPR, both f2-only and all-factor versions)
#' - KNS, KNSf2
#' - RP-PCA, RP-PCAf2
#' - PCA, PCAf2 (if available)
#' - Tangency, Tangencyf2
#' - MinVar, MinVarf2
#' - EqualWeight, EqualWeightf2

os_asset_pricing <- function(R_oss,
                             IS_AP,
                             f1,
                             f2,
                             fac_freq,
                             frequentist_models,
                             kns_out,
                             rp_out,
                             pca_out = NULL,
                             intercept = TRUE,
                             date_start = NULL,
                             date_end = NULL,
                             verbose = TRUE
) {
  
  library(dplyr)
  library(matrixStats)
  
  ## ---- 0. Input validation -----------------------------------------------------
  if (is.null(frequentist_models)) {
    stop("`frequentist_models` is REQUIRED. Must be a named list of factor vectors.")
  }
  
  if (!is.list(frequentist_models) || is.null(names(frequentist_models))) {
    stop("`frequentist_models` must be a named list")
  }
  
  ## ---- 1. Prepare data with date columns ---------------------------------------
  if (verbose) message("Validating and aligning R_oss dates...")
  
  # Helper function to check if data has date column
  has_date_col <- function(x) {
    if (is.null(x)) return(FALSE)
    "date" %in% colnames(x)
  }
  
  # Convert R_oss to data frame if needed
  if (is.matrix(R_oss)) {
    R_oss <- as.data.frame(R_oss)
  }
  
  # Check for date column in R_oss
  if (!has_date_col(R_oss)) {
    stop("R_oss must have 'date' as first column")
  }
  
  # Prepare f1 data
  if (!is.null(f1)) {
    if (has_date_col(f1)) {
      # Already has date column - use as is
      f1_data <- as.data.frame(f1)
    } else {
      # No date column - add it from IS_AP$dates
      if (is.null(IS_AP$dates)) {
        stop("IS_AP$dates is NULL. Ensure dates were passed during IS estimation.")
      }
      dates_is <- as.character(IS_AP$dates)
      f1_data <- cbind(date = dates_is, as.data.frame(f1))
    }
  } else {
    f1_data <- NULL
  }
  
  # Prepare f2 data
  if (!is.null(f2)) {
    if (has_date_col(f2)) {
      # Already has date column - use as is
      f2_data <- as.data.frame(f2)
    } else {
      # No date column - add it from IS_AP$dates
      if (is.null(IS_AP$dates)) {
        stop("IS_AP$dates is NULL. Ensure dates were passed during IS estimation.")
      }
      dates_is <- as.character(IS_AP$dates)
      f2_data <- cbind(date = dates_is, as.data.frame(f2))
    }
  } else {
    stop("f2 is required for OOS pricing")
  }
  
  # Prepare fac_freq data
  if (has_date_col(fac_freq)) {
    # Already has date column - use as is
    fac_freq_data <- as.data.frame(fac_freq)
  } else {
    # No date column - add it from IS_AP$dates
    if (is.null(IS_AP$dates)) {
      stop("IS_AP$dates is NULL. Ensure dates were passed during IS estimation.")
    }
    dates_is <- as.character(IS_AP$dates)
    fac_freq_data <- cbind(date = dates_is, as.data.frame(fac_freq))
  }
  
  ## ---- 2. Validate and align dates ---------------------------------------------
  # Check if validate_and_align_dates helper exists
  if (!exists("validate_and_align_dates", mode = "function")) {
    stop("Function 'validate_and_align_dates' not found. Please source helper functions.")
  }
  
  # Build data_list conditionally based on f1
  data_list <- if (!is.null(f1_data)) {
    list(f1 = f1_data, f2 = f2_data, R_oss = R_oss, fac_freq = fac_freq_data)
  } else {
    list(f2 = f2_data, R_oss = R_oss, fac_freq = fac_freq_data)
  }
  
  aligned <- validate_and_align_dates(
    data_list,
    date_start = date_start,
    date_end = date_end,
    verbose = verbose
  )
  
  # Extract aligned data (drop date column)
  R_oss_matrix <- as.matrix(aligned$data$R_oss[, -1, drop = FALSE])
  f1_matrix <- if (!is.null(f1_data)) {
    as.matrix(aligned$data$f1[, -1, drop = FALSE])
  } else {
    NULL
  }
  f2_matrix <- as.matrix(aligned$data$f2[, -1, drop = FALSE])
  fac_freq_matrix <- as.matrix(aligned$data$fac_freq[, -1, drop = FALSE])
  
  if (verbose) {
    message("  OOS period: ", as.character(aligned$date_range["start"]), " to ",
            as.character(aligned$date_range["end"]))
    message("  OOS observations: ", nrow(R_oss_matrix))
  }
  
  ## ---- 3. Extract lambdas from IS_AP -------------------------------------------
  lambdas <- IS_AP$lambdas
  
  # Verify lambdas exist
  if (is.null(lambdas)) {
    stop("IS_AP$lambdas is NULL. Ensure IS estimation completed successfully.")
  }
  
  ## ---- 4. Helper objects --------------------------------------------------------
  N <- ncol(R_oss_matrix)
  get_cor <- function(x) cor(R_oss_matrix, as.matrix(x))
  
  # Combine R_oss with f2 for some models
  Rc_oss <- cbind(R_oss_matrix, f2_matrix)
  
  # Build f_all from aligned f1 and f2
  f_all <- if (!is.null(f1_matrix) && ncol(f1_matrix) > 0) {
    as.data.frame(cbind(f1_matrix, f2_matrix))
  } else {
    as.data.frame(f2_matrix)
  }
  
  f2_names <- if (!is.null(f2_matrix)) colnames(f2_matrix) else character(0)
  
  ## ---- 5. Build C_f for BMA models ---------------------------------------------
  f_combined <- if (!is.null(f1_matrix)) {
    cbind(f1_matrix, f2_matrix)
  } else {
    f2_matrix
  }
  
  C_f <- if (intercept) {
    cbind(1, cor(R_oss_matrix, f_combined))
  } else {
    cor(R_oss_matrix, f_combined)
  }
  
  ## ---- 6. Compute Expected Returns (ER_pred) -----------------------------------
  ER_pred <- list()
  
  ## ---- 6.1. BMA Models ---------------------------------------------------------
  bma_names <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%")
  
  for (bma_name in bma_names) {
    if (bma_name %in% names(lambdas)) {
      lambda_vec <- drop(lambdas[[bma_name]])  # drop() converts 1-row matrix to vector
      ER_pred[[bma_name]] <- C_f %*% lambda_vec
    }
  }
  
  ## ---- 6.2. Frequentist Models -------------------------------------------------
  for (model_name in names(frequentist_models)) {
    if (model_name %in% names(lambdas)) {
      factor_cols <- frequentist_models[[model_name]]
      
      # Check if all factors are available in fac_freq
      if (all(factor_cols %in% colnames(fac_freq_matrix))) {
        lambda_vec <- drop(lambdas[[model_name]])
        ER_pred[[model_name]] <- cbind(1, get_cor(fac_freq_matrix[, factor_cols, drop = FALSE])) %*% lambda_vec
      } else {
        warning(paste0("Model '", model_name, "': some factors not in fac_freq. Skipping."))
      }
    }
  }
  
  ## ---- 6.3. Bayesian-Selected Models (Top, Top-MPR) ----------------------------
  # Get factor specifications from IS_AP
  top_factors_f2 <- IS_AP$top_factors       # f2-only
  top_mpr_factors_f2 <- IS_AP$top_mpr_factors
  top_factors_all <- IS_AP$top_factors_all  # all factors
  top_mpr_factors_all <- IS_AP$top_mpr_factors_all
  
  # f2-only Top models
  bayesian_models_f2 <- list(
    `Top-20%` = if (length(top_factors_f2) >= 1) top_factors_f2[[1]] else NULL,
    `Top-40%` = if (length(top_factors_f2) >= 2) top_factors_f2[[2]] else NULL,
    `Top-60%` = if (length(top_factors_f2) >= 3) top_factors_f2[[3]] else NULL,
    `Top-80%` = if (length(top_factors_f2) >= 4) top_factors_f2[[4]] else NULL,
    `Top-MPR-20%` = if (length(top_mpr_factors_f2) >= 1) top_mpr_factors_f2[[1]] else NULL,
    `Top-MPR-40%` = if (length(top_mpr_factors_f2) >= 2) top_mpr_factors_f2[[2]] else NULL,
    `Top-MPR-60%` = if (length(top_mpr_factors_f2) >= 3) top_mpr_factors_f2[[3]] else NULL,
    `Top-MPR-80%` = if (length(top_mpr_factors_f2) >= 4) top_mpr_factors_f2[[4]] else NULL
  )
  
  for (model_name in names(bayesian_models_f2)) {
    if (model_name %in% names(lambdas)) {
      factor_cols <- bayesian_models_f2[[model_name]]
      if (!is.null(factor_cols) && length(factor_cols) > 0 && all(factor_cols %in% colnames(f_all))) {
        lambda_vec <- drop(lambdas[[model_name]])
        ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*% lambda_vec
      }
    }
  }
  
  # All-factor Top models (for lambdas only, not used for portfolio construction)
  bayesian_models_all <- list(
    `Top-20%-All` = if (length(top_factors_all) >= 1) top_factors_all[[1]] else NULL,
    `Top-40%-All` = if (length(top_factors_all) >= 2) top_factors_all[[2]] else NULL,
    `Top-60%-All` = if (length(top_factors_all) >= 3) top_factors_all[[3]] else NULL,
    `Top-80%-All` = if (length(top_factors_all) >= 4) top_factors_all[[4]] else NULL,
    `Top-MPR-20%-All` = if (length(top_mpr_factors_all) >= 1) top_mpr_factors_all[[1]] else NULL,
    `Top-MPR-40%-All` = if (length(top_mpr_factors_all) >= 2) top_mpr_factors_all[[2]] else NULL,
    `Top-MPR-60%-All` = if (length(top_mpr_factors_all) >= 3) top_mpr_factors_all[[3]] else NULL,
    `Top-MPR-80%-All` = if (length(top_mpr_factors_all) >= 4) top_mpr_factors_all[[4]] else NULL
  )
  
  for (model_name in names(bayesian_models_all)) {
    if (model_name %in% names(lambdas)) {
      factor_cols <- bayesian_models_all[[model_name]]
      if (!is.null(factor_cols) && length(factor_cols) > 0 && all(factor_cols %in% colnames(f_all))) {
        lambda_vec <- drop(lambdas[[model_name]])
        ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*% lambda_vec
      }
    }
  }
  
  ## ---- 6.4. RP-PCA Models ------------------------------------------------------
  if ("RP-PCA" %in% names(lambdas)) {
    # Combined (R+f2) - use IS PC factors directly
    lambda_vec_rp <- drop(lambdas$`RP-PCA`)
    f_pc_rp <- rp_out$combined$factors
    ER_pred$`RP-PCA` <- cbind(1, get_cor(f_pc_rp)) %*% lambda_vec_rp
  }
  
  if ("RP-PCAf2" %in% names(lambdas) && !is.null(rp_out$f2_only)) {
    # f2 only - use IS PC factors directly
    lambda_vec_rpf2 <- drop(lambdas$`RP-PCAf2`)
    f_pc_rpf2 <- rp_out$f2_only$factors
    ER_pred$`RP-PCAf2` <- cbind(1, get_cor(f_pc_rpf2)) %*% lambda_vec_rpf2
  }
  
  ## ---- 6.5. PCA Models (if available) ------------------------------------------
  if (!is.null(pca_out)) {
    if ("PCA" %in% names(lambdas)) {
      # Combined (R+f2) - use IS PC factors directly
      lambda_vec_pca <- drop(lambdas$PCA)
      f_pc_pca <- pca_out$combined$factors
      ER_pred$PCA <- cbind(1, get_cor(f_pc_pca)) %*% lambda_vec_pca
    }
    
    if ("PCAf2" %in% names(lambdas) && !is.null(pca_out$f2_only)) {
      # f2 only - use IS PC factors directly
      lambda_vec_pcaf2 <- drop(lambdas$PCAf2)
      f_pc_pcaf2 <- pca_out$f2_only$factors
      ER_pred$PCAf2 <- cbind(1, get_cor(f_pc_pcaf2)) %*% lambda_vec_pcaf2
    }
  }
  
  ## ---- 6.6. KNS Models ---------------------------------------------------------
  if ("KNS" %in% names(lambdas)) {
    # Combined (R+f2) - use IS PC factors directly
    lambda_vec_kns <- drop(lambdas$KNS) 
    kns_PCs <- kns_out$combined$kns_PCs
    scl     <- colSds(kns_PCs)
    kns_PCs         <- t(t(kns_PCs) / colSds(kns_PCs))
    # KNS has no intercept
    ER_pred$KNS <- get_cor(kns_PCs) %*% (lambda_vec_kns* scl)
  }
  
  if ("KNSf2" %in% names(lambdas) && !is.null(kns_out$f2_only)) {
    # f2 only - use IS PC factors directly
    lambda_vec_knsf2 <- drop(lambdas$KNSf2)
    kns_PCs_f2 <- kns_out$f2_only$kns_PCs
    scl     <- colSds(kns_PCs_f2)
    kns_PCs_f2 <- t(t(kns_PCs_f2) / colSds(kns_PCs_f2))
    # KNS has no intercept
    ER_pred$KNSf2 <- get_cor(kns_PCs_f2) %*% (lambda_vec_knsf2* scl)
  }
  
  ## ---- 6.7. Optimal Portfolios (single-factor models) --------------------------
  # Optimal portfolios are stored as SDF mimicking factors in IS_AP$sdf_mim
  # These are single-factor models
  optimal_model_names <- c("Tangency", "MinVar", "EqualWeight",
                           "Tangencyf2", "MinVarf2", "EqualWeightf2")
  
  for (opt_name in optimal_model_names) {
    if (opt_name %in% names(lambdas)) {
      # Check if SDF factor exists in IS_AP$sdf_mim
      if (!is.null(IS_AP$sdf_mim) && opt_name %in% colnames(IS_AP$sdf_mim)) {
        # Get SDF mimicking portfolio from IS period
        sdf_factor <- IS_AP$sdf_mim[, opt_name, drop = FALSE]
        
        # Compute expected return (with intercept)
        lambda_vec <- drop(lambdas[[opt_name]])
        ER_pred[[opt_name]] <- cbind(1, get_cor(sdf_factor)) %*% lambda_vec
      } else {
        if (verbose) {
          message(paste0("  Skipping ", opt_name, ": not found in IS_AP$sdf_mim"))
        }
      }
    }
  }
  
  ## ---- 7. Combine all expected returns -----------------------------------------
  ER_pred_all <- do.call(cbind, ER_pred) * sqrt(12)  # Annualize to match ER_oos units
  
  if (verbose) {
    message("  Models evaluated: ", ncol(ER_pred_all))
  }
  
  ## ---- 8. Unconditional SRs & pricing errors -----------------------------------
  # Annualized Sharpe ratios (pricing in SR units)
  ER_oos <- sqrt(12) * colMeans(R_oss_matrix) / colSds(R_oss_matrix)  # N × 1 (annualized SRs)
  
  alpha <- ER_oos %*% matrix(1, nrow = 1, ncol = ncol(ER_pred_all)) - ER_pred_all
  
  ## ---- 9. Asset-pricing metrics ------------------------------------------------
  Sigma_inv <- solve(cor(R_oss_matrix))
  
  SharpeRatio <- function(R) {
    
    ER <- matrix(colMeans(R), ncol=1)
    covR <- cov(R)
    as.numeric(crossprod(ER, solve(covR, ER)))
  }
  
  # Final scalar: 12 * annualized max SR
  SR_scalar <- 12 * SharpeRatio(R_oss_matrix)
  
  # Demeaned pricing errors (ONLY for RMSE/MAPE)
  dm_alpha <- sweep(alpha, 2, colMeans(alpha))
  
  # Metric functions - NOTE: R2 uses RAW alpha, not demeaned!
  rmse   <- function(mat) sqrt(colMeans(mat^2))
  mape   <- function(mat)        colMeans(abs(mat))
  r2_ols <- function(mat) 1 - apply(mat, 2, var) / var(drop(ER_oos))
  r2_gls <- function(mat) 1 - diag(t(mat) %*% Sigma_inv %*% mat) / SR_scalar
  
  # Assemble results - Use dm_alpha for RMSE/MAPE, RAW alpha for R2
  metrics_tbl <- rbind(
    RMSEdm = rmse(dm_alpha),
    MAPEdm = mape(dm_alpha),
    R2OLS  = r2_ols(alpha),      # RAW alpha
    R2GLS  = r2_gls(alpha)       # RAW alpha
  ) |>
    as.data.frame() |>
    `colnames<-`(names(ER_pred)) |>
    tibble::rownames_to_column("metric")
  
  if (verbose) {
    message("Out-of-sample pricing evaluation complete.")
  }
  
  return(metrics_tbl)
}