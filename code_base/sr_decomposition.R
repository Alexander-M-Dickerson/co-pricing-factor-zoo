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
