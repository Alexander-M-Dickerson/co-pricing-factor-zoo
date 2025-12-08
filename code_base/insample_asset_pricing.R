#' Enhanced In-Sample Asset Pricing (Unconditional with Time-Varying Features)
#'
#' Adapted from insample_asset_pricing_time_varying.R for unconditional estimation.
#' Computes lambdas, scaled lambdas, weights, and gammas with enhanced portfolio metrics.
#'
#' KEY DIFFERENCES FROM TIME-VARYING VERSION:
#'   - date_end is optional (defaults to "unconditional")
#'   - Handles both nested (TS) and flat structures for KNS/RP-PCA outputs
#'   - Backward compatible with existing unconditional pipeline
#'
#' @param results MCMC results list (4 elements for different psi)
#' @param f_all Matrix of all factors (non-traded + traded)
#' @param R Matrix of test asset returns
#' @param f1 Matrix of non-traded factors
#' @param f2 Matrix of traded factors (can be NULL for treasury models)
#' @param rp_out RP-PCA output from estim_rppca() or estim_rppca_ts()
#' @param pca_out Standard PCA output from estim_rppca() with kappa=0
#' @param kns_out KNS output from estimate_kns_oos() or estimate_kns_oos_ts()
#' @param intercept Logical, whether model includes intercept
#' @param fac_freq Matrix of frequentist model factors
#' @param frequentist_models Named list of frequentist model specifications
#' @param date_end Character or Date, estimation label (defaults to "unconditional")
#' @param drop_draws_pct Burn-in percentage (0-0.5)
#'
#' @return List with elements:
#'   - lambdas: Raw lambda estimates (1-row matrices)
#'   - scaled_lambdas: Lambdas descaled by factor SDs
#'   - weights: Asset weights (normalized to sum to 1)
#'   - gammas: Average gamma (inclusion probabilities) for BMA models
#'   - date_end: Estimation label
#'   - top_factors: Top 5 f2 factors by gamma for each psi
#'   - top_mpr_factors: Top 5 f2 factors by absolute MPR for each psi
#'   - top_factors_all: Top 5 all factors by gamma for each psi
#'   - top_mpr_factors_all: Top 5 all factors by absolute MPR for each psi
#'   - kns_pcs_weights: PC weights from KNS combined (R+f2)
#'   - knsf2_pc_weights: PC weights from KNS f2_only
#'   - rppca_pcs_weights: PC weights from RP-PCA combined (R+f2)
#'   - rppcaf2_pc_weights: PC weights from RP-PCA f2_only
#'   - pca_pcs_weights: PC weights from PCA combined (R+f2)
#'   - pcaf2_pc_weights: PC weights from PCA f2_only

