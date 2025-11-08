#### Sharpe ####
SharpeRatio <- function(R) {
  
  ER <- matrix(colMeans(R), ncol=1)
  covR <- cov(R)
  return(t(ER)%*%solve(covR)%*%ER)
  
}

#### GMM ####
gmm_estimation <- function(R, f, W, include.intercept = TRUE) {
  library(proxyC)
  # R: matrix of test assets with dimension t times N, where N is the number of test assets;
  # f: matrix of factors with dimension t times k, where k is the number of factors and t is
  #    the number of periods;
  # W: weighting matrix in GMM estimation.
  R <- t(t(R)/colSds(R))   # standardize returns
  f <- t(t(f)/colSds(f))   # standardize factors
  Sigma_Rf <- cov(R, f)
  ER <- matrix(colMeans(R), ncol=1)
  if (include.intercept == TRUE) {
    N <- dim(R)[2]
    Sigma_Rf <- cbind(matrix(1,ncol=1,nrow=N), Sigma_Rf)
    return(solve(t(Sigma_Rf)%*%solve(W)%*%Sigma_Rf) %*% t(Sigma_Rf)%*%solve(W)%*%ER)
  } else {
    return(solve(t(Sigma_Rf)%*%solve(W)%*%Sigma_Rf) %*% t(Sigma_Rf)%*%solve(W)%*%ER)
  }
}

#### Drop Factors ###
drop_factors <- function(fac, fac_to_drop = NULL, verbose = TRUE) {
  
  if (is.null(fac_to_drop) ||
      (length(fac_to_drop$top_gamma)  == 0L &&
       length(fac_to_drop$top_lambda) == 0L)) {
    return(fac)                       # nothing to do
  }
  
  # 1. build the drop set -----------------------------------------------------
  drop_set <- unique( unlist(fac_to_drop, use.names = FALSE) )
  
  # 2. quick helper to strip columns from a matrix ---------------------------
  strip_cols <- function(mat) {
    if (is.null(mat)) return(NULL)
    keep <- !colnames(mat) %in% drop_set
    mat[ , keep, drop = FALSE]
  }
  
  fac$f1        <- strip_cols(fac$f1)
  fac$f2        <- strip_cols(fac$f2)
  fac$f_all_raw <- strip_cols(fac$f_all_raw)
  
  # 3. update name vectors ----------------------------------------------------
  fac$nontraded_names <- setdiff(fac$nontraded_names, drop_set)
  fac$bond_names      <- if (!is.null(fac$bond_names))
    setdiff(fac$bond_names, drop_set) else NULL
  fac$stock_names     <- if (!is.null(fac$stock_names))
    setdiff(fac$stock_names, drop_set) else NULL
  
  # 4. refresh counts & master name list --------------------------------------
  fac$n_nontraded <- length(fac$nontraded_names)
  fac$n_bondfac   <- if (!is.null(fac$bond_names))
    length(fac$bond_names) else NULL
  fac$n_stockfac  <- if (!is.null(fac$stock_names))
    length(fac$stock_names) else NULL
  
  fac$all_factor_names <- c(fac$nontraded_names,
                            fac$bond_names  %||% character(0),
                            fac$stock_names %||% character(0))
  
  # 5. warn about any requested drops that were not present -------------------
  if (verbose) {
    missing <- setdiff(drop_set, fac$all_factor_names)
    if (length(missing))
      message("Dropped factors are: ",
              paste(missing, collapse = ", "))
  }
  
  fac
}

#### RP-PCA ####
estim_rppca <- function(R,
                        f2      = NULL,
                        kappa   = 20,
                        npc     = 5,
                        verbose = TRUE) {
  
  ## ---- 0.  Checks ----------------------------------------------------------
  stopifnot(is.matrix(R))
  if (!is.null(f2)) stopifnot(is.matrix(f2), nrow(f2) == nrow(R))
  if (npc < 1L)       stop("npc must be ≥ 1")
  if (kappa <= 0)     stop("kappa must be positive")
  
  ## ---- 1.  Combine & standardise ------------------------------------------
  X <- if (is.null(f2)) R else cbind(R, f2)
  
  # fast column sds (matrixStats is ~10× faster for big matrices)
  if (requireNamespace("matrixStats", quietly = TRUE)) {
    sds <- matrixStats::colSds(X)
  } else {
    sds <- apply(X, 2, sd)
  }
  X_scale <- t( t(X) / sds )        # scale but do not demean
  
  mu   <- matrix(colMeans(X_scale), ncol = 1)
  Tobs <- nrow(X_scale)
  
  ## ---- 2.  RP-PCA eigen-decomposition -------------------------------------
  Sigma_hat <- crossprod(X_scale) / Tobs        # t(X)%*%X
  M_plus    <- Sigma_hat + kappa * mu %*% t(mu)
  
  eig <- eigen(M_plus, symmetric = TRUE)
  loadings <- eig$vectors
  eigval   <- eig$values
  
  if (npc > ncol(loadings))
    stop("npc (", npc, ") exceeds number of available PCs (", ncol(loadings), ")")
  
  ## ---- 3.  Return requested PCs -------------------------------------------
  F_pc <- X %*% loadings[ , seq_len(npc), drop = FALSE]
  colnames(F_pc) <- paste0("PC", seq_len(npc))
  
  if (verbose) {
    cat("\n*** RP-PCA SUMMARY ***\n")
    cat("κ           :", kappa, "\n")
    cat("PCs returned:", npc, "\n")
    cat("Explained λ :", round(sum(eigval[1:npc]) / sum(eigval), 3), "\n")
  }
  
  invisible(list(loadings = loadings,
                 factors   = F_pc,
                 eigval    = eigval,
                 kappa     = kappa,
                 npc       = npc))
}

