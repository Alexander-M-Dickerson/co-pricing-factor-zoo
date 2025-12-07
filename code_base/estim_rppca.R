# ---------------------------------------------------------------------------
#  estim_rppca()
# ---------------------------------------------------------------------------
#
#  Args:
#    R       :  T×N matrix of test-asset excess returns
#    f2      :  T×K matrix of tradable factors (may be NULL)
#    kappa   :  Scalar κ (default 20)
#    npc     :  Number of PCs to return (default 5)
#    verbose :  Print a short summary?
#
#  Returns:  list(loadings, factors, eigval, kappa, npc)
#
estim_rppca <- function(R,
                        f2      = NULL,
                        kappa   = 20,
                        npc     = 5,
                        verbose = TRUE) {
  
  ## ---- 0.  Checks ----------------------------------------------------------
  stopifnot(is.matrix(R))
  if (!is.null(f2)) stopifnot(is.matrix(f2), nrow(f2) == nrow(R))
  if (npc < 1L)       stop("npc must be >= 1")
  if (kappa < 0)      stop("kappa must be positive")
  
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
  L_k <- loadings[ , seq_len(npc), drop = FALSE]
  
  # Factors from SCALED data 
  F_pc <- X_scale %*% L_k
  colnames(F_pc) <- paste0("PC", seq_len(npc))
  
  # Weights on RAW (unscaled) returns that reproduce the same factors:
  # w_rpca = diag(1/sds) %*% L_k
  L_k_all <- loadings[ , , drop = FALSE]
  w_rpca <- sweep(L_k_all, 1, 1/sds, `*`)
  colnames(w_rpca) <- paste0("PC", seq_len(ncol(w_rpca)))
  
  # Sum-to-1 (budget-normalized) weights; each column sums exactly to 1
  w_sum       <- colSums(w_rpca)
  w_rpca_sum1 <- sweep(w_rpca, 2, w_sum, `/`)
  colnames(w_rpca_sum1) <- colnames(w_rpca)
  
  if (verbose) {
    cat("\n*** RP-PCA SUMMARY ***\n")
    cat("κ           :", kappa, "\n")
    cat("PCs returned:", npc, "\n")
    cat("Explained lambda :", round(sum(eigval[1:npc]) / sum(eigval), 3), "\n")
  }
  
  invisible(list(loadings = loadings,
                 factors   = F_pc,
                 w_rpca    = w_rpca,        # raw-return weights (reproduce F_pc)
                 w_rpca_sum1 = w_rpca_sum1, # budget-normalized weights (columns sum to 1)
                 eigval    = eigval,
                 kappa     = kappa,
                 npc       = npc))
}


estim_rppca_ts <- function(R,
                        f2      = NULL,
                        kappa   = 20,
                        npc     = 5,
                        verbose = TRUE) {
  
  ## ---- 0.  Checks ----------------------------------------------------------
  stopifnot(is.matrix(R))
  if (!is.null(f2)) stopifnot(is.matrix(f2), nrow(f2) == nrow(R))
  if (npc < 1L)       stop("npc must be >= 1")
  if (kappa < 0)     stop("kappa must be positive")
  
  ## ---- Helper function to run RP-PCA estimation ----------------------------
  run_rppca_estimation <- function(X_input, kappa, npc, label, verbose) {
    
    ## ---- 1.  Standardise ---------------------------------------------------
    # fast column sds (matrixStats is ~10× faster for big matrices)
    if (requireNamespace("matrixStats", quietly = TRUE)) {
      sds <- matrixStats::colSds(X_input)
    } else {
      sds <- apply(X_input, 2, sd)
    }
    X_scale <- t( t(X_input) / sds )        # scale but do not demean
    
    mu   <- matrix(colMeans(X_scale), ncol = 1)
    Tobs <- nrow(X_scale)
    
    ## ---- 2.  RP-PCA eigen-decomposition -------------------------------------
    Sigma_hat <- crossprod(X_scale) / Tobs        # t(X)%*%X
    M_plus    <- Sigma_hat + kappa * mu %*% t(mu)
    
    eig <- eigen(M_plus, symmetric = TRUE)
    loadings <- eig$vectors
    eigval   <- eig$values
    
    if (npc > ncol(loadings))
      stop(paste0("[", label, "] npc (", npc, ") exceeds number of available PCs (", ncol(loadings), ")"))
    
    ## ---- 3.  Return requested PCs -------------------------------------------
    L_k <- loadings[ , seq_len(npc), drop = FALSE]
    
    # Factors from SCALED data 
    F_pc <- X_scale %*% L_k
    colnames(F_pc) <- paste0("PC", seq_len(npc))
    
    # Weights on RAW (unscaled) returns that reproduce the same factors:
    # w_rpca = diag(1/sds) %*% L_k
    L_k_all <- loadings[ , , drop = FALSE]
    w_rpca <- sweep(L_k_all, 1, 1/sds, `*`)
    colnames(w_rpca) <- paste0("PC", seq_len(ncol(w_rpca)))
    
    # Sum-to-1 (budget-normalized) weights; each column sums exactly to 1
    w_sum       <- colSums(w_rpca)
    w_rpca_sum1 <- sweep(w_rpca, 2, w_sum, `/`)
    colnames(w_rpca_sum1) <- colnames(w_rpca)
    
    if (verbose) {
      cat(paste0("\n*** RP-PCA SUMMARY (", label, ") ***\n"))
      cat("κ           :", kappa, "\n")
      cat("PCs returned:", npc, "\n")
      cat("Explained lambda :", round(sum(eigval[1:npc]) / sum(eigval), 3), "\n")
    }
    
    return(list(loadings     = loadings,
                factors      = F_pc,
                w_rpca       = w_rpca,        # raw-return weights (reproduce F_pc)
                w_rpca_sum1  = w_rpca_sum1,   # budget-normalized weights (columns sum to 1)
                eigval       = eigval,
                kappa        = kappa,
                npc          = npc))
  }
  
  ## ---- 1.  Estimate RP-PCA on R+f2 (combined) ------------------------------
  if (verbose) cat("\n=== Estimating RP-PCA on R+f2 (combined) ===\n")
  X_combined <- if (is.null(f2)) R else cbind(R, f2)
  results_combined <- run_rppca_estimation(
    X_input  = X_combined,
    kappa    = kappa,
    npc      = npc,
    label    = "R+f2",
    verbose  = verbose
  )
  
  ## ---- 2.  Estimate RP-PCA on f2 only (if f2 exists) -----------------------
  if (!is.null(f2)) {
    if (verbose) cat("\n=== Estimating RP-PCA on f2 only ===\n")
    results_f2_only <- run_rppca_estimation(
      X_input  = f2,
      kappa    = kappa,
      npc      = npc,
      label    = "f2 only",
      verbose  = verbose
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
