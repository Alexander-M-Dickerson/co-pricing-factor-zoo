psi_to_priorSR_multi_asset <- function(R, f,
                                       psi0      = NULL,
                                       priorSR   = NULL,
                                       aw        = 1,
                                       bw        = 1,
                                       w         = NULL,
                                       kappa     = NULL,      # either: ① numeric (legacy), ② named numeric (new)
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
    drop(t(μ) %*% solve(Σ) %*% μ)     # μᵀ Σ⁻¹ μ
  }
  
  ## ---- 3. ingredients --------------------------------------------------
  SR.max <- sqrt(SR_quad(R))
  N      <- ncol(R)
  
  ρtilde <- cor(R, f)
  ρtilde <- sweep(ρtilde, 2, colMeans(ρtilde), FUN = "-")
  ssq    <- diag(t(ρtilde) %*% ρtilde)          # r(γ_k) ρ̃_kᵀρ̃_k
  
  if (is.null(w)) w <- rep(1, ncol(f))
  
  ## ---- 4. η ------------------------------------------------------------
  eta <- (aw / (aw + bw)) * sum(w * scaling * ssq) / N
  
  ## ---- 5. main scalar result ------------------------------------------
  main_out <- if (!is.null(psi0)) {                     # ψ given → implied prior SR
    sqrt((psi0 * eta) / (1 + psi0 * eta)) * SR.max
  } else if (!is.null(priorSR)) {                       # prior SR given → implied ψ
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