#### Sparse Model Params ####
beta_params_auto_sd <- function(expec_fac,
                                tot_fac = 54) {
  
  ## ---- 1. Basic checks ----
  if (length(expec_fac) != 1 || length(tot_fac) != 1)
    stop("Supply scalar values for expec_fac and tot_fac.")
  if (expec_fac <= 0 || expec_fac >= tot_fac)
    stop("expec_fac must lie strictly between 0 and tot_fac.")
  
  ## ---- 2. Choose σ so ±2σ hits the closer boundary ----
  sd_count <- min(expec_fac, tot_fac - expec_fac) / 2      # one-σ in *counts*
  
  ## ---- 3. Convert to proportions ----
  mean_prop <- expec_fac / tot_fac
  sd_prop   <- sd_count / tot_fac
  var_prop  <- sd_prop^2
  
  ## ---- 4. Feasibility check for Beta variance ----
  vmax <- mean_prop * (1 - mean_prop)            # theoretical upper limit
  if (var_prop >= vmax)
    stop("Automatic σ is too wide for a Beta prior; "
         ,"reduce expec_fac or tot_fac.")
  
  ## ---- 5. Solve for (α,β) ----
  s      <- mean_prop * (1 - mean_prop) / var_prop - 1      # α+β
  alpha  <- mean_prop * s
  beta   <- (1 - mean_prop) * s
  
  ## ---- 6. Package results ----
  list(
    ## counts
    mean_count   = expec_fac,
    sd_count     = sd_count,
    lower2_count = expec_fac - 2 * sd_count,       # touches [0, tot_fac]
    upper2_count = expec_fac + 2 * sd_count,
    
    ## proportions
    mean_prop = mean_prop,
    sd_prop   = sd_prop,
    var_prop  = var_prop,
    
    ## Beta parameters
    alpha = alpha,
    beta  = beta
  )
}

#### KNS ####
## Reference: Shrinking the cross-section, by Kozak, Nagel, and 
## Santosh (2020, JFE) (also denoted as KNS).
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
  
  # ---- 3.  OOS R2 surface (Eq. 30, KNS 2020) -------------------------------
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

#### psi to prior multi-asset ####
psi_to_priorSR_multi_asset <- function(R, f,
                                       psi0      = NULL,
                                       priorSR   = NULL,
                                       aw        = 1,
                                       bw        = 1,
                                       w         = NULL,
                                       kappa     = NULL,      # either:  numeric (legacy), named numeric (new)
                                       kappa_fac = NULL) {    # list of factor groups (legacy) or NULL
  ## ---- 1. κ handling ---------------------------------------------------
  κ_vec <- numeric(ncol(f))            # default = 0 for every factor
  names(κ_vec) <- colnames(f)
  
  if (!is.null(kappa)) {
    
    ## ---- 1a. NEW interface – named numeric -----------------------------
    if (!is.null(names(kappa)) && all(names(kappa) != "")) {
      matched <- intersect(names(kappa), names(κ_vec))
      κ_vec[matched] <- kappa[matched]          # direct per-factor deviations
    }
    
    ## ---- 1b. LEGACY interface – group weights --------------------------
    else if (!is.null(kappa_fac)) {
      for (g in seq_along(kappa)) {
        fac_grp <- kappa_fac[[g]]
        κ_vec[fac_grp] <- kappa[g]
      }
    }
  }
  
  scaling <- 1 + κ_vec                # per-factor multiplier (length = ncol(f))
  
  ## ---- 2. helper -------------------------------------------------------
  SR_quad <- function(Rmat) {
    μ <- colMeans(Rmat)
    Σ <- cov(Rmat)
    drop(t(μ) %*% solve(Σ) %*% μ)     # 
  }
  
  ## ---- 3. ingredients --------------------------------------------------
  SR.max <- sqrt(SR_quad(R))
  N      <- ncol(R)
  
  ρtilde <- cor(R, f)
  ρtilde <- sweep(ρtilde, 2, colMeans(ρtilde), FUN = "-")
  ssq    <- diag(t(ρtilde) %*% ρtilde)          # 
  
  if (is.null(w)) w <- rep(1, ncol(f))
  
  ## ---- 4. η ------------------------------------------------------------
  eta <- (aw / (aw + bw)) * sum(w * scaling * ssq) / N
  
  ## ---- 5. main scalar result ------------------------------------------
  main_out <- if (!is.null(psi0)) {                     #  given → implied prior SR
    sqrt((psi0 * eta) / (1 + psi0 * eta)) * SR.max
  } else if (!is.null(priorSR)) {                       # prior SR given → implied 
    priorSR^2 / ((SR.max^2 - priorSR^2) * eta)
  } else {
    stop("Either `psi0` or `priorSR` must be supplied.")  # still a necessary guard
  }
  
  ## ---- 6. return -------------------------------------------------------
  list(
    result  = main_out,
    scaling = scaling    # named vector of per-factor multipliers
  )
}

