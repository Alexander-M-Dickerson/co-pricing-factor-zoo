# =========================================================================
#  run_sr_decomposition_multi()  ---  SR Decomposition Across Model Types
# =========================================================================
# Runs sr_decomposition() for multiple model types and combines results
# into a single nested list. This is the intermediate step required before
# generating Tables 1, 4, and 5.
#
# Workflow:
#   1. Load variance decomposition results (DR/CF factor classification)
#   2. For each model type, load .Rdata and run sr_decomposition()
#   3. Combine into nested list and save as .rds
#
# Required
# --------
#   results_path     Path to folder containing model subfolders with .Rdata
#   data_path        Path to folder containing variance_decomp_results_vuol.rds
#
# Optional
# --------
#   model_types      Vector of model types to process
#                    (default: c("bond_stock_with_sp", "stock", "bond"))
#   return_type      "excess" or "duration" (default: "excess")
#   alpha.w, beta.w  Beta prior hyperparameters (default: 1, 1)
#   kappa            Factor tilt (default: 0)
#   tag              Run identifier (default: "baseline")
#   top_factors      Number of top factors for decomposition (default: 5)
#   save_output      Save results to .rds? (default: TRUE)
#   output_path      Where to save .rds (default: data_path)
#   verbose          Print progress messages (default: TRUE)
#
# Returns
# -------
#   Nested list: list(bond_stock_with_sp = <tibble>, stock = <tibble>, bond = <tibble>)
#   Also saves to: {output_path}/sr_decomposition_results.rds
# =========================================================================

