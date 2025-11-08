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