#### continuous sdf multi-asset ####
continuous_ss_sdf_multi_asset <- function (f1, f2, R, sim_length,
                                           psi0      = 1,
                                           r         = 0.001,
                                           aw        = 1,
                                           bw        = 1,
                                           type      = "OLS",
                                           intercept = TRUE,
                                           kappa     = NULL,          # <- NEW
                                           kappa_fac = NULL) {        # <- NEW
  
  ## ---- 0. combine factors & basic dims ---------------------------------
  f   <- cbind(f1, f2)
  k1  <- ncol(f1)
  k2  <- ncol(f2)
  k   <- k1 + k2                    # total factors
  N   <- ncol(R) + k2
  t   <- nrow(R)
  p   <- k1 + N
  Y   <- cbind(f, R)
  
  ## ---- 1. κ-scaling ----------------------------------------------------
  κ_vec <- numeric(k); names(κ_vec) <- colnames(f)     # default 0
  
  if (!is.null(kappa)) {
    
    ## 1a. NEW interface – named numeric -------------------------------
    if (!is.null(names(kappa)) && all(names(kappa) != "")) {
      matched <- intersect(names(kappa), names(κ_vec))
      κ_vec[matched] <- kappa[matched]
      
      ## 1b. LEGACY interface – group weights ----------------------------
    } else if (!is.null(kappa_fac)) {
      for (g in seq_along(kappa)) {
        κ_vec[kappa_fac[[g]]] <- kappa[g]
      }
    }
  }
  
  scaling <- 1 + κ_vec                                  # per-factor multiplier
  
  ## ---- 2. pre-computations (unchanged) ---------------------------------
  Sigma_ols <- cov(Y)
  Corr_ols  <- cor(Y)
  sd_ols    <- matrixStats::colSds(Y)
  mu_ols    <- matrix(colMeans(Y), ncol = 1)
  
  # check_input2(f, cbind(R, f2))
  
  lambda_path <- if (intercept) matrix(0, nrow = sim_length, ncol = 1 + k)
  else            matrix(0, nrow = sim_length, ncol = k)
  gamma_path  <- matrix(0, nrow = sim_length, ncol = k)
  sdf_path    <- matrix(0, nrow = sim_length, ncol = t)
  
  beta_ols <- if (intercept)
    cbind(1, Corr_ols[(k1 + 1):p, 1:k])
  else
    Corr_ols[(k1 + 1):p, 1:k, drop = FALSE]
  
  a_ols      <- mu_ols[(1 + k1):p, , drop = FALSE] / sd_ols[(1 + k1):p]
  Lambda_ols <- chol2inv(chol(t(beta_ols) %*% beta_ols)) %*% t(beta_ols) %*% a_ols
  
  omega  <- rep(0.5, k)
  gamma  <- rbinom(k, size = 1, prob = omega)
  sigma2 <- as.vector((1 / N) * t(a_ols - beta_ols %*% Lambda_ols) %*%
                        (a_ols - beta_ols %*% Lambda_ols))
  
  r_gamma <- ifelse(gamma == 1, 1, r)
  rho     <- Corr_ols[(k1 + 1):p, 1:k, drop = FALSE]
  rho.demean <- if (intercept)
    rho - matrix(1, nrow = N, ncol = 1) %*% matrix(colMeans(rho), nrow = 1)
  else
    rho
  
  psi <- if (k == 1)
    psi0 * c(t(rho.demean) %*% rho.demean)
  else
    psi0 * diag(t(rho.demean) %*% rho.demean)
  
  ## ---- 3. Gibbs loop ----------------------------------------------------
  for (i in seq_len(sim_length)) {
    set.seed(i)
    
    Sigma        <- MCMCpack::riwish(v = t - 1, S = t * Sigma_ols)
    Var_mu_half  <- chol(Sigma / t)
    mu           <- mu_ols + t(Var_mu_half) %*% matrix(rnorm(p), ncol = 1)
    sd_Y         <- matrix(sqrt(diag(Sigma)), ncol = 1)
    corr_Y       <- Sigma / (sd_Y %*% t(sd_Y))
    C_f          <- corr_Y[(k1 + 1):p, 1:k]
    a            <- mu[(1 + k1):p, , drop = FALSE] / sd_Y[(1 + k1):p]
    beta         <- if (intercept) cbind(1, C_f) else matrix(C_f, nrow = N)
    corrR        <- corr_Y[(k1 + 1):p, (k1 + 1):p]
    
    # ----- κ-scaled (r_gamma * psi)  -------------------------------------
    rpsi_scaled <- scaling * r_gamma * psi   # length-k vector
    
    D <- if (intercept) {
      diag(c(1 / 1e5, 1 / rpsi_scaled))
    } else if (k == 1) {
      matrix(1 / rpsi_scaled)
    } else {
      diag(1 / rpsi_scaled)
    }
    # --------------------------------------------------------------------
    
    ## ... rest of the loop (unchanged) ...
    if (type == "OLS") {
      beta_D_inv <- chol2inv(chol(t(beta) %*% beta + D))
      cov_Lambda <- sigma2 * beta_D_inv
      Lambda_hat <- beta_D_inv %*% t(beta) %*% a
    } else {                              # GLS
      beta_D_inv <- chol2inv(chol(t(beta) %*% solve(corrR) %*% beta + D))
      cov_Lambda <- sigma2 * beta_D_inv
      Lambda_hat <- beta_D_inv %*% t(beta) %*% solve(corrR) %*% a
    }
    
    Lambda <- Lambda_hat + t(chol(cov_Lambda)) %*%
      matrix(rnorm(nrow(Lambda_hat)), ncol = 1)
    
    log.odds <- log(omega / (1 - omega)) + 0.5 * log(r) +
      0.5 * (if (intercept) Lambda[-1] else Lambda)^2 *
      (1 / r - 1) / (sigma2 * psi)
    
    odds      <- pmin(exp(log.odds), 1000)
    prob      <- odds / (1 + odds)
    gamma     <- rbinom(k, size = 1, prob = prob)
    r_gamma   <- ifelse(gamma == 1, 1, r)
    gamma_path[i, ] <- gamma
    omega     <- rbeta(k, aw + gamma, bw + 1 - gamma)
    
    # update sigma2
    resid <- a - beta %*% Lambda
    quad  <- if (type == "GLS") t(resid) %*% solve(corrR) %*% resid else t(resid) %*% resid
    sigma2 <- MCMCpack::rinvgamma(1,
                                  shape = (N + nrow(Lambda)) / 2,
                                  scale = (quad + t(Lambda) %*% D %*% Lambda) / 2)
    
    lambda_path[i, ] <- as.vector(Lambda)
    
    Lambda_f <- if (intercept) Lambda[-1] / matrixStats::colSds(f) else
      Lambda     / matrixStats::colSds(f)
    sdf_path[i, ] <- 1 - f %*% Lambda_f
    sdf_path[i, ] <- 1 + sdf_path[i, ] - mean(sdf_path[i, ])
  }
  
  list(
    gamma_path        = gamma_path,
    lambda_path       = lambda_path,
    sdf_path          = sdf_path,
    bma_sdf           = colMeans(sdf_path),
    kappa_scaling     = scaling  
  )
}

