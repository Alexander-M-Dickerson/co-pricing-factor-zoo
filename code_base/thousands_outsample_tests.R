# =========================================================================
#  thousands_outsample_tests.R  ---  Massive OOS Pricing Diagnostics
# =========================================================================
#' Run thousands of out-of-sample pricing tests across asset subsets
#'
#' Tests OOS pricing performance across all non-empty subsets of test asset
#' blocks for three universes: co-pricing (bonds+stocks), equity-only, bond-only.
#'
#' Main Functions:
#'   run_thousands_oos_tests()     - Master function for all model types
#'   os_pricing_fast()             - Lightweight OOS pricing (no date handling)
#'   run_subset_combos()           - Run all subset combinations in parallel
# =========================================================================


# =========================================================================
#  os_pricing_fast: Lightweight OOS pricing for speed
# =========================================================================
#' Fast out-of-sample pricing (no date handling overhead)
#'
#' Computes OOS pricing metrics using pre-computed factor matrices.
#' This is a streamlined version of os_asset_pricing() optimized for
#' repeated calls with different R_oss subsets.
#'
#' @param R_oss_mat Numeric matrix of OOS test asset returns (T x N)
#' @param precomputed List of pre-computed objects from prepare_oos_inputs()
#' @param intercept Logical, whether models include intercept
#'
#' @return Data frame with pricing metrics for all models
os_pricing_fast <- function(R_oss_mat, precomputed, intercept = TRUE) {

  # Extract pre-computed objects
  lambdas <- precomputed$lambdas
  f_combined <- precomputed$f_combined
  f_all <- precomputed$f_all
  fac_freq <- precomputed$fac_freq
  kns_PCs <- precomputed$kns_PCs
  kns_PCs_f2 <- precomputed$kns_PCs_f2
  rp_factors <- precomputed$rp_factors
  rp_factors_f2 <- precomputed$rp_factors_f2
  sdf_mim <- precomputed$sdf_mim
  frequentist_models <- precomputed$frequentist_models
  top_factors_f2 <- precomputed$top_factors_f2
  top_factors_all <- precomputed$top_factors_all
  kns_scl <- precomputed$kns_scl
  kns_scl_f2 <- precomputed$kns_scl_f2

  N <- ncol(R_oss_mat)

  # Helper for correlation
  get_cor <- function(x) {
    if (is.null(x) || ncol(x) == 0) return(NULL)
    cor(R_oss_mat, as.matrix(x))
  }

  # Build C_f for BMA models
  C_f <- if (intercept) {
    cbind(1, get_cor(f_combined))
  } else {
    get_cor(f_combined)
  }

  # --- Compute Expected Returns ---
  ER_pred <- list()

  # BMA Models
  for (bma_name in c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%")) {
    if (bma_name %in% names(lambdas)) {
      ER_pred[[bma_name]] <- C_f %*% drop(lambdas[[bma_name]])
    }
  }

  # Frequentist Models
  if (!is.null(frequentist_models)) {
    for (model_name in names(frequentist_models)) {
      if (model_name %in% names(lambdas)) {
        factor_cols <- frequentist_models[[model_name]]
        if (all(factor_cols %in% colnames(fac_freq))) {
          cor_f <- get_cor(fac_freq[, factor_cols, drop = FALSE])
          ER_pred[[model_name]] <- cbind(1, cor_f) %*% drop(lambdas[[model_name]])
        }
      }
    }
  }

  # Bayesian Top models (f2-only)
  for (i in 1:4) {
    for (prefix in c("Top-", "Top-MPR-")) {
      model_name <- paste0(prefix, c("20%", "40%", "60%", "80%")[i])
      if (model_name %in% names(lambdas) && length(top_factors_f2) >= i) {
        factor_cols <- top_factors_f2[[i]]
        if (!is.null(factor_cols) && all(factor_cols %in% colnames(f_all))) {
          ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*%
            drop(lambdas[[model_name]])
        }
      }
    }
  }

  # Bayesian Top models (all factors)
  for (i in 1:4) {
    for (prefix in c("Top-", "Top-MPR-")) {
      model_name <- paste0(prefix, c("20%", "40%", "60%", "80%")[i], "-All")
      if (model_name %in% names(lambdas) && length(top_factors_all) >= i) {
        factor_cols <- top_factors_all[[i]]
        if (!is.null(factor_cols) && all(factor_cols %in% colnames(f_all))) {
          ER_pred[[model_name]] <- cbind(1, get_cor(f_all[, factor_cols, drop = FALSE])) %*%
            drop(lambdas[[model_name]])
        }
      }
    }
  }

  # RP-PCA Models
  if ("RP-PCA" %in% names(lambdas) && !is.null(rp_factors)) {
    ER_pred$`RP-PCA` <- cbind(1, get_cor(rp_factors)) %*% drop(lambdas$`RP-PCA`)
  }
  if ("RP-PCAf2" %in% names(lambdas) && !is.null(rp_factors_f2)) {
    ER_pred$`RP-PCAf2` <- cbind(1, get_cor(rp_factors_f2)) %*% drop(lambdas$`RP-PCAf2`)
  }

  # KNS Models (no intercept, need to rescale)
  if ("KNS" %in% names(lambdas) && !is.null(kns_PCs)) {
    kns_scaled <- t(t(kns_PCs) / kns_scl)
    ER_pred$KNS <- get_cor(kns_scaled) %*% (drop(lambdas$KNS) * kns_scl)
  }
  if ("KNSf2" %in% names(lambdas) && !is.null(kns_PCs_f2)) {
    kns_scaled_f2 <- t(t(kns_PCs_f2) / kns_scl_f2)
    ER_pred$KNSf2 <- get_cor(kns_scaled_f2) %*% (drop(lambdas$KNSf2) * kns_scl_f2)
  }

  # Optimal Portfolio Models
  for (opt_name in c("Tangency", "MinVar", "EqualWeight",
                     "Tangencyf2", "MinVarf2", "EqualWeightf2")) {
    if (opt_name %in% names(lambdas) && !is.null(sdf_mim) && opt_name %in% colnames(sdf_mim)) {
      ER_pred[[opt_name]] <- cbind(1, get_cor(sdf_mim[, opt_name, drop = FALSE])) %*%
        drop(lambdas[[opt_name]])
    }
  }

  # --- Combine and compute metrics ---
  if (length(ER_pred) == 0) {
    return(data.frame(metric = c("RMSEdm", "MAPEdm", "R2OLS", "R2GLS")))
  }

  ER_pred_all <- do.call(cbind, ER_pred) * sqrt(12)  # Annualize

  # Observed SRs (annualized)
  ER_oos <- sqrt(12) * colMeans(R_oss_mat) / matrixStats::colSds(R_oss_mat)

  # Pricing errors
  alpha <- ER_oos %*% matrix(1, nrow = 1, ncol = ncol(ER_pred_all)) - ER_pred_all

  # GLS ingredients
  Sigma_inv <- tryCatch(solve(cor(R_oss_mat)), error = function(e) NULL)
  if (is.null(Sigma_inv)) {
    # Fallback if singular
    Sigma_inv <- diag(N)
  }

  SR_scalar <- 12 * {
    ER <- matrix(colMeans(R_oss_mat), ncol = 1)
    covR <- cov(R_oss_mat)
    covR_inv <- tryCatch(solve(covR), error = function(e) diag(N))
    as.numeric(crossprod(ER, covR_inv %*% ER))
  }

  # Demeaned alpha for RMSE/MAPE

  dm_alpha <- sweep(alpha, 2, colMeans(alpha))

  # Metrics
  rmse_vals   <- sqrt(colMeans(dm_alpha^2))
  mape_vals   <- colMeans(abs(dm_alpha))
  r2_ols_vals <- 1 - apply(alpha, 2, var) / var(drop(ER_oos))
  r2_gls_vals <- 1 - diag(t(alpha) %*% Sigma_inv %*% alpha) / SR_scalar

  # Return as data frame
  metrics_df <- data.frame(
    metric = c("RMSEdm", "MAPEdm", "R2OLS", "R2GLS"),
    stringsAsFactors = FALSE
  )

  for (j in seq_along(ER_pred)) {
    metrics_df[[names(ER_pred)[j]]] <- c(rmse_vals[j], mape_vals[j],
                                          r2_ols_vals[j], r2_gls_vals[j])
  }

  metrics_df
}


