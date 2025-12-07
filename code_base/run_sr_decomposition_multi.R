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

  ## ---- 2. Process each model type ------------------------------------------
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

    ## ---- 2a. Construct .Rdata filename -------------------------------------
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

    ## ---- 2b. Check if file exists ------------------------------------------
    if (!file.exists(rdata_path)) {
      warning("Results file not found for ", model_type, ": ", rdata_path)
      res_tbl_top[[model_type]] <- NULL
      next
    }

    ## ---- 2c. Load .Rdata directly into global environment ------------------
    # sr_decomposition() uses inherits=TRUE to find variables,
    # so we must load into global environment for it to work correctly.
    # Save any existing variables we might overwrite, then restore after.

    vars_to_save <- c("results", "f1", "f2", "intercept",
                      "nontraded_names", "bond_names", "stock_names")
    saved_vars <- list()
    for (v in vars_to_save) {
      if (exists(v, envir = .GlobalEnv)) {
        saved_vars[[v]] <- get(v, envir = .GlobalEnv)
      }
    }

    # Load the .Rdata file
    load(rdata_path, envir = .GlobalEnv)

    if (verbose) {
      message("  Loaded: ", rdata_filename)
    }

    ## ---- 2d. Report factor counts from loaded data -------------------------
    if (verbose) {
      n_nontraded <- if (exists("nontraded_names", envir = .GlobalEnv)) {
        length(get("nontraded_names", envir = .GlobalEnv))
      } else 0
      n_bond <- if (exists("bond_names", envir = .GlobalEnv)) {
        length(get("bond_names", envir = .GlobalEnv))
      } else 0
      n_stock <- if (exists("stock_names", envir = .GlobalEnv)) {
        length(get("stock_names", envir = .GlobalEnv))
      } else 0

      message("  Nontraded factors: ", n_nontraded)
      message("  Bond factors: ", n_bond)
      message("  Stock factors: ", n_stock)
    }

    ## ---- 2e. Run sr_decomposition ------------------------------------------
    tryCatch({
      result_tbl <- sr_decomposition(
        results      = results,
        prior_labels = prior_labels,
        dr_cf_decomp = factor_lists,
        top_factors  = top_factors
      )

      res_tbl_top[[model_type]] <- result_tbl

      if (verbose) {
        message("  SR decomposition complete: ", nrow(result_tbl), " rows")
      }

    }, error = function(e) {
      warning("Error processing ", model_type, ": ", e$message)
      res_tbl_top[[model_type]] <<- NULL
    })

    ## ---- 2f. Restore saved variables ---------------------------------------
    # Remove loaded variables
    for (v in vars_to_save) {
      if (exists(v, envir = .GlobalEnv)) {
        rm(list = v, envir = .GlobalEnv)
      }
    }
    # Restore previously saved variables
    for (v in names(saved_vars)) {
      assign(v, saved_vars[[v]], envir = .GlobalEnv)
    }

    gc(verbose = FALSE)
  }

  ## ---- 3. Save combined results --------------------------------------------
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

  ## ---- 4. Return results ---------------------------------------------------
  invisible(res_tbl_top)
}


# =========================================================================
#  Helper: Null-coalescing operator
# =========================================================================
`%||%` <- function(x, y) if (is.null(x)) y else x
