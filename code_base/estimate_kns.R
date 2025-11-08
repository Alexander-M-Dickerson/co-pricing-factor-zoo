
##################################################
### Elastic Net Estimation of PCs' Risk Prices ###
##################################################

## Reference: Shrinking the cross-section, by Kozak, Nagel, and Santosh (2020, JFE) (also denoted as KNS).
## See Equations (28) and (29) in their paper. 

trace <- function(A) {
  return(sum(diag(A)))
}

elastic_net_pc <- function(R, prior.SR) {
  
  ## R: the matrix of asset returns;
  ## prior.SR: the vector of prior SR implied by the factor models.
  
  T1 <- dim(R)[1]
  N <- dim(R)[2]
  Sigma_R <- cov(R)
  eigen_decom <- eigen(Sigma_R)   # Sigma_R = Q %*% D %*% t(Q)
  Q <- eigen_decom$vectors        # eigenvectors;
  D <- diag(eigen_decom$values)   # eigenvalues;
  f <- R %*% Q 
  
  mu_f <- matrix(colMeans(f), ncol=1)
  Q <- Q %*% diag(as.vector(sign(mu_f)))
  f <- f %*% diag(as.vector(sign(mu_f)))  # make sure that expected returns of factors > 0;
  mu_f <- matrix(colMeans(f), ncol=1)
  seq_v1 <- sort(mu_f*0.999)
  tau <- trace(Sigma_R)
  seq_v2 <- tau / (T1 * prior.SR^2)      # from equation (29) in their paper (see Section 3.3 in KNS (2020));
  lambda_array <- array(NA, dim = c(length(seq_v1), length(seq_v2), N))
  
  for (ii in 1:length(seq_v1)) {
    for (jj in 1:length(seq_v2)) {
      v1 <- seq_v1[ii]
      v2 <- seq_v2[jj]
      lambda_pc <- (mu_f-v1) / (diag(D)+v2)
      lambda_pc <- matrix(apply(lambda_pc, 1, max, 0), ncol=1)
      lambda_array[ii,jj,] <- lambda_pc
    }
  }
  
  return(list(lambda_array <- lambda_array,
              Q <- Q))
}


#########################################################################################
#########################################################################################


elastic_net_pc_oos_new <- function(R_in, R_oos, prior.SR) {
  
  ## R_in: the matrix of in-sample asset returns.
  ## R_oos: the matrix of out-of-sample asset returns.
  ## prior.SR: the vector of prior SR implied by the factor models.
  
  T1 <- dim(R_in)[1]
  T2 <- dim(R_oos)[1]
  N <- dim(R_in)[2]
  
  Sigma_R_in <- cov(R_in)
  eigen_decom_in <- eigen(Sigma_R_in)
  Q_in <- eigen_decom_in$vectors
  D_in <- diag(eigen_decom_in$values)
  f_in <- R_in %*% Q_in 
  ER_in <- matrix(colMeans(R_in), ncol=1)
  mu_f_in <- matrix(colMeans(f_in), ncol=1)
  Q_in <- Q_in %*% diag(as.vector(sign(mu_f_in)))
  f_in <- f_in %*% diag(as.vector(sign(mu_f_in)))  # make sure that expected returns of factors > 0;
  mu_f_in <- matrix(colMeans(f_in), ncol=1)
  seq_v1 <- sort(mu_f_in*0.999)
  tau <- trace(Sigma_R_in)
  seq_v2 <- tau / (T1 * prior.SR^2)
  lambda_array <- array(NA, dim = c(length(seq_v1), length(seq_v2), N))
  
  f_oos <- R_oos %*% Q_in    # out-of-sample factors;
  ER_oos <- matrix(colMeans(R_oos), ncol=1)
  C_f_oos <- cov(R_oos, f_oos)
  
  OOS_stats <- list()
  OOS_stats[["MSE"]] <- matrix(NA, nrow=length(seq_v1), ncol=length(seq_v2))
  OOS_stats[["MAPE"]] <- matrix(NA, nrow=length(seq_v1), ncol=length(seq_v2))
  OOS_stats[["SR2_alpha"]] <- matrix(NA, nrow=length(seq_v1), ncol=length(seq_v2))
  
  OOS_stats_dm <- list()   # demeaned statistics
  OOS_stats_dm[["MSE"]] <- matrix(NA, nrow=length(seq_v1), ncol=length(seq_v2))
  OOS_stats_dm[["MAPE"]] <- matrix(NA, nrow=length(seq_v1), ncol=length(seq_v2))
  OOS_stats_dm[["SR2_alpha"]] <- matrix(NA, nrow=length(seq_v1), ncol=length(seq_v2))
  
  
  for (ii in 1:length(seq_v1)) {
    for (jj in 1:length(seq_v2)) {
      v1 <- seq_v1[ii]
      v2 <- seq_v2[jj]
      
      ## (1) In-sample estimation:
      lambda_pc_in <- (mu_f_in-v1) / (diag(D_in)+v2)
      lambda_pc_in <- matrix(apply(lambda_pc_in, 1, max, 0), ncol=1)
      lambda_array[ii,jj,] <- lambda_pc_in
      
      ## (2) Out-of-sample statistics:
      alpha_oos <- ER_oos - C_f_oos %*% lambda_pc_in
      OOS_stats[["MSE"]][ii,jj] <- mean(alpha_oos^2)
      OOS_stats[["MAPE"]][ii,jj] <- sqrt(12)*mean(abs(alpha_oos))
      OOS_stats[["SR2_alpha"]][ii,jj] <- 12*t(alpha_oos) %*% solve(cor(R_oos)) %*% alpha_oos
      
      alpha_oos_dm <- alpha_oos - mean(alpha_oos)
      OOS_stats_dm[["MSE"]][ii,jj] <- mean(alpha_oos_dm^2)
      OOS_stats_dm[["MAPE"]][ii,jj] <- sqrt(12)*mean(abs(alpha_oos_dm))
      OOS_stats_dm[["SR2_alpha"]][ii,jj] <- 12*t(alpha_oos_dm) %*% solve(cor(R_oos)) %*% alpha_oos_dm
      
    }
  }
  
  return(list(lambda_array <- lambda_array,
              Q_in <- Q_in, 
              OOS_stats <- OOS_stats, 
              OOS_stats_dm <- OOS_stats_dm))
}