# =========================================================================
#  prepare_oos_inputs: Pre-compute shared objects for fast pricing
# =========================================================================
#' Prepare pre-computed inputs for fast OOS pricing
#'
#' Extracts and prepares all factor matrices and lambdas from loaded .Rdata
#' objects. Called once per model type, then reused for all subset combinations.
#'
#' @param IS_AP IS_AP object from .Rdata
#' @param f1 Non-traded factors matrix
#' @param f2 Traded factors matrix
#' @param data_list Data list containing fac_freq
#' @param frequentist_models Named list of frequentist model specifications
#' @param kns_out KNS output object
#' @param rp_out RP-PCA output object
#' @param intercept Logical
#'
#' @return List of pre-computed objects for os_pricing_fast()
prepare_oos_inputs <- function(IS_AP, f1, f2, data_list, frequentist_models,
                                kns_out, rp_out, intercept = TRUE) {

  # Factor matrices (as matrices, no dates)
  f1_mat <- if (!is.null(f1)) as.matrix(f1) else NULL
  f2_mat <- if (!is.null(f2)) as.matrix(f2) else NULL

  f_combined <- if (!is.null(f1_mat)) cbind(f1_mat, f2_mat) else f2_mat
  f_all <- as.data.frame(f_combined)

  # Frequentist factors
  fac_freq <- if (!is.null(data_list$fac_freq)) {
    fac_freq_raw <- data_list$fac_freq
    # Remove date column if present
    if ("date" %in% colnames(fac_freq_raw)) {
      as.matrix(fac_freq_raw[, -1, drop = FALSE])
    } else {
      as.matrix(fac_freq_raw)
    }
  } else {
    NULL
  }

  # KNS PCs
  kns_PCs <- if (!is.null(kns_out$combined$kns_PCs)) kns_out$combined$kns_PCs else NULL
  kns_scl <- if (!is.null(kns_PCs)) matrixStats::colSds(kns_PCs) else NULL

  kns_PCs_f2 <- if (!is.null(kns_out$f2_only$kns_PCs)) kns_out$f2_only$kns_PCs else NULL
  kns_scl_f2 <- if (!is.null(kns_PCs_f2)) matrixStats::colSds(kns_PCs_f2) else NULL

  # RP-PCA factors
  rp_factors <- if (!is.null(rp_out$combined$factors)) rp_out$combined$factors else NULL
  rp_factors_f2 <- if (!is.null(rp_out$f2_only$factors)) rp_out$f2_only$factors else NULL

  # SDF mimicking portfolios
  sdf_mim <- IS_AP$sdf_mim

  # Top factors
  top_factors_f2 <- IS_AP$top_factors
  top_factors_all <- IS_AP$top_factors_all

  list(
    lambdas = IS_AP$lambdas,
    f_combined = f_combined,
    f_all = f_all,
    fac_freq = fac_freq,
    kns_PCs = kns_PCs,
    kns_PCs_f2 = kns_PCs_f2,
    kns_scl = kns_scl,
    kns_scl_f2 = kns_scl_f2,
    rp_factors = rp_factors,
    rp_factors_f2 = rp_factors_f2,
    sdf_mim = sdf_mim,
    frequentist_models = frequentist_models,
    top_factors_f2 = top_factors_f2,
    top_factors_all = top_factors_all,
    intercept = intercept
  )
}


