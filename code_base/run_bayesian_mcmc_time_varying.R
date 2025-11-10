#' Run Bayesian Asset-Pricing MCMC - Time-Varying Version
#'
#' Optimized version for expanding/rolling window estimation. Returns only
#' lambdas, scaled lambdas, weights, and gammas (no full MCMC draws).
#'
#' @param main_path      Root folder of the project
#' @param data_folder    Sub-folder containing user's data files
#' @param output_folder  Sub-folder where results are saved
#' @param code_folder    Sub-folder with helper R scripts
#'
#' @param model_type     Model configuration: "bond", "stock", "bond_stock_with_sp", "treasury"
#' @param return_type    Return measure: "excess" or "duration"
#'
#' @param f1             Filename for non-traded factors (in data_folder)
#' @param f2             Filename(s) for traded factors. Can be:
#'                       - Single file: "traded_factors.csv"
#'                       - Multiple files: c("traded_bond.csv", "traded_equity.csv")
#'                       Multi-file mode auto-aligns dates and combines columns
#' @param R              Filename(s) for test assets. Supports single or multiple files like f2
#' @param fac_freq      Filename for frequentist factors (single file only, in data_folder).
#'                       Must contain all factors specified in frequentist_models.
#' @param n_bond_factors For bond_stock_with_sp with SINGLE FILE: number of bond factors in f2
#'                       For bond_stock_with_sp with MULTI-FILE: automatically inferred from first f2 file
#'                       Bond factors MUST come first (first file for multi-file mode)
#'
#' @param date_start     Start date for analysis (YYYY-MM-DD) or NULL to infer from data
#' @param date_end       End date for analysis (YYYY-MM-DD) or NULL to infer from data
#'
#' @param frequentist_models REQUIRED named list of frequentist models for comparison.
#'                          Format: list(ModelName = c("factor1", "factor2", ...))
#'                          Example: list(CAPM = "MKT", FF5 = c("MKT", "SMB", "HML", "RMW", "CMA"))
#'                          Top, Top-MPR, KNS, RP-PCA are always included automatically.
#'                          All factors must exist in f1 or f2 files.
#'
#' @param ndraws         MCMC iterations (default 50000)
#' @param SRscale        Vector of prior SR multipliers
#' @param alpha.w,beta.w Beta-prior hyper-parameters
#' @param kappa          Factor tilt parameter (default 0)
#' @param kappa_fac      Factor-specific kappa values (optional)
#' @param tag            Label for output files (default "ExpandingForward")
#' @param num_cores      Number of CPU cores for parallel processing
#' @param seed           RNG seed
#' @param intercept      Include linear intercept?
#' @param save_flag      Save IS_AP results to .Rdata?
#' @param verbose        Print progress messages?
#' @param fac_to_drop    List of factor names to exclude (optional)
#' @param weighting      Weighting scheme: "GLS" or "OLS"
#'
#' @return Invisible list containing IS_AP (lambdas, scaled_lambdas, weights, gammas)
#'
#' @details
#' Differences from run_bayesian_mcmc():
#'   - Uses estimate_kns_oos_ts() instead of estimate_kns_oos()
#'   - Calls insample_asset_pricing_time_varying() with date_end
#'   - Saves only IS_AP output (not full workspace)
#'   - Filename format: SS_{return_type}_{model_type}_alpha.w={alpha.w}_beta.w={beta.w}_SRscale={tag}{date_end}.Rdata