################################################################################################

## In-sample squared SR in two subsamples
SharpeRatio <- function(R) {
  
  ER <- matrix(colMeans(R), ncol=1)
  covR <- cov(R)
  return(t(ER)%*%solve(covR)%*%ER)
  
}

# -----------------------------------------------------------------------
#  estimate_kns_oos()
# -----------------------------------------------------------------------
# A reusable wrapper that computes the out-of-sample (OOS) R² surface for
# the Kozak, Nagel & Shanken (2020) elastic-net PC model and extracts the
# Sharpe-ratio / factor-count combination that maximises it.
#
#  * R          :  T×N matrix of test-asset excess returns
#  * f2         :  T×K matrix of tradable factors (may be NULL)
#  * prior_SR   :  vector of annualised prior SRs (default 0.1 … 3.0)
#  * split      :  either a proportion (0–1) or an integer row index
#  * annual_div :  divisor to convert annual SR → data frequency
#  * verbose    :  print progress?
#
# Returns a list with
#   $OOS_R2     full OOS-R² matrix  (#nf rows × #prior_SR cols)
#   $best_idx   two-element vector  (row, col)
#   $summary    data-frame with nf, nfac, SR, best_R2
#   $details    list(OOS1, OOS2, ER1, ER2)      – optional diagnostics
#
estimate_kns_oos <- function(R,
                             f2          = NULL,
                             prior_SR    = seq(0.1, 3, 0.1),
                             split       = 0.5,
                             annual_div  = sqrt(12),   # monthly data
                             verbose     = TRUE) {
  
  ## ---- 0.  Input checks ----------------------------------------------------
  stopifnot(is.matrix(R))
  if (!is.null(f2)) stopifnot(nrow(f2) == nrow(R))
  if (is.numeric(split) && length(split) == 1L) {
    if (split < 1) {                             # treat as proportion
      split_point <- floor(nrow(R) * split)
    } else {
      split_point <- round(split)
    }
  } else {
    stop("`split` must be a single numeric (row index or proportion).")
  }
  if (split_point <= 10 || split_point >= nrow(R) - 10)
    stop("`split` leaves too few observations in one subsample.")
  
  ## ---- 1.  Prepare data ----------------------------------------------------
  Rkns <- if (is.null(f2)) R else cbind(R, f2)
  
  R1 <- Rkns[1:split_point,  , drop = FALSE]
  R2 <- Rkns[(split_point + 1):nrow(Rkns), , drop = FALSE]
  
  # column-wise standardisation (faster via matrixStats)
  if (!requireNamespace("matrixStats", quietly = TRUE))
    stop("Package 'matrixStats' must be installed.")
  colSds <- matrixStats::colSds
  
  R1.sd <- t( t(R1) / colSds(R1) )
  R2.sd <- t( t(R2) / colSds(R2) )
  
  ER1   <- matrix(colMeans(R1.sd), ncol = 1)
  ER2   <- matrix(colMeans(R2.sd), ncol = 1)
  
  ## ---- 2.  Sub-sample estimation ------------------------------------------
  if (verbose) message("  • Sub-sample (2→1) …")
  OOS1 <- elastic_net_pc_oos_new(
    R_in  = t( t(R2) / colSds(R2) ),   # in-sample = subsample-2
    R_oos = t( t(R1) / colSds(R1) ),   # OOS       = subsample-1
    prior_SR / annual_div)
  
  if (verbose) message("  • Sub-sample (1→2) …")
  OOS2 <- elastic_net_pc_oos_new(
    R_in  = t( t(R1) / colSds(R1) ),
    R_oos = t( t(R2) / colSds(R2) ),
    prior_SR / annual_div)
  
  ## Each call returns a list; element [[3]] must contain $MSE matrix
  mse1 <- OOS1[[3]]$MSE
  mse2 <- OOS2[[3]]$MSE
  
  # ---- 3.  OOS R² surface (Eq. 30, KNS 2020) -------------------------------
  OOS_R2_s1 <- 1 - mse1 / mean(ER1^2)  # nf × SR grid
  OOS_R2_s2 <- 1 - mse2 / mean(ER2^2)
  OOS_R2    <- (OOS_R2_s1 + OOS_R2_s2) / 2
  colnames(OOS_R2) <- prior_SR
  
  ## ---- 4.  Extract optimum -------------------------------------------------
  max_idx <- which(OOS_R2 == max(OOS_R2), arr.ind = TRUE)[1, ]  # row, col
  nf_opt  <- max_idx[1]                         # column index  = # factors kept
  sr_opt  <- max_idx[2]/10                      # row index     = SR choice
  nfac    <- ncol(Rkns) + 1 - nf_opt            # adjusted factors
  
  summary_df <- data.frame(
    nf       = nf_opt,
    nfac     = nfac,
    SR       = sr_opt,
    row.names = NULL
  )
  
  if (verbose) {
    cat("\n*** KNS-OOS SUMMARY ***\n")
    print(summary_df, row.names = FALSE)
  }
  
  # Compute lambdas and PCs #
  Rkns.sd     <- t(t(Rkns) / colSds(Rkns))
  pca_output  <- elastic_net_pc(Rkns.sd, as.numeric(sr_opt)/sqrt(12))       
  lambda.pca1 <- matrix(pca_output[[1]][as.numeric(nf_opt),1,], ncol=1)  
  PCs         <- (Rkns.sd %*% pca_output[[2]])
  lambda.pca1 <- lambda.pca1 * colSds(PCs)
  PCs         <- t(t(PCs) / colSds(PCs))
  
  # Remove / pick non-zero elements #
  nz_idx      <- which(lambda.pca1 != 0)         
  lambda.pca1 <- lambda.pca1[nz_idx]
  PCs         <- PCs[ , nz_idx, drop = FALSE] 
  
  ## ---- 5.  Return ----------------------------------------------------------
  invisible(list(
                 #OOS_R2   = OOS_R2,
                 #best_idx = max_idx,
                 summary     = summary_df,
                 kns_lambdas = lambda.pca1,
                 kns_PCs     = PCs
                 # details  = list(OOS1 = OOS1, OOS2 = OOS2,
                 #                 ER1  = ER1,  ER2  = ER2)
                 )
            )
}