insample_asset_pricing_enhanced <- function(results, f_all, R, f1, f2,
                                            rp_out, pca_out = NULL, kns_out,
                                            intercept,
                                            fac_freq,
                                            frequentist_models = NULL,
                                            date_end = NULL,
                                            drop_draws_pct = 0,
                                            dates = NULL
) {
  
  library(purrr)          # functional helpers
  library(dplyr)          # select, mutate, ...
  library(matrixStats)    # for colSds()
  
  select  <- dplyr::select
  
  ## ---- 0. Set default date_end for unconditional estimation -------------
  if (is.null(date_end)) {
    date_end <- "unconditional"
  }
  date_label <- as.character(date_end)
  
  ## ---- 0.1 Detect if we're using nested (TS) or flat structures -------------
  is_nested_kns <- !is.null(kns_out) && !is.null(kns_out$combined)
  is_nested_rp <- !is.null(rp_out) && !is.null(rp_out$combined)
  is_nested_pca <- !is.null(pca_out) && !is.null(pca_out$combined)
  
  ## ---- BMA results extraction with burn-in handling -------------
  for (i in 1:4){
    # Calculate number of draws to keep (drop burn-in period)
    n_draws <- nrow(results[[i]]$gamma_path)
    start_row <- floor(n_draws * drop_draws_pct) + 1
    
    # Subset to post-burn-in draws
    gamma_keep <- results[[i]]$gamma_path[start_row:n_draws, , drop = FALSE]
    lambda_keep <- results[[i]]$lambda_path[start_row:n_draws, , drop = FALSE]
    
    # Compute means on retained draws
    assign(paste0("models.psi", i), colMeans(gamma_keep))
    assign(paste0("lambda.bma.psi", i), colMeans(lambda_keep))
  }
  
  names = if (is.null(f1)) colnames(f2) else colnames(cbind(f1, f2))
  Gamma = data.frame( gam1 = models.psi1, gam2 = models.psi2, gam3 = models.psi3,
                      gam4 = models.psi4, row.names = names )
  
  f_all    <- as.data.frame(f_all)
  fac_freq <- as.data.frame(fac_freq)
  
  #### Combine R with traded assets in f2 (if applicable), f2 can be NULL ####
  Rc <- cbind(R,f2)
  N = dim(Rc)[2]
  
  # Get f2 column names for filtering (if f2 is not NULL)
  f2_names <- if (!is.null(f2)) colnames(f2) else character(0)
  
  #### Top - ALL FACTORS ####
  top5_list_all <- lapply(colnames(Gamma), function(col) {
    row.names(Gamma)[order(Gamma[[col]], decreasing = TRUE)[1:5]]
  })
  
  #### Top - F2 ONLY ####
  top5_list_f2 <- lapply(colnames(Gamma), function(col) {
    if (length(f2_names) == 0) {
      return(character(0))
    }
    # Filter Gamma to f2 factors only
    gamma_f2 <- Gamma[rownames(Gamma) %in% f2_names, , drop = FALSE]
    if (nrow(gamma_f2) == 0) {
      return(character(0))
    }
    # Get top N (up to 5, or fewer if less than 5 f2 factors)
    top_n <- min(5, nrow(gamma_f2))
    row.names(gamma_f2)[order(gamma_f2[[col]], decreasing = TRUE)[1:top_n]]
  })
  
  #### Top-MPR - ALL FACTORS ####
  # Create Lambda dataframe for MPR-based top factors
  Lambda <- data.frame(
    lam1 = lambda.bma.psi1,
    lam2 = lambda.bma.psi2,
    lam3 = lambda.bma.psi3,
    lam4 = lambda.bma.psi4,
    row.names = if (intercept) c("(Intercept)", names) else names
  )
  
  # Extract top 5 factors by absolute MPR, excluding intercept if present
  top5_mpr_list_all <- lapply(colnames(Lambda), function(col) {
    # Drop intercept row if present
    Lambda_no_int <- if (intercept) Lambda[-1, , drop = FALSE] else Lambda
    # Get top 5 by absolute value of Lambda (MPR)
    row.names(Lambda_no_int)[order(abs(Lambda_no_int[[col]]), decreasing = TRUE)[1:5]]
  })
  
  #### Top-MPR - F2 ONLY ####
  top5_mpr_list_f2 <- lapply(colnames(Lambda), function(col) {
    if (length(f2_names) == 0) {
      return(character(0))
    }
    # Drop intercept row if present
    Lambda_no_int <- if (intercept) Lambda[-1, , drop = FALSE] else Lambda
    # Filter to f2 factors only
    lambda_f2 <- Lambda_no_int[rownames(Lambda_no_int) %in% f2_names, , drop = FALSE]
    if (nrow(lambda_f2) == 0) {
      return(character(0))
    }
    # Get top N (up to 5)
    top_n <- min(5, nrow(lambda_f2))
    row.names(lambda_f2)[order(abs(lambda_f2[[col]]), decreasing = TRUE)[1:top_n]]
  })
  
  
  #### BMA Pricing ####
  # Compute factor matrix for correlation (handle NULL f1)
  f_combined <- if (is.null(f1)) f2 else cbind(f1, f2)
  
  if (intercept == FALSE){
    C_f   <- cor(Rc, f_combined)
  }  else{
    C_f   <- cbind(
      matrix(1, nrow=N,ncol=1),
      cor(Rc, f_combined)
    )
  }
  
  ## ---- 0  House-keeping -------------
  W  <- cor(Rc)           # weighting matrix, computed once
  N  <- ncol(Rc)          # number of test assets
  
  # Weighting matrix for f2-only models (RP-PCAf2)
  W_f2 <- if (!is.null(f2)) cor(f2) else NULL
  
  ## ---- 0.2  Compute Optimal Portfolios -------------
  # Computed early so portfolio returns can be used in GMM estimation
  # Two versions: combined (R+f2) and f2-only
  optimal_portfolios <- list()
  optimal_weights <- list()
  
  ## ---- 0.2.1  Combined (R+f2) Optimal Portfolios -------------
  # Rc = cbind(R, f2) is already computed above
  Rc_mat <- as.matrix(Rc)
  Rc_names <- colnames(Rc_mat)
  mu_Rc <- colMeans(Rc_mat)
  Sigma_Rc <- cov(Rc_mat)
  
  # Tangency Portfolio - Combined (Maximum Sharpe Ratio)
  tryCatch({
    Sigma_inv_Rc <- solve(Sigma_Rc)
    w_tangency_raw <- Sigma_inv_Rc %*% mu_Rc
    w_tangency <- as.vector(w_tangency_raw / sum(w_tangency_raw))
    names(w_tangency) <- Rc_names
    optimal_weights$Tangency <- w_tangency
    # Form portfolio return time-series (T x 1)
    optimal_portfolios$Tangency <- as.matrix(Rc_mat %*% w_tangency)
    colnames(optimal_portfolios$Tangency) <- "Tangency"
  }, error = function(e) {
    warning("Tangency portfolio (combined) calculation failed: ", e$message)
    optimal_weights$Tangency <- NULL
    optimal_portfolios$Tangency <- NULL
  })
  
  # Minimum Variance Portfolio - Combined
  tryCatch({
    Sigma_inv_Rc <- solve(Sigma_Rc)
    ones <- rep(1, length(Rc_names))
    w_minvar_raw <- Sigma_inv_Rc %*% ones
    w_minvar <- as.vector(w_minvar_raw / sum(w_minvar_raw))
    names(w_minvar) <- Rc_names
    optimal_weights$MinVar <- w_minvar
    # Form portfolio return time-series (T x 1)
    optimal_portfolios$MinVar <- as.matrix(Rc_mat %*% w_minvar)
    colnames(optimal_portfolios$MinVar) <- "MinVar"
  }, error = function(e) {
    warning("Minimum variance portfolio (combined) calculation failed: ", e$message)
    optimal_weights$MinVar <- NULL
    optimal_portfolios$MinVar <- NULL
  })
  
  # Equal-Weight Portfolio - Combined (1/N)
  w_equalweight <- rep(1 / length(Rc_names), length(Rc_names))
  names(w_equalweight) <- Rc_names
  optimal_weights$EqualWeight <- w_equalweight
  # Form portfolio return time-series (T x 1)
  optimal_portfolios$EqualWeight <- as.matrix(Rc_mat %*% w_equalweight)
  colnames(optimal_portfolios$EqualWeight) <- "EqualWeight"
  
  ## ---- 0.2.2  f2-only Optimal Portfolios -------------
  if (!is.null(f2) && length(f2_names) > 0) {
    f2_mat <- as.matrix(f2)
    mu_f2 <- colMeans(f2_mat)
    Sigma_f2 <- cov(f2_mat)
    
    # Tangency Portfolio - f2 only (Maximum Sharpe Ratio)
    tryCatch({
      Sigma_inv_f2 <- solve(Sigma_f2)
      w_tangency_raw <- Sigma_inv_f2 %*% mu_f2
      w_tangency <- as.vector(w_tangency_raw / sum(w_tangency_raw))
      names(w_tangency) <- f2_names
      optimal_weights$Tangencyf2 <- w_tangency
      # Form portfolio return time-series (T x 1)
      optimal_portfolios$Tangencyf2 <- as.matrix(f2_mat %*% w_tangency)
      colnames(optimal_portfolios$Tangencyf2) <- "Tangencyf2"
    }, error = function(e) {
      warning("Tangency portfolio (f2) calculation failed: ", e$message)
      optimal_weights$Tangencyf2 <- NULL
      optimal_portfolios$Tangencyf2 <- NULL
    })
    
    # Minimum Variance Portfolio - f2 only
    tryCatch({
      Sigma_inv_f2 <- solve(Sigma_f2)
      ones <- rep(1, length(f2_names))
      w_minvar_raw <- Sigma_inv_f2 %*% ones
      w_minvar <- as.vector(w_minvar_raw / sum(w_minvar_raw))
      names(w_minvar) <- f2_names
      optimal_weights$MinVarf2 <- w_minvar
      # Form portfolio return time-series (T x 1)
      optimal_portfolios$MinVarf2 <- as.matrix(f2_mat %*% w_minvar)
      colnames(optimal_portfolios$MinVarf2) <- "MinVarf2"
    }, error = function(e) {
      warning("Minimum variance portfolio (f2) calculation failed: ", e$message)
      optimal_weights$MinVarf2 <- NULL
      optimal_portfolios$MinVarf2 <- NULL
    })
    
    # Equal-Weight Portfolio - f2 only (1/N)
    w_equalweight_f2 <- rep(1 / length(f2_names), length(f2_names))
    names(w_equalweight_f2) <- f2_names
    optimal_weights$EqualWeightf2 <- w_equalweight_f2
    # Form portfolio return time-series (T x 1)
    optimal_portfolios$EqualWeightf2 <- as.matrix(f2_mat %*% w_equalweight_f2)
    colnames(optimal_portfolios$EqualWeightf2) <- "EqualWeightf2"
  }
  
  ## ---- 1  lambda-hat estimates for the "frequentist" models (DYNAMIC) -------------
  
  # Use user-specified models or defaults
  if (is.null(frequentist_models)) {
    # Default models for replication
    freq_models <- list(
      CAPM  = "MKTS",
      CAPMB = "MKTB",
      FF5   = c("MKTS", "SMB", "HML", "DEF", "TERM"),
      HKM   = c("MKTS", "CPTLT")
    )
  } else {
    freq_models <- frequentist_models
  }
  
  # Add Top and Top-MPR models (f2-only and all-factor versions)
  # Skip if f2 is NULL (treasury models)
  if (!is.null(f2) && length(f2_names) > 0) {
    # 8 f2-only models (for weights + lambdas + scaled_lambdas)
    factor_specs_bayesian <- list(
      `Top-20%`     = top5_list_f2[[1]],
      `Top-40%`     = top5_list_f2[[2]],
      `Top-60%`     = top5_list_f2[[3]],
      `Top-80%`     = top5_list_f2[[4]],
      `Top-MPR-20%` = top5_mpr_list_f2[[1]],
      `Top-MPR-40%` = top5_mpr_list_f2[[2]],
      `Top-MPR-60%` = top5_mpr_list_f2[[3]],
      `Top-MPR-80%` = top5_mpr_list_f2[[4]]
    )
    
    # 8 all-factor models (for lambdas + scaled_lambdas only, NO weights)
    factor_specs_all <- list(
      `Top-20%-All`     = top5_list_all[[1]],
      `Top-40%-All`     = top5_list_all[[2]],
      `Top-60%-All`     = top5_list_all[[3]],
      `Top-80%-All`     = top5_list_all[[4]],
      `Top-MPR-20%-All` = top5_mpr_list_all[[1]],
      `Top-MPR-40%-All` = top5_mpr_list_all[[2]],
      `Top-MPR-60%-All` = top5_mpr_list_all[[3]],
      `Top-MPR-80%-All` = top5_mpr_list_all[[4]]
    )
  } else {
    # f2 is NULL, skip all Top models
    factor_specs_bayesian <- list()
    factor_specs_all <- list()
  }
  
  # GMM estimation - frequentist models use fac_freq
  lambda_hat <- imap(
    freq_models,
    ~ gmm_estimation(Rc, as.matrix(select(fac_freq, all_of(.x))), W = W)
  )
  
  # GMM estimation - Bayesian-selected f2-only models use f_all
  lambda_hat_bayesian <- imap(
    factor_specs_bayesian,
    ~ gmm_estimation(Rc, as.matrix(select(f_all, all_of(.x))), W = W)
  )
  
  # GMM estimation - Bayesian-selected all-factor models use f_all
  lambda_hat_all <- imap(
    factor_specs_all,
    ~ gmm_estimation(Rc, as.matrix(select(f_all, all_of(.x))), W = W)
  )
  
  # Combine all lambda estimates
  lambda_hat <- c(lambda_hat, lambda_hat_bayesian, lambda_hat_all)
  
  # GMM estimation - Optimal portfolios (single-factor models)
  # Combined (R+f2) versions
  if (!is.null(optimal_portfolios$Tangency)) {
    lambda_hat$Tangency <- gmm_estimation(Rc, optimal_portfolios$Tangency, W, include.intercept = TRUE)
  }
  if (!is.null(optimal_portfolios$MinVar)) {
    lambda_hat$MinVar <- gmm_estimation(Rc, optimal_portfolios$MinVar, W, include.intercept = TRUE)
  }
  if (!is.null(optimal_portfolios$EqualWeight)) {
    lambda_hat$EqualWeight <- gmm_estimation(Rc, optimal_portfolios$EqualWeight, W, include.intercept = TRUE)
  }
  # f2-only versions
  if (!is.null(optimal_portfolios$Tangencyf2)) {
    lambda_hat$Tangencyf2 <- gmm_estimation(Rc, optimal_portfolios$Tangencyf2, W, include.intercept = TRUE)
  }
  if (!is.null(optimal_portfolios$MinVarf2)) {
    lambda_hat$MinVarf2 <- gmm_estimation(Rc, optimal_portfolios$MinVarf2, W, include.intercept = TRUE)
  }
  if (!is.null(optimal_portfolios$EqualWeightf2)) {
    lambda_hat$EqualWeightf2 <- gmm_estimation(Rc, optimal_portfolios$EqualWeightf2, W, include.intercept = TRUE)
  }
  
  # Add RP-PCA, PCA, and KNS (always included)
  # Handle nested vs flat structures
  if (is_nested_rp) {
    lambda_hat$`RP-PCA` <- gmm_estimation(Rc, rp_out$combined$factors, W, include.intercept = TRUE)
    if (!is.null(rp_out$f2_only)) {
      lambda_hat$`RP-PCAf2` <- gmm_estimation(Rc, rp_out$f2_only$factors, W, include.intercept = TRUE)
    }
  } else {
    lambda_hat$`RP-PCA` <- gmm_estimation(Rc, rp_out$factors, W, include.intercept = TRUE)
    # No f2_only for flat structure
  }

  if (is_nested_pca && !is.null(pca_out)) {
    lambda_hat$PCA <- gmm_estimation(Rc, pca_out$combined$factors, W, include.intercept = TRUE)
    if (!is.null(pca_out$f2_only)) {
      lambda_hat$PCAf2 <- gmm_estimation(Rc, pca_out$f2_only$factors, W, include.intercept = TRUE)
    }
  } else if (!is.null(pca_out)) {
    lambda_hat$PCA <- gmm_estimation(Rc, pca_out$factors, W, include.intercept = TRUE)
    # No f2_only for flat structure
  }

  if (is_nested_kns) {
    lambda_hat$KNS <- as.matrix(kns_out$combined$kns_lambdas)
    if (!is.null(kns_out$f2_only)) {
      lambda_hat$KNSf2 <- as.matrix(kns_out$f2_only$kns_lambdas)
    }
  } else {
    lambda_hat$KNS <- as.matrix(kns_out$kns_lambdas)
    # No f2_only for flat structure
  }
  
  ## ---- 2  lambda-hat estimates for the four BMA shrinkage levels -------------
  lambda_bma <- list(
    `BMA-20%` = lambda.bma.psi1,
    `BMA-40%` = lambda.bma.psi2,
    `BMA-60%` = lambda.bma.psi3,
    `BMA-80%` = lambda.bma.psi4
  )
  
  ## ---- 3  Neatly bundled outputs -------------
  insample_lambda      <- lambda_hat
  insample_lambda_bma  <- lambda_bma
  
  ## ---- 4  Descale lambdas and convert to weights -------------
  
  # Initialize output lists
  lambdas_out <- list()
  scaled_lambdas_out <- list()
  weights_out <- list()
  gammas_out <- list()
  
  ## ---- 4.1  BMA Models -------------
  bma_names <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%")
  
  # Compute scale vector (1 for intercept, SD for each factor)
  f_all_mat <- as.matrix(f_all)
  scale_vec <- if (intercept) {
    c(1, colSds(f_all_mat))
  } else {
    colSds(f_all_mat)
  }
  names(scale_vec) <- if (intercept) c("(Intercept)", colnames(f_all_mat)) else colnames(f_all_mat)
  
  for (bma_name in bma_names) {
    # Raw lambda
    lambda_raw <- lambda_bma[[bma_name]]
    
    # Add names to lambda_raw based on intercept and f_all structure
    names(lambda_raw) <- if (intercept) {
      c("(Intercept)", colnames(f_all_mat))
    } else {
      colnames(f_all_mat)
    }
    
    # Store raw lambda with proper names
    lambdas_out[[bma_name]] <- matrix(lambda_raw, nrow = 1, 
                                      dimnames = list(date_label, names(lambda_raw)))
    
    # Descale
    lambda_scaled <- lambda_raw / scale_vec
    
    # Store scaled lambdas
    scaled_lambdas_out[[bma_name]] <- matrix(lambda_scaled, nrow = 1,
                                             dimnames = list(date_label, names(lambda_scaled)))
    
    # Keep only traded factors (present in f2) for weights
    if (length(f2_names) > 0) {
      # Extract factors (excluding intercept if present) with names preserved
      lambda_scaled_factors <- if (intercept) {
        lambda_scaled[-1]  # Remove intercept, names automatically preserved
      } else {
        lambda_scaled
      }
      
      # Get factor names from the scaled vector
      factor_names <- names(lambda_scaled_factors)
      
      # Filter to only traded factors (those in f2)
      traded_idx <- factor_names %in% f2_names
      lambda_scaled_traded <- lambda_scaled_factors[traded_idx]
      
      # Convert to weights (normalize to sum = 1)
      if (length(lambda_scaled_traded) > 0 && sum(abs(lambda_scaled_traded)) > 0) {
        w <- lambda_scaled_traded / sum(lambda_scaled_traded)
      } else {
        w <- rep(0, length(lambda_scaled_traded))
        names(w) <- names(lambda_scaled_traded)
      }
      
      weights_out[[bma_name]] <- matrix(w, nrow = 1,
                                        dimnames = list(date_label, names(w)))
    } else {
      weights_out[[bma_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                        dimnames = list(date_label, NULL))
    }
  }
  
  # Store BMA gammas (average probabilities) with factor names
  for (i in 1:4) {
    psi_name <- bma_names[i]
    gamma_avg <- get(paste0("models.psi", i))
    # Ensure gamma names match factor names (no intercept in gamma)
    names(gamma_avg) <- names
    gammas_out[[psi_name]] <- matrix(gamma_avg, nrow = 1,
                                     dimnames = list(date_label, names(gamma_avg)))
  }
  
  ## ---- 4.2  Frequentist Models -------------
  for (model_name in names(freq_models)) {
    factor_cols <- freq_models[[model_name]]
    lambda_raw <- lambda_hat[[model_name]]
    
    # Store raw lambda
    lambdas_out[[model_name]] <- matrix(lambda_raw, nrow = 1,
                                        dimnames = list(date_label, rownames(lambda_raw)))
    
    # Get factor SDs from fac_freq
    f_sub <- as.matrix(fac_freq[, factor_cols, drop = FALSE])
    factor_sds <- colSds(f_sub)
    names(factor_sds) <- factor_cols
    
    # Descale (skip intercept)
    lambda_no_int <- lambda_raw[-1, , drop = FALSE]
    lambda_scaled <- lambda_no_int / factor_sds
    
    # Store scaled lambdas (with intercept)
    lambda_scaled_full <- rbind(lambda_raw[1, , drop = FALSE], lambda_scaled)
    scaled_lambdas_out[[model_name]] <- matrix(lambda_scaled_full, nrow = 1,
                                               dimnames = list(date_label, rownames(lambda_scaled_full)))
    
    # Convert to weights (ALWAYS compute for frequentist models)
    if (length(factor_cols) == 1) {
      # Single factor: weight = 1.0 (100%)
      weights_out[[model_name]] <- matrix(1.0, nrow = 1, ncol = 1,
                                          dimnames = list(date_label, factor_cols))
    } else {
      # Multiple factors: normalize to sum = 1
      w <- lambda_scaled / sum(lambda_scaled)
      weights_out[[model_name]] <- matrix(w, nrow = 1,
                                          dimnames = list(date_label, rownames(lambda_scaled)))
    }
  }
  
  ## ---- 4.3  Bayesian-Selected Models - f2-only (Top, Top-MPR) -------------
  for (model_name in names(factor_specs_bayesian)) {
    factor_cols <- factor_specs_bayesian[[model_name]]
    
    # Skip if no factors selected
    if (length(factor_cols) == 0) {
      lambdas_out[[model_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                          dimnames = list(date_label, NULL))
      scaled_lambdas_out[[model_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                                 dimnames = list(date_label, NULL))
      weights_out[[model_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                          dimnames = list(date_label, NULL))
      next
    }
    
    lambda_raw <- lambda_hat[[model_name]]
    
    # Store raw lambda
    lambdas_out[[model_name]] <- matrix(lambda_raw, nrow = 1,
                                        dimnames = list(date_label, rownames(lambda_raw)))
    
    # Get factor SDs from f_all
    f_sub <- as.matrix(f_all[, factor_cols, drop = FALSE])
    factor_sds <- colSds(f_sub)
    names(factor_sds) <- factor_cols
    
    # Descale (skip intercept)
    lambda_no_int <- lambda_raw[-1, , drop = FALSE]
    lambda_scaled <- lambda_no_int / factor_sds
    
    # Store scaled lambdas (with intercept)
    lambda_scaled_full <- rbind(lambda_raw[1, , drop = FALSE], lambda_scaled)
    scaled_lambdas_out[[model_name]] <- matrix(lambda_scaled_full, nrow = 1,
                                               dimnames = list(date_label, rownames(lambda_scaled_full)))
    
    # Convert to weights (ALWAYS compute)
    if (length(factor_cols) == 1) {
      # Single factor: weight = 1.0 (100%)
      weights_out[[model_name]] <- matrix(1.0, nrow = 1, ncol = 1,
                                          dimnames = list(date_label, factor_cols))
    } else {
      # Multiple factors: normalize to sum = 1
      w <- lambda_scaled / sum(lambda_scaled)
      weights_out[[model_name]] <- matrix(w, nrow = 1,
                                          dimnames = list(date_label, rownames(lambda_scaled)))
    }
  }
  
  ## ---- 4.3.1  Bayesian-Selected Models - ALL FACTORS (Top-All, Top-MPR-All) - Compute lambdas and scaled_lambdas ONLY (no weights) -------------
  for (model_name in names(factor_specs_all)) {
    factor_cols <- factor_specs_all[[model_name]]
    
    # Skip if no factors selected
    if (length(factor_cols) == 0) {
      lambdas_out[[model_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                          dimnames = list(date_label, NULL))
      scaled_lambdas_out[[model_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                                 dimnames = list(date_label, NULL))
      next
    }
    
    lambda_raw <- lambda_hat[[model_name]]
    
    # Store raw lambda
    lambdas_out[[model_name]] <- matrix(lambda_raw, nrow = 1,
                                        dimnames = list(date_label, rownames(lambda_raw)))
    
    # Get factor SDs from f_all
    f_sub <- as.matrix(f_all[, factor_cols, drop = FALSE])
    factor_sds <- colSds(f_sub)
    names(factor_sds) <- factor_cols
    
    # Descale (skip intercept)
    lambda_no_int <- lambda_raw[-1, , drop = FALSE]
    lambda_scaled <- lambda_no_int / factor_sds
    
    # Store scaled lambdas (with intercept)
    lambda_scaled_full <- rbind(lambda_raw[1, , drop = FALSE], lambda_scaled)
    scaled_lambdas_out[[model_name]] <- matrix(lambda_scaled_full, nrow = 1,
                                               dimnames = list(date_label, rownames(lambda_scaled_full)))
    
    # NO WEIGHTS for all-factor models
  }
  
  ## ---- 4.4  RP-PCA Model - Combined (R+f2) -------------
  if (is_nested_rp) {
    rp_combined <- rp_out$combined
  } else {
    rp_combined <- rp_out
  }
  
  lambda_raw_rp <- lambda_hat$`RP-PCA`
  lambdas_out$`RP-PCA` <- matrix(lambda_raw_rp, nrow = 1,
                                 dimnames = list(date_label, rownames(lambda_raw_rp)))
  
  # Descale by PC SDs (omit intercept)
  f_pc   <- rp_combined$factors
  pc_sds <- matrixStats::colSds(f_pc)
  names(pc_sds) <- colnames(f_pc)
  
  lambda_no_int_rp <- drop(lambda_raw_rp[-1, , drop = FALSE])
  stopifnot(all(names(lambda_no_int_rp) %in% names(pc_sds)))
  lambda_scaled_rp <- lambda_no_int_rp / pc_sds[names(lambda_no_int_rp)]
  
  # Store scaled lambdas (with intercept)
  lambda_scaled_full_rp <- rbind(
    intercept = matrix(lambda_raw_rp[1, , drop = FALSE], ncol = 1,
                       dimnames = list(rownames(lambda_raw_rp)[1], colnames(lambda_raw_rp))),
    matrix(lambda_scaled_rp, ncol = 1,
           dimnames = list(names(lambda_scaled_rp), colnames(lambda_raw_rp)))
  )
  scaled_lambdas_out$`RP-PCA` <- matrix(lambda_scaled_full_rp, nrow = 1,
                                        dimnames = list(date_label, rownames(lambda_scaled_full_rp)))
  
  # Convert to asset weights using RAW-space loader
  if (length(f2_names) > 0 && !is.null(rp_combined$w_rpca)) {
    npc <- rp_combined$npc
    L_all <- rp_combined$w_rpca
    pc_keep <- intersect(colnames(L_all), names(lambda_scaled_rp))
    stopifnot(length(pc_keep) == npc)
    Loading_pc <- L_all[, pc_keep, drop = FALSE]
    
    w_rppca_exact <- Loading_pc %*% matrix(lambda_scaled_rp[pc_keep], ncol = 1)
    sum_w <- sum(w_rppca_exact)
    if (abs(sum_w) < 1e-12) warning("RP-PCA combined: sum of weights is ~0; budget-1 normalization may be unstable.")
    w_rppca <- as.vector(w_rppca_exact) / sum_w
    
    asset_names <- if (!is.null(colnames(Rc))) {
      colnames(Rc)
    } else if (!is.null(colnames(R))) {
      colnames(R)
    } else {
      paste0("Asset", seq_len(nrow(Loading_pc)))
    }
    
    weights_out$`RP-PCA` <- matrix(w_rppca, nrow = 1,
                                   dimnames = list(date_label, asset_names))
  } else {
    weights_out$`RP-PCA` <- matrix(numeric(0), nrow = 1, ncol = 0,
                                   dimnames = list(date_label, NULL))
  }
  
  ## ---- 4.4.1  RP-PCA Model - f2 only (RP-PCAf2) - ONLY IF NESTED -------------
  if (is_nested_rp && !is.null(rp_out$f2_only)) {
    lambda_raw_rpf2 <- lambda_hat$`RP-PCAf2`
    lambdas_out$`RP-PCAf2` <- matrix(lambda_raw_rpf2, nrow = 1,
                                     dimnames = list(date_label, rownames(lambda_raw_rpf2)))
    
    f_pc_f2   <- rp_out$f2_only$factors
    pc_sds_f2 <- matrixStats::colSds(f_pc_f2)
    names(pc_sds_f2) <- colnames(f_pc_f2)
    
    lambda_no_int_rpf2 <- drop(lambda_raw_rpf2[-1, , drop = FALSE])
    stopifnot(all(names(lambda_no_int_rpf2) %in% names(pc_sds_f2)))
    lambda_scaled_rpf2 <- lambda_no_int_rpf2 / pc_sds_f2[names(lambda_no_int_rpf2)]
    
    lambda_scaled_full_rpf2 <- rbind(
      intercept = matrix(lambda_raw_rpf2[1, , drop = FALSE], ncol = 1,
                         dimnames = list(rownames(lambda_raw_rpf2)[1], colnames(lambda_raw_rpf2))),
      matrix(lambda_scaled_rpf2, ncol = 1,
             dimnames = list(names(lambda_scaled_rpf2), colnames(lambda_raw_rpf2)))
    )
    scaled_lambdas_out$`RP-PCAf2` <- matrix(lambda_scaled_full_rpf2, nrow = 1,
                                            dimnames = list(date_label, rownames(lambda_scaled_full_rpf2)))
    
    # Weights
    if (length(f2_names) > 0 && !is.null(rp_out$f2_only$w_rpca)) {
      npc_f2 <- rp_out$f2_only$npc
      L_all_f2 <- rp_out$f2_only$w_rpca
      pc_keep_f2 <- intersect(colnames(L_all_f2), names(lambda_scaled_rpf2))
      stopifnot(length(pc_keep_f2) == npc_f2)
      Loading_pc_f2 <- L_all_f2[, pc_keep_f2, drop = FALSE]
      
      w_rppcaf2_exact <- Loading_pc_f2 %*% matrix(lambda_scaled_rpf2[pc_keep_f2], ncol = 1)
      sum_w2 <- sum(w_rppcaf2_exact)
      if (abs(sum_w2) < 1e-12) warning("RP-PCA f2: sum of weights is ~0; budget-1 normalization may be unstable.")
      w_rppcaf2 <- as.vector(w_rppcaf2_exact) / sum_w2
      
      f2_asset_names <- if (!is.null(colnames(f2))) colnames(f2) else paste0("Asset", seq_len(nrow(Loading_pc_f2)))
      
      weights_out$`RP-PCAf2` <- matrix(w_rppcaf2, nrow = 1,
                                       dimnames = list(date_label, f2_asset_names))
    } else {
      weights_out$`RP-PCAf2` <- matrix(numeric(0), nrow = 1, ncol = 0,
                                       dimnames = list(date_label, NULL))
    }
  }
  
  ## ---- 4.4.2  RP-PCA PC Weights (NxN matrices) -------------
  rppca_pcs_weights_matrix   <- if (is_nested_rp) rp_out$combined$w_rpca_sum1 else rp_out$w_rpca_sum1
  rppcaf2_pc_weights_matrix  <- if (is_nested_rp && !is.null(rp_out$f2_only)) rp_out$f2_only$w_rpca_sum1 else NULL
  
  ## ---- 4.5  Standard PCA Model - Combined (R+f2) - ONLY IF pca_out EXISTS -------------
  if (!is.null(pca_out)) {
    if (is_nested_pca) {
      pca_combined <- pca_out$combined
    } else {
      pca_combined <- pca_out
    }
    
    lambda_raw_pca <- lambda_hat$PCA
    lambdas_out$PCA <- matrix(lambda_raw_pca, nrow = 1,
                              dimnames = list(date_label, rownames(lambda_raw_pca)))
    
    f_pc_pca   <- pca_combined$factors
    pc_sds_pca <- matrixStats::colSds(f_pc_pca)
    names(pc_sds_pca) <- colnames(f_pc_pca)
    
    lambda_no_int_pca <- drop(lambda_raw_pca[-1, , drop = FALSE])
    stopifnot(all(names(lambda_no_int_pca) %in% names(pc_sds_pca)))
    lambda_scaled_pca <- lambda_no_int_pca / pc_sds_pca[names(lambda_no_int_pca)]
    
    lambda_scaled_full_pca <- rbind(
      intercept = matrix(lambda_raw_pca[1, , drop = FALSE], ncol = 1,
                         dimnames = list(rownames(lambda_raw_pca)[1], colnames(lambda_raw_pca))),
      matrix(lambda_scaled_pca, ncol = 1,
             dimnames = list(names(lambda_scaled_pca), colnames(lambda_raw_pca)))
    )
    scaled_lambdas_out$PCA <- matrix(lambda_scaled_full_pca, nrow = 1,
                                     dimnames = list(date_label, rownames(lambda_scaled_full_pca)))
    
    # Weights
    if (length(f2_names) > 0 && !is.null(pca_combined$w_rpca)) {
      npc_pca <- pca_combined$npc
      L_all_pca <- pca_combined$w_rpca
      pc_keep_pca <- intersect(colnames(L_all_pca), names(lambda_scaled_pca))
      stopifnot(length(pc_keep_pca) == npc_pca)
      Loading_pc_pca <- L_all_pca[, pc_keep_pca, drop = FALSE]
      
      w_pca_exact <- Loading_pc_pca %*% matrix(lambda_scaled_pca[pc_keep_pca], ncol = 1)
      sum_w_pca <- sum(w_pca_exact)
      if (abs(sum_w_pca) < 1e-12) warning("PCA combined: sum of weights is ~0; budget-1 normalization may be unstable.")
      w_pca <- as.vector(w_pca_exact) / sum_w_pca
      
      asset_names_pca <- if (!is.null(colnames(Rc))) {
        colnames(Rc)
      } else if (!is.null(colnames(R))) {
        colnames(R)
      } else {
        paste0("Asset", seq_len(nrow(Loading_pc_pca)))
      }
      
      weights_out$PCA <- matrix(w_pca, nrow = 1,
                                dimnames = list(date_label, asset_names_pca))
    } else {
      weights_out$PCA <- matrix(numeric(0), nrow = 1, ncol = 0,
                                dimnames = list(date_label, NULL))
    }
    
    ## 4.5.1  Standard PCA Model - f2 only (PCAf2) - ONLY IF NESTED
    if (is_nested_pca && !is.null(pca_out$f2_only)) {
      lambda_raw_pcaf2 <- lambda_hat$PCAf2
      lambdas_out$PCAf2 <- matrix(lambda_raw_pcaf2, nrow = 1,
                                  dimnames = list(date_label, rownames(lambda_raw_pcaf2)))
      
      f_pc_f2_pca   <- pca_out$f2_only$factors
      pc_sds_f2_pca <- matrixStats::colSds(f_pc_f2_pca)
      names(pc_sds_f2_pca) <- colnames(f_pc_f2_pca)
      
      lambda_no_int_pcaf2 <- drop(lambda_raw_pcaf2[-1, , drop = FALSE])
      stopifnot(all(names(lambda_no_int_pcaf2) %in% names(pc_sds_f2_pca)))
      lambda_scaled_pcaf2 <- lambda_no_int_pcaf2 / pc_sds_f2_pca[names(lambda_no_int_pcaf2)]
      
      lambda_scaled_full_pcaf2 <- rbind(
        intercept = matrix(lambda_raw_pcaf2[1, , drop = FALSE], ncol = 1,
                           dimnames = list(rownames(lambda_raw_pcaf2)[1], colnames(lambda_raw_pcaf2))),
        matrix(lambda_scaled_pcaf2, ncol = 1,
               dimnames = list(names(lambda_scaled_pcaf2), colnames(lambda_raw_pcaf2)))
      )
      scaled_lambdas_out$PCAf2 <- matrix(lambda_scaled_full_pcaf2, nrow = 1,
                                         dimnames = list(date_label, rownames(lambda_scaled_full_pcaf2)))
      
      # Weights
      if (length(f2_names) > 0 && !is.null(pca_out$f2_only$w_rpca)) {
        npc_f2_pca <- pca_out$f2_only$npc
        L_all_f2_pca <- pca_out$f2_only$w_rpca
        pc_keep_f2_pca <- intersect(colnames(L_all_f2_pca), names(lambda_scaled_pcaf2))
        stopifnot(length(pc_keep_f2_pca) == npc_f2_pca)
        Loading_pc_f2_pca <- L_all_f2_pca[, pc_keep_f2_pca, drop = FALSE]
        
        w_pcaf2_exact <- Loading_pc_f2_pca %*% matrix(lambda_scaled_pcaf2[pc_keep_f2_pca], ncol = 1)
        sum_w2_pca <- sum(w_pcaf2_exact)
        if (abs(sum_w2_pca) < 1e-12) warning("PCA f2: sum of weights is ~0; budget-1 normalization may be unstable.")
        w_pcaf2 <- as.vector(w_pcaf2_exact) / sum_w2_pca
        
        f2_asset_names_pca <- if (!is.null(colnames(f2))) colnames(f2) else paste0("Asset", seq_len(nrow(Loading_pc_f2_pca)))
        
        weights_out$PCAf2 <- matrix(w_pcaf2, nrow = 1,
                                    dimnames = list(date_label, f2_asset_names_pca))
      } else {
        weights_out$PCAf2 <- matrix(numeric(0), nrow = 1, ncol = 0,
                                    dimnames = list(date_label, NULL))
      }
    }
    
    ## 4.5.2  Standard PCA PC Weights
    pca_pcs_weights_matrix   <- if (is_nested_pca) pca_out$combined$w_rpca_sum1 else pca_out$w_rpca_sum1
    pcaf2_pc_weights_matrix  <- if (is_nested_pca && !is.null(pca_out$f2_only)) pca_out$f2_only$w_rpca_sum1 else NULL
  } else {
    # No PCA output
    pca_pcs_weights_matrix <- NULL
    pcaf2_pc_weights_matrix <- NULL
  }
  
  ## ---- 4.6  KNS Model - Combined (R+f2) -------------
  if (is_nested_kns) {
    kns_combined <- kns_out$combined
  } else {
    kns_combined <- kns_out
  }
  
  lambda_raw_kns <- lambda_hat$KNS
  lambdas_out$KNS <- matrix(lambda_raw_kns, nrow = 1,
                            dimnames = list(date_label, rownames(lambda_raw_kns)))
  
  # For KNS, lambdas are already from standardized data
  scaled_lambdas_out$KNS <- matrix(lambda_raw_kns, nrow = 1,
                                   dimnames = list(date_label, rownames(lambda_raw_kns)))
  
  # Extract weights
  if (is_nested_kns) {
    w_kns <- kns_combined$kns_w1
  } else {
    # Flat structure: compute weights from PCs
    # This is a fallback for unconditional estimate_kns_oos()
    # We need to compute the tradable weights
    # For now, create empty weights as fallback
    w_kns <- NULL
  }
  
  if (!is.null(w_kns)) {
    asset_names <- if (!is.null(colnames(Rc))) {
      colnames(Rc)
    } else {
      paste0("Asset", 1:length(w_kns))
    }
    
    weights_out$KNS <- matrix(as.vector(w_kns), nrow = 1,
                              dimnames = list(date_label, asset_names))
  } else {
    weights_out$KNS <- matrix(numeric(0), nrow = 1, ncol = 0,
                              dimnames = list(date_label, NULL))
  }
  
  ## ---- 4.7  KNS Model - f2 only (KNSf2) - ONLY IF NESTED -------------
  if (is_nested_kns && !is.null(kns_out$f2_only)) {
    lambda_raw_knsf2 <- lambda_hat$KNSf2
    lambdas_out$KNSf2 <- matrix(lambda_raw_knsf2, nrow = 1,
                                dimnames = list(date_label, rownames(lambda_raw_knsf2)))
    
    scaled_lambdas_out$KNSf2 <- matrix(lambda_raw_knsf2, nrow = 1,
                                       dimnames = list(date_label, rownames(lambda_raw_knsf2)))
    
    w_knsf2 <- kns_out$f2_only$kns_w1
    f2_asset_names <- if (!is.null(colnames(f2))) {
      colnames(f2)
    } else {
      paste0("Asset", 1:length(w_knsf2))
    }
    
    weights_out$KNSf2 <- matrix(as.vector(w_knsf2), nrow = 1,
                                dimnames = list(date_label, f2_asset_names))
  }
  
  ## ---- 4.8  KNS PC Weights (NxN matrices) -------------
  kns_pcs_weights_matrix <- if (is_nested_kns) kns_out$combined$w_sum1_pc else NULL
  knsf2_pc_weights_matrix <- if (is_nested_kns && !is.null(kns_out$f2_only)) kns_out$f2_only$w_sum1_pc else NULL
  
  ## ---- 4.9  Optimal Portfolios - Lambdas, Scaled Lambdas, and Weights -------------
  # Store weights from pre-computed optimal_weights (computed in Section 0.2)
  # Store lambdas and scaled_lambdas from GMM estimation (computed in Section 1)
  # Two versions: combined (R+f2) and f2-only
  
  optimal_model_names <- c("Tangency", "MinVar", "EqualWeight", 
                           "Tangencyf2", "MinVarf2", "EqualWeightf2")
  
  for (opt_name in optimal_model_names) {
    # Check if this optimal portfolio was successfully computed
    if (!is.null(optimal_portfolios[[opt_name]]) && !is.null(lambda_hat[[opt_name]])) {
      
      # Get GMM lambda (from Section 1)
      lambda_raw_opt <- lambda_hat[[opt_name]]
      
      # Store raw lambda
      lambdas_out[[opt_name]] <- matrix(lambda_raw_opt, nrow = 1,
                                        dimnames = list(date_label, rownames(lambda_raw_opt)))
      
      # Descale by portfolio return SD (single factor, skip intercept)
      port_sd <- sd(optimal_portfolios[[opt_name]])
      lambda_no_int_opt <- lambda_raw_opt[-1, , drop = FALSE]
      lambda_scaled_opt <- lambda_no_int_opt / port_sd
      
      # Store scaled lambdas (with intercept)
      lambda_scaled_full_opt <- rbind(lambda_raw_opt[1, , drop = FALSE], lambda_scaled_opt)
      scaled_lambdas_out[[opt_name]] <- matrix(lambda_scaled_full_opt, nrow = 1,
                                               dimnames = list(date_label, rownames(lambda_scaled_full_opt)))
      
      # Store weights from pre-computed optimal_weights
      w_opt <- optimal_weights[[opt_name]]
      weights_out[[opt_name]] <- matrix(w_opt, nrow = 1,
                                        dimnames = list(date_label, names(w_opt)))
    } else {
      # Failed or not available
      lambdas_out[[opt_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                        dimnames = list(date_label, NULL))
      scaled_lambdas_out[[opt_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                               dimnames = list(date_label, NULL))
      weights_out[[opt_name]] <- matrix(numeric(0), nrow = 1, ncol = 0,
                                        dimnames = list(date_label, NULL))
    }
  }
  
  ## ---- 5  Estimate expected returns (DYNAMIC) -------------
  get_cor <- function(x) cor(Rc, as.matrix(x))
  
  # Start with BMA models
  ER_pred <- list(
    `BMA-20%` = C_f %*% lambda_bma$`BMA-20%`,
    `BMA-40%` = C_f %*% lambda_bma$`BMA-40%`,
    `BMA-60%` = C_f %*% lambda_bma$`BMA-60%`,
    `BMA-80%` = C_f %*% lambda_bma$`BMA-80%`
  )
  
  # Add frequentist models dynamically (use fac_freq)
  for (model_name in names(freq_models)) {
    factor_cols <- freq_models[[model_name]]
    ER_pred[[model_name]] <- cbind(1, get_cor(fac_freq[, factor_cols, drop = FALSE])) %*% 
      lambda_hat[[model_name]]
  }
  
  # Add Bayesian-selected f2-only models (use f_all)
  for (model_name in names(factor_specs_bayesian)) {
    factor_cols <- factor_specs_bayesian[[model_name]]
    if (length(factor_cols) > 0) {
      ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*% 
        lambda_hat[[model_name]]
    }
  }
  
  # Add Bayesian-selected all-factor models (use f_all)
  for (model_name in names(factor_specs_all)) {
    factor_cols <- factor_specs_all[[model_name]]
    if (length(factor_cols) > 0) {
      ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*% 
        lambda_hat[[model_name]]
    }
  }
  
  # Add optimal portfolio models (single-factor)
  for (opt_name in optimal_model_names) {
    if (!is.null(optimal_portfolios[[opt_name]]) && !is.null(lambda_hat[[opt_name]])) {
      ER_pred[[opt_name]] <- cbind(1, get_cor(optimal_portfolios[[opt_name]])) %*% 
        lambda_hat[[opt_name]]
    }
  }
  
  # Add RP-PCA models
  if (is_nested_rp) {
    ER_pred$`RP-PCA` <- cbind(1, get_cor(rp_out$combined$factors)) %*% lambda_hat$`RP-PCA`
    if (!is.null(rp_out$f2_only)) {
      ER_pred$`RP-PCAf2` <- cbind(1, get_cor(rp_out$f2_only$factors)) %*% lambda_hat$`RP-PCAf2`
    }
  } else {
    ER_pred$`RP-PCA` <- cbind(1, get_cor(rp_out$factors)) %*% lambda_hat$`RP-PCA`
  }
  
  # Add PCA models (if available)
  if (!is.null(pca_out)) {
    if (is_nested_pca) {
      ER_pred$PCA <- cbind(1, get_cor(pca_out$combined$factors)) %*% lambda_hat$PCA
      if (!is.null(pca_out$f2_only)) {
        ER_pred$PCAf2 <- cbind(1, get_cor(pca_out$f2_only$factors)) %*% lambda_hat$PCAf2
      }
    } else {
      ER_pred$PCA <- cbind(1, get_cor(pca_out$factors)) %*% lambda_hat$PCA
    }
  }
  
  # Add KNS models (no intercept for KNS)
  if (is_nested_kns) {
    # For nested structure: match old workflow exactly
    # 1. Standardize returns
    Rc_std <- scale(Rc, center = FALSE, scale = colSds(Rc))
    
    # 2. Get Q matrix and raw lambdas
    Q_combined <- kns_out$combined$pca_output[[2]]
    lambda_raw <- kns_out$combined$kns_lambdas
    
    # 3. Create ALL PCs from standardized returns
    PCs_all <- Rc_std %*% Q_combined  # T x N matrix
    
    # 4. Scale lambdas by PC standard deviations
    lambda_scaled <- lambda_raw * colSds(PCs_all)
    
    # 5. Filter to non-zero lambdas only
    nz_idx <- which(abs(lambda_scaled) > 1e-10)
    lambda_final <- lambda_scaled[nz_idx, , drop = FALSE]
    PCs_filtered <- PCs_all[, nz_idx, drop = FALSE]
    
    # 6. Re-standardize the filtered PCs
    PCs_std <- scale(PCs_filtered, center = FALSE, scale = colSds(PCs_filtered))
    
    # 7. Use for ER_pred
    ER_pred$KNS <- get_cor(PCs_std) %*% lambda_final
    
    # Repeat for f2_only if available
    if (!is.null(kns_out$f2_only)) {
      f2_std <- scale(f2, center = FALSE, scale = colSds(f2))
      Q_f2 <- kns_out$f2_only$pca_output[[2]]
      lambda_raw_f2 <- kns_out$f2_only$kns_lambdas
      
      PCs_all_f2 <- f2_std %*% Q_f2
      lambda_scaled_f2 <- lambda_raw_f2 * colSds(PCs_all_f2)
      
      nz_idx_f2 <- which(abs(lambda_scaled_f2) > 1e-10)
      lambda_final_f2 <- lambda_scaled_f2[nz_idx_f2, , drop = FALSE]
      PCs_filtered_f2 <- PCs_all_f2[, nz_idx_f2, drop = FALSE]
      
      PCs_std_f2 <- scale(PCs_filtered_f2, center = FALSE, scale = colSds(PCs_filtered_f2))
      
      ER_pred$KNSf2 <- get_cor(PCs_std_f2) %*% lambda_final_f2
    }
  } else {
    ER_pred$KNS <- get_cor(kns_out$PCs_unscaled) %*% lambda_hat$KNS
  }
  
  ER_pred_all_in <- do.call(cbind, ER_pred) * sqrt(12)   # N x Nm matrix
  Nm             <- dim(ER_pred_all_in)[2]
  
  # ER.in is the matrix of unconditional Sharpe ratios
  ER.in    <- matrix(sqrt(12)*colMeans(Rc)/colSds(Rc), ncol=1)
  # Pricing errors
  alpha_in        <- ER.in %*% matrix(1,nrow=1,ncol=Nm) - ER_pred_all_in[,c(1:Nm)]
  
  ## ---- 6  In-sample pricing diagnostics  ->  is_pricing_result -------------
  
  # --- helpers computed once ---------------------------------------------
  Sigma_inv  <- solve(W)                          # W = cor(Rc) from above
  # SR_scalar computation --------------------------------------------------------
  SR_scalar <- tryCatch(
    12 * SharpeRatio(Rc)[1, 1],
    error = function(e) {
      if (grepl("incorrect number of dimensions", e$message)) {
        12 * as.numeric(SharpeRatio(Rc))
      } else {
        stop(e)
      }
    }
  )
  
  # --- pricing errors -----------------------------------------------------
  dm_alpha   <- sweep(alpha_in, 2, colMeans(alpha_in))     # demeaned across assets
  
  # --- metric functions (vectorised) --------------------------------------
  rmse   <- function(mat) sqrt(colMeans(mat^2))
  mape   <- function(mat)        colMeans(abs(mat))
  r2_ols <- function(mat) 1 - apply(mat, 2, var) / var(drop(ER.in))
  r2_gls <- function(mat)
    1 - diag(t(mat) %*% Sigma_inv %*% mat) / SR_scalar
  
  # --- assemble neatly ----------------------------------------------------
  is_pricing_result <- rbind(
    RMSEdm = rmse(dm_alpha),
    MAPEdm = mape(dm_alpha),
    R2OLS  = r2_ols(alpha_in),
    R2GLS  = r2_gls(alpha_in)
  ) |>
    as.data.frame() |>
    `colnames<-`(names(ER_pred)) |>
    tibble::rownames_to_column(var = "metric")
  
  ## ---- 7  Model-implied SDF series  ->  sdf_mat  (T x K)  (ROBUST) -------------
  # helper: build one SDF time-series --------------------------------------
  compute_sdf <- function(F_mat, lambda, intercept = TRUE) {
    slope <- if (intercept) lambda[-1, , drop = TRUE] else lambda[, , drop = TRUE]
    slope <- as.vector(slope) / colSds(F_mat)             # scale by sigma_f
    sdf   <- 1 - as.vector(F_mat %*% slope)               # m_t = 1 - f_t'lambda
    1 + sdf - mean(sdf)                                   # re-centre => E[m]=1
  }
  
  # Build SDF specs dynamically
  sdf_specs <- list()
  
  # Add frequentist models - use fac_freq
  for (model_name in names(freq_models)) {
    factor_cols <- freq_models[[model_name]]
    
    # Check if all factors are available in fac_freq
    if (all(factor_cols %in% colnames(fac_freq))) {
      sdf_specs[[model_name]] <- list(
        X = as.matrix(fac_freq[, factor_cols, drop = FALSE]),
        lambda = insample_lambda[[model_name]],
        int = TRUE
      )
    }
  }
  
  # Add Bayesian-selected f2-only models - use f_all
  for (model_name in names(factor_specs_bayesian)) {
    factor_cols <- factor_specs_bayesian[[model_name]]
    
    # Check if all factors are available in f_all
    if (length(factor_cols) > 0 && all(factor_cols %in% colnames(f_all))) {
      sdf_specs[[model_name]] <- list(
        X = as.matrix(f_all[, factor_cols, drop = FALSE]),
        lambda = insample_lambda[[model_name]],
        int = TRUE
      )
    }
  }
  
  # Add Bayesian-selected all-factor models - use f_all
  for (model_name in names(factor_specs_all)) {
    factor_cols <- factor_specs_all[[model_name]]
    
    # Check if all factors are available in f_all
    if (length(factor_cols) > 0 && all(factor_cols %in% colnames(f_all))) {
      sdf_specs[[model_name]] <- list(
        X = as.matrix(f_all[, factor_cols, drop = FALSE]),
        lambda = insample_lambda[[model_name]],
        int = TRUE
      )
    }
  }
  
  # Add optimal portfolio models (single-factor)
  for (opt_name in optimal_model_names) {
    if (!is.null(optimal_portfolios[[opt_name]]) && !is.null(insample_lambda[[opt_name]])) {
      sdf_specs[[opt_name]] <- list(
        X = optimal_portfolios[[opt_name]],
        lambda = insample_lambda[[opt_name]],
        int = TRUE
      )
    }
  }
  
  # Always add RP-PCA models (data-driven, always available)
  if (is_nested_rp) {
    sdf_specs$`RP-PCA` <- list(
      X = rp_out$combined$factors,
      lambda = insample_lambda$`RP-PCA`,
      int = TRUE
    )
    if (!is.null(rp_out$f2_only)) {
      sdf_specs$`RP-PCAf2` <- list(
        X = rp_out$f2_only$factors,
        lambda = insample_lambda$`RP-PCAf2`,
        int = TRUE
      )
    }
  } else {
    sdf_specs$`RP-PCA` <- list(
      X = rp_out$factors,
      lambda = insample_lambda$`RP-PCA`,
      int = TRUE
    )
  }
  
  # Add PCA models (if available)
  if (!is.null(pca_out)) {
    if (is_nested_pca) {
      sdf_specs$PCA <- list(
        X = pca_out$combined$factors,
        lambda = insample_lambda$PCA,
        int = TRUE
      )
      if (!is.null(pca_out$f2_only)) {
        sdf_specs$PCAf2 <- list(
          X = pca_out$f2_only$factors,
          lambda = insample_lambda$PCAf2,
          int = TRUE
        )
      }
    } else {
      sdf_specs$PCA <- list(
        X = pca_out$factors,
        lambda = insample_lambda$PCA,
        int = TRUE
      )
    }
  }
  
  # Add KNS models
  if (is_nested_kns) {
    # For nested structure: match old workflow exactly
    # 1. Standardize returns
    Rc_std <- scale(Rc, center = FALSE, scale = colSds(Rc))
    
    # 2. Get Q matrix and raw lambdas
    Q_combined <- kns_out$combined$pca_output[[2]]
    lambda_raw <- kns_out$combined$kns_lambdas
    
    # 3. Create ALL PCs from standardized returns
    PCs_all <- Rc_std %*% Q_combined  # T x N matrix
    
    # 4. Scale lambdas by PC standard deviations
    lambda_scaled <- lambda_raw * colSds(PCs_all)
    
    # 5. Filter to non-zero lambdas only
    nz_idx <- which(abs(lambda_scaled) > 1e-10)
    lambda_final <- lambda_scaled[nz_idx, , drop = FALSE]
    PCs_filtered <- PCs_all[, nz_idx, drop = FALSE]
    
    # 6. Re-standardize the filtered PCs
    PCs_std <- scale(PCs_filtered, center = FALSE, scale = colSds(PCs_filtered))
    
    # 7. Use for SDF
    sdf_specs$KNS <- list(
      X = PCs_std,
      lambda = lambda_final,
      int = FALSE           # KNS lambda already has no intercept
    )
    
    # Repeat for f2_only if available
    if (!is.null(kns_out$f2_only)) {
      f2_std <- scale(f2, center = FALSE, scale = colSds(f2))
      Q_f2 <- kns_out$f2_only$pca_output[[2]]
      lambda_raw_f2 <- kns_out$f2_only$kns_lambdas
      
      PCs_all_f2 <- f2_std %*% Q_f2
      lambda_scaled_f2 <- lambda_raw_f2 * colSds(PCs_all_f2)
      
      nz_idx_f2 <- which(abs(lambda_scaled_f2) > 1e-10)
      lambda_final_f2 <- lambda_scaled_f2[nz_idx_f2, , drop = FALSE]
      PCs_filtered_f2 <- PCs_all_f2[, nz_idx_f2, drop = FALSE]
      
      PCs_std_f2 <- scale(PCs_filtered_f2, center = FALSE, scale = colSds(PCs_filtered_f2))
      
      sdf_specs$KNSf2 <- list(
        X = PCs_std_f2,
        lambda = lambda_final_f2,
        int = FALSE
      )
    }
  } else {
    sdf_specs$KNS <- list(
      X = kns_out$PCs_unscaled,
      lambda = insample_lambda$KNS,
      int = FALSE
    )
  }
  
  # build all SDFs in one sweep -------------------------------------------
  sdf_list <- imap(
    sdf_specs,
    ~ compute_sdf(.x$X, .x$lambda, intercept = .x$int)
  )
  
  sdf_mat <- do.call(cbind, sdf_list)    # T x K matrix
  colnames(sdf_mat) <- names(sdf_list)
  
  ## ---- 7.1  Mimicking Portfolio Returns (sdf_mim) -------------
  # Compute portfolio returns using weights applied to appropriate asset universe
  # Combined models (weights over Rc) vs f2-only models (weights over f2)
  # vs frequentist models (weights over fac_freq)
  
  Rc_mat <- as.matrix(Rc)
  Rc_names <- colnames(Rc_mat)
  f2_mat <- if (!is.null(f2)) as.matrix(f2) else NULL
  fac_freq_mat <- as.matrix(fac_freq)
  fac_freq_names <- colnames(fac_freq_mat)
  
  sdf_mim_list <- list()
  
  for (model_name in names(weights_out)) {
    w_matrix <- weights_out[[model_name]]
    
    # Skip if weights are empty
    if (ncol(w_matrix) == 0) next
    
    # Extract weight vector (1-row matrix to vector)
    w_vec <- as.vector(w_matrix)
    w_names <- colnames(w_matrix)
    names(w_vec) <- w_names
    
    # Determine which asset universe to use based on weight names
    if (all(w_names %in% Rc_names)) {
      # Combined model - use Rc
      # Align weights to Rc column order
      w_aligned <- w_vec[Rc_names]
      w_aligned[is.na(w_aligned)] <- 0
      port_ret <- as.vector(Rc_mat %*% w_aligned)
    } else if (!is.null(f2_mat) && all(w_names %in% f2_names)) {
      # f2-only model - use f2
      # Align weights to f2 column order
      w_aligned <- w_vec[f2_names]
      w_aligned[is.na(w_aligned)] <- 0
      port_ret <- as.vector(f2_mat %*% w_aligned)
    } else if (all(w_names %in% fac_freq_names)) {
      # Frequentist model - use fac_freq
      # Align weights to fac_freq column order (only use relevant columns)
      fac_freq_sub <- fac_freq_mat[, w_names, drop = FALSE]
      port_ret <- as.vector(fac_freq_sub %*% w_vec)
    } else {
      # Mixed or unknown - skip with warning
      warning(paste0("Model '", model_name, "': weight names don't match Rc, f2, or fac_freq columns. Skipping."))
      next
    }
    
    sdf_mim_list[[model_name]] <- port_ret
  }
  
  # Combine into matrix
  if (length(sdf_mim_list) > 0) {
    sdf_mim <- do.call(cbind, sdf_mim_list)
    colnames(sdf_mim) <- names(sdf_mim_list)
  } else {
    sdf_mim <- matrix(numeric(0), nrow = nrow(Rc_mat), ncol = 0)
  }
  
  ## ---- 7.2  Add date as first column to sdf_mat and sdf_mim -------------
  if (!is.null(dates)) {
    # Convert dates to character if needed
    date_col <- as.character(dates)
    
    # Add date column to sdf_mat
    sdf_mat <- cbind(date = date_col, as.data.frame(sdf_mat))
    
    # Add date column to sdf_mim
    if (ncol(sdf_mim) > 0) {
      sdf_mim <- cbind(date = date_col, as.data.frame(sdf_mim))
    } else {
      sdf_mim <- data.frame(date = date_col)
    }
  }
  
  ## ---- 8  Return results -------------
  return(list(
    lambdas           = lambdas_out,
    scaled_lambdas    = scaled_lambdas_out,
    weights           = weights_out,
    gammas            = gammas_out,
    date_end          = date_end,
    dates             = dates,
    top_factors       = top5_list_f2,
    top_mpr_factors   = top5_mpr_list_f2,
    top_factors_all   = top5_list_all,
    top_mpr_factors_all = top5_mpr_list_all,
    kns_pcs_weights   = kns_pcs_weights_matrix,
    knsf2_pc_weights  = knsf2_pc_weights_matrix,
    rppca_pcs_weights = rppca_pcs_weights_matrix,
    rppcaf2_pc_weights = rppcaf2_pc_weights_matrix,
    pca_pcs_weights   = pca_pcs_weights_matrix,
    pcaf2_pc_weights  = pcaf2_pc_weights_matrix,
    is_pricing_result = is_pricing_result,
    sdf_mat           = sdf_mat,
    sdf_mim           = sdf_mim
  ))
}