run_bayesian_mcmc_time_varying <- function(
    # Paths
  main_path,
  data_folder   = "data",
  output_folder = "output",
  code_folder   = "code_base",
  
  # Model configuration
  model_type    = "bond",
  return_type   = "excess",
  
  # Data files (filenames in data_folder)
  f1            = "nontraded_factors.csv",
  f2            = "traded_factors.csv",
  R             = "test_assets.csv",
  fac_freq      = "frequentist_factors.csv",
  n_bond_factors = NULL,
  
  # Date filtering (NULL = infer from data)
  date_start    = NULL,
  date_end      = NULL,
  
  # Frequentist models (REQUIRED - cannot be NULL)
  frequentist_models = NULL,
  
  # MCMC parameters
  ndraws        = 50000,
  SRscale       = c(0.20, 0.40, 0.60, 0.80),
  alpha.w       = 1,
  beta.w        = 1,
  kappa         = 0,
  kappa_fac     = NULL,
  
  # Other settings
  tag           = "ExpandingForward",
  num_cores     = 4,
  seed          = 234,
  intercept     = TRUE,
  save_flag     = TRUE,
  verbose       = TRUE,
  fac_to_drop   = NULL,
  weighting     = "GLS"
) {
  
  library(doRNG)
  
  ## ---- 0. Sanity checks -----------------------------------------------------
  if (!dir.exists(main_path)) {
    stop("`main_path` does not exist: ", main_path)
  }
  
  valid_models <- c("bond", "stock", "bond_stock_with_sp", "treasury")
  if (!model_type %in% valid_models) {
    stop("`model_type` must be one of: ", paste(valid_models, collapse = ", "))
  }
  
  return_type <- match.arg(return_type, c("excess", "duration"))
  if (num_cores < 1L) stop("`num_cores` must be >= 1")
  
  # Determine if multi-file mode
  is_multifile_f2 <- length(f2) > 1
  is_multifile_R  <- length(R) > 1
  
  # Validate n_bond_factors for bond_stock_with_sp
  if (model_type == "bond_stock_with_sp") {
    if (is_multifile_f2) {
      # Multi-file mode: n_bond_factors will be auto-inferred
      if (!is.null(n_bond_factors)) {
        if (verbose) {
          message("NOTE: n_bond_factors specified but will be auto-inferred from first f2 file in multi-file mode")
        }
      }
    } else {
      # Single-file mode: n_bond_factors is required
      if (is.null(n_bond_factors) || !is.numeric(n_bond_factors)) {
        stop("For model_type='bond_stock_with_sp' with single f2 file, must specify n_bond_factors as an integer")
      }
      if (n_bond_factors < 1) {
        stop("n_bond_factors must be >= 1")
      }
    }
  }
  
  # Validate frequentist_models is provided
  if (is.null(frequentist_models)) {
    stop("`frequentist_models` is REQUIRED. Must be a named list of factor vectors.\n",
         "Example: list(CAPM = 'MKT', FF5 = c('MKT', 'SMB', 'HML', 'RMW', 'CMA'))")
  }
  
  if (!is.list(frequentist_models) || is.null(names(frequentist_models))) {
    stop("`frequentist_models` must be a named list")
  }
  
  ## ---- 1. Dependencies ------------------------------------------------------
  pkgs <- c("BayesianFactorZoo", "MASS", "doParallel", "doRNG",
            "foreach", "compiler", "parallel", "lubridate", "PerformanceAnalytics")
  missing_pkgs <- pkgs[!sapply(pkgs, requireNamespace, quietly = TRUE)]
  if (length(missing_pkgs) > 0) {
    stop("Required packages not installed: ", paste(missing_pkgs, collapse = ", "),
         "\nInstall with: install.packages(c('", paste(missing_pkgs, collapse = "', '"), "'))")
  }
  
  ## ---- 1.1. Source user code ------------------------------------------------
  code_path <- if (dir.exists(code_folder)) {
    code_folder
  } else {
    file.path(main_path, code_folder)
  }
  if (!dir.exists(code_path)) {
    stop("`code_folder` does not exist: ", code_path)
  }
  
  r_files <- list.files(code_path, pattern = "[.][Rr]$", full.names = TRUE)
  invisible(lapply(r_files, source))
  if (verbose) message(length(r_files), " file(s) sourced from ", code_path)
  
  ## ---- 2. Path helper functions ---------------------------------------------
  data_path <- if (dir.exists(data_folder)) {
    data_folder
  } else {
    file.path(main_path, data_folder)
  }
  if (!dir.exists(data_path)) {
    stop("`data_folder` does not exist: ", data_path)
  }
  
  path_data <- function(file) file.path(data_path, file)
  
  path_out  <- function(file) {
    out_dir <- if (dir.exists(output_folder)) {
      output_folder
    } else {
      file.path(main_path, output_folder)
    }
    if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)
    file.path(out_dir, file)
  }
  
  ## ---- 3. Load user data with multi-file support ----------------------------
  if (verbose) message("Loading user data...")
  
  # Check if load_and_combine_files helper exists
  if (!exists("load_and_combine_files", mode = "function")) {
    stop("Function 'load_and_combine_files' not found. Please ensure data_loading_helpers.R is sourced.")
  }
  
  # Load f1 (always single file)
  if (verbose) message("  Loading f1 (non-traded factors): ", f1)
  f1_filepath <- path_data(f1)
  if (!file.exists(f1_filepath)) {
    stop("f1 file not found: ", f1_filepath)
  }
  f1_data <- read.csv(f1_filepath, check.names = FALSE)
  if (!"date" %in% colnames(f1_data)) {
    stop("f1 file '", f1, "' must have 'date' as first column")
  }
  
  # Load f2 (single or multi-file)
  if (is_multifile_f2) {
    f2_data <- load_and_combine_files(f2, path_data, "f2", verbose = verbose)
  } else {
    if (verbose) message("  Loading f2 (traded factors): ", f2)
    f2_filepath <- path_data(f2)
    if (!file.exists(f2_filepath)) {
      stop("f2 file not found: ", f2_filepath)
    }
    f2_data <- read.csv(f2_filepath, check.names = FALSE)
    if (!"date" %in% colnames(f2_data)) {
      stop("f2 file '", f2, "' must have 'date' as first column")
    }
  }
  
  # Load R (single or multi-file)
  if (is_multifile_R) {
    R_data <- load_and_combine_files(R, path_data, "R", verbose = verbose)
  } else {
    if (verbose) message("  Loading R (test assets): ", R)
    R_filepath <- path_data(R)
    if (!file.exists(R_filepath)) {
      stop("R file not found: ", R_filepath)
    }
    R_data <- read.csv(R_filepath, check.names = FALSE)
    if (!"date" %in% colnames(R_data)) {
      stop("R file '", R, "' must have 'date' as first column")
    }
  }
  # Load fac_freq (always single file)
  if (verbose) message("  Loading fac_freq (frequentist factors): ", fac_freq)
  fac_freq_filepath <- path_data(fac_freq)
  if (!file.exists(fac_freq_filepath)) {
    stop("fac_freq file not found: ", fac_freq_filepath)
  }
  fac_freq_data <- read.csv(fac_freq_filepath, check.names = FALSE)
  if (!"date" %in% colnames(fac_freq_data)) {
    stop("fac_freq file '", fac_freq, "' must have 'date' as first column")
  }
  
  
  ## ---- 4. Validate and align dates ------------------------------------------
  if (verbose) message("Validating and aligning dates...")
  
  aligned <- validate_and_align_dates(
    list(f1 = f1_data, f2 = f2_data, R = R_data, fac_freq = fac_freq_data),
    date_start = date_start,
    date_end = date_end,
    verbose = verbose
  )
  
  # Extract aligned data (drop date column)
  R_matrix  <- as.matrix(aligned$data$R[, -1, drop = FALSE])
  f1_matrix <- as.matrix(aligned$data$f1[, -1, drop = FALSE])
  f2_matrix <- as.matrix(aligned$data$f2[, -1, drop = FALSE])
  fac_freq_matrix <- as.matrix(aligned$data$fac_freq[, -1, drop = FALSE])
  
  ## ---- 5. Build factor structure --------------------------------------------
  if (model_type == "bond_stock_with_sp") {
    # Auto-infer n_bond_factors for multi-file mode
    if (is_multifile_f2) {
      # First f2 file contains bond factors
      # Count columns from first file
      first_f2_file <- path_data(f2[1])
      first_f2_data <- read.csv(first_f2_file, check.names = FALSE)
      n_bond_factors_inferred <- ncol(first_f2_data) - 1  # Exclude date column
      
      if (verbose) {
        message(sprintf("  Auto-inferred n_bond_factors = %d from first f2 file: %s", 
                        n_bond_factors_inferred, f2[1]))
      }
      
      n_bond_factors <- n_bond_factors_inferred
    }
    
    # Validate n_bond_factors
    if (n_bond_factors >= ncol(f2_matrix)) {
      stop("n_bond_factors (", n_bond_factors, ") must be less than total f2 columns (",
           ncol(f2_matrix), ")")
    }
    
    bond_cols <- 1:n_bond_factors
    stock_cols <- (n_bond_factors + 1):ncol(f2_matrix)
    
    fac <- list(
      f1 = f1_matrix,
      f2 = f2_matrix,
      f_all_raw = cbind(f1_matrix, f2_matrix),
      n_nontraded = ncol(f1_matrix),
      n_bondfac = n_bond_factors,
      n_stockfac = length(stock_cols),
      nontraded_names = colnames(f1_matrix),
      bond_names = colnames(f2_matrix)[bond_cols],
      stock_names = colnames(f2_matrix)[stock_cols],
      all_factor_names = c(colnames(f1_matrix), colnames(f2_matrix))
    )
  } else if (model_type == "treasury") {
    # Treasury: all factors treated as non-traded
    fac <- list(
      f1 = cbind(f1_matrix, f2_matrix),
      f2 = NULL,
      f_all_raw = cbind(f1_matrix, f2_matrix),
      n_nontraded = ncol(f1_matrix) + ncol(f2_matrix),
      n_bondfac = NULL,
      n_stockfac = NULL,
      nontraded_names = c(colnames(f1_matrix), colnames(f2_matrix)),
      bond_names = NULL,
      stock_names = NULL,
      all_factor_names = c(colnames(f1_matrix), colnames(f2_matrix))
    )
  } else {
    # bond or stock
    fac <- list(
      f1 = f1_matrix,
      f2 = f2_matrix,
      f_all_raw = cbind(f1_matrix, f2_matrix),
      n_nontraded = ncol(f1_matrix),
      n_bondfac = if (model_type == "bond") ncol(f2_matrix) else NULL,
      n_stockfac = if (model_type == "stock") ncol(f2_matrix) else NULL,
      nontraded_names = colnames(f1_matrix),
      bond_names = if (model_type == "bond") colnames(f2_matrix) else NULL,
      stock_names = if (model_type == "stock") colnames(f2_matrix) else NULL,
      all_factor_names = c(colnames(f1_matrix), colnames(f2_matrix))
    )
  }
  
  ## ---- 6. Validate frequentist_models factors -------------------------------
  if (verbose) message("Validating frequentist model specifications...")
  
  available_factors <- colnames(fac_freq_matrix)
  
  missing_factors <- list()
  for (model_name in names(frequentist_models)) {
    required_factors <- frequentist_models[[model_name]]
    missing <- setdiff(required_factors, available_factors)
    if (length(missing) > 0) {
      missing_factors[[model_name]] <- missing
    }
  }
  
  if (length(missing_factors) > 0) {
    error_msg <- "ERROR: Missing required factors in fac_freq file:\n"
    for (model_name in names(missing_factors)) {
      error_msg <- paste0(error_msg, "  Model '", model_name, "' requires: ",
                          paste(missing_factors[[model_name]], collapse = ", "), "\n")
    }
    error_msg <- paste0(error_msg, "\nAvailable factors in fac_freq: ",
                        paste(available_factors, collapse = ", "))
    stop(error_msg)
  }
  
  if (verbose) message("  All frequentist model factors validated successfully in fac_freq")
  
  ## ---- 7. Drop factors if specified -----------------------------------------
  fac <- drop_factors(fac, fac_to_drop, verbose = verbose)
  
  # Extract final factors
  if (!is.null(fac$R)) R_matrix <- fac$R
  f1 <- fac$f1
  f2 <- fac$f2
  f_all_raw <- fac$f_all_raw
  
  nontraded_names <- fac$nontraded_names
  bond_names      <- fac$bond_names
  stock_names     <- fac$stock_names
  all_names       <- fac$all_factor_names
  
  n_nontraded <- fac$n_nontraded
  n_bondfac   <- fac$n_bondfac
  n_stockfac  <- fac$n_stockfac
  
  ## ---- 8. Print summary -----------------------------------------------------
  if (verbose) {
    # Calculate maximum prior SR
    Rc_for_SR <- if (is.null(f2)) R_matrix else cbind(R_matrix, f2)
    max_annual_SR <- sqrt(12 * SharpeRatio(Rc_for_SR))
    
    # Calculate number of models
    n_models <- 2^ncol(f_all_raw) - 1
    
    cat("\n")
    cat("========================================\n")
    cat("Bayesian Asset Pricing Estimation\n")
    cat("========================================\n")
    cat("Model type:             ", model_type, "\n")
    cat("Return type:            ", return_type, "\n")
    cat("Test assets:            ", ncol(R_matrix), "\n")
    cat("Non-traded factors:     ", n_nontraded, "\n")
    if (!is.null(n_bondfac))  cat("Bond factors:           ", n_bondfac, "\n")
    if (!is.null(n_stockfac)) cat("Stock factors:          ", n_stockfac, "\n")
    cat("Total factors:          ", ncol(f_all_raw), "\n")
    cat("Number of models:       ", format(n_models, big.mark = ","), "\n")
    cat("Time periods:           ", nrow(R_matrix), "\n")
    cat("Date range:             ", as.character(aligned$date_range["start"]), " to ", 
        as.character(aligned$date_range["end"]), "\n")
    cat("MCMC draws:             ", ndraws, "\n")
    cat(sprintf("Maximum annual SR:      %.3f\n", max_annual_SR))
    cat("Linear intercept:       ", intercept, "\n")
    cat("Frequentist models:     ", paste(names(frequentist_models), collapse = ", "), "\n")
    cat("========================================\n\n")
  }
  
  ## ---- 9. Prior specification -----------------------------------------------
  if (verbose) message("Computing prior specifications...")
  
  if (is.null(kappa)) {
    # No kappa: use BayesianFactorZoo::psi_to_priorSR
    Rc <- if (is.null(f2)) R_matrix else cbind(R_matrix, f2)
    priorSR_vec <- SRscale * sqrt(SharpeRatio(Rc))
    psi.0 <- BayesianFactorZoo::psi_to_priorSR(
      R          = Rc,
      f          = f_all_raw,
      psi0       = NULL,
      priorSR    = priorSR_vec,
      aw         = alpha.w,
      bw         = beta.w
    )
  } else {
    # With kappa: use psi_to_priorSR_multi_asset
    Rc <- if (is.null(f2)) R_matrix else cbind(R_matrix, f2)
    priorSR_vec <- SRscale * sqrt(SharpeRatio(Rc))
    psi.0 <- psi_to_priorSR_multi_asset(
      R          = Rc,
      f          = f_all_raw,
      priorSR    = priorSR_vec,
      kappa      = kappa,
      kappa_fac  = kappa_fac
    )
  }
  
  
  
  ## ---- 10. Parallel backend setup -------------------------------------------
  if (num_cores > 1) {
    cl <- parallel::makeCluster(num_cores)
    doParallel::registerDoParallel(cl)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    if (verbose) message("Parallel backend registered with ", num_cores, " cores")
  } else {
    foreach::registerDoSEQ()
  }
  
  ## ---- 11. MCMC estimation --------------------------------------------------
  # Determine self-pricing vs no-self-pricing based on f2 presence
  # Treasury models have f2=NULL (no-SP), others have f2 present (SP)
  
  if (is.null(f2)) {
    ## ──────────── No-self-pricing variants (treasury) ────────────────────────
    f_all <- f1
    use_kappa_no_sp <- !is.null(kappa) && any(kappa != 0)
    
    CJ_ss <- if (use_kappa_no_sp) {
      compiler::cmpfun(continuous_ss_sdf_multi_asset_no_sp)
    } else {
      compiler::cmpfun(BayesianFactorZoo::continuous_ss_sdf)
    }
    
    psi.0 <- psi.0$result
    
    if (verbose) {
      message("Running MCMC (no-SP, GLS",
              if (use_kappa_no_sp) " + kappa" else "", ") ...")
    }
    
    t0 <- Sys.time()
    results <- foreach::foreach(
      current_psi = psi.0,
      .options.RNG = seed,
      .packages    = c("BayesianFactorZoo", "MASS")
    ) %dorng% {
      if (use_kappa_no_sp) {
        CJ_ss(
          f           = f_all,
          R           = R_matrix,
          sim_length  = ndraws,
          psi0        = current_psi,
          r           = 0.001,
          aw          = alpha.w,
          bw          = beta.w,
          type        = weighting,
          intercept   = intercept,
          kappa       = kappa,
          kappa_fac   = kappa_fac
        )
      } else {
        CJ_ss(
          f           = f_all,
          R           = R_matrix,
          sim_length  = ndraws,
          psi0        = current_psi,
          r           = 0.001,
          aw          = alpha.w,
          bw          = beta.w,
          type        = weighting,
          intercept   = intercept
        )
      }
    }
    
  } else {
    ## ──────────── Self-pricing variants (bond, stock, bond_stock_with_sp) ────
    use_multi_asset <- !is.null(kappa) && any(kappa != 0)
    
    CJ_ss <- if (use_multi_asset) {
      compiler::cmpfun(continuous_ss_sdf_multi_asset)
    } else {
      compiler::cmpfun(BayesianFactorZoo::continuous_ss_sdf_v2)
    }
    
    psi.0 <- psi.0$result
    
    if (verbose) {
      message("Running MCMC (self-pricing, GLS",
              if (use_multi_asset) " + kappa" else "", ") ...")
    }
    
    t0 <- Sys.time()
    results <- foreach::foreach(
      current_psi = psi.0,
      .options.RNG = seed,
      .packages    = c("BayesianFactorZoo", "MASS")
    ) %dorng% {
      if (use_multi_asset) {
        CJ_ss(
          f1         = f1,
          f2         = f2,
          R          = R_matrix,
          sim_length = ndraws,
          psi0       = current_psi,
          r          = 0.001,
          aw         = alpha.w,
          bw         = beta.w,
          type       = weighting,
          intercept  = intercept,
          kappa      = kappa,
          kappa_fac  = kappa_fac
        )
      } else {
        CJ_ss(
          f1         = f1,
          f2         = f2,
          R          = R_matrix,
          sim_length = ndraws,
          psi0       = current_psi,
          r          = 0.001,
          aw         = alpha.w,
          bw         = beta.w,
          type       = weighting,
          intercept  = intercept
        )
      }
    }
  }
  
  
  if (verbose) {
    message("MCMC finished in ",
            round(difftime(Sys.time(), t0, units = "mins"), 2),
            " minutes.")
  }
  
  ## ---- 12. Post-estimation: KNS and RP-PCA ---------------------------------
  # KNS estimation with time-varying function
  if (exists("estimate_kns_oos_ts", mode = "function")) {
    if (verbose) message("Running Kozak-Nagel-Shanken OOS procedure (time-varying) ...")
    
    kns_out <- estimate_kns_oos_ts(
      R  = R_matrix,
      f2 = f2,
      verbose = verbose
    )
  } else {
    warning("Function 'estimate_kns_oos_ts()' not found after sourcing -- KNS step skipped.")
    kns_out <- NULL
  }
  
  # RP-PCA estimation
  if (exists("estim_rppca", mode = "function")) {
    if (verbose) message("Running RP-PCA ...")
    rp_out <- estim_rppca_ts(
      R      = R_matrix,
      f2     = f2,
      kappa  = 20,
      npc    = 5,
      verbose = verbose
    )
  } else {
    warning("Function 'estim_rppca()' not found -- RP-PCA step skipped.")
    rp_out <- NULL
  }
  
  ## ---- 13. In-Sample Asset Pricing (Time-Varying) --------------------------
  if (verbose) message("Computing time-varying asset pricing metrics...")
  
  # Extract date_end from aligned data
  estimation_date_end <- aligned$date_range["end"]
  
  IS_AP <- insample_asset_pricing_time_varying(
    results   = results,
    f_all     = f_all_raw,
    R         = R_matrix,
    f1        = f1,
    f2        = f2,
    rp_out    = rp_out,
    kns_out   = kns_out,
    intercept = intercept,
    frequentist_models = frequentist_models,
    fac_freq  = fac_freq_matrix,
    date_end  = estimation_date_end
  )
  
  ## ---- 14. Save IS_AP output only ------------------------------------------
  saved_path <- NULL
  if (save_flag) {
    # Build filename: SS_{return_type}_{model_type}_alpha.w={alpha.w}_beta.w={beta.w}_SRscale={tag}{date_end}.Rdata
    # Format date_end without dashes
    date_str <- gsub("-", "", as.character(estimation_date_end))
    
    fname <- sprintf(
      "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s%s.Rdata",
      return_type,
      model_type,
      trunc(alpha.w),
      trunc(beta.w),
      tag,
      date_str
    )
    
    saved_path <- path_out(fname)
    
    # Save only IS_AP (not full workspace)
    save(IS_AP, file = saved_path, compress = TRUE)
    
    if (verbose) message("IS_AP results saved to: ", saved_path)
  }
  
  invisible(IS_AP)
}