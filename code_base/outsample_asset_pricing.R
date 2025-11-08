os_asset_pricing <- function(R_oss,
                             IS_AP,
                             f1, f2,                      
                             f_all_raw,                   
                             intercept,                                           
                             kns_out,                     
                             rp_out)                    
{
  stopifnot(is.matrix(R_oss))
  
  ## -- 0.  Helper objects ------------------------------------------------------
  N  <- ncol(R_oss)
  λb <- IS_AP$insample_lambda_bma        # shorter aliases
  λh <- IS_AP$insample_lambda
  get_cor <- function(x) cor(R_oss, as.matrix(x))
  
  ## -- 1.  Build C_f -----------------------------------------------------------
  C_f <- if (intercept) {
    cbind(1, cor(R_oss, cbind(f1, f2)))
  } else {
    cor(R_oss, cbind(f1, f2))
  }
  
  f_all_raw <- as.data.frame(f_all_raw)
  
  ## -- 2.  Expected returns ----------------------------------------------------
  ER_pred <- list(
    `BMA-20%` = C_f %*% λb$`BMA-20%`,
    `BMA-40%` = C_f %*% λb$`BMA-40%`,
    `BMA-60%` = C_f %*% λb$`BMA-60%`,
    `BMA-80%` = C_f %*% λb$`BMA-80%`,
    CAPM      = cbind(1, get_cor(f_all_raw$MKTS))                                      %*% λh$CAPM,
    CAPMB     = cbind(1, get_cor(f_all_raw$MKTB))                                      %*% λh$CAPMB,
    FF5       = cbind(1, get_cor(f_all_raw[ , c("MKTS","SMB","HML","DEF","TERM")]))    %*% λh$FF5,
    HKM       = cbind(1, get_cor(f_all_raw[ , c("MKTS","CPTLT")]))                     %*% λh$HKM,
    Top       = cbind(1, get_cor(f_all_raw[ , IS_AP$top_factors[[4]]]))                        %*% λh$Top,
    KNS       =           get_cor(kns_out$kns_PCs)                                     %*% λh$KNS,
    `RP-PCA`  = cbind(1, get_cor(rp_out$factors))                                      %*% λh$`RP-PCA`
  )
  
  ER_pred_all <- do.call(cbind, ER_pred) * sqrt(12)      # N × 11
  
  ## -- 3.  Unconditional SRs & pricing errors ---------------------------------
  ER_in   <- sqrt(12) * colMeans(R_oss) / matrixStats::colSds(R_oss)   # N × 1
  alpha   <- ER_in %*% matrix(1, nrow = 1, ncol = ncol(ER_pred_all)) -
    ER_pred_all
  
  ## -- 4.  Asset-pricing metrics ----------------------------------------------
  Sigma_inv <- solve(cor(R_oss))
  
  SR_scalar <- tryCatch(
    12 * SharpeRatio(R_oss)[1, 1],
    error = function(e) 12 * as.numeric(SharpeRatio(R_oss))
  )
  
  dm_alpha <- sweep(alpha, 2, colMeans(alpha))           # demean across assets
  rmse     <- function(m) sqrt(colMeans(m^2))
  mape     <- function(m)        colMeans(abs(m))
  r2_ols   <- function(m) 1 - apply(m, 2, var) / var(drop(ER_in))
  r2_gls   <- function(m) 1 - diag(t(m) %*% Sigma_inv %*% m) / SR_scalar
  
  metrics_tbl <- rbind(
    RMSEdm = rmse(dm_alpha),
    MAPEdm = mape(dm_alpha),
    R2OLS  = r2_ols(alpha),
    R2GLS  = r2_gls(alpha)
  ) |>
    as.data.frame() |>
    `colnames<-`(names(ER_pred)) |>
    tibble::rownames_to_column("metric")
  
  return(metrics_tbl)
}

