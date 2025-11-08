# ---------------------------------------------------------------------------
#  estim_rppca()
# ---------------------------------------------------------------------------
# Computes the “Risk-Parity” PCA of Kozak–Nagel–Shanken (2020, §3.5).
# Columns are first scaled by σ_j; the eigen-decomposition of
#
#        Σ̂ + κ · μ μᵀ
#
# is taken, where Σ̂ = 1/T · RᵀR and μ = E[R].
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
