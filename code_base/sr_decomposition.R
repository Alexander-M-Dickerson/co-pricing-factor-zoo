# =========================================================================
#  sr_decomposition()   ---  Sharpe Ratio Decomposition by Factor Groups
# =========================================================================
# Decomposes the SDF Sharpe ratio contribution by factor type/group.
#
# Paper role: map posterior BMA-SDF draws into the factor-group decompositions
# used in the main text and Treasury-component robustness sections.
# Paper refs: Eq. (7); Table 1; Table 4; Table 5; Table IA.XVIII; IA.5; IA.6
#
# Mathematical Background
# -----------------------
# The stochastic discount factor (SDF) is:
#
#   m_t = 1 - (f_t - E[f])' * (lambda / sigma_f)
#
# where:
#   f_t       = factor realizations at time t
#   lambda    = market prices of risk (from MCMC)
#   sigma_f   = factor standard deviations
#
# The SDF Sharpe ratio for a subset of factors S is:
#
#   SR_S = sqrt(12) * sd(m_S)
#
# where m_S is the SDF constructed using only factors in set S.
#
# The squared SR contribution ratio is:
#
#   SR^2_S / SR^2_m = Var(m_S) / Var(m)
#
# This measures how much of the full SDF variance is explained by
# factors in group S.
#
# Output Metrics
# --------------
# For each factor group and shrinkage level, computes:
#   - Mean:               E[|S|] = expected number of included factors
#   - 5%, 95%:            90% credible interval for |S|
#   - E[SR_f|data]:       Posterior mean Sharpe ratio for group
#   - E[SR^2_f/SR^2_m|data]: Posterior mean squared SR contribution
#
# Required Objects in Calling Environment
# ---------------------------------------
#   f1              Non-traded factors matrix (T x N1)
#   f2              Traded factors matrix (T x N2), can be NULL
#   intercept       Logical: whether intercept was included
#   nontraded_names Factor names classified as non-traded (optional)
#   bond_names      Factor names classified as bond factors (optional)
#   stock_names     Factor names classified as stock factors (optional)
#
# Parameters
# ----------
#   results         MCMC results list from run_bayesian_mcmc()
#   prior_labels    Labels for shrinkage levels (default: 20/40/60/80%)
#   dr_cf_decomp    List with DR_factors and CF_factors vectors (optional)
#   top_factors     Integer N for top-N analysis, or character vector
#
# Returns
# -------
#   Tibble with columns: shrinkage, factor_type, metric, value
# =========================================================================