# =========================================================================
#  run_subset_combos: Run all subset combinations in parallel
# =========================================================================
#' Run OOS pricing for all non-empty subsets of asset blocks
#'
#' @param R_oss_mat Full OOS returns matrix (T x N, no date column)
#' @param cols_from Vector of starting column indices for each block
#' @param cols_to Vector of ending column indices for each block
#' @param precomputed Pre-computed objects from prepare_oos_inputs()
#' @param n_cores Number of parallel cores
#' @param verbose Print progress
#'
#' @return data.table of stacked pricing metrics for all combinations
run_subset_combos <- function(R_oss_mat, cols_from, cols_to, precomputed,
                               n_cores = parallel::detectCores() - 1,
                               verbose = TRUE) {

  n_blocks <- length(cols_from)

  # Build list of column splits
  splits <- mapply(function(s, e) R_oss_mat[, s:e, drop = FALSE],
                   cols_from, cols_to, SIMPLIFY = FALSE)

  # Generate all non-empty subset combinations
  combos <- unlist(
    lapply(seq_len(n_blocks), function(k) {
      combn(seq_len(n_blocks), k, simplify = FALSE)
    }),
    recursive = FALSE
  )

  n_combos <- length(combos)
  if (verbose) message("    Running ", n_combos, " subset combinations...")

  # Worker function for pricing one combination
  price_combo <- function(idx, splits, precomputed) {
    R_sub <- do.call(cbind, splits[idx])
    tryCatch({
      metrics <- os_pricing_fast(R_sub, precomputed, precomputed$intercept)
      metrics$n_blocks <- length(idx)
      metrics$n_assets <- ncol(R_sub)
      metrics$combo_id <- paste(idx, collapse = "-")
      metrics
    }, error = function(e) {
      data.frame(
        metric = c("RMSEdm", "MAPEdm", "R2OLS", "R2GLS"),
        n_blocks = length(idx),
        n_assets = ncol(R_sub),
        combo_id = paste(idx, collapse = "-"),
        error = e$message,
        stringsAsFactors = FALSE
      )
    })
  }

  start_time <- Sys.time()

  # Check if running on Windows
  is_windows <- .Platform$OS.type == "windows"

  if (is_windows) {
    # Windows: use parLapply with PSOCK cluster
    if (n_cores > 1) {
      if (verbose) message("    (Windows detected: using PSOCK cluster)")
      cl <- parallel::makeCluster(n_cores)
      on.exit(parallel::stopCluster(cl), add = TRUE)

      # Export required objects and functions to cluster
      parallel::clusterExport(cl, c("os_pricing_fast", "splits", "precomputed", "price_combo"),
                               envir = environment())

      # Load required packages on workers
      parallel::clusterEvalQ(cl, {
        library(matrixStats)
        library(data.table)
      })

      results <- parallel::parLapply(cl, combos, function(idx) {
        price_combo(idx, splits, precomputed)
      })
    } else {
      # Single core fallback
      results <- lapply(combos, function(idx) price_combo(idx, splits, precomputed))
    }
  } else {
    # Linux/Mac: use mclapply (fork-based, faster)
    results <- parallel::mclapply(combos, function(idx) {
      price_combo(idx, splits, precomputed)
    }, mc.cores = n_cores)
  }

  elapsed <- as.numeric(difftime(Sys.time(), start_time, units = "mins"))

  if (verbose) {
    message(sprintf("    Finished %d combos in %.1f min (%.0f combos/min)",
                    n_combos, elapsed, n_combos / elapsed))
  }

  # Stack results
  data.table::rbindlist(results, fill = TRUE, use.names = TRUE)
}


