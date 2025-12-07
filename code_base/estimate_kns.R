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
  
  ## Precompute this ONCE instead of inside the grid loops
  inv_cor_R_oos <- solve(cor(R_oos))
  
  n1 <- length(seq_v1)
  n2 <- length(seq_v2)
  N  <- length(mu_f_in)
  P  <- n1 * n2
  
  OOS_stats    <- list(
    MSE        = matrix(NA_real_, nrow = n1, ncol = n2),
    MAPE       = matrix(NA_real_, nrow = n1, ncol = n2),
    SR2_alpha  = matrix(NA_real_, nrow = n1, ncol = n2)
  )
  
  OOS_stats_dm <- list(
    MSE        = matrix(NA_real_, nrow = n1, ncol = n2),
    MAPE       = matrix(NA_real_, nrow = n1, ncol = n2),
    SR2_alpha  = matrix(NA_real_, nrow = n1, ncol = n2)
  )
  
  
  
  ## Build the full (v1, v2) grid -----------------------------------------
  v1_grid <- rep(seq_v1, each = n2)   # length P: v1 varies slowest
  v2_grid <- rep(seq_v2, times = n1)  # length P: v2 varies fastest
  
  # Expand mu_f_in and eigenvalues across the grid
  mu_mat <- matrix(mu_f_in, nrow = N, ncol = P)             # same column replicated
  d_vec  <- diag(D_in)
  d_mat  <- matrix(d_vec,  nrow = N, ncol = P)
  
  v1_mat <- matrix(v1_grid, nrow = N, ncol = P, byrow = TRUE)
  v2_mat <- matrix(v2_grid, nrow = N, ncol = P, byrow = TRUE)
  
  ## 1) All lambdas on the grid (N × P) -------------------------------
  lambda_mat <- (mu_mat - v1_mat) / (d_mat + v2_mat)
  lambda_mat[lambda_mat < 0] <- 0      # pmax(., 0) vectorised
  
  ## 2) All alphas on the grid (N × P) --------------------------------
  ER_mat    <- matrix(ER_oos, nrow = N, ncol = P)     # replicate ER_oos per column
  alpha_mat <- ER_mat - C_f_oos %*% lambda_mat        # big GEMM
  
  ## 3) OOS stats from alpha_mat --------------------------------------
  sqrt12 <- sqrt(12)
  
  # MSE and MAPE
  mse_vec   <- colMeans(alpha_mat^2)
  mape_vec  <- sqrt12 * colMeans(abs(alpha_mat))
  
  # SR^2(alpha): 12 * alpha' inv_cor_R_oos alpha, for each column
  MA        <- inv_cor_R_oos %*% alpha_mat          # N × P
  sr2_vec   <- 12 * colSums(alpha_mat * MA)         # elementwise product then colSums
  
  ## Demeaned alphas
  alpha_dm  <- sweep(alpha_mat, 2L, colMeans(alpha_mat), FUN = "-")
  mse_dm    <- colMeans(alpha_dm^2)
  mape_dm   <- sqrt12 * colMeans(abs(alpha_dm))
  
  MA_dm     <- inv_cor_R_oos %*% alpha_dm
  sr2_dm    <- 12 * colSums(alpha_dm * MA_dm)
  
  ## 4) Reshape vectors back to (n1 × n2) matrices ---------------------
  OOS_stats$MSE       [,] <- matrix(mse_vec,   nrow = n1, ncol = n2, byrow = TRUE)
  OOS_stats$MAPE      [,] <- matrix(mape_vec,  nrow = n1, ncol = n2, byrow = TRUE)
  OOS_stats$SR2_alpha [,] <- matrix(sr2_vec,   nrow = n1, ncol = n2, byrow = TRUE)
  
  OOS_stats_dm$MSE    [,] <- matrix(mse_dm,    nrow = n1, ncol = n2, byrow = TRUE)
  OOS_stats_dm$MAPE   [,] <- matrix(mape_dm,   nrow = n1, ncol = n2, byrow = TRUE)
  OOS_stats_dm$SR2_alpha[,] <- matrix(sr2_dm,  nrow = n1, ncol = n2, byrow = TRUE)
  
  
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
  as.numeric(crossprod(ER, solve(covR, ER)))
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
#   $OOS_R2     full OOS-R2 matrix  (#nf rows × #prior_SR cols)
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
  
  # Extra #
  Q_matrix     <- pca_output[[2]]
  PCs_unscaled <- Rkns.sd %*% Q_matrix
  
  ## ---- 5.  Return ----------------------------------------------------------
  invisible(list(
                 #OOS_R2   = OOS_R2,
                 #best_idx = max_idx,
                 summary     = summary_df,
                 kns_lambdas = lambda.pca1,
                 kns_PCs     = PCs,
                 PCs_unscaled= PCs_unscaled
                 # details  = list(OOS1 = OOS1, OOS2 = OOS2,
                 #                 ER1  = ER1,  ER2  = ER2)
                 )
            )
}