#### contunous sdf no sp multi-asset ####
continuous_ss_sdf_multi_asset_no_sp <- function (f, R, sim_length,
                                                 psi0      = 1,
                                                 r         = 0.001,
                                                 aw        = 1,
                                                 bw        = 1,
                                                 type      = "OLS",
                                                 intercept = TRUE,
                                                 kappa     = NULL,      # NEW: numeric (named = per-factor)
                                                 kappa_fac = NULL) {    # NEW: legacy grouping (optional)
  
  ## ---- 0. basic dims ---------------------------------------------------
  k <- ncol(f)                 # # factors
  t <- nrow(f)                 # time series length
  N <- ncol(R)                 # # assets
  p <- k + N
  Y <- cbind(f, R)
  
  ## ---- 1. κ-scaling ----------------------------------------------------
  κ_vec <- numeric(k); names(κ_vec) <- colnames(f)   # default zeros
  
  if (!is.null(kappa)) {
    if (!is.null(names(kappa)) && all(names(kappa) != "")) {
      ## NEW: named per-factor κ
      matched <- intersect(names(kappa), names(κ_vec))
      κ_vec[matched] <- kappa[matched]
    } else if (!is.null(kappa_fac)) {
      ## LEGACY: grouped κ
      for (g in seq_along(kappa)) {
        κ_vec[kappa_fac[[g]]] <- kappa[g]
      }
    }
  }
  scaling <- 1 + κ_vec                              # length-k multiplier
  ## ---------------------------------------------------------------------
  
  ## ---- 2. pre-computations (unchanged) --------------------------------
  Sigma_ols <- cov(Y)
  Corr_ols  <- cor(Y)
  sd_ols    <- matrixStats::colSds(Y)
  mu_ols    <- matrix(colMeans(Y), ncol = 1)
  
  lambda_path <- if (intercept) matrix(0, sim_length, 1 + k) else matrix(0, sim_length, k)
  gamma_path  <- matrix(0, sim_length, k)
  sdf_path    <- matrix(0, sim_length, t)
  
  beta_ols <- if (intercept)
    cbind(1, Corr_ols[(k + 1):p, 1:k])
  else
    Corr_ols[(k + 1):p, 1:k, drop = FALSE]
  
  a_ols      <- mu_ols[(k + 1):p, , drop = FALSE] / sd_ols[(k + 1):p]
  Lambda_ols <- chol2inv(chol(t(beta_ols) %*% beta_ols)) %*% t(beta_ols) %*% a_ols
  
  omega  <- rep(0.5, k)
  gamma  <- rbinom(k, 1, omega)
  sigma2 <- as.vector((1 / N) * t(a_ols - beta_ols %*% Lambda_ols) %*%
                        (a_ols - beta_ols %*% Lambda_ols))
  
  r_gamma <- ifelse(gamma == 1, 1, r)
  rho     <- Corr_ols[(k + 1):p, 1:k, drop = FALSE]
  rho.demean <- if (intercept)
    rho - matrix(1, N, 1) %*% matrix(colMeans(rho), 1)
  else
    rho
  
  psi <- if (k == 1)
    psi0 * c(t(rho.demean) %*% rho.demean)
  else
    psi0 * diag(t(rho.demean) %*% rho.demean)
  
  ## ---- 3. Gibbs loop ---------------------------------------------------
  for (i in seq_len(sim_length)) {
    set.seed(i)
    
    Sigma        <- MCMCpack::riwish(v = t - 1, S = t * Sigma_ols)
    Var_mu_half  <- chol(Sigma / t)
    mu           <- mu_ols + t(Var_mu_half) %*% matrix(rnorm(p), ncol = 1)
    sd_Y         <- matrix(sqrt(diag(Sigma)), ncol = 1)
    corr_Y       <- Sigma / (sd_Y %*% t(sd_Y))
    C_f          <- corr_Y[(k + 1):p, 1:k]
    a            <- mu[(k + 1):p, 1, drop = FALSE] / sd_Y[(k + 1):p]
    beta         <- if (intercept) cbind(1, C_f) else matrix(C_f, nrow = N)
    corrR        <- corr_Y[(k + 1):p, (k + 1):p]
    
    ## ----- κ-scaled (r_gamma * psi) ------------------------------------
    rpsi_scaled <- scaling * r_gamma * psi            # length-k vector
    
    D <- if (intercept) {
      diag(c(1 / 1e5, 1 / rpsi_scaled))
    } else if (k == 1) {
      matrix(1 / rpsi_scaled)
    } else {
      diag(1 / rpsi_scaled)
    }
    ## -------------------------------------------------------------------
    
    if (type == "OLS") {
      beta_D_inv <- chol2inv(chol(t(beta) %*% beta + D))
      cov_Lambda <- sigma2 * beta_D_inv
      Lambda_hat <- beta_D_inv %*% t(beta) %*% a
    } else {                    # GLS
      beta_D_inv <- chol2inv(chol(t(beta) %*% solve(corrR) %*% beta + D))
      cov_Lambda <- sigma2 * beta_D_inv
      Lambda_hat <- beta_D_inv %*% t(beta) %*% solve(corrR) %*% a
    }
    
    Lambda <- Lambda_hat + t(chol(cov_Lambda)) %*%
      matrix(rnorm(nrow(Lambda_hat)), ncol = 1)
    
    log.odds <- log(omega / (1 - omega)) + 0.5 * log(r) +
      0.5 * (if (intercept) Lambda[-1] else Lambda)^2 *
      (1 / r - 1) / (sigma2 * psi)
    
    odds      <- pmin(exp(log.odds), 1000)
    prob      <- odds / (1 + odds)
    gamma     <- rbinom(k, 1, prob)
    r_gamma   <- ifelse(gamma == 1, 1, r)
    gamma_path[i, ] <- gamma
    omega     <- rbeta(k, aw + gamma, bw + 1 - gamma)
    
    ## update sigma2 – unchanged ...
    if (type == "OLS") {
      quad <- t(a - beta %*% Lambda) %*% (a - beta %*% Lambda)
    } else {                    # GLS
      quad <- t(a - beta %*% Lambda) %*% solve(corrR) %*% (a - beta %*% Lambda)
    }
    sigma2 <- MCMCpack::rinvgamma(1,
                                  shape = (N + if (intercept) k + 1 else k) / 2,
                                  scale = (quad + t(Lambda) %*% D %*% Lambda) / 2)
    
    lambda_path[i, ] <- as.vector(Lambda)
    
    Lambda_f <- if (intercept) Lambda[-1] / matrixStats::colSds(f) else
      Lambda     / matrixStats::colSds(f)
    sdf_path[i, ] <- 1 - f %*% Lambda_f
    sdf_path[i, ] <- 1 + sdf_path[i, ] - mean(sdf_path[i, ])
  }
  
  list(
    gamma_path    = gamma_path,
    lambda_path   = lambda_path,
    sdf_path      = sdf_path,
    bma_sdf       = colMeans(sdf_path),
    kappa_scaling = scaling        # NEW: handy to inspect
  )
}