# =========================================================================
#  run_thousands_oos_tests: Master function
# =========================================================================
#' Run thousands of out-of-sample pricing tests
#'
#' Runs OOS pricing across all non-empty subsets of test asset blocks for
#' three universes (co-pricing, equity-only, bond-only) across multiple
#' model types.
#'
#' @param results_path Path to results folder containing .Rdata files
#' @param data_path Path to data folder containing OOS test assets
#' @param model_types Vector of model types to process
#' @param return_type Return type (e.g., "excess") - used for stock model
#' @param alpha.w Beta prior hyperparameter
#' @param beta.w Beta prior hyperparameter
#' @param kappa Factor tilt
#' @param tag Run identifier
#' @param intercept Logical, whether models include intercept
#' @param bond_oos_file Filename for bond OOS assets (excess returns)
#' @param stock_oos_file Filename for stock OOS assets
#' @param duration_mode Logical, if TRUE use duration-adjusted for bond models
#' @param bond_oos_file_duration Filename for bond OOS assets (duration returns)
#' @param n_cores Number of parallel cores (default: detectCores - 1)
#' @param save_output Save results to RDS?
#' @param output_path Path for output file
#' @param output_name Output filename
#' @param verbose Print progress
#'
#' @return Nested list: results[[model_type]][[universe]] -> data.table
#'
#' @examples
#' \dontrun{
#'   # Excess returns mode
#'   res <- run_thousands_oos_tests(
#'     results_path = "output/unconditional",
#'     data_path = "data",
#'     model_types = c("bond_stock_with_sp", "stock", "bond"),
#'     verbose = TRUE
#'   )
#'
#'   # Duration-adjusted mode
#'   res_dur <- run_thousands_oos_tests(
#'     results_path = "output/unconditional",
#'     data_path = "data",
#'     model_types = c("bond_stock_with_sp", "stock", "bond"),
#'     duration_mode = TRUE,
#'     output_name = "thousands_oos_results_duration.rds",
#'     verbose = TRUE
#'   )
#' }
run_thousands_oos_tests <- function(results_path,
                                     data_path,
                                     model_types = c("bond_stock_with_sp", "stock", "bond"),
                                     return_type = "excess",
                                     alpha.w = 1,
                                     beta.w = 1,
                                     kappa = 0,
                                     tag = "baseline",
                                     intercept = TRUE,
                                     bond_oos_file = "bond_oosample_all_excess.csv",
                                     stock_oos_file = "equity_os_77.csv",
                                     duration_mode = FALSE,
                                     bond_oos_file_duration = "bond_oosample_all_duration_tmt.csv",
                                     n_cores = max(1, parallel::detectCores() - 1),
                                     save_output = TRUE,
                                     output_path = NULL,
                                     output_name = "thousands_oos_results.rds",
                                     verbose = TRUE) {

  if (verbose) {
    message("\n", strrep("=", 70))
    message("THOUSANDS OUT-OF-SAMPLE TESTS")
    if (duration_mode) message("MODE: Duration-adjusted")
    message(strrep("=", 70))
    message("Using ", n_cores, " parallel cores")
  }

  # --- Determine which bond OOS file to use ---
  bond_file_to_use <- if (duration_mode) bond_oos_file_duration else bond_oos_file

  # --- Load OOS test assets (with correct date handling) ---
  bond_path <- file.path(data_path, bond_file_to_use)
  stock_path <- file.path(data_path, stock_oos_file)

  if (!file.exists(bond_path)) stop("Bond OOS file not found: ", bond_path)
  if (!file.exists(stock_path)) stop("Stock OOS file not found: ", stock_path)

  # Read with date column preserved (first column)
  R_ossB_df <- read.csv(bond_path, check.names = FALSE)
  R_ossE_df <- read.csv(stock_path, check.names = FALSE)

  # Extract date column and convert to matrices
  dates_oos <- R_ossB_df[[1]]
  R_ossB <- as.matrix(R_ossB_df[, -1, drop = FALSE])
  R_ossE <- as.matrix(R_ossE_df[, -1, drop = FALSE])

  # Combined matrix (equity + bond for co-pricing)
  R_oss_combined <- cbind(R_ossE, R_ossB)

  if (verbose) {
    message("OOS assets loaded:")
    message("  Equity: ", ncol(R_ossE), " portfolios, ", nrow(R_ossE), " obs")
    message("  Bond:   ", ncol(R_ossB), " portfolios, ", nrow(R_ossB), " obs")
    message("  Bond file: ", bond_file_to_use)
  }

  # --- Block indices for subset combinations ---
  # Co-pricing: 14 blocks (7 equity + 7 bond)
  cols_from_CP <- c(1, 11, 21, 38, 48, 58, 68, 78, 88, 98, 108, 118, 128, 138)
  cols_to_CP   <- c(10, 20, 37, 47, 57, 67, 77, 87, 97, 107, 117, 127, 137, 154)

  # Equity only: 7 blocks
  cols_from_E <- c(1, 11, 21, 38, 48, 58, 68)
  cols_to_E   <- c(10, 20, 37, 47, 57, 67, 77)

  # Bond only: 7 blocks (offset by equity columns)
  offset <- ncol(R_ossE)  # 77
  cols_from_B <- c(78, 88, 98, 108, 118, 128, 138) - offset
  cols_to_B   <- c(87, 97, 107, 117, 127, 137, 154) - offset

  # --- Process each model type ---
  out_all <- list()

  for (model_type in model_types) {
    if (verbose) {
      message("\n", strrep("-", 60))
      message("Model: ", model_type)
      message(strrep("-", 60))
    }

    # Determine return_type for this model
    # In duration_mode: bond and bond_stock_with_sp use "duration", stock uses "excess"
    model_return_type <- if (duration_mode && model_type != "stock") {
      "duration"
    } else {
      return_type
    }

    # Construct filename
    rdata_filename <- sprintf(
      "%s_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s.Rdata",
      model_return_type, model_type, alpha.w, beta.w, kappa, tag
    )
    rdata_path <- file.path(results_path, model_type, rdata_filename)

    if (!file.exists(rdata_path)) {
      warning("File not found: ", rdata_path, ". Skipping.")
      out_all[[model_type]] <- NULL
      next
    }

    # Load into temporary environment
    load_env <- new.env()
    load(rdata_path, envir = load_env)
    if (verbose) message("  Loaded: ", rdata_filename)

    # Extract required objects
    IS_AP <- get("IS_AP", envir = load_env)
    f1 <- get("f1", envir = load_env)
    f2 <- get("f2", envir = load_env)
    data_list <- get("data_list", envir = load_env)
    frequentist_models <- get("frequentist_models", envir = load_env)
    kns_out <- get("kns_out", envir = load_env)
    rp_out <- get("rp_out", envir = load_env)

    # Prepare pre-computed inputs (done once per model type)
    if (verbose) message("  Preparing pre-computed inputs...")
    precomputed <- prepare_oos_inputs(
      IS_AP = IS_AP,
      f1 = f1,
      f2 = f2,
      data_list = data_list,
      frequentist_models = frequentist_models,
      kns_out = kns_out,
      rp_out = rp_out,
      intercept = intercept
    )

    # --- Run three universes ---
    if (verbose) message("  Universe: co_pricing (14 blocks, 16383 combos)")
    res_cp <- run_subset_combos(R_oss_combined, cols_from_CP, cols_to_CP,
                                 precomputed, n_cores, verbose)

    if (verbose) message("  Universe: equity (7 blocks, 127 combos)")
    res_eq <- run_subset_combos(R_ossE, cols_from_E, cols_to_E,
                                 precomputed, n_cores, verbose)

    if (verbose) message("  Universe: bond (7 blocks, 127 combos)")
    res_bd <- run_subset_combos(R_ossB, cols_from_B, cols_to_B,
                                 precomputed, n_cores, verbose)

    out_all[[model_type]] <- list(
      co_pricing = res_cp,
      equity = res_eq,
      bond = res_bd
    )

    # Clean up
    rm(load_env)
    gc()
  }

  # --- Save results ---
  if (save_output && !is.null(output_path)) {
    save_file <- file.path(output_path, output_name)
    dir.create(dirname(save_file), recursive = TRUE, showWarnings = FALSE)
    saveRDS(out_all, save_file)
    if (verbose) message("\nResults saved to: ", save_file)
  }

  if (verbose) {
    message("\n", strrep("=", 70))
    message("THOUSANDS OOS TESTS COMPLETE")
    message(strrep("=", 70), "\n")
  }

  invisible(out_all)
}