# -----------------------------------------------------------------------
#  estimate_kns_oos() -- for OS Time-series
#  REFACTORED: Estimates KNS on both (R+f2) and (f2 only)
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
  
  ## ---- Helper function to run KNS estimation -------------------------------
  run_kns_estimation <- function(Rkns_input, R_original, label, verbose) {
    n_obs  <- nrow(Rkns_input)              # total time-series length  (T)
    n_fac  <- ncol(Rkns_input)              # number of factors         (N)
    min_T  <- n_fac + 1L                    # strict lower bound so T > N
    
    ## ---- 2.  Initial split-point ------------------------------------------
    split_point <- if (is.numeric(split) && length(split) == 1L) {
      if (split < 1) floor(n_obs * split) else round(split)
    } else {
      stop("`split` must be a single numeric (row index or proportion).")
    }
    if (split_point <= 10 || split_point >= n_obs - 10)
      stop(paste0("`split` leaves too few observations in one subsample (", label, ")."))
    
    T1 <- split_point
    T2 <- n_obs - split_point
    
    ## ---- 3.  Make sure each subsample has T > N ----------------------------
    if (T1 <= n_fac || T2 <= n_fac) {
      # (a) Try a non-overlapping fix by nudging the boundary
      if (n_obs >= 2 * min_T) {
        split_point <- max(min(split_point, n_obs - min_T), min_T)
        T1 <- split_point
        T2 <- n_obs - split_point
      }
    }
    
    ## ---- 4.  Final allocation of R1 and R2 --------------------------------
    if (T1 <= n_fac || T2 <= n_fac) {
      # (b) Still impossible ⇒ fall back to overlapping windows
      if (verbose)
        message(paste0("  [", label, "] Switching to overlapping subsamples to satisfy T > N."))
      R1 <- Rkns_input[1:min_T, , drop = FALSE]
      R2 <- Rkns_input[(n_obs - min_T + 1L):n_obs, , drop = FALSE]
    } else {
      # standard (possibly nudged) non-overlapping split
      R1 <- Rkns_input[1:split_point, , drop = FALSE]
      R2 <- Rkns_input[(split_point + 1L):n_obs, , drop = FALSE]
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
    if (verbose) message(paste0("  [", label, "] Sub-sample (2→1) …"))
    OOS1 <- elastic_net_pc_oos_new(
      R_in  = t( t(R2) / colSds(R2) ),   # in-sample = subsample-2
      R_oos = t( t(R1) / colSds(R1) ),   # OOS       = subsample-1
      prior_SR / annual_div)
    
    if (verbose) message(paste0("  [", label, "] Sub-sample (1→2) …"))
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
    nfac    <- ncol(Rkns_input) + 1 - nf_opt      # adjusted factors
    
    summary_df <- data.frame(
      nf       = nf_opt,
      nfac     = nfac,
      SR       = sr_opt,
      row.names = NULL
    )
    
    if (verbose) {
      cat(paste0("\n*** KNS-OOS SUMMARY (", label, ") ***\n"))
      print(summary_df, row.names = FALSE)
    }
    
    # Compute lambdas and PCs #
    Rkns.sd     <- t(t(Rkns_input) / colSds(Rkns_input))
    # Pull KNS PCs
    pca_output  <- elastic_net_pc(Rkns.sd, summary_df$SR/sqrt(12))  # Optimal SR from 2-Fold CV      
    lambda.pca1 <- matrix(pca_output[[1]][summary_df$nf,1,], ncol=1)# Optimal nf from 2-Fold CV    
    PCs         <- (Rkns.sd %*% pca_output[[2]]) # Create the PCS -- long-short factors
    
    ## 1) SDF time series 
    #sdf <- as.vector(1 - PCs %*% lambda.pca1)
    
    ## 2) Normalize SDF to have mean 1 
    #sdf <- 1 + sdf - mean(sdf)
    
    ## 3) Transform to "tradable" weights
    ## Corr with SDF will be preserved, we just de-scale etc. 
    Q   <- pca_output[[2]]
    lam <- matrix(lambda.pca1, ncol = 1) # This is the optimal/sparse/CV risk prices from KNS
    
    ##    Exact raw-weights that replicate the SDF's payoff component f_t' lambda
    ##    S^{-1} = diag(1 / sd_i) computed from RAW returns R_original
    sig_raw <- apply(R_original, 2, sd)        # N-vector of raw volatilities
    Sinv    <- diag(1 / as.vector(sig_raw))    # N x N
    w_exact <- Sinv %*% (Q %*% lam)            # N x 1   (no budget normalization)
    
    ## Traded portfolio returns from raw returns
    #r_port_exact <- as.vector(R_original %*% w_exact)   # T-vector
    
    ## 4) Budget-1 normalization (weights sum to 1)
    s1          <- sum(w_exact)
    w_1sum      <- as.vector(w_exact) / s1
    #r_port_1sum <- as.vector(R_original %*% w_1sum)
    
    ## 5) Weights on the long-short KNS PCs 
    # Raw volatilities and S^{-1}
    sig_raw <- apply(R_original, 2, sd)
    Sinv    <- diag(1 / as.vector(sig_raw))
    
    Q  <- pca_output[[2]]           # sign-normalized eigenvectors
    W_raw <- Sinv %*% Q             # N x N matrix: column j = raw weights for PC j
    
    # Inputs: R_original (T x N), Q, Sinv (N x N), PCs (T x N)
    w_raw_pc  <- Sinv %*% Q  # N x N
    sums <- colSums(W_raw)
    w_sum1_pc <- sweep(w_raw_pc, 2, sums, "/")
    
    ## ---- Return list -------------------------------------------------------
    return(list(
      summary     = summary_df,
      pca_output  = pca_output,
      kns_lambdas = lambda.pca1,
      kns_w_exact = w_exact,
      kns_w1      = w_1sum,
      w_raw_pc    = w_raw_pc,
      w_sum1_pc   = w_sum1_pc,
      kns_PCs     = PCs
    ))
  }
  
  ## ---- 1.  Estimate KNS on R+f2 (combined) ---------------------------------
  if (verbose) cat("\n=== Estimating KNS on R+f2 (combined) ===\n")
  Rkns_combined <- if (is.null(f2)) R else cbind(R, f2)
  results_combined <- run_kns_estimation(
    Rkns_input   = Rkns_combined,
    R_original   = Rkns_combined,
    label        = "R+f2",
    verbose      = verbose
  )
  
  ## ---- 2.  Estimate KNS on f2 only (if f2 exists) --------------------------
  if (!is.null(f2)) {
    if (verbose) cat("\n=== Estimating KNS on f2 only ===\n")
    results_f2_only <- run_kns_estimation(
      Rkns_input   = f2,
      R_original   = f2,
      label        = "f2 only",
      verbose      = verbose
    )
  } else {
    results_f2_only <- NULL
  }
  
  ## ---- 3.  Return both sets of results -------------------------------------
  output <- list(
    combined = results_combined,
    f2_only  = results_f2_only
  )
  
  invisible(output)
}