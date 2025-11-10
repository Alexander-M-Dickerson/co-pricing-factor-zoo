insample_asset_pricing <- function(results=results,f_all=f_all_raw,R=R,f1=f1,f2=f2,
                                   rp_out=rp_out, kns_out=kns_out,
                                   intercept=intercept,
                                   fac_freq=fac_freq,
                                   frequentist_models=NULL) {
  
  library(purrr)          # functional helpers
  library(dplyr)          # select, mutate, ...
  library(matrixStats)    # for colSds()
  
  select  <- dplyr::select
  
  for (i in 1:4){
    assign(paste0("models.psi" , i), colMeans(results[[i]]$gamma_path))
    assign(paste0("lambda.bma.psi", i), colMeans(results[[i]]$lambda_path))
    assign(paste0("sdf.bma.psi", i), (results[[i]]$bma_sdf))
  }
  
  names = colnames(cbind(f1,f2))
  Gamma = data.frame( gam1 = models.psi4,gam2 = models.psi2,gam3 = models.psi3,
                      gam4 = models.psi4, row.names = names )
  
  f_all <- as.data.frame(f_all)
  fac_freq <- as.data.frame(fac_freq)
  
  #### Combine R with traded assets in f2 (if applicable), f2 can be NULL ####
  Rc <- cbind(R,f2)
  N = dim(Rc)[2]
  
  #### Top ####
  top5_list <- lapply(colnames(Gamma), function(col) {
    row.names(Gamma)[order(Gamma[[col]], decreasing = TRUE)[1:5]]
  })
  
  #### Top-MPR ####
  # Create Lambda dataframe for MPR-based top factors
  Lambda <- data.frame(
    lam1 = lambda.bma.psi1,
    lam2 = lambda.bma.psi2,
    lam3 = lambda.bma.psi3,
    lam4 = lambda.bma.psi4,
    row.names = if (intercept) c("(Intercept)", names) else names
  )
  
  # Extract top 5 factors by absolute MPR, excluding intercept if present
  top5_mpr_list <- lapply(colnames(Lambda), function(col) {
    # Drop intercept row if present
    Lambda_no_int <- if (intercept) Lambda[-1, , drop = FALSE] else Lambda
    # Get top 5 by absolute value of Lambda (MPR)
    row.names(Lambda_no_int)[order(abs(Lambda_no_int[[col]]), decreasing = TRUE)[1:5]]
  })
  
  
  #### BMA Pricing ####
  if (intercept == FALSE){
    C_f   <- cor(Rc, cbind(f1,f2))
  }  else{
    C_f   <- cbind(
      matrix(1, nrow=N,ncol=1),
      cor(Rc, cbind(f1,f2))
    )
  }
  
  ## -----------------------------------------------------------------------
  ## 0  House-keeping
  ## -----------------------------------------------------------------------
  W  <- cor(Rc)           # weighting matrix, computed once
  N  <- ncol(Rc)          # number of test assets
  
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
  
  # Always add Top and Top-MPR (data-dependent models)
  factor_specs_bayesian <- list(
    Top       = top5_list[[4]],
    `Top-MPR` = top5_mpr_list[[4]]
  )
  
  # GMM estimation - frequentist models use fac_freq
  lambda_hat <- imap(
    freq_models,
    ~ gmm_estimation(Rc, as.matrix(select(fac_freq, all_of(.x))), W = W)
  )
  
  # GMM estimation - Bayesian-selected models use f_all
  lambda_hat_bayesian <- imap(
    factor_specs_bayesian,
    ~ gmm_estimation(Rc, as.matrix(select(f_all, all_of(.x))), W = W)
  )
  
  # Combine all lambda estimates
  lambda_hat <- c(lambda_hat, lambda_hat_bayesian)
  
  # add RP-PCA and KNS (always included)
  lambda_hat$`RP-PCA` <- gmm_estimation(Rc, rp_out$factors, W, include.intercept = TRUE)
  lambda_hat$KNS      <- as.matrix(kns_out$kns_lambdas)              # renamed -> no overwrite
  
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
  ## 4  Estimate expected returns (DYNAMIC)
  ## -----------------------------------------------------------------------
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
  
  # Add Bayesian-selected models (use f_all)
  for (model_name in names(factor_specs_bayesian)) {
    factor_cols <- factor_specs_bayesian[[model_name]]
    ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*% 
      lambda_hat[[model_name]]
  }
  
  # Add KNS and RP-PCA (no intercept for KNS, has intercept for RP-PCA)
  ER_pred$KNS      <- get_cor(kns_out$kns_PCs)          %*% lambda_hat$KNS
  ER_pred$`RP-PCA` <- cbind(1, get_cor(rp_out$factors)) %*% lambda_hat$`RP-PCA`
  
  ER_pred_all_in <- do.call(cbind, ER_pred)*sqrt(12)   # N x Nm matrix
  Nm             <- dim(ER_pred_all_in)[2]
  
  # Build column names dynamically
  Colnames <- c(
    "BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",  # BMA models
    names(freq_models),                           # Frequentist models
    names(factor_specs_bayesian),                 # Bayesian-selected (Top/Top-MPR)
    "KNS", "RP-PCA"                               # Special models
  )
  colnames(ER_pred_all_in) <- Colnames
  
  # ER.in is the matrix of unconditional Sharpe ratios
  ER.in    <- matrix(sqrt(12)*colMeans(Rc)/colSds(Rc), ncol=1)
  # Pricing errors
  alpha_in        <- ER.in %*% matrix(1,nrow=1,ncol=Nm) - ER_pred_all_in[,c(1:Nm)]
  
  ## -----------------------------------------------------------------------
  ## 5  In-sample pricing diagnostics  ->  is_pricing_result
  ## -----------------------------------------------------------------------
  
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
  alpha_in   <- ER.in %*% matrix(1, nrow = 1, ncol = Nm) - ER_pred_all_in
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
    `colnames<-`(Colnames) |>
    tibble::rownames_to_column(var = "metric")
  
  ## -----------------------------------------------------------------------
  ## 6  Model-implied SDF series  ->  sdf_mat  (T x K)  (ROBUST)
  ## -----------------------------------------------------------------------
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
  
  # Add Bayesian-selected models - use f_all
  for (model_name in names(factor_specs_bayesian)) {
    factor_cols <- factor_specs_bayesian[[model_name]]
    
    # Check if all factors are available in f_all
    if (all(factor_cols %in% colnames(f_all))) {
      sdf_specs[[model_name]] <- list(
        X = as.matrix(f_all[, factor_cols, drop = FALSE]),
        lambda = insample_lambda[[model_name]],
        int = TRUE
      )
    }
  }
  
  # Always add RP-PCA and KNS (data-driven, always available)
  sdf_specs$`RP-PCA` <- list(
    X = rp_out$factors,
    lambda = insample_lambda$`RP-PCA`,
    int = TRUE
  )
  sdf_specs$KNS <- list(
    X = kns_out$kns_PCs,
    lambda = insample_lambda$KNS,
    int = FALSE           # KNS lambda already has no intercept
  )
  
  # build all SDFs in one sweep -------------------------------------------
  sdf_list <- imap(
    sdf_specs,
    ~ compute_sdf(.x$X, .x$lambda, intercept = .x$int)
  )
  
  sdf_mat <- do.call(cbind, sdf_list)    # T x K matrix
  colnames(sdf_mat) <- names(sdf_list)
  
  ## -----------------------------------------------------------------------
  ## 7  Pack outputs and lighten memory
  ## -----------------------------------------------------------------------
  
  IS_AP_output <- list(
    insample_lambda      = insample_lambda,
    insample_lambda_bma  = insample_lambda_bma,
    is_pricing_result    = is_pricing_result,
    sdf_mat              = sdf_mat,
    top_factors          = top5_list,
    top_mpr_factors      = top5_mpr_list
  )
  
  
  return(IS_AP_output)
}