#### OS Time-series version ####
os_asset_pricing_ts <- function(R_oss,
                                IS_AP,
                                f1, f2,                      
                                f_all_raw,                   
                                intercept,                                           
                                kns_out,                     
                                rp_out)                    
{
  stopifnot(is.matrix(R_oss))
  
  ## -- 0.  Helper objects ------------------------------------------------------
  N  <- ncol(R_oss)
  λb <- IS_AP$insample_lambda_bma        # shorter aliases
  λh <- IS_AP$insample_lambda
  get_cor <- function(x) cor(R_oss, as.matrix(x))
  
  ## -- 1.  Build C_f -----------------------------------------------------------
  C_f <- if (intercept) {
    cbind(1, cor(R_oss, cbind(f1, f2)))
  } else {
    cor(R_oss, cbind(f1, f2))
  }
  
  f_all_raw <- as.data.frame(f_all_raw)
  
  ## KNS OS ##
  X1        <- cbind(R[idx,],f2[idx,])
  X         <- t( t(X1)/matrixStats::colSds(X1) )
  X_os      <- t( t(R_oss)/matrixStats::colSds(R_oss) )
  
  pca_out  <- elastic_net_pc(X, kns_out$summary$SR/sqrt(12))
  lambda_A <- pca_out[[1]]
  Q        <- pca_out[[2]]
  
  lambda_hat <- as.vector(lambda_A[kns_out$summary$nf, 1, ])
  keep_idx   <- which(lambda_hat > 0)
  
  # ── 1.  Raw elastic-net coefficients that survive shrinkage ────────────────
  lambda_raw <- lambda_hat[keep_idx]              # *** keep this unchanged ***
  Q_sel      <- Q[ , keep_idx, drop = FALSE]
  
  w_kns      <- Q_sel %*% kns_out$kns_lambdas
  
  # Create OS KNS #
  X_os %*% w_kns
  
  
  # ── 2.  PCs for those columns & their s.d.’s ───────────────────────────────
  PCs_sel    <- X %*% Q_sel                       # raw PCs
  pc_sd      <- matrixStats::colSds(PCs_sel)
  
  # ── 3.  Scale:  PCs → unit s.d.  AND  λ̂ → compensate ──────────────────────
  PCs_std       <- t( t(PCs_sel) / pc_sd )        # divide each PC by its σ
  lambda_scaled <- lambda_raw * pc_sd             # multiply λ̂ by the same σ
  
  # ── 4.  Non-traded SDF component ───────────────────────────────────────────
  nontraded_comp <- drop(PCs_std %*% lambda_scaled)
  sdf_nontraded  <- 1 + (1 - nontraded_comp) - mean(1 - nontraded_comp)
  
  # ── 5.  Traded version:  asset weights use RAW λ̂ ──────────────────────────
  w_ast <- Q_sel %*% lambda_raw                  # *** raw λ̂ here ***
  w_ast <- w_ast / sum(w_ast)                    # optional scaling (correlation unaffected)
  
  traded_comp <- drop(X %*% w_ast)
  
  # ── 6.  Check ───────────────────────────────────────────────────────────────
  cat("Correlation :", cor(sdf_nontraded, traded_comp), "\n")
  
  
  ## -- 2.  Expected returns ----------------------------------------------------
  ER_pred <- list(
    `BMA-20%` = C_f %*% λb$`BMA-20%`,
    `BMA-40%` = C_f %*% λb$`BMA-40%`,
    `BMA-60%` = C_f %*% λb$`BMA-60%`,
    `BMA-80%` = C_f %*% λb$`BMA-80%`,
    CAPM      = cbind(1, get_cor(f_all_raw$MKTS))                                      %*% λh$CAPM,
    CAPMB     = cbind(1, get_cor(f_all_raw$MKTB))                                      %*% λh$CAPMB,
    FF5       = cbind(1, get_cor(f_all_raw[ , c("MKTS","SMB","HML","DEF","TERM")]))    %*% λh$FF5,
    HKM       = cbind(1, get_cor(f_all_raw[ , c("MKTS","CPTLT")]))                     %*% λh$HKM,
    Top       = cbind(1, get_cor(f_all_raw[ , IS_AP$top_factors[[4]]]))                %*% λh$Top,
    KNS       =           get_cor(kns_out$kns_PCs_os)                                  %*% λh$KNS,
    `RP-PCA`  = cbind(1, get_cor(rp_out$factors_os))                                   %*% λh$`RP-PCA`
  )
  
  ER_pred_all <- do.call(cbind, ER_pred) * sqrt(12)      # N × 11
  
  ## -- 3.  Unconditional SRs & pricing errors ---------------------------------
  ER_in   <- sqrt(12) * colMeans(R_oss) / matrixStats::colSds(R_oss)   # N × 1
  alpha   <- ER_in %*% matrix(1, nrow = 1, ncol = ncol(ER_pred_all)) -
    ER_pred_all
  
  ## -- 4.  Asset-pricing metrics ----------------------------------------------
  Sigma_inv <- solve(cor(R_oss))
  
  SR_scalar <- tryCatch(
    12 * SharpeRatio(R_oss)[1, 1],
    error = function(e) 12 * as.numeric(SharpeRatio(R_oss))
  )
  
  dm_alpha <- sweep(alpha, 2, colMeans(alpha))           # demean across assets
  rmse     <- function(m) sqrt(colMeans(m^2))
  mape     <- function(m)        colMeans(abs(m))
  r2_ols   <- function(m) 1 - apply(m, 2, var) / var(drop(ER_in))
  r2_gls   <- function(m) 1 - diag(t(m) %*% Sigma_inv %*% m) / SR_scalar
  
  metrics_tbl <- rbind(
    RMSEdm = rmse(dm_alpha),
    MAPEdm = mape(dm_alpha),
    R2OLS  = r2_ols(alpha),
    R2GLS  = r2_gls(alpha)
  ) |>
    as.data.frame() |>
    `colnames<-`(names(ER_pred)) |>
    tibble::rownames_to_column("metric")
  
  return(metrics_tbl)
}