#### DR/DF weights ####
get_factor_weights <- function(vd, f,
                               type  = c("all", "DR", "CF"),
                               spike = FALSE,
                               allow_negative = TRUE) {
  library(dplyr)
  
  type <- match.arg(type)
  opp  <- if (type == "DR") "CF"
  else if (type == "CF") "DR"
  else NA_character_
  
  # ── 1. Core look-up table --------------------------------------------------
  df_core <- vd %>%
    dplyr::select(factors, DRr, DR_CF)
  
  factor_order <- colnames(f)
  
  df_aligned <- tibble(factors = factor_order) %>%           # preserve order
    left_join(df_core, by = "factors") %>%
    mutate(
      DRr   = coalesce(DRr,   0),
      DR_CF = coalesce(DR_CF, "")
    )
  
  # ── 2. Build signed weights -----------------------------------------------
  if (type == "all") {
    
    ## Long-only weights (unchanged – may not sum to 0)
    total_wt <- sum(df_aligned$DRr[df_aligned$DRr != 0])
    base_wts <- if (total_wt == 0) rep(0, length(factor_order))
    else df_aligned$DRr / total_wt
    
  } else if (allow_negative) {
    
    ## Positive on ‘type’, negative on the opposite; rescale so Σw = 0
    pos_mask <- df_aligned$DR_CF == type & df_aligned$DRr != 0
    neg_mask <- df_aligned$DR_CF == opp  & df_aligned$DRr != 0
    
    signed_vals <- numeric(length(factor_order))
    signed_vals[pos_mask] <-  df_aligned$DRr[pos_mask]       # + side
    signed_vals[neg_mask] <- -df_aligned$DRr[neg_mask]       # – side
    
    pos_total <- sum(signed_vals[signed_vals > 0])
    neg_total <- sum(abs(signed_vals[signed_vals < 0]))
    
    if (pos_total == 0 && neg_total == 0) {
      base_wts <- rep(0, length(factor_order))               # no active weights
    } else if (pos_total == 0 || neg_total == 0) {
      ## One-sided case: keep original scale (cannot reach Σw = 0)
      base_wts <- signed_vals
    } else {
      ## Rescale each side so longs sum to +1 and shorts to –1  → Σw = 0
      base_wts <- signed_vals
      base_wts[base_wts > 0] <-  base_wts[base_wts > 0] /  pos_total
      base_wts[base_wts < 0] <-  base_wts[base_wts < 0] /  neg_total
    }
    
  } else {
    
    ## Previous behaviour: opposite side forced to 0
    df_aligned <- df_aligned %>%
      mutate(DRr = if_else(DR_CF == type, DRr, 0))
    
    total_wt <- sum(df_aligned$DRr[df_aligned$DRr != 0])
    base_wts <- if (total_wt == 0) rep(0, length(factor_order))
    else ifelse(df_aligned$DRr == 0, 0,
                df_aligned$DRr / total_wt)
  }
  
  # ── 3. Optional spike treatment -------------------------------------------
  if (spike && type != "all") {
    spike_mask <- df_aligned$DR_CF == opp   # rows to receive −1
    base_wts[spike_mask] <- -1
  }
  
  # ── 4. Return --------------------------------------------------------------
  setNames(base_wts, factor_order)
}