sr_decomposition <- function(results,
                             prior_labels = c("20%","40%","60%","80%"),
                             dr_cf_decomp = NULL,
                             top_factors  = NULL) {
  
  library(dplyr)
  if (!requireNamespace("matrixStats", quietly = TRUE))
    stop("matrixStats package is required.")
  if (!requireNamespace("purrr", quietly = TRUE))
    stop("purrr package is required.")
  
  ## ------------------------------------------------------------------ #
  ## 1.  Factor matrix & stats
  ## ------------------------------------------------------------------ #
  if (!exists("f1", inherits = TRUE))
    stop("f1 (and optionally f2) must exist in calling environment.")
  f1 <- get("f1", inherits = TRUE)
  f2 <- if (exists("f2", inherits = TRUE)) get("f2", inherits = TRUE) else NULL
  
  f         <- cbind(f1, f2)
  factor_nm <- colnames(f)
  factor_sd <- matrixStats::colSds(f)
  
  ## ------------------------------------------------------------------ #
  ## 2.  Average inclusion probabilities  γ̄  (K × |ψ|)
  ## ------------------------------------------------------------------ #
  prob_mat <- sapply(results, function(r) colMeans(r$gamma_path))
  rownames(prob_mat) <- factor_nm
  
  ## ------------------------------------------------------------------ #
  ## 3.  Static factor-type vectors
  ## ------------------------------------------------------------------ #
  nontraded <- if (exists("nontraded_names", inherits = TRUE))
    get("nontraded_names", inherits = TRUE) else character(0)
  bond_fac  <- if (exists("bond_names", inherits = TRUE))
    get("bond_names", inherits = TRUE) else character(0)
  stock_fac <- if (exists("stock_names", inherits = TRUE))
    get("stock_names", inherits = TRUE) else character(0)
  tradable  <- unique(c(bond_fac, stock_fac))
  
  dr_fac <- cf_fac <- character(0)
  if (!is.null(dr_cf_decomp)) {
    if (!is.null(dr_cf_decomp$factor_lists)) {
      dr_fac <- dr_cf_decomp$factor_lists$DR_factors %||% character(0)
      cf_fac <- dr_cf_decomp$factor_lists$CF_factors %||% character(0)
    } else {
      dr_fac <- dr_cf_decomp$DR_factors %||% character(0)
      cf_fac <- dr_cf_decomp$CF_factors %||% character(0)
    }
  }
  
  base_groups <- list(
    "Nontraded factors"      = nontraded,
    "Tradable factors"       = tradable,
    "Bond tradable factors"  = bond_fac,
    "Stock tradable factors" = stock_fac,
    "DR factors"             = dr_fac,
    "CF factors"             = cf_fac,
    "All factors"            = factor_nm
  )
  base_groups <- base_groups[lengths(base_groups) > 0]
  
  ## ------------------------------------------------------------------ #
  ## 4.  Helper – SDF builder
  ## ------------------------------------------------------------------ #
  process_row <- function(lambda_vec, sel_sd, sel_fac) {
    # Paper: Eq. (7) forms a draw-specific SDF from the posterior market prices
    # of risk; group-level SR contributions are computed by zeroing out the
    # complement set of factors.
    lam_scaled <- lambda_vec / sel_sd
    sdf        <- 1 - sel_fac %*% lam_scaled
    sdf        <- sdf - mean(sdf) + 1
    drop(sdf)
  }
  
  out <- vector("list", length(results))
  
  for (i in seq_along(results)) {
    
    res_i <- results[[i]]
    intercept_present <- isTRUE(intercept)
    offs <- if (intercept_present) 1L else 0L
    
    sr_m_i <- apply(res_i$sdf_path, 1, sd) * sqrt(12)
    
    lambda_draws <- res_i$lambda_path
    gamma_draws  <- res_i$gamma_path
    
    ## ---- Build groups for this shrinkage level ---------------------- #
    groups_i <- base_groups
    
    # Handle top_factors logic
    if (!is.null(top_factors)) {
      if (is.numeric(top_factors) && length(top_factors) == 1L) {
        n_keep <- max(0L, min(as.integer(top_factors[1]), length(factor_nm)))
        if (n_keep > 0L) {
          top_idx   <- head(order(prob_mat[, i],
                                  decreasing = TRUE, na.last = NA),
                            n_keep)
          top_names <- factor_nm[top_idx]
          groups_i[[paste0("Top ", n_keep, " Factors")]] <- top_names
          groups_i[["Without Top"]] <- setdiff(factor_nm, top_names)
        }
      } else if (is.character(top_factors)) {
        excl <- intersect(top_factors, factor_nm)
        if (length(excl)) {
          groups_i[["Top Factors"]] <- excl
          groups_i[["Without Top"]] <- setdiff(factor_nm, excl)
        }
      }
    }
    
    ## ---- Compute stats for all groups ------------------------------- #
    tbl_i <- purrr::imap_dfr(groups_i, function(g, lbl) {
      
      idx <- match(g, factor_nm)
      idx <- idx[!is.na(idx)]
      if (!length(idx)) return(NULL)
      
      n_fac_draws <- rowSums(gamma_draws[, idx, drop = FALSE])
      mean_n      <- mean(n_fac_draws)
      q05_n       <- quantile(n_fac_draws, 0.05, names = FALSE)
      q95_n       <- quantile(n_fac_draws, 0.95, names = FALSE)
      
      sel_sd  <- factor_sd[idx]
      sel_fac <- f[, idx, drop = FALSE]
      lam_sub <- lambda_draws[, idx + offs, drop = FALSE]
      
      sdf_sub <- t(apply(lam_sub, 1, process_row,
                         sel_sd  = sel_sd,
                         sel_fac = sel_fac))
      
      sr_f  <- apply(sdf_sub, 1, sd) * sqrt(12)
      ratio <- (sr_f^2) / (sr_m_i^2)
      
      tibble::tibble(
        shrinkage   = prior_labels[i],
        factor_type = lbl,
        metric      = c("Mean", "5%", "95%",
                        "E[SR_f|data]", "E[SR^2_f/SR^2_m|data]"),
        value       = c(mean_n, q05_n, q95_n,
                        mean(sr_f), mean(ratio))
      )
    })
    
    out[[i]] <- tbl_i
  }
  
  dplyr::bind_rows(out) %>%
    dplyr::select(shrinkage, factor_type, metric, value)
}


# =========================================================================
#  Helper: Null-coalescing operator (if not already defined)
# =========================================================================
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x)) y else x
}