#### OLD ####
# os_asset_pricing_ts <- function(R_oss,
#                                 IS_AP,
#                                 f1, f2,                      
#                                 f_all_raw,                   
#                                 intercept,                                           
#                                 kns_out,                     
#                                 rp_out)                    
# {
#   stopifnot(is.matrix(R_oss))
#   
#   ## -- 0.  Helper objects ------------------------------------------------------
#   N  <- ncol(R_oss)
#   λb <- IS_AP$insample_lambda_bma        # shorter aliases
#   λh <- IS_AP$insample_lambda
#   get_cor <- function(x) cor(R_oss, as.matrix(x))
#   
#   ## -- 1.  Build C_f -----------------------------------------------------------
#   C_f <- if (intercept) {
#     cbind(1, cor(R_oss, cbind(f1, f2)))
#   } else {
#     cor(R_oss, cbind(f1, f2))
#   }
#   
#   f_all_raw <- as.data.frame(f_all_raw)
#   
#   ## -- 2.  Expected returns ----------------------------------------------------
#   ER_pred <- list(
#     `BMA-20%` = C_f %*% λb$`BMA-20%`,
#     `BMA-40%` = C_f %*% λb$`BMA-40%`,
#     `BMA-60%` = C_f %*% λb$`BMA-60%`,
#     `BMA-80%` = C_f %*% λb$`BMA-80%`,
#     CAPM      = cbind(1, get_cor(f_all_raw$MKTS))                                      %*% λh$CAPM,
#     CAPMB     = cbind(1, get_cor(f_all_raw$MKTB))                                      %*% λh$CAPMB,
#     FF5       = cbind(1, get_cor(f_all_raw[ , c("MKTS","SMB","HML","DEF","TERM")]))    %*% λh$FF5,
#     HKM       = cbind(1, get_cor(f_all_raw[ , c("MKTS","CPTLT")]))                     %*% λh$HKM,
#     Top       = cbind(1, get_cor(f_all_raw[ , IS_AP$top_factors[[4]]]))                %*% λh$Top,
#     KNS       =           get_cor(kns_out$kns_PCs_os)                                  %*% λh$KNS,
#     `RP-PCA`  = cbind(1, get_cor(rp_out$factors_os))                                   %*% λh$`RP-PCA`
#   )
#   
#   ER_pred_all <- do.call(cbind, ER_pred) * sqrt(12)      # N × 11
#   
#   ## -- 3.  Unconditional SRs & pricing errors ---------------------------------
#   ER_in   <- sqrt(12) * colMeans(R_oss) / matrixStats::colSds(R_oss)   # N × 1
#   alpha   <- ER_in %*% matrix(1, nrow = 1, ncol = ncol(ER_pred_all)) -
#     ER_pred_all
#   
#   ## -- 4.  Asset-pricing metrics ----------------------------------------------
#   Sigma_inv <- solve(cor(R_oss))
#   
#   SR_scalar <- tryCatch(
#     12 * SharpeRatio(R_oss)[1, 1],
#     error = function(e) 12 * as.numeric(SharpeRatio(R_oss))
#   )
#   
#   dm_alpha <- sweep(alpha, 2, colMeans(alpha))           # demean across assets
#   rmse     <- function(m) sqrt(colMeans(m^2))
#   mape     <- function(m)        colMeans(abs(m))
#   r2_ols   <- function(m) 1 - apply(m, 2, var) / var(drop(ER_in))
#   r2_gls   <- function(m) 1 - diag(t(m) %*% Sigma_inv %*% m) / SR_scalar
#   
#   metrics_tbl <- rbind(
#     RMSEdm = rmse(dm_alpha),
#     MAPEdm = mape(dm_alpha),
#     R2OLS  = r2_ols(alpha),
#     R2GLS  = r2_gls(alpha)
#   ) |>
#     as.data.frame() |>
#     `colnames<-`(names(ER_pred)) |>
#     tibble::rownames_to_column("metric")
#   
#   return(metrics_tbl)
# }