#### IS AP ####
insample_asset_pricing <- function(results=results,f_all=f_all_raw,R=R,f1=f1,f2=f2,
                                   rp_out=rp_out, kns_out=kns_out,
                                   intercept=intercept,
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
  factor_specs <- c(
    freq_models,
    list(
      Top       = top5_list[[4]],
      `Top-MPR` = top5_mpr_list[[4]]
    )
  )
  
  # GMM estimation in one pass
  lambda_hat <- imap(
    factor_specs,
    ~ gmm_estimation(Rc, as.matrix(select(f_all, all_of(.x))), W = W)
  )
  
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
  
  # Add frequentist models dynamically
  for (model_name in names(factor_specs)) {
    factor_cols <- factor_specs[[model_name]]
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
    names(factor_specs),                           # Frequentist models (includes Top/Top-MPR)
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
  
  # Build SDF specs dynamically - only for models where factors are in f_all
  sdf_specs <- list()
  
  # Add frequentist models if all factors are available
  for (model_name in names(factor_specs)) {
    factor_cols <- factor_specs[[model_name]]
    
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

#### Validate dates ####
validate_and_align_dates <- function(data_list, 
                                     date_start = NULL, 
                                     date_end = NULL,
                                     verbose = TRUE) {
  
  # Load required package
  if (!requireNamespace("lubridate", quietly = TRUE)) {
    stop("Package 'lubridate' is required. Install with: install.packages('lubridate')")
  }
  
  ## ---- 1. Validate inputs ----------------------------------------------------
  if (!is.list(data_list) || length(data_list) == 0) {
    stop("data_list must be a non-empty named list of datasets")
  }
  
  if (is.null(names(data_list)) || any(names(data_list) == "")) {
    stop("data_list must have names for all elements (e.g., list(R = ..., f1 = ...))")
  }
  
  if (verbose) message("Validating and aligning dates across ", length(data_list), " datasets...")
  
  ## ---- 2. Process each dataset -----------------------------------------------
  processed_data <- list()
  date_ranges <- list()
  
  for (name in names(data_list)) {
    if (verbose) message("  Processing: ", name)
    
    dataset <- data_list[[name]]
    
    # Convert matrix to data.frame
    if (is.matrix(dataset)) {
      dataset <- as.data.frame(dataset, stringsAsFactors = FALSE)
    }
    
    if (!is.data.frame(dataset)) {
      stop(sprintf("Dataset '%s' must be a data.frame or matrix", name))
    }
    
    if (ncol(dataset) < 2) {
      stop(sprintf("Dataset '%s' must have at least 2 columns (date + data)", name))
    }
    
    # Check if first column is named "date" (case-insensitive)
    first_col_name <- colnames(dataset)[1]
    if (tolower(first_col_name) != "date") {
      if (verbose) {
        message(sprintf("    WARNING: First column '%s' is not named 'date'. Renaming to 'date'.", 
                        first_col_name))
      }
      colnames(dataset)[1] <- "date"
    }
    
    # Extract date column
    date_col <- dataset[[1]]
    
    # Check for NaN/NA in date column
    if (any(is.na(date_col))) {
      na_count <- sum(is.na(date_col))
      stop(sprintf("Dataset '%s': Date column contains %d NA/NaN values. Please clean your data.", 
                   name, na_count))
    }
    
    # Parse dates robustly
    parsed_dates <- parse_dates_robust(date_col, dataset_name = name, verbose = verbose)
    
    # Validate all dates parsed successfully
    if (any(is.na(parsed_dates))) {
      na_count <- sum(is.na(parsed_dates))
      stop(sprintf("Dataset '%s': %d dates failed to parse. Check date format.", name, na_count))
    }
    
    # Replace date column with parsed dates
    dataset[[1]] <- parsed_dates
    
    # Check for NaN/NA in numeric columns
    numeric_cols <- sapply(dataset[, -1, drop = FALSE], is.numeric)
    if (any(numeric_cols)) {
      numeric_data <- dataset[, -1, drop = FALSE][, numeric_cols, drop = FALSE]
      na_check <- sapply(numeric_data, function(x) sum(is.na(x)))
      
      if (any(na_check > 0)) {
        na_cols <- names(na_check[na_check > 0])
        na_summary <- paste(sprintf("  - %s: %d NAs", na_cols, na_check[na_check > 0]), 
                            collapse = "\n")
        stop(sprintf("Dataset '%s': Found NA/NaN values in numeric columns:\n%s\nPlease clean your data.", 
                     name, na_summary))
      }
    }
    
    # Store processed dataset and date range
    processed_data[[name]] <- dataset
    date_ranges[[name]] <- range(parsed_dates)
  }
  
  ## ---- 3. Find common date range ---------------------------------------------
  if (verbose) message("Finding common date range...")
  
  all_starts <- sapply(date_ranges, function(x) x[1])
  all_ends   <- sapply(date_ranges, function(x) x[2])
  
  common_start <- max(all_starts)
  common_end   <- min(all_ends)
  
  if (common_start > common_end) {
    date_summary <- sapply(names(date_ranges), function(nm) {
      rng <- date_ranges[[nm]]
      sprintf("  %s: %s to %s", nm, rng[1], rng[2])
    })
    stop(sprintf("ERROR: No overlapping dates found across datasets. Check date ranges:\n%s", 
                 paste(date_summary, collapse = "\n")))
  }
  
  ## ---- 4. Apply user-specified date filters ----------------------------------
  filter_start <- common_start
  filter_end   <- common_end
  
  if (!is.null(date_start)) {
    date_start_parsed <- as.Date(date_start)
    if (is.na(date_start_parsed)) {
      stop("date_start must be in YYYY-MM-DD format, got: ", date_start)
    }
    if (date_start_parsed < common_start) {
      if (verbose) {
        message(sprintf("  WARNING: date_start (%s) is before common start (%s). Using common start.", 
                        date_start, common_start))
      }
    } else {
      filter_start <- date_start_parsed
    }
  }
  
  if (!is.null(date_end)) {
    date_end_parsed <- as.Date(date_end)
    if (is.na(date_end_parsed)) {
      stop("date_end must be in YYYY-MM-DD format, got: ", date_end)
    }
    if (date_end_parsed > common_end) {
      if (verbose) {
        message(sprintf("  WARNING: date_end (%s) is after common end (%s). Using common end.", 
                        date_end, common_end))
      }
    } else {
      filter_end <- date_end_parsed
    }
  }
  
  if (filter_start > filter_end) {
    stop(sprintf("Invalid date range: start (%s) is after end (%s)", filter_start, filter_end))
  }
  
  ## ---- 5. Align datasets to common dates -------------------------------------
  if (verbose) message("Aligning datasets to common dates...")
  
  aligned_data <- list()
  
  for (name in names(processed_data)) {
    dataset <- processed_data[[name]]
    date_col <- dataset[[1]]
    
    # Filter to common date range
    in_range <- (date_col >= filter_start) & (date_col <= filter_end)
    
    if (sum(in_range) == 0) {
      stop(sprintf("Dataset '%s': No observations in date range [%s, %s]", 
                   name, filter_start, filter_end))
    }
    
    aligned_data[[name]] <- dataset[in_range, , drop = FALSE]
  }
  
  # Verify all datasets have same dates
  date_counts <- sapply(aligned_data, nrow)
  if (length(unique(date_counts)) > 1) {
    count_summary <- paste(sprintf("  %s: %d rows", names(date_counts), date_counts), 
                           collapse = "\n")
    stop(sprintf("ERROR: Datasets have different numbers of observations after alignment:\n%s", 
                 count_summary))
  }
  
  # Check that dates are identical across datasets
  first_dates <- aligned_data[[1]][[1]]
  for (name in names(aligned_data)[-1]) {
    if (!identical(aligned_data[[name]][[1]], first_dates)) {
      stop(sprintf("Dataset '%s': Dates do not match first dataset after alignment", name))
    }
  }
  
  n_periods <- nrow(aligned_data[[1]])
  
  if (verbose) {
    message(sprintf("  SUCCESS: All datasets aligned to %d periods [%s to %s]", 
                    n_periods, filter_start, filter_end))
  }
  
  ## ---- 6. Return results -----------------------------------------------------
  return(list(
    data = aligned_data,
    date_range = c(start = filter_start, end = filter_end),
    n_periods = n_periods,
    original_ranges = date_ranges
  ))
}


#' Parse Dates Robustly Using Multiple Formats
#'
#' Tries multiple date parsing strategies using lubridate.
#' All dates must convert to YYYY-MM-DD format or function fails.
#'
#' @param date_col Vector of dates (character, factor, or numeric)
#' @param dataset_name Name of dataset (for error messages)
#' @param verbose Print parsing info
#' @return Vector of Date objects in YYYY-MM-DD format

parse_dates_robust <- function(date_col, dataset_name = "unknown", verbose = TRUE) {
  
  # Convert factor or numeric to character
  if (is.factor(date_col)) {
    date_col <- as.character(date_col)
  } else if (is.numeric(date_col)) {
    date_col <- as.character(date_col)
  }
  
  if (!is.character(date_col)) {
    stop(sprintf("Dataset '%s': Date column must be character, factor, or numeric. Got: %s", 
                 dataset_name, class(date_col)[1]))
  }
  
  # Remove leading/trailing whitespace
  date_col <- trimws(date_col)
  
  # Strategy 1: Try dmy (DD/MM/YYYY) - Europe/Australia format
  parsed <- lubridate::dmy(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using DD/MM/YYYY format"))
    return(parsed)
  }
  
  # Strategy 2: Try mdy (MM/DD/YYYY) - US format
  parsed <- lubridate::mdy(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using MM/DD/YYYY format"))
    return(parsed)
  }
  
  # Strategy 3: Try ymd (YYYY-MM-DD) - ISO format
  parsed <- lubridate::ymd(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using YYYY-MM-DD format"))
    return(parsed)
  }
  
  # Strategy 4: Try ydm (YYYY-DD-MM)
  parsed <- lubridate::ydm(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using YYYY-DD-MM format"))
    return(parsed)
  }
  
  # Strategy 5: Try multiple formats with parse_date_time
  formats <- c("dmy", "mdy", "ymd", "ydm", "dmy HMS", "mdy HMS", "ymd HMS")
  parsed <- lubridate::parse_date_time(date_col, orders = formats, quiet = TRUE)
  
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using mixed format detection"))
    return(as.Date(parsed))
  }
  
  # If we get here, parsing failed
  failed_samples <- head(date_col[is.na(parsed)], 5)
  stop(sprintf("Dataset '%s': Could not parse dates. Examples of failed dates:\n  %s\n\nSupported formats: DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD", 
               dataset_name, paste(failed_samples, collapse = ", ")))
}

#### data loading ####
read_mat <- function(path_data_fn, fname) {
  as.matrix(utils::read.csv(path_data_fn(fname), check.names = FALSE)[, -1])
}

#' Read matrix with names attribute
#'
#' @param path_data_fn Function that constructs path to data file
#' @param file Filename to read
#' @return Matrix with "fname" attribute containing column names
read_mat_named <- function(path_data_fn, file) {
  m <- read_mat(path_data_fn, file)
  attr(m, "fname") <- colnames(m)
  m
}

#' Get column names from matrix with fname attribute
#'
#' @param x Matrix with fname attribute
#' @return Character vector of column names
get_names <- function(x) {
  attr(x, "fname")
}

#' Calculate Sharpe Ratio from returns matrix
#'
#' @param R Returns matrix (T x N)
#' @return Numeric scalar - squared Sharpe ratio
SharpeRatio <- function(R) {
  mu <- colMeans(R)
  as.numeric(t(mu) %*% solve(stats::cov(R)) %*% mu)
}

#' Format integer with commas or scientific notation
#'
#' @param x Numeric value
#' @return Formatted character string
pretty_int <- function(x) {
  if (abs(x) < 1e9) {
    formatC(x, format = "d", big.mark = ",")
  } else {
    format(x, scientific = TRUE, digits = 3)
  }
}

#' Load test assets based on model type and return type
#'
#' @param model_type Character: "bond", "stock", "bond_stock_with_sp", or "treasury"
#' @param return_type Character: "excess" or "duration"
#' @param path_data_fn Function to construct path to data files
#' @return Matrix of test asset returns
load_test_assets <- function(model_type, return_type, path_data_fn) {
  # Validate inputs
  valid_models <- c("bond", "stock", "bond_stock_with_sp", "treasury")
  if (!model_type %in% valid_models) {
    stop("model_type must be one of: ", paste(valid_models, collapse = ", "))
  }
  
  # Load bond returns
  R_bond <- switch(
    return_type,
    duration = read_mat(path_data_fn, "bond_insample_test_assets_50_duration_tmt.csv"),
    excess   = read_mat(path_data_fn, "bond_insample_test_assets_50_excess.csv")
  )
  
  # Load equity returns if needed
  R_equity <- if (model_type %in% c("bond_stock_with_sp", "stock")) {
    read_mat(path_data_fn, "equity_anomalies_composite_33.csv")
  } else {
    NULL
  }
  
  # Combine based on model type
  R <- switch(
    model_type,
    bond = R_bond,
    stock = R_equity,
    bond_stock_with_sp = cbind(R_bond, R_equity),
    treasury = {
      if (return_type == "excess") {
        read_mat(path_data_fn, "bond_insample_test_assets_50_duration_tmt_tbond.csv")
      } else {
        R_bond
      }
    }
  )
  
  return(R)
}

#' Load factor data based on model configuration
#'
#' @param model_type Character: model specification
#' @param return_type Character: "excess" or "duration"
#' @param path_data_fn Function to construct path to data files
#' @param tag Character: optional tag for special configurations (e.g., "credit")
#' @return List with factor matrices and metadata
load_factors <- function(model_type, return_type, path_data_fn, tag = "baseline") {
  
  # Load all base factor files
  NT   <- read_mat_named(path_data_fn, "nontraded.csv")
  BD_D <- read_mat_named(path_data_fn, "traded_bond_duration_tmt.csv")
  BD_E <- read_mat_named(path_data_fn, "traded_bond_excess.csv")
  EQ_T <- read_mat_named(path_data_fn, "traded_equity.csv")
  
  # Select bond factors based on return type
  bond_factors <- if (return_type == "duration") BD_D else BD_E
  
  # Build factor configuration based on model type
  result <- switch(
    model_type,
    
    # Bond only model
    bond = list(
      f1          = NT,
      f2          = bond_factors,
      f_all_raw   = cbind(NT, bond_factors, EQ_T),
      n_nontraded = ncol(NT),
      n_bondfac   = ncol(bond_factors),
      n_stockfac  = NULL,
      nontraded_names = get_names(NT),
      bond_names      = get_names(bond_factors),
      stock_names     = NULL,
      all_factor_names = c(get_names(NT), get_names(bond_factors))
    ),
    
    # Stock only model
    stock = list(
      f1          = NT,
      f2          = EQ_T,
      f_all_raw   = cbind(NT, BD_E, EQ_T),
      R           = read_mat(path_data_fn, "equity_anomalies_composite_33.csv"),
      n_nontraded = ncol(NT),
      n_bondfac   = NULL,
      n_stockfac  = ncol(EQ_T),
      nontraded_names = get_names(NT),
      bond_names      = NULL,
      stock_names     = get_names(EQ_T),
      all_factor_names = c(get_names(NT), get_names(EQ_T))
    ),
    
    # Bond + Stock with self-pricing
    bond_stock_with_sp = {
      # Handle credit column override if specified
      f1 <- NT
      if (identical(tag, "credit")) {
        f_credit <- read_mat(path_data_fn, "CREDIT_DJM_Corrected.csv")
        f1[, "CREDIT"] <- f_credit
      }
      
      f2 <- cbind(bond_factors, EQ_T)
      
      list(
        f1          = f1,
        f2          = f2,
        f_all_raw   = cbind(f1, f2),
        n_nontraded = ncol(f1),
        n_bondfac   = ncol(bond_factors),
        n_stockfac  = ncol(EQ_T),
        nontraded_names = get_names(f1),
        bond_names      = get_names(bond_factors),
        stock_names     = get_names(EQ_T),
        all_factor_names = c(get_names(f1), get_names(f2))
      )
    },
    
    # Treasury model
    treasury = {
      b_trd <- bond_factors
      f1 <- cbind(NT, b_trd)
      
      list(
        f1          = f1,
        f2          = NULL,
        f_all_raw   = cbind(NT, b_trd, EQ_T),
        n_nontraded = ncol(NT),
        n_bondfac   = ncol(b_trd),
        n_stockfac  = NULL,
        nontraded_names = get_names(NT),
        bond_names      = get_names(b_trd),
        stock_names     = NULL,
        all_factor_names = c(get_names(NT), get_names(b_trd))
      )
    },
    
    stop("Unsupported model_type: ", model_type, 
         ". Must be one of: bond, stock, bond_stock_with_sp, treasury")
  )
  
  return(result)
}