run_sr_decomposition_multi <- function(results_path,
                                       data_path,
                                       # Model types to process
                                       model_types   = c("bond_stock_with_sp", "stock", "bond"),
                                       # .Rdata file parameters
                                       return_type   = "excess",
                                       alpha.w       = 1,
                                       beta.w        = 1,
                                       kappa         = 0,
                                       tag           = "baseline",
                                       # SR decomposition parameters
                                       top_factors   = 5,
                                       prior_labels  = c("20%", "40%", "60%", "80%"),
                                       # Output options
                                       save_output   = TRUE,
                                       output_path   = NULL,
                                       output_name   = "sr_decomposition_results.rds",
                                       verbose       = TRUE) {

  ## ---- 0. Validate inputs --------------------------------------------------
  if (!dir.exists(results_path)) {
    stop("results_path does not exist: ", results_path)
  }
  if (!dir.exists(data_path)) {
    stop("data_path does not exist: ", data_path)
  }

  if (is.null(output_path)) {
    output_path <- data_path
  }

  ## ---- 1. Load variance decomposition (DR/CF factor classification) --------
  dr_cf_file <- file.path(data_path, "variance_decomp_results_vuol.rds")

  if (!file.exists(dr_cf_file)) {
    warning("DR/CF decomposition file not found: ", dr_cf_file,
            "\n  DR/CF factor groups will be empty.")
    factor_lists <- NULL
  } else {
    if (verbose) message("Loading DR/CF factor classification...")
    df_dr_cf <- readRDS(dr_cf_file)
    factor_lists <- df_dr_cf$factor_lists
    if (verbose) {
      message("  DR factors: ", length(factor_lists$DR_factors %||% character(0)))
      message("  CF factors: ", length(factor_lists$CF_factors %||% character(0)))
    }
  }

  ## ---- 2. Source sr_decomposition function ---------------------------------
  # Assume it's already sourced or source it
  sr_decomp_path <- file.path(dirname(results_path), "code_base", "sr_decomposition.R")
  if (!exists("sr_decomposition", mode = "function")) {
    if (file.exists(sr_decomp_path)) {
      source(sr_decomp_path)
    } else {
      # Try relative to current working directory
      alt_path <- "code_base/sr_decomposition.R"
      if (file.exists(alt_path)) {
        source(alt_path)
      } else {
        stop("sr_decomposition.R not found. Please source it before calling this function.")
      }
    }
  }

  ## ---- 3. Process each model type ------------------------------------------
  if (verbose) {
    message("\n", strrep("=", 60))
    message("RUNNING SR DECOMPOSITION ACROSS MODEL TYPES")
    message(strrep("=", 60))
  }

  res_tbl_top <- list()

  for (model_type in model_types) {

    if (verbose) {
      message("\n--- Processing: ", model_type, " ---")
    }

    ## ---- 3a. Construct .Rdata filename -------------------------------------
    rdata_filename <- sprintf(
      "%s_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s.Rdata",
      return_type,
      model_type,
      alpha.w,
      beta.w,
      kappa,
      tag
    )

    rdata_path <- file.path(results_path, model_type, rdata_filename)

    ## ---- 3b. Check if file exists ------------------------------------------
    if (!file.exists(rdata_path)) {
      warning("Results file not found for ", model_type, ": ", rdata_path)
      res_tbl_top[[model_type]] <- NULL
      next
    }

    ## ---- 3c. Load .Rdata into a fresh environment --------------------------
    # Use a local environment to avoid polluting global namespace
    load_env <- new.env()
    load(rdata_path, envir = load_env)

    if (verbose) {
      message("  Loaded: ", rdata_filename)
      message("  Objects: ", paste(ls(load_env), collapse = ", "))
    }

    ## ---- 3d. Check required objects exist ----------------------------------
    if (!exists("results", envir = load_env)) {
      warning("'results' object not found in ", rdata_filename)
      res_tbl_top[[model_type]] <- NULL
      next
    }

    ## ---- 3e. Set up factor name vectors in the environment -----------------
    # sr_decomposition() expects these in the calling environment
    # We need to determine nontraded vs traded factors
    f1_local <- get("f1", envir = load_env)
    f2_local <- if (exists("f2", envir = load_env)) get("f2", envir = load_env) else NULL

    # Assign to load_env for sr_decomposition to find
    load_env$nontraded_names <- colnames(f1_local)

    if (!is.null(f2_local)) {
      # For bond_stock_with_sp, we need to split bond vs stock factors
      # This is model-specific logic
      f2_names <- colnames(f2_local)

      if (model_type == "bond_stock_with_sp") {
        # Heuristic: bond factors typically have certain naming patterns
        # User may need to customize this
        load_env$bond_names <- f2_names[grepl("^(TERM|DEF|CORP|GOV|BOND|YLD|DUR)", f2_names, ignore.case = TRUE)]
        load_env$stock_names <- setdiff(f2_names, load_env$bond_names)

        # If heuristic didn't work, just split evenly or use all as stock
        if (length(load_env$bond_names) == 0 && length(load_env$stock_names) == 0) {
          load_env$stock_names <- f2_names
        }
      } else if (model_type == "bond") {
        load_env$bond_names <- f2_names
        load_env$stock_names <- character(0)
      } else if (model_type == "stock") {
        load_env$bond_names <- character(0)
        load_env$stock_names <- f2_names
      } else {
        # Default: all are stock factors
        load_env$stock_names <- f2_names
        load_env$bond_names <- character(0)
      }
    } else {
      load_env$bond_names <- character(0)
      load_env$stock_names <- character(0)
    }

    if (verbose) {
      message("  Nontraded factors: ", length(load_env$nontraded_names))
      message("  Bond factors: ", length(load_env$bond_names))
      message("  Stock factors: ", length(load_env$stock_names))
    }

    ## ---- 3f. Run sr_decomposition in the load environment ------------------
    # We need to evaluate sr_decomposition in the context of load_env
    # so it can find f1, f2, intercept, etc.

    tryCatch({
      # Run sr_decomposition with the loaded environment
      result_tbl <- eval(
        expr = quote(
          sr_decomposition(
            results      = results,
            prior_labels = prior_labels,
            dr_cf_decomp = factor_lists,
            top_factors  = top_factors
          )
        ),
        envir = load_env
      )

      res_tbl_top[[model_type]] <- result_tbl

      if (verbose) {
        message("  SR decomposition complete: ",
                nrow(result_tbl), " rows")
      }

    }, error = function(e) {
      warning("Error processing ", model_type, ": ", e$message)
      res_tbl_top[[model_type]] <<- NULL
    })

    # Clean up
    rm(load_env)
    gc(verbose = FALSE)
  }

  ## ---- 4. Save combined results --------------------------------------------
  if (save_output) {
    if (!dir.exists(output_path)) {
      dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
    }

    output_file <- file.path(output_path, output_name)
    saveRDS(res_tbl_top, output_file)

    if (verbose) {
      message("\n", strrep("=", 60))
      message("SR DECOMPOSITION COMPLETE")
      message(strrep("=", 60))
      message("Results saved to: ", normalizePath(output_file))
      message("Model types processed: ", paste(names(res_tbl_top), collapse = ", "))
      message(strrep("=", 60))
    }
  }

  ## ---- 5. Return results ---------------------------------------------------
  invisible(res_tbl_top)
}


# =========================================================================
#  Helper: Null-coalescing operator
# =========================================================================
`%||%` <- function(x, y) if (is.null(x)) y else x
