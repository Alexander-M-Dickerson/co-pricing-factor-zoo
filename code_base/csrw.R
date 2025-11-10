# -------------------------------------------------------------------
# csrw_core()
#   - Returns: beta_matrix, beta_rp, cov_matrix, cov_rp,
#              H_betas, H_covs, A_betas, A_covs
#   - type = "OLS"  ->  W = I_N
#   - type = "GLS"  ->  W = V22^{-1}
#   - include_constant:
#       TRUE  -> prepend a column of ones (default)
#       FALSE -> no intercept
# -------------------------------------------------------------------
csrw_core <- function(R,
                      F,
                      type = c("GLS", "OLS"),
                      include_constant = TRUE) {
  
  # ---- 1. Pre-flight -------------------------------------------------------
  type <- match.arg(type)
  if (!is.matrix(R)) R <- as.matrix(R)
  if (!is.matrix(F)) F <- as.matrix(F)
  stopifnot(nrow(R) == nrow(F))
  
  keep <- !apply(F, 1, anyNA)       # mirror MATLAB behavior
  R <- R[keep, , drop = FALSE]
  F <- F[keep, , drop = FALSE]
  
  Tobs <- nrow(R)
  N    <- ncol(R)
  K    <- ncol(F)
  
  # ---- 2. Sample means and covariances ------------------------------------
  cov_T <- function(x) cov(x) * (nrow(x) - 1) / nrow(x)
  
  Y   <- cbind(F, R)               # T x (K+N)
  mu2 <- colMeans(R)
  
  V   <- cov_T(Y)
  V11 <- V[1:K,            1:K,            drop = FALSE]
  V12 <- V[1:K,            K + seq_len(N), drop = FALSE]
  V21 <- t(V12)
  V22 <- V[K + seq_len(N), K + seq_len(N), drop = FALSE]
  
  # ---- 3. Weighting matrix W ----------------------------------------------
  W <- if (type == "OLS") diag(N) else solve(V22)
  
  # ---- 4. Asset betas and risk premia -------------------------------------
  beta_matrix <- V21 %*% solve(V11)              # N x K
  
  X <- if (include_constant) cbind(1, beta_matrix) else beta_matrix
  p <- ncol(X)                                   # p = K+1 or K
  
  H_betas_inv <- solve(t(X) %*% W %*% X)         # p x p
  H_betas     <-     t(X) %*% W %*% X
  A_betas     <- H_betas_inv %*% t(X) %*% W      # p x N
  beta_rp     <- as.vector(A_betas %*% mu2)      # length p
  
  # ---- 5. Cov-risk premia and matrices ------------------------------------
  if (include_constant) {
    gamma1  <- beta_rp[-1]                       # drop intercept
    lambda1 <- solve(V11) %*% gamma1
    cov_rp  <- c(beta_rp[1], lambda1)            # length K+1
  } else {
    lambda1 <- solve(V11) %*% beta_rp
    cov_rp  <- lambda1                           # length K
  }
  
  cov_matrix <- if (include_constant) cbind(1, V21) else V21  # N x p
  
  H_covs_inv <- solve(t(cov_matrix) %*% W %*% cov_matrix)
  H_covs     <-     t(cov_matrix) %*% W %*% cov_matrix
  A_covs     <- H_covs_inv %*% t(cov_matrix) %*% W
  
  # ---- 6. Return -----------------------------------------------------------
  list(
    beta_matrix = beta_matrix,   # N x K
    beta_rp     = beta_rp,       # length p
    cov_matrix  = cov_matrix,    # N x p
    cov_rp      = cov_rp,        # length p
    H_betas     = H_betas,       # p x p
    H_betas_inv = H_betas_inv,   # p x p
    H_covs      = H_covs,        # p x p
    H_covs_inv  = H_covs_inv,    # p x p
    A_betas     = A_betas,       # p x N
    A_covs      = A_covs         # p x N
  )
}
