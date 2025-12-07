#' In-Sample Asset Pricing with Time-Varying Outputs
#'
#' Computes lambdas, scaled lambdas, weights, and gammas for time-varying estimation.
#' Designed for expanding/rolling window analysis where we need to extract weights
#' at each time period.
#'
#' @param results MCMC results list (4 elements for different psi)
#' @param f_all Matrix of all factors (non-traded + traded)
#' @param R Matrix of test asset returns
#' @param f1 Matrix of non-traded factors
#' @param f2 Matrix of traded factors (can be NULL for treasury models)
#' @param rp_out RP-PCA output from estim_rppca()
#' @param pca_out Standard PCA output from estim_rppca() with kappa=0
#' @param kns_out KNS output from estimate_kns_oos_ts()
#' @param intercept Logical, whether model includes intercept
#' @param fac_freq Matrix of frequentist model factors
#' @param frequentist_models Named list of frequentist model specifications
#' @param date_end Character or Date, last date of estimation window (YYYY-MM-DD)
#'
#' @return List with elements:
#'   - lambdas: Raw lambda estimates (matrices with date_end as rowname)
#'   - scaled_lambdas: Lambdas descaled by factor SDs
#'   - weights: Asset weights (normalized to sum to 1)
#'   - gammas: Average gamma (inclusion probabilities) for BMA models
#'   - date_end: Last date of estimation period
#'   - top_factors: Top 5 f2 factors by gamma for each psi
#'   - top_mpr_factors: Top 5 f2 factors by absolute MPR for each psi
#'   - top_factors_all: Top 5 all factors by gamma for each psi
#'   - top_mpr_factors_all: Top 5 all factors by absolute MPR for each psi
#'   - kns_pcs_weights: NxN matrix of PC weights from KNS combined (R+f2)
#'   - knsf2_pc_weights: MxM matrix of PC weights from KNS f2_only
#'   - rppca_pcs_weights: NxN matrix of PC weights from RP-PCA combined (R+f2)
#'   - rppcaf2_pc_weights: MxM matrix of PC weights from RP-PCA f2_only
#'   - pca_pcs_weights: NxN matrix of PC weights from PCA combined (R+f2)
#'   - pcaf2_pc_weights: MxM matrix of PC weights from PCA f2_only