# -----------------------------------------------------------------------
#  estimate_kns_oos() -- for OS Time-series
# -----------------------------------------------------------------------

estimate_kns_oos_ts <- function(R,
                                f2          = NULL,
                                prior_SR    = seq(0.1, 3, 0.1),
                                split       = 0.5,
                                annual_div  = sqrt(12),   # monthly data
                                verbose     = TRUE) {
  
  ## ---- 0.  Basic checks ----------------------------------------------------
  stopifnot(is.matrix(R))
  if (!is.null(f2)) stopifnot(nrow(f2) == nrow(R))
  
  ## ---- 1.  Merge R & f2 ----------------------------------------------------
  Rkns   <- if (is.null(f2)) R else cbind(R, f2)
  n_obs  <- nrow(Rkns)              # total time-series length  (T)
  n_fac  <- ncol(Rkns)              # number of factors         (N)
  min_T  <- n_fac + 1L              # strict lower bound so T > N
  
  ## ---- 2.  Initial split-point --------------------------------------------
  split_point <- if (is.numeric(split) && length(split) == 1L) {
    if (split < 1) floor(n_obs * split) else round(split)
  } else {
    stop("`split` must be a single numeric (row index or proportion).")
  }
  if (split_point <= 10 || split_point >= n_obs - 10)
    stop("`split` leaves too few observations in one subsample.")
  
  T1 <- split_point
  T2 <- n_obs - split_point
  
  ## ---- 3.  Make sure each subsample has T > N ------------------------------
  if (T1 <= n_fac || T2 <= n_fac) {
    # (a) Try a non-overlapping fix by nudging the boundary
    if (n_obs >= 2 * min_T) {
      split_point <- max(min(split_point, n_obs - min_T), min_T)
      T1 <- split_point
      T2 <- n_obs - split_point
    }
  }
  
  ## ---- 4.  Final allocation of R1 and R2 ----------------------------------
  if (T1 <= n_fac || T2 <= n_fac) {
    # (b) Still impossible ⇒ fall back to overlapping windows
    if (verbose)
      message("Switching to overlapping subsamples to satisfy T > N.")
    R1 <- Rkns[1:min_T, , drop = FALSE]
    R2 <- Rkns[(n_obs - min_T + 1L):n_obs, , drop = FALSE]
  } else {
    # standard (possibly nudged) non-overlapping split
    R1 <- Rkns[1:split_point, , drop = FALSE]
    R2 <- Rkns[(split_point + 1L):n_obs, , drop = FALSE]
  }
  
  # column-wise standardisation (faster via matrixStats)
  if (!requireNamespace("matrixStats", quietly = TRUE))
    stop("Package 'matrixStats' must be installed.")
  colSds <- matrixStats::colSds
  
  R1.sd <- t( t(R1) / colSds(R1) )
  R2.sd <- t( t(R2) / colSds(R2) )
  
  ER1   <- matrix(colMeans(R1.sd), ncol = 1)
  ER2   <- matrix(colMeans(R2.sd), ncol = 1)
  
  ## ---- 2.  Sub-sample estimation ------------------------------------------
  if (verbose) message("  • Sub-sample (2→1) …")
  OOS1 <- elastic_net_pc_oos_new(
    R_in  = t( t(R2) / colSds(R2) ),   # in-sample = subsample-2
    R_oos = t( t(R1) / colSds(R1) ),   # OOS       = subsample-1
    prior_SR / annual_div)
  
  if (verbose) message("  • Sub-sample (1→2) …")
  OOS2 <- elastic_net_pc_oos_new(
    R_in  = t( t(R1) / colSds(R1) ),
    R_oos = t( t(R2) / colSds(R2) ),
    prior_SR / annual_div)
  
  ## Each call returns a list; element [[3]] must contain $MSE matrix
  mse1 <- OOS1[[3]]$MSE
  mse2 <- OOS2[[3]]$MSE
  
  # ---- 3.  OOS R² surface (Eq. 30, KNS 2020) -------------------------------
  OOS_R2_s1 <- 1 - mse1 / mean(ER1^2)  # nf × SR grid
  OOS_R2_s2 <- 1 - mse2 / mean(ER2^2)
  OOS_R2    <- (OOS_R2_s1 + OOS_R2_s2) / 2
  colnames(OOS_R2) <- prior_SR
  
  ## ---- 4.  Extract optimum -------------------------------------------------
  max_idx <- which(OOS_R2 == max(OOS_R2), arr.ind = TRUE)[1, ]  # row, col
  nf_opt  <- max_idx[1]                         # column index  = # factors kept
  sr_opt  <- max_idx[2]/10                      # row index     = SR choice
  nfac    <- ncol(Rkns) + 1 - nf_opt            # adjusted factors
  
  summary_df <- data.frame(
    nf       = nf_opt,
    nfac     = nfac,
    SR       = sr_opt,
    row.names = NULL
  )
  
  if (verbose) {
    cat("\n*** KNS-OOS SUMMARY ***\n")
    print(summary_df, row.names = FALSE)
  }
  
  # Compute lambdas and PCs #
  Rkns.sd     <- t(t(Rkns) / colSds(Rkns))
  pca_output  <- elastic_net_pc(Rkns.sd, as.numeric(sr_opt)/sqrt(12))       
  lambda.pca1 <- matrix(pca_output[[1]][as.numeric(nf_opt),1,], ncol=1)  
  PCs         <- (Rkns.sd %*% pca_output[[2]])
  lambda.pca1 <- lambda.pca1 * colSds(PCs)
  PCs         <- t(t(PCs) / colSds(PCs))
  
  # Remove / pick non-zero elements #
  nz_idx      <- which(lambda.pca1 != 0)         
  lambda.pca1 <- lambda.pca1[nz_idx]
  PCs         <- PCs[ , nz_idx, drop = FALSE] 
  
  ## ---- 5.  Return ----------------------------------------------------------
  invisible(list(
    summary     = summary_df,
    kns_lambdas = lambda.pca1,
    kns_PCs     = PCs,
    pca_output  = pca_output,
    nz_idx      = nz_idx
    
  )
  )
}


