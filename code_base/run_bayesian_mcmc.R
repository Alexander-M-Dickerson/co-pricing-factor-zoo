#' Run Bayesian Asset-Pricing MCMC - Public Release (Extensible Version)
#'
#' Maximum extensibility with NO hard-coded data. Users provide their own data
#' files and specify all models for comparison.
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
#' @param f2             Filename for traded factors (in data_folder)
#' @param R              Filename for test assets (in data_folder)
#' @param n_bond_factors For bond_stock_with_sp: number of bond factors in f2 (rest are stock)
#'                       Bond factors MUST come first in f2 file
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
#' @param tag            Label for output files (default "baseline")
#' @param num_cores      Number of CPU cores for parallel processing
#' @param seed           RNG seed
#' @param intercept      Include linear intercept?
#' @param save_flag      Save full workspace?
#' @param verbose        Print progress messages?
#' @param fac_to_drop    List of factor names to exclude (optional)
#' @param weighting      Weighting scheme: "GLS" or "OLS"
#'
#' @return Invisible list containing results, IS_AP, and output path
#'
#' @examples
#' \dontrun{
#' res <- run_bayesian_mcmc(
#'   main_path = "/path/to/project",
#'   data_folder = "my_data",
#'   f1 = "nontraded_factors.csv",
#'   f2 = "traded_factors.csv",
#'   R = "test_assets.csv",
#'   model_type = "bond",
#'   return_type = "excess",
#'   frequentist_models = list(
#'     CAPM = "MKT",
#'     FF5 = c("MKT", "SMB", "HML", "RMW", "CMA")
#'   )
#' )
#' }

run_bayesian_mcmc <- function(
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
  tag           = "baseline",
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
  
  # Validate n_bond_factors for bond_stock_with_sp
  if (model_type == "bond_stock_with_sp") {
    if (is.null(n_bond_factors) || !is.numeric(n_bond_factors)) {
      stop("For model_type='bond_stock_with_sp', must specify n_bond_factors as an integer")
    }
    if (n_bond_factors < 1) {
      stop("n_bond_factors must be >= 1")
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
  
  ## ---- 3. Load user data ----------------------------------------------------
  if (verbose) message("Loading user data...")
  
  # Load data files
  load_data_file <- function(filename, label) {
    filepath <- path_data(filename)
    if (!file.exists(filepath)) {
      stop(sprintf("%s file not found: %s", label, filepath))
    }
    data <- read.csv(filepath, check.names = FALSE)
    
    # Validate date column
    if (!"date" %in% colnames(data)) {
      stop(sprintf("%s file '%s' must have 'date' as first column", label, filename))
    }
    
    return(data)
  }
  
  if (verbose) message("  Loading f1 (non-traded factors): ", f1)
  f1_data <- load_data_file(f1, "f1 (non-traded factors)")
  
  if (verbose) message("  Loading f2 (traded factors): ", f2)
  f2_data <- load_data_file(f2, "f2 (traded factors)")
  
  if (verbose) message("  Loading R (test assets): ", R)
  R_data  <- load_data_file(R, "R (test assets)")
  
  ## ---- 4. Validate and align dates ------------------------------------------
  if (verbose) message("Validating and aligning dates...")
  
  aligned <- validate_and_align_dates(
    list(f1 = f1_data, f2 = f2_data, R = R_data),
    date_start = date_start,
    date_end = date_end,
    verbose = verbose
  )
  
  # Extract aligned data (drop date column)
  R_matrix  <- as.matrix(aligned$data$R[, -1, drop = FALSE])
  f1_matrix <- as.matrix(aligned$data$f1[, -1, drop = FALSE])
  f2_matrix <- as.matrix(aligned$data$f2[, -1, drop = FALSE])
  
  ## ---- 5. Build factor structure --------------------------------------------
  if (model_type == "bond_stock_with_sp") {
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
  
  f_all_raw <- fac$f_all_raw
  available_factors <- colnames(f_all_raw)
  
  missing_factors <- list()
  for (model_name in names(frequentist_models)) {
    required_factors <- frequentist_models[[model_name]]
    missing <- setdiff(required_factors, available_factors)
    if (length(missing) > 0) {
      missing_factors[[model_name]] <- missing
    }
  }
  
  if (length(missing_factors) > 0) {
    error_msg <- "ERROR: Missing required factors in frequentist_models:\n"
    for (model_name in names(missing_factors)) {
      error_msg <- paste0(error_msg, "  Model '", model_name, "' requires: ",
                          paste(missing_factors[[model_name]], collapse = ", "), "\n")
    }
    error_msg <- paste0(error_msg, "\nAvailable factors: ",
                        paste(available_factors, collapse = ", "))
    stop(error_msg)
  }
  
  if (verbose) message("  All frequentist model factors validated successfully")
  
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
    cat("Time periods:           ", nrow(R_matrix), "\n")
    cat("Date range:             ", as.character(aligned$date_range["start"]), " to ", as.character(aligned$date_range["end"]), "\n")
    cat("MCMC draws:             ", ndraws, "\n")
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
    ## â”€â”€ No-self-pricing variants (treasury) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
    ## â”€â”€ Self-pricing variants (bond, stock, bond_stock_with_sp) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
  # KNS estimation
  if (exists("estimate_kns_oos", mode = "function")) {
    if (verbose) message("Running Kozak-Nagel-Shanken OOS procedure ...")
    
    kns_out <- estimate_kns_oos(
      R  = R_matrix,
      f2 = f2,
      verbose = verbose
    )
  } else {
    warning("Function 'estimate_kns_oos()' not found after sourcing -- KNS step skipped.")
    kns_out <- NULL
  }
  
  # RP-PCA estimation
  if (exists("estim_rppca", mode = "function")) {
    if (verbose) message("Running RP-PCA ...")
    rp_out <- estim_rppca(
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
  
  ## ---- 13. In-Sample Asset Pricing -----------------------------------------
  IS_AP <- insample_asset_pricing(
    results   = results,
    f_all     = f_all_raw,
    R         = R_matrix,
    f1        = f1,
    f2        = f2,
    rp_out    = rp_out,
    kns_out   = kns_out,
    intercept = intercept,
    frequentist_models = frequentist_models
  )
  
  ## ---- 14. Save workspace ---------------------------------------------------
  saved_path <- NULL
  if (save_flag) {
    kappa_str <- if (all(kappa == 0)) {
      "0"
    } else {
      paste(format(kappa, digits = 3, trim = TRUE), collapse = "_")
    }
    
    kappa_label <- if (nchar(kappa_str) > 10) "weighted" else kappa_str
    
    # Build filename: {return_type}_{model_type}_alpha.w={alpha.w}_beta.w={beta.w}_kappa={kappa}_{tag}
    fname_parts <- c(
      return_type,
      model_type,
      sprintf("alpha.w=%g", trunc(alpha.w)),
      sprintf("beta.w=%g", trunc(beta.w)),
      sprintf("kappa=%s", kappa_label)
    )
    
    if (!isTRUE(intercept)) {
      fname_parts <- c(fname_parts, "no_intercept")
    }
    
    if (nzchar(tag)) {
      fname_parts <- c(fname_parts, tag)
    }
    
    fname <- paste0(paste(fname_parts, collapse = "_"), ".Rdata")
    
    saved_path <- path_out(fname)
    
    save(list = ls(envir = environment()),
         file = saved_path,
         compress = TRUE,
         envir = environment())
    
    if (verbose) message("Workspace saved to: ", saved_path)
  }
  
  invisible(list(
    results = results,
    IS_AP = IS_AP,
    saved_path = saved_path
  ))
}