insample_asset_pricing_time_varying <- function(results, f_all, R, f1, f2,
                                                rp_out, pca_out, kns_out,
                                                intercept,
                                                fac_freq,
                                                frequentist_models = NULL,
                                                date_end = NULL,
                                                drop_draws_pct = 0
) {
  
  library(purrr)          # functional helpers
  library(dplyr)          # select, mutate, ...
  library(matrixStats)    # for colSds()
  
  select  <- dplyr::select
  
  
  #### BMA results extraction with burn-in handling ####
 
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
  
  ## -----------------------------------------------------------------------
  ## 0  House-keeping
  ## -----------------------------------------------------------------------
  W  <- cor(Rc)           # weighting matrix, computed once
  N  <- ncol(Rc)          # number of test assets
  
  # Weighting matrix for f2-only models (RP-PCAf2)
  W_f2 <- if (!is.null(f2)) cor(f2) else NULL
  
  ## -----------------------------------------------------------------------
  ## 1  lambda-hat estimates for the "frequentist" models (DYNAMIC)
  ## -----------------------------------------------------------------------
  
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
  
  # add RP-PCA and KNS (always included)
  lambda_hat$`RP-PCA`   <- gmm_estimation(Rc, rp_out$combined$factors, W, include.intercept = TRUE)
  lambda_hat$`RP-PCAf2` <- gmm_estimation(f2, rp_out$f2_only$factors, W_f2, include.intercept = TRUE)
  lambda_hat$PCA        <- gmm_estimation(Rc, pca_out$combined$factors, W, include.intercept = TRUE)
  lambda_hat$PCAf2      <- gmm_estimation(f2, pca_out$f2_only$factors, W_f2, include.intercept = TRUE)
  lambda_hat$KNS        <- as.matrix(kns_out$combined$kns_lambdas)
  lambda_hat$KNSf2      <- as.matrix(kns_out$f2_only$kns_lambdas)
  
  ## -----------------------------------------------------------------------
  ## 2  lambda-hat estimates for the four BMA shrinkage levels
  ## -----------------------------------------------------------------------
  lambda_bma <- list(
    `BMA-20%` = lambda.bma.psi1,
    `BMA-40%` = lambda.bma.psi2,
    `BMA-60%` = lambda.bma.psi3,
    `BMA-80%` = lambda.bma.psi4
  )
  
  ## -----------------------------------------------------------------------
  ## 3  Neatly bundled outputs
  ## -----------------------------------------------------------------------
  insample_lambda      <- lambda_hat
  insample_lambda_bma  <- lambda_bma
  
  ## -----------------------------------------------------------------------
  ## 4  Descale lambdas and convert to weights
  ## -----------------------------------------------------------------------
  
  # Validate date_end parameter
  if (is.null(date_end)) {
    stop("date_end is required for time-varying estimation. Provide the last date of the estimation window.")
  }
  
  # Convert to character for row naming
  date_label <- as.character(date_end)
  
  # Initialize output lists
  lambdas_out <- list()
  scaled_lambdas_out <- list()
  weights_out <- list()
  gammas_out <- list()
  
  ## -----------------------------------------------------------------------
  ## 4.1  BMA Models
  ## -----------------------------------------------------------------------
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
    
    # FIXED: Add names to lambda_raw based on intercept and f_all structure
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
      # FIXED: Extract factors (excluding intercept if present) with names preserved
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
    # FIXED: Ensure gamma names match factor names (no intercept in gamma)
    names(gamma_avg) <- names
    gammas_out[[psi_name]] <- matrix(gamma_avg, nrow = 1,
                                     dimnames = list(date_label, names(gamma_avg)))
  }
  
  ## -----------------------------------------------------------------------
  ## 4.2  Frequentist Models
  ## -----------------------------------------------------------------------
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
    
    # Convert to weights
    # FIX: ALWAYS compute weights for frequentist models (regardless of f2 membership)
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
  
  ## -----------------------------------------------------------------------
  ## 4.3  Bayesian-Selected Models - f2-only (Top, Top-MPR)
  ## -----------------------------------------------------------------------
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
    
    # Convert to weights
    # FIX: ALWAYS compute weights for Bayesian-selected models (regardless of f2 membership)
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
  
  ## -----------------------------------------------------------------------
  ## 4.3.1  Bayesian-Selected Models - ALL FACTORS (Top-All, Top-MPR-All)
  ##        Compute lambdas and scaled_lambdas ONLY (no weights)
  ## -----------------------------------------------------------------------
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
  
  ## -----------------------------------------------------------------------
  ## 4.4  RP-PCA Model - Combined (R+f2)
  ## -----------------------------------------------------------------------
  lambda_raw_rp <- lambda_hat$`RP-PCA`
  lambdas_out$`RP-PCA` <- matrix(lambda_raw_rp, nrow = 1,
                                 dimnames = list(date_label, rownames(lambda_raw_rp)))
  
  # --- Descale by PC SDs (omit intercept) ---------------------------------
  f_pc   <- rp_out$combined$factors                      # T x K factors actually priced
  pc_sds <- matrixStats::colSds(f_pc)                    # K
  names(pc_sds) <- colnames(f_pc)
  
  lambda_no_int_rp <- drop(lambda_raw_rp[-1, , drop = FALSE])  # length K, named by PCs
  # Align names explicitly to avoid accidental mismatch
  stopifnot(all(names(lambda_no_int_rp) %in% names(pc_sds)))
  lambda_scaled_rp <- lambda_no_int_rp / pc_sds[names(lambda_no_int_rp)]  # back on f_pc scale
  
  # --- Store scaled lambdas (with intercept) -------------------------------
  lambda_scaled_full_rp <- rbind(
    intercept = matrix(lambda_raw_rp[1, , drop = FALSE], ncol = 1,
                       dimnames = list(rownames(lambda_raw_rp)[1], colnames(lambda_raw_rp))),
    matrix(lambda_scaled_rp, ncol = 1,
           dimnames = list(names(lambda_scaled_rp), colnames(lambda_raw_rp)))
  )
  scaled_lambdas_out$`RP-PCA` <- matrix(lambda_scaled_full_rp, nrow = 1,
                                        dimnames = list(date_label, rownames(lambda_scaled_full_rp)))
  
  # --- Convert to asset weights using RAW-space loader ---------------------
  if (length(f2_names) > 0 && !is.null(rp_out$combined$w_rpca)) {
    # Number of PCs used
    npc <- rp_out$combined$npc
    
    # RAW-space loader L = S^{-1} V (reproduces f_pc from RAW returns):
    # use the first npc PCs and align columns by PC names used in lambda
    L_all <- rp_out$combined$w_rpca                       # (N_assets_total) x (num_PCs_available)
    pc_keep <- intersect(colnames(L_all), names(lambda_scaled_rp))
    stopifnot(length(pc_keep) == npc)
    Loading_pc <- L_all[, pc_keep, drop = FALSE]          # N x npc
    
    # EXACT replication weights for r_combo = f_pc %*% lambda_scaled_rp
    w_rppca_exact <- Loading_pc %*% matrix(lambda_scaled_rp[pc_keep], ncol = 1)
    
    # Optional: budget-1 normalization (changes only scale)
    sum_w <- sum(w_rppca_exact)
    if (abs(sum_w) < 1e-12) warning("RP-PCA combined: sum of weights is ~0; budget-1 normalization may be unstable.")
    w_rppca <- as.vector(w_rppca_exact) / sum_w
    
    # Asset names (prefer Rc, then R, else generic)
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
  
  ## -----------------------------------------------------------------------
  ## 4.4.1  RP-PCA Model - f2 only (RP-PCAf2)
  ## -----------------------------------------------------------------------
  lambda_raw_rpf2 <- lambda_hat$`RP-PCAf2`
  lambdas_out$`RP-PCAf2` <- matrix(lambda_raw_rpf2, nrow = 1,
                                   dimnames = list(date_label, rownames(lambda_raw_rpf2)))
  
  # --- Descale by PC SDs (omit intercept) ---------------------------------
  f_pc_f2   <- rp_out$f2_only$factors
  pc_sds_f2 <- matrixStats::colSds(f_pc_f2)
  names(pc_sds_f2) <- colnames(f_pc_f2)
  
  lambda_no_int_rpf2 <- drop(lambda_raw_rpf2[-1, , drop = FALSE])
  stopifnot(all(names(lambda_no_int_rpf2) %in% names(pc_sds_f2)))
  lambda_scaled_rpf2 <- lambda_no_int_rpf2 / pc_sds_f2[names(lambda_no_int_rpf2)]
  
  # --- Store scaled lambdas (with intercept) -------------------------------
  lambda_scaled_full_rpf2 <- rbind(
    intercept = matrix(lambda_raw_rpf2[1, , drop = FALSE], ncol = 1,
                       dimnames = list(rownames(lambda_raw_rpf2)[1], colnames(lambda_raw_rpf2))),
    matrix(lambda_scaled_rpf2, ncol = 1,
           dimnames = list(names(lambda_scaled_rpf2), colnames(lambda_raw_rpf2)))
  )
  scaled_lambdas_out$`RP-PCAf2` <- matrix(lambda_scaled_full_rpf2, nrow = 1,
                                          dimnames = list(date_label, rownames(lambda_scaled_full_rpf2)))
  
  # --- Convert to asset weights using RAW-space loader ---------------------
  if (length(f2_names) > 0 && !is.null(rp_out$f2_only$w_rpca)) {
    npc_f2 <- rp_out$f2_only$npc
    L_all_f2 <- rp_out$f2_only$w_rpca
    pc_keep_f2 <- intersect(colnames(L_all_f2), names(lambda_scaled_rpf2))
    stopifnot(length(pc_keep_f2) == npc_f2)
    Loading_pc_f2 <- L_all_f2[, pc_keep_f2, drop = FALSE]   # M x npc_f2
    
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
  
  ## -----------------------------------------------------------------------
  ## 4.4.2  RP-PCA PC Weights (NxN matrices)
  ## -----------------------------------------------------------------------
  # NOTE: These are budget-normalized PC constructions (columns sum to 1);
  # they DO NOT reproduce the scores unless you remove the sum-to-1 scaling.
  # Combined (R+f2) PC weights
  rppca_pcs_weights_matrix   <- rp_out$combined$w_rpca_sum1
  
  # f2 only PC weights
  rppcaf2_pc_weights_matrix  <- rp_out$f2_only$w_rpca_sum1
  
  
  
  ## -----------------------------------------------------------------------
  ## 4.5  Standard PCA Model - Combined (R+f2)
  ## -----------------------------------------------------------------------
  lambda_raw_pca <- lambda_hat$PCA
  lambdas_out$PCA <- matrix(lambda_raw_pca, nrow = 1,
                            dimnames = list(date_label, rownames(lambda_raw_pca)))
  
  # --- Descale by PC SDs (omit intercept) ---------------------------------
  f_pc_pca   <- pca_out$combined$factors                      # T x K factors actually priced
  pc_sds_pca <- matrixStats::colSds(f_pc_pca)                 # K
  names(pc_sds_pca) <- colnames(f_pc_pca)
  
  lambda_no_int_pca <- drop(lambda_raw_pca[-1, , drop = FALSE])  # length K, named by PCs
  # Align names explicitly to avoid accidental mismatch
  stopifnot(all(names(lambda_no_int_pca) %in% names(pc_sds_pca)))
  lambda_scaled_pca <- lambda_no_int_pca / pc_sds_pca[names(lambda_no_int_pca)]  # back on f_pc scale
  
  # --- Store scaled lambdas (with intercept) -------------------------------
  lambda_scaled_full_pca <- rbind(
    intercept = matrix(lambda_raw_pca[1, , drop = FALSE], ncol = 1,
                       dimnames = list(rownames(lambda_raw_pca)[1], colnames(lambda_raw_pca))),
    matrix(lambda_scaled_pca, ncol = 1,
           dimnames = list(names(lambda_scaled_pca), colnames(lambda_raw_pca)))
  )
  scaled_lambdas_out$PCA <- matrix(lambda_scaled_full_pca, nrow = 1,
                                   dimnames = list(date_label, rownames(lambda_scaled_full_pca)))
  
  # --- Convert to asset weights using RAW-space loader ---------------------
  if (length(f2_names) > 0 && !is.null(pca_out$combined$w_rpca)) {
    # Number of PCs used
    npc_pca <- pca_out$combined$npc
    
    # RAW-space loader L = S^{-1} V (reproduces f_pc from RAW returns):
    # use the first npc PCs and align columns by PC names used in lambda
    L_all_pca <- pca_out$combined$w_rpca                       # (N_assets_total) x (num_PCs_available)
    pc_keep_pca <- intersect(colnames(L_all_pca), names(lambda_scaled_pca))
    stopifnot(length(pc_keep_pca) == npc_pca)
    Loading_pc_pca <- L_all_pca[, pc_keep_pca, drop = FALSE]   # N x npc
    
    # EXACT replication weights for r_combo = f_pc %*% lambda_scaled_pca
    w_pca_exact <- Loading_pc_pca %*% matrix(lambda_scaled_pca[pc_keep_pca], ncol = 1)
    
    # Optional: budget-1 normalization (changes only scale)
    sum_w_pca <- sum(w_pca_exact)
    if (abs(sum_w_pca) < 1e-12) warning("PCA combined: sum of weights is ~0; budget-1 normalization may be unstable.")
    w_pca <- as.vector(w_pca_exact) / sum_w_pca
    
    # Asset names (prefer Rc, then R, else generic)
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
  
  ## -----------------------------------------------------------------------
  ## 4.5.1  Standard PCA Model - f2 only (PCAf2)
  ## -----------------------------------------------------------------------
  lambda_raw_pcaf2 <- lambda_hat$PCAf2
  lambdas_out$PCAf2 <- matrix(lambda_raw_pcaf2, nrow = 1,
                              dimnames = list(date_label, rownames(lambda_raw_pcaf2)))
  
  # --- Descale by PC SDs (omit intercept) ---------------------------------
  f_pc_f2_pca   <- pca_out$f2_only$factors
  pc_sds_f2_pca <- matrixStats::colSds(f_pc_f2_pca)
  names(pc_sds_f2_pca) <- colnames(f_pc_f2_pca)
  
  lambda_no_int_pcaf2 <- drop(lambda_raw_pcaf2[-1, , drop = FALSE])
  stopifnot(all(names(lambda_no_int_pcaf2) %in% names(pc_sds_f2_pca)))
  lambda_scaled_pcaf2 <- lambda_no_int_pcaf2 / pc_sds_f2_pca[names(lambda_no_int_pcaf2)]
  
  # --- Store scaled lambdas (with intercept) -------------------------------
  lambda_scaled_full_pcaf2 <- rbind(
    intercept = matrix(lambda_raw_pcaf2[1, , drop = FALSE], ncol = 1,
                       dimnames = list(rownames(lambda_raw_pcaf2)[1], colnames(lambda_raw_pcaf2))),
    matrix(lambda_scaled_pcaf2, ncol = 1,
           dimnames = list(names(lambda_scaled_pcaf2), colnames(lambda_raw_pcaf2)))
  )
  scaled_lambdas_out$PCAf2 <- matrix(lambda_scaled_full_pcaf2, nrow = 1,
                                     dimnames = list(date_label, rownames(lambda_scaled_full_pcaf2)))
  
  # --- Convert to asset weights using RAW-space loader ---------------------
  if (length(f2_names) > 0 && !is.null(pca_out$f2_only$w_rpca)) {
    npc_f2_pca <- pca_out$f2_only$npc
    L_all_f2_pca <- pca_out$f2_only$w_rpca
    pc_keep_f2_pca <- intersect(colnames(L_all_f2_pca), names(lambda_scaled_pcaf2))
    stopifnot(length(pc_keep_f2_pca) == npc_f2_pca)
    Loading_pc_f2_pca <- L_all_f2_pca[, pc_keep_f2_pca, drop = FALSE]   # M x npc_f2
    
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
  
  ## -----------------------------------------------------------------------
  ## 4.5.2  Standard PCA PC Weights (NxN matrices)
  ## -----------------------------------------------------------------------
  # NOTE: These are budget-normalized PC constructions (columns sum to 1);
  # they DO NOT reproduce the scores unless you remove the sum-to-1 scaling.
  # Combined (R+f2) PC weights
  pca_pcs_weights_matrix   <- pca_out$combined$w_rpca_sum1
  
  # f2 only PC weights
  pcaf2_pc_weights_matrix  <- pca_out$f2_only$w_rpca_sum1
  
  ## -----------------------------------------------------------------------
  ## 4.6  KNS Model - Combined (R+f2)
  ## -----------------------------------------------------------------------
  lambda_raw_kns <- lambda_hat$KNS
  lambdas_out$KNS <- matrix(lambda_raw_kns, nrow = 1,
                            dimnames = list(date_label, rownames(lambda_raw_kns)))
  
  # For KNS, lambdas are computed from standardized data, so raw lambdas = scaled lambdas
  # (Scaling is already embedded in the KNS elastic net procedure)
  scaled_lambdas_out$KNS <- matrix(lambda_raw_kns, nrow = 1,
                                   dimnames = list(date_label, rownames(lambda_raw_kns)))
  
  # Extract weights from kns_out$combined$kns_w1
  w_kns <- kns_out$combined$kns_w1
  
  # Get asset names from Rc
  asset_names <- if (!is.null(colnames(Rc))) {
    colnames(Rc)
  } else {
    paste0("Asset", 1:length(w_kns))
  }
  
  weights_out$KNS <- matrix(as.vector(w_kns), nrow = 1,
                            dimnames = list(date_label, asset_names))
  
  ## -----------------------------------------------------------------------
  ## 4.7  KNS Model - f2 only (KNSf2)
  ## -----------------------------------------------------------------------
  lambda_raw_knsf2 <- lambda_hat$KNSf2
  lambdas_out$KNSf2 <- matrix(lambda_raw_knsf2, nrow = 1,
                              dimnames = list(date_label, rownames(lambda_raw_knsf2)))
  
  # For KNSf2, lambdas are computed from standardized data, so raw lambdas = scaled lambdas
  scaled_lambdas_out$KNSf2 <- matrix(lambda_raw_knsf2, nrow = 1,
                                     dimnames = list(date_label, rownames(lambda_raw_knsf2)))
  
  # Extract weights from kns_out$f2_only$kns_w1
  w_knsf2 <- kns_out$f2_only$kns_w1
  
  # Get f2 asset names
  f2_asset_names <- if (!is.null(colnames(f2))) {
    colnames(f2)
  } else {
    paste0("Asset", 1:length(w_knsf2))
  }
  
  weights_out$KNSf2 <- matrix(as.vector(w_knsf2), nrow = 1,
                              dimnames = list(date_label, f2_asset_names))
  
  ## -----------------------------------------------------------------------
  ## 4.8  KNS PC Weights (NxN matrices)
  ## -----------------------------------------------------------------------
  # Store NxN PC weight matrices from combined and f2_only
  # These matrices show how each PC is constructed from the underlying assets
  
  # Combined (R+f2) PC weights
  kns_pcs_weights_matrix <- kns_out$combined$w_sum1_pc
  
  # f2 only PC weights
  knsf2_pc_weights_matrix <- kns_out$f2_only$w_sum1_pc
  
  ## -----------------------------------------------------------------------
  ## 4.9  Optimal Portfolios (f2 only)
  ## -----------------------------------------------------------------------
  # Only compute if f2 exists and has factors
  if (!is.null(f2) && length(f2_names) > 0) {
    
    # Convert f2 to matrix
    f2_mat <- as.matrix(f2)
    
    # Compute mean returns and covariance matrix
    mu_f2 <- colMeans(f2_mat)
    Sigma_f2 <- cov(f2_mat)
    
    # --- 4.9.1 Tangency Portfolio (Maximum Sharpe Ratio) ---
    # Using formula: w = Sigma^{-1} * mu / (1' * Sigma^{-1} * mu)
    tryCatch({
      Sigma_inv <- solve(Sigma_f2)
      w_tangency_raw <- Sigma_inv %*% mu_f2
      w_tangency <- as.vector(w_tangency_raw / sum(w_tangency_raw))
      names(w_tangency) <- f2_names
      
      weights_out$Tangency <- matrix(w_tangency, nrow = 1,
                                     dimnames = list(date_label, f2_names))
    }, error = function(e) {
      warning("Tangency portfolio calculation failed: ", e$message)
      weights_out$Tangency <- matrix(numeric(0), nrow = 1, ncol = 0,
                                     dimnames = list(date_label, NULL))
    })
    
    # --- 4.9.2 Minimum Variance Portfolio ---
    # Using formula: w = Sigma^{-1} * 1 / (1' * Sigma^{-1} * 1)
    tryCatch({
      Sigma_inv <- solve(Sigma_f2)
      ones <- rep(1, length(f2_names))
      w_minvar_raw <- Sigma_inv %*% ones
      w_minvar <- as.vector(w_minvar_raw / sum(w_minvar_raw))
      names(w_minvar) <- f2_names
      
      weights_out$MinVar <- matrix(w_minvar, nrow = 1,
                                   dimnames = list(date_label, f2_names))
    }, error = function(e) {
      warning("Minimum variance portfolio calculation failed: ", e$message)
      weights_out$MinVar <- matrix(numeric(0), nrow = 1, ncol = 0,
                                   dimnames = list(date_label, NULL))
    })
    
    # --- 4.9.3 Equal-Weight Portfolio (1/N) ---
    w_equalweight <- rep(1 / length(f2_names), length(f2_names))
    names(w_equalweight) <- f2_names
    
    weights_out$EqualWeight <- matrix(w_equalweight, nrow = 1,
                                      dimnames = list(date_label, f2_names))
    
  } else {
    # No f2 factors, return empty matrices
    weights_out$Tangency <- matrix(numeric(0), nrow = 1, ncol = 0,
                                   dimnames = list(date_label, NULL))
    weights_out$MinVar <- matrix(numeric(0), nrow = 1, ncol = 0,
                                 dimnames = list(date_label, NULL))
    weights_out$EqualWeight <- matrix(numeric(0), nrow = 1, ncol = 0,
                                      dimnames = list(date_label, NULL))
  }
  
  ## -----------------------------------------------------------------------
  ## 5  Return results
  ## -----------------------------------------------------------------------
  return(list(
    lambdas           = lambdas_out,
    scaled_lambdas    = scaled_lambdas_out,
    weights           = weights_out,
    gammas            = gammas_out,
    date_end          = date_end,
    top_factors       = top5_list_f2,        # f2-only top factors
    top_mpr_factors   = top5_mpr_list_f2,    # f2-only top MPR factors
    top_factors_all   = top5_list_all,       # ALL factors top
    top_mpr_factors_all = top5_mpr_list_all, # ALL factors top MPR
    kns_pcs_weights   = kns_pcs_weights_matrix,
    knsf2_pc_weights  = knsf2_pc_weights_matrix,
    rppca_pcs_weights = rppca_pcs_weights_matrix,
    rppcaf2_pc_weights = rppcaf2_pc_weights_matrix,
    pca_pcs_weights   = pca_pcs_weights_matrix,
    pcaf2_pc_weights  = pcaf2_pc_weights_matrix
  ))
}