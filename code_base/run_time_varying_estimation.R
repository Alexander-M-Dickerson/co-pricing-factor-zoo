#' Run Time-Varying Bayesian Asset-Pricing Estimation
#'
#' Executes run_bayesian_mcmc_time_varying() over multiple expanding or rolling windows,
#' then combines results into time-series matrices and saves to CSV/RDS files.
#'
#' @param main_path      Root folder of the project
#' @param data_folder    Sub-folder containing data files
#' @param output_folder  Sub-folder where results are saved
#' @param code_folder    Sub-folder with helper R scripts
#'
#' @param model_type     Model configuration: "bond", "stock", "bond_stock_with_sp", "treasury"
#' @param return_type    Return measure: "excess" or "duration"
#'
#' @param f1             Filename for non-traded factors
#' @param f2             Filename(s) for traded factors (single or vector)
#' @param R              Filename(s) for test assets (single or vector)
#' @param fac_freq       Filename for frequentist factors
#' @param n_bond_factors For bond_stock_with_sp: number of bond factors (NULL for auto-infer)
#'
#' @param date_start     Start date for entire analysis period (YYYY-MM-DD)
#' @param date_end       End date for entire analysis period (YYYY-MM-DD)
#'
#' @param initial_window EITHER integer (number of months) OR character (date range "YYYY-MM-DD:YYYY-MM-DD")
#'                       For integer: counts from date_start
#'                       For date range: explicit window boundaries
#'                       MUTUALLY EXCLUSIVE with window_start/window_end
#' @param holding_period Number of months between re-estimations (e.g., 12 = annual, 1 = monthly)
#' @param window_type    Either "expanding" or "rolling"
#'
#' @param frequentist_models Named list of frequentist models (REQUIRED)
#'
#' @param ndraws         MCMC iterations
#' @param SRscale        Vector of prior SR multipliers
#' @param alpha.w        Beta prior hyperparameter
#' @param beta.w         Beta prior hyperparameter
#' @param kappa          Factor tilt parameter
#' @param kappa_fac      Factor-specific kappa values
#'
#' @param tag            Label for output files
#' @param num_cores      Number of CPU cores for parallel MCMC
#' @param seed           RNG seed
#' @param intercept      Include linear intercept?
#' @param save_flag      Save individual IS_AP results to .Rdata? (passed to run_bayesian_mcmc_time_varying)
#' @param verbose        Print progress messages?
#' @param fac_to_drop    List of factor names to exclude
#' @param weighting      Weighting scheme: "GLS" or "OLS"
#'
#' @return List containing combined time-series results:
#'   - weights: list of data.frames (one per model) with date column + asset weights
#'   - lambdas: list of data.frames (one per model) with date column + factor lambdas
#'   - scaled_lambdas: list of data.frames (one per model)
#'   - gammas: list of data.frames (BMA models only) with date column + inclusion probabilities
#'   - top_factors: data.frame with date + top 5 factors per psi
#'   - top_mpr_factors: data.frame with date + top 5 MPR factors per psi
#'   - metadata: estimation parameters and window schedule
#'
#' @details
#' This function orchestrates multiple calls to run_bayesian_mcmc_time_varying(),
#' automatically managing expanding or rolling window estimation.
#' Individual window results are saved by run_bayesian_mcmc_time_varying().
#' Combined time-series results are saved to output/time_varying/ as CSVs and RDS.

run_time_varying_estimation <- function(
    # Paths
  main_path,
  data_folder   = "data",
  output_folder = "output",
  code_folder   = "code_base",
  
  # Model configuration
  model_type    = "bond",
  return_type   = "excess",
  
  # Data files
  f1            = "nontraded_factors.csv",
  f2            = "traded_factors.csv",
  R             = "test_assets.csv",
  fac_freq      = "frequentist_factors.csv",
  n_bond_factors = NULL,
  
  # Date range for entire analysis
  date_start    = NULL,
  date_end      = NULL,
  
  # Time-varying parameters
  initial_window  = 222,
  holding_period  = 12,
  window_type     = "expanding",
  
  # Frequentist models (REQUIRED)
  frequentist_models = NULL,
  
  # MCMC parameters
  ndraws        = 50000,
  SRscale       = c(0.20, 0.40, 0.60, 0.80),
  alpha.w       = 1,
  beta.w        = 1,
  kappa         = 0,
  kappa_fac     = NULL,
  
  # Other settings
  tag           = "TimeVarying",
  num_cores     = 4,
  seed          = 234,
  intercept     = TRUE,
  save_flag     = TRUE,
  verbose       = TRUE,
  fac_to_drop   = NULL,
  weighting     = "GLS"
) {
  
  ## =========================================================================
  ## 0. VALIDATION
  ## =========================================================================
  
  if (is.null(date_start) || is.null(date_end)) {
    stop("Both date_start and date_end must be provided")
  }
  
  if (is.null(frequentist_models)) {
    stop("`frequentist_models` is REQUIRED. Must be a named list of factor vectors.")
  }
  
  if (!window_type %in% c("expanding", "rolling")) {
    stop("`window_type` must be either 'expanding' or 'rolling'")
  }
  
  if (holding_period < 1) {
    stop("`holding_period` must be >= 1")
  }
  
  # Validate initial_window format
  if (is.character(initial_window)) {
    # Should be format "YYYY-MM-DD:YYYY-MM-DD"
    if (!grepl("^\\d{4}-\\d{2}-\\d{2}:\\d{4}-\\d{2}-\\d{2}$", initial_window)) {
      stop("`initial_window` as character must be format 'YYYY-MM-DD:YYYY-MM-DD'")
    }
  } else if (!is.numeric(initial_window) || initial_window < 1) {
    stop("`initial_window` must be positive integer (months) or date range string")
  }
  
  ## =========================================================================
  ## 1. SETUP LOGGING (MUST BE FIRST - before any verbose output)
  ## =========================================================================
  
  # Prepare output directories
  time_varying_dir <- file.path(
    if (dir.exists(output_folder)) output_folder else file.path(main_path, output_folder),
    "time_varying"
  )
  if (!dir.exists(time_varying_dir)) {
    dir.create(time_varying_dir, recursive = TRUE)
  }
  
  # Create logs subdirectory
  logs_dir <- file.path(time_varying_dir, "logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE)
  }
  
  # Error log file
  error_log_path <- file.path(logs_dir, "estimation_errors.log")
  if (file.exists(error_log_path)) file.remove(error_log_path)
  
  # Execution log file with timestamp
  log_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  exec_log_path <- file.path(logs_dir, 
                             sprintf("execution_%s_%s_%s.log", 
                                     window_type, tag, log_timestamp))
  
  # Open log file
  log_con <- file(exec_log_path, open = "wt")
  
  # Custom logging function (writes to both console and file)
  log_msg <- function(...) {
    msg <- paste0(...)
    cat(msg, file = log_con)
    cat(msg)
    flush(log_con)
  }
  
  # Ensure log file is closed on exit
  on.exit(close(log_con), add = TRUE)
  
  ## =========================================================================
  ## 2. GENERATE WINDOW SCHEDULE
  ## =========================================================================
  
  if (verbose) {
    log_msg("\n")
    log_msg("=====================================\n")
    log_msg("TIME-VARYING ESTIMATION SETUP\n")
    log_msg("=====================================\n")
    log_msg("Window type    : ", window_type, "\n")
    log_msg("Holding period : ", holding_period, " months\n")
    log_msg("Analysis period: ", date_start, " to ", date_end, "\n")
  }
  
  window_schedule <- generate_window_schedule(
    date_start      = date_start,
    date_end        = date_end,
    initial_window  = initial_window,
    holding_period  = holding_period,
    window_type     = window_type,
    verbose         = verbose,
    log_msg         = log_msg
  )
  
  n_windows <- nrow(window_schedule)
  
  if (verbose) {
    log_msg("Total windows  : ", n_windows, "\n")
    log_msg("Execution log  : ", exec_log_path, "\n")
    log_msg("\n")
  }
  
  ## =========================================================================
  ## 3. EXECUTE ESTIMATION FOR EACH WINDOW
  ## =========================================================================
  
  if (verbose) {
    log_msg("=====================================\n")
    log_msg("EXECUTING ESTIMATIONS\n")
    log_msg("=====================================\n\n")
  }
  
  failed_windows <- integer(0)
  window_times <- numeric(0)  # Track time per window
  
  for (i in 1:n_windows) {
    window_start <- window_schedule$start_date[i]
    window_end   <- window_schedule$end_date[i]
    
    if (verbose) {
      log_msg(sprintf("Window %d/%d: %s to %s\n", i, n_windows, window_start, window_end))
    }
    
    window_start_time <- Sys.time()
    
    tryCatch({
      # Call run_bayesian_mcmc_time_varying for this window
      run_bayesian_mcmc_time_varying(
        # Paths
        main_path     = main_path,
        data_folder   = data_folder,
        output_folder = output_folder,
        code_folder   = code_folder,
        
        # Model configuration
        model_type    = model_type,
        return_type   = return_type,
        
        # Data files
        f1            = f1,
        f2            = f2,
        R             = R,
        fac_freq      = fac_freq,
        n_bond_factors = n_bond_factors,
        
        # Date range for THIS WINDOW
        date_start    = window_start,
        date_end      = window_end,
        
        # Frequentist models
        frequentist_models = frequentist_models,
        
        # MCMC parameters
        ndraws        = ndraws,
        SRscale       = SRscale,
        alpha.w       = alpha.w,
        beta.w        = beta.w,
        kappa         = kappa,
        kappa_fac     = kappa_fac,
        
        # Other settings
        tag           = tag,
        num_cores     = num_cores,
        seed          = i,
        intercept     = intercept,
        save_flag     = save_flag,
        verbose       = FALSE,  # Suppress individual window verbosity
        fac_to_drop   = fac_to_drop,
        weighting     = weighting
      )
      
      window_end_time <- Sys.time()
      window_elapsed <- as.numeric(difftime(window_end_time, window_start_time, units = "mins"))
      window_times <- c(window_times, window_elapsed)
      
      # Calculate forecast
      avg_time_per_window <- mean(window_times)
      windows_remaining <- n_windows - i
      forecast_mins <- avg_time_per_window * windows_remaining
      
      if (verbose) {
        log_msg(sprintf("  Completed in %.2f mins", window_elapsed))
        if (windows_remaining > 0) {
          log_msg(sprintf(" | Est. remaining: %.1f mins", forecast_mins))
        }
        log_msg("\n\n")
      }
      
    }, error = function(e) {
      failed_windows <<- c(failed_windows, i)
      
      error_msg <- sprintf(
        "\n[%s] Window %d FAILED\nPeriod: %s to %s\nError: %s\n\n",
        Sys.time(), i, window_start, window_end, e$message
      )
      
      log_msg("  FAILED - ", e$message, "\n\n")
      
      # Write to error log file
      cat(error_msg, file = error_log_path, append = TRUE)
    })
  }
  
  ## =========================================================================
  ## 4. LOAD AND COMBINE RESULTS
  ## =========================================================================
  
  if (verbose) {
    log_msg("=====================================\n")
    log_msg("COMBINING RESULTS\n")
    log_msg("=====================================\n\n")
  }
  
  # Construct expected filenames for successful windows
  successful_windows <- setdiff(1:n_windows, failed_windows)
  
  if (length(successful_windows) == 0) {
    stop("All windows failed. Check error log: ", error_log_path)
  }
  
  if (length(failed_windows) > 0 && verbose) {
    log_msg("WARNING: ", length(failed_windows), " window(s) failed. See: ", error_log_path, "\n\n")
  }
  
  # Load IS_AP objects from saved files
  IS_AP_list <- list()
  
  output_dir <- if (dir.exists(output_folder)) {
    output_folder
  } else {
    file.path(main_path, output_folder)
  }
  
  for (i in successful_windows) {
    window_end_date <- window_schedule$end_date[i]
    date_str <- gsub("-", "", window_end_date)
    
    fname <- sprintf(
      "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s%s.Rdata",
      return_type,
      model_type,
      trunc(alpha.w),
      trunc(beta.w),
      tag,
      date_str
    )
    
    fpath <- file.path(output_dir, fname)
    
    if (file.exists(fpath)) {
      env <- new.env()
      load(fpath, envir = env)
      if (exists("IS_AP", envir = env)) {
        IS_AP_list[[as.character(window_end_date)]] <- env$IS_AP
      } else {
        warning("IS_AP object not found in ", fname)
      }
    } else {
      warning("Expected file not found: ", fpath)
    }
  }
  
  if (length(IS_AP_list) == 0) {
    stop("No IS_AP objects could be loaded from saved files")
  }
  
  if (verbose) {
    log_msg("Loaded ", length(IS_AP_list), " IS_AP objects\n")
  }
  
  ## =========================================================================
  ## 5. STACK RESULTS INTO TIME-SERIES MATRICES
  ## =========================================================================
  
  combined_results <- stack_window_results(
    IS_AP_list = IS_AP_list,
    verbose    = verbose,
    log_msg    = log_msg
  )
  
  ## =========================================================================
  ## 6. ADD METADATA
  ## =========================================================================
  
  combined_results$metadata <- list(
    window_type        = window_type,
    holding_period     = holding_period,
    initial_window     = initial_window,
    model_type         = model_type,
    return_type        = return_type,
    date_start         = date_start,
    date_end           = date_end,
    ndraws             = ndraws,
    alpha.w            = alpha.w,
    beta.w             = beta.w,
    SRscale            = SRscale,
    tag                = tag,
    n_windows_total    = n_windows,
    n_windows_success  = length(successful_windows),
    n_windows_failed   = length(failed_windows),
    failed_window_ids  = failed_windows,
    estimation_windows = window_schedule,
    frequentist_models = frequentist_models
  )
  
  ## =========================================================================
  ## 7. SAVE COMBINED RESULTS
  ## =========================================================================
  
  saved_paths <- save_combined_results(
    combined_results = combined_results,
    output_dir       = time_varying_dir,
    return_type      = return_type,
    model_type       = model_type,
    alpha.w          = alpha.w,
    beta.w           = beta.w,
    tag              = tag,
    verbose          = verbose,
    log_msg          = log_msg
  )
  
  ## =========================================================================
  ## 8. SUMMARY
  ## =========================================================================
  
  if (verbose) {
    log_msg("\n")
    log_msg("=====================================\n")
    log_msg("ESTIMATION COMPLETE\n")
    log_msg("=====================================\n")
    log_msg("Windows estimated: ", length(successful_windows), "/", n_windows, "\n")
    if (length(failed_windows) > 0) {
      log_msg("Failed windows   : ", paste(failed_windows, collapse = ", "), "\n")
    }
    if (length(window_times) > 0) {
      total_time <- sum(window_times)
      avg_time <- mean(window_times)
      log_msg(sprintf("Total time       : %.2f mins\n", total_time))
      log_msg(sprintf("Avg time/window  : %.2f mins\n", avg_time))
    }
    log_msg("Results saved to : ", time_varying_dir, "\n")
    log_msg("Execution log    : ", exec_log_path, "\n")
    log_msg("=====================================\n\n")
  }
  
  # Return combined results
  invisible(combined_results)
}


## =============================================================================
## HELPER FUNCTION: Generate Window Schedule
## =============================================================================

generate_window_schedule <- function(date_start, date_end, initial_window,
                                     holding_period, window_type, verbose = TRUE,
                                     log_msg = cat) {
  
  library(lubridate)
  
  # Parse dates
  start_date <- as.Date(date_start)
  end_date   <- as.Date(date_end)
  
  # Determine initial window end date
  if (is.character(initial_window)) {
    # Parse date range format "YYYY-MM-DD:YYYY-MM-DD"
    parts <- strsplit(initial_window, ":")[[1]]
    initial_start <- as.Date(parts[1])
    initial_end   <- as.Date(parts[2])
    
    if (initial_start < start_date || initial_end > end_date) {
      stop("initial_window dates must be within date_start and date_end range")
    }
  } else {
    # Integer: count months from start_date
    initial_start <- start_date
    initial_end   <- start_date %m+% months(initial_window - 1)
    
    # Adjust to end of month
    initial_end <- ceiling_date(initial_end, "month") - days(1)
    
    if (initial_end > end_date) {
      stop("initial_window extends beyond date_end")
    }
  }
  
  # Build window schedule
  windows <- data.frame(
    window_id  = integer(0),
    start_date = character(0),
    end_date   = character(0),
    stringsAsFactors = FALSE
  )
  
  current_start <- initial_start
  current_end   <- initial_end
  window_id     <- 1
  
  # First window
  windows <- rbind(windows, data.frame(
    window_id  = window_id,
    start_date = as.character(current_start),
    end_date   = as.character(current_end),
    stringsAsFactors = FALSE
  ))
  
  # Subsequent windows
  while (TRUE) {
    # Calculate next window end
    next_end <- current_end %m+% months(holding_period)
    next_end <- ceiling_date(next_end, "month") - days(1)
    
    # If we've reached or passed the final date
    if (next_end >= end_date) {
      # Include final window using all remaining data (if different from current)
      if (end_date > current_end) {
        window_id <- window_id + 1
        next_start <- if (window_type == "rolling") {
          current_start %m+% months(holding_period)
        } else {
          initial_start  # expanding: keep original start
        }
        
        windows <- rbind(windows, data.frame(
          window_id  = window_id,
          start_date = as.character(next_start),
          end_date   = as.character(end_date),
          stringsAsFactors = FALSE
        ))
      }
      break
    }
    
    # Regular window
    window_id <- window_id + 1
    
    if (window_type == "rolling") {
      # Rolling: shift both start and end forward
      next_start <- current_start %m+% months(holding_period)
    } else {
      # Expanding: keep original start
      next_start <- initial_start
    }
    
    windows <- rbind(windows, data.frame(
      window_id  = window_id,
      start_date = as.character(next_start),
      end_date   = as.character(next_end),
      stringsAsFactors = FALSE
    ))
    
    current_start <- next_start
    current_end   <- next_end
  }
  
  if (verbose) {
    log_msg("Window schedule generated:\n")
    log_msg("  First window: ", windows$start_date[1], " to ", windows$end_date[1], "\n")
    log_msg("  Last window : ", windows$start_date[nrow(windows)], " to ", windows$end_date[nrow(windows)], "\n")
  }
  
  return(windows)
}


## =============================================================================
## HELPER FUNCTION: Stack Window Results
## =============================================================================

stack_window_results <- function(IS_AP_list, verbose = TRUE, log_msg = cat) {
  
  if (length(IS_AP_list) == 0) {
    stop("IS_AP_list is empty")
  }
  
  # Get dates (sorted)
  dates <- sort(as.Date(names(IS_AP_list)))
  date_labels <- as.character(dates)
  
  # Get all model names from first IS_AP object
  first_IS_AP <- IS_AP_list[[1]]
  
  ## -------------------------------------------------------------------------
  ## 1. Stack WEIGHTS
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Stacking weights...\n")
  
  model_names <- names(first_IS_AP$weights)
  weights_stacked <- list()
  
  for (model_name in model_names) {
    # Collect all asset names across all windows (union)
    all_assets <- character(0)
    for (date_label in date_labels) {
      w <- IS_AP_list[[date_label]]$weights[[model_name]]
      if (!is.null(w) && ncol(w) > 0) {
        # Get colnames and filter out empty strings
        cols <- colnames(w)
        cols <- cols[nzchar(cols)]  # Remove empty strings
        all_assets <- union(all_assets, cols)
      }
    }
    
    if (length(all_assets) == 0) next
    
    # Build matrix: rows = dates, cols = assets
    weight_matrix <- matrix(NA, nrow = length(dates), ncol = length(all_assets),
                            dimnames = list(date_labels, all_assets))
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      w <- IS_AP_list[[date_label]]$weights[[model_name]]
      if (!is.null(w) && ncol(w) > 0) {
        # Direct assignment - use available columns
        tryCatch({
          # Use drop() which preserves names better
          w_vec <- drop(w)
          
          # Filter to non-empty names only
          valid_idx <- nzchar(names(w_vec))
          w_vec <- w_vec[valid_idx]
          
          # Assign to matrix
          for (col in names(w_vec)) {
            if (col %in% all_assets) {
              weight_matrix[i, col] <- w_vec[col]
            }
          }
        }, error = function(e) {
          warning("Failed to assign weights for ", model_name, " at ", date_label, ": ", e$message)
        })
      }
    }
    
    # Convert to data.frame with date column first
    weights_stacked[[model_name]] <- data.frame(
      date = dates,
      weight_matrix,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }
  
  ## -------------------------------------------------------------------------
  ## 2. Stack LAMBDAS
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Stacking lambdas...\n")
  
  lambdas_stacked <- list()
  
  for (model_name in model_names) {
    # Collect all factor names
    all_factors <- character(0)
    for (date_label in date_labels) {
      lam <- IS_AP_list[[date_label]]$lambdas[[model_name]]
      if (!is.null(lam) && ncol(lam) > 0) {
        # Get colnames and filter out empty strings
        cols <- colnames(lam)
        cols <- cols[nzchar(cols)]  # Remove empty strings
        all_factors <- union(all_factors, cols)
      }
    }
    
    if (length(all_factors) == 0) next
    
    # Build matrix
    lambda_matrix <- matrix(NA, nrow = length(dates), ncol = length(all_factors),
                            dimnames = list(date_labels, all_factors))
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      lam <- IS_AP_list[[date_label]]$lambdas[[model_name]]
      if (!is.null(lam) && ncol(lam) > 0) {
        tryCatch({
          # Use drop() which preserves names better
          lam_vec <- drop(lam)
          
          # Filter to non-empty names only
          valid_idx <- nzchar(names(lam_vec))
          lam_vec <- lam_vec[valid_idx]
          
          # Assign to matrix
          for (col in names(lam_vec)) {
            if (col %in% all_factors) {
              lambda_matrix[i, col] <- lam_vec[col]
            }
          }
        }, error = function(e) {
          warning("Failed to assign lambdas for ", model_name, " at ", date_label, ": ", e$message)
        })
      }
    }
    
    # Convert to data.frame
    lambdas_stacked[[model_name]] <- data.frame(
      date = dates,
      lambda_matrix,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }
  
  ## -------------------------------------------------------------------------
  ## 3. Stack SCALED_LAMBDAS
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Stacking scaled lambdas...\n")
  
  scaled_lambdas_stacked <- list()
  
  for (model_name in model_names) {
    # Collect all factor names
    all_factors <- character(0)
    for (date_label in date_labels) {
      lam <- IS_AP_list[[date_label]]$scaled_lambdas[[model_name]]
      if (!is.null(lam) && ncol(lam) > 0) {
        # Get colnames and filter out empty strings
        cols <- colnames(lam)
        cols <- cols[nzchar(cols)]  # Remove empty strings
        all_factors <- union(all_factors, cols)
      }
    }
    
    if (length(all_factors) == 0) next
    
    # Build matrix
    lambda_matrix <- matrix(NA, nrow = length(dates), ncol = length(all_factors),
                            dimnames = list(date_labels, all_factors))
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      lam <- IS_AP_list[[date_label]]$scaled_lambdas[[model_name]]
      if (!is.null(lam) && ncol(lam) > 0) {
        tryCatch({
          # Use drop() which preserves names better
          lam_vec <- drop(lam)
          
          # Filter to non-empty names only
          valid_idx <- nzchar(names(lam_vec))
          lam_vec <- lam_vec[valid_idx]
          
          # Assign to matrix
          for (col in names(lam_vec)) {
            if (col %in% all_factors) {
              lambda_matrix[i, col] <- lam_vec[col]
            }
          }
        }, error = function(e) {
          warning("Failed to assign scaled_lambdas for ", model_name, " at ", date_label, ": ", e$message)
        })
      }
    }
    
    # Convert to data.frame
    scaled_lambdas_stacked[[model_name]] <- data.frame(
      date = dates,
      lambda_matrix,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }
  
  ## -------------------------------------------------------------------------
  ## 4. Stack GAMMAS (BMA models only)
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Stacking gammas...\n")
  
  gammas_stacked <- list()
  
  # Check which models have gammas (should be BMA models)
  gamma_models <- names(first_IS_AP$gammas)
  
  for (model_name in gamma_models) {
    # Collect all factor names
    all_factors <- character(0)
    for (date_label in date_labels) {
      gam <- IS_AP_list[[date_label]]$gammas[[model_name]]
      if (!is.null(gam) && ncol(gam) > 0) {
        # Get colnames and filter out empty strings
        cols <- colnames(gam)
        cols <- cols[nzchar(cols)]  # Remove empty strings
        all_factors <- union(all_factors, cols)
      }
    }
    
    if (length(all_factors) == 0) next
    
    # Build matrix
    gamma_matrix <- matrix(NA, nrow = length(dates), ncol = length(all_factors),
                           dimnames = list(date_labels, all_factors))
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      gam <- IS_AP_list[[date_label]]$gammas[[model_name]]
      if (!is.null(gam) && ncol(gam) > 0) {
        tryCatch({
          # Use drop() which preserves names better
          gam_vec <- drop(gam)
          
          # Filter to non-empty names only
          valid_idx <- nzchar(names(gam_vec))
          gam_vec <- gam_vec[valid_idx]
          
          # Assign to matrix
          for (col in names(gam_vec)) {
            if (col %in% all_factors) {
              gamma_matrix[i, col] <- gam_vec[col]
            }
          }
        }, error = function(e) {
          warning("Failed to assign gammas for ", model_name, " at ", date_label, ": ", e$message)
        })
      }
    }
    
    # Convert to data.frame
    gammas_stacked[[model_name]] <- data.frame(
      date = dates,
      gamma_matrix,
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  }
  
  ## -------------------------------------------------------------------------
  ## 5. Stack TOP_FACTORS and TOP_MPR_FACTORS
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Stacking top factors...\n")
  
  # top_factors is a list of 4 elements (one per psi), each containing 5 factor names
  # Convert to data.frame: date, psi1_1, psi1_2, ..., psi1_5, psi2_1, ..., psi4_5
  
  top_factors_df <- data.frame(date = dates)
  top_mpr_factors_df <- data.frame(date = dates)
  
  for (psi_idx in 1:4) {
    for (rank in 1:5) {
      col_name <- paste0("psi", psi_idx, "_", rank)
      
      # Top factors
      factor_vals <- sapply(date_labels, function(dl) {
        tf <- IS_AP_list[[dl]]$top_factors[[psi_idx]]
        if (length(tf) >= rank) tf[rank] else NA_character_
      })
      top_factors_df[[col_name]] <- factor_vals
      
      # Top MPR factors
      factor_vals_mpr <- sapply(date_labels, function(dl) {
        tf <- IS_AP_list[[dl]]$top_mpr_factors[[psi_idx]]
        if (length(tf) >= rank) tf[rank] else NA_character_
      })
      top_mpr_factors_df[[col_name]] <- factor_vals_mpr
    }
  }
  
  ## -------------------------------------------------------------------------
  ## 6. Return Combined Results
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Stacking complete.\n\n")
  
  return(list(
    weights          = weights_stacked,
    lambdas          = lambdas_stacked,
    scaled_lambdas   = scaled_lambdas_stacked,
    gammas           = gammas_stacked,
    top_factors      = top_factors_df,
    top_mpr_factors  = top_mpr_factors_df
  ))
}


## =============================================================================
## HELPER FUNCTION: Save Combined Results
## =============================================================================

save_combined_results <- function(combined_results, output_dir, return_type,
                                  model_type, alpha.w, beta.w, tag, verbose = TRUE,
                                  log_msg = cat) {
  
  if (verbose) {
    log_msg("=====================================\n")
    log_msg("SAVING COMBINED RESULTS\n")
    log_msg("=====================================\n\n")
  }
  
  saved_paths <- list()
  
  # Base filename pattern (following run_bayesian_mcmc_time_varying convention)
  base_pattern <- sprintf(
    "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s",
    return_type, model_type, trunc(alpha.w), trunc(beta.w), tag
  )
  
  ## -------------------------------------------------------------------------
  ## 1. Save WEIGHTS as individual CSVs
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Saving weights CSVs...\n")
  
  for (model_name in names(combined_results$weights)) {
    # Clean model name for filename (replace special chars)
    clean_name <- gsub("[^A-Za-z0-9]", "", model_name)
    
    fname <- paste0(base_pattern, "_weights_", model_name, "_COMBINED.csv")
    fpath <- file.path(output_dir, fname)
    
    write.csv(combined_results$weights[[model_name]], 
              file = fpath, row.names = FALSE)
    
    saved_paths$weights[[model_name]] <- fpath
    
    if (verbose) log_msg("  ", fname, "\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 2. Save LAMBDAS as individual CSVs
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("\nSaving lambdas CSVs...\n")
  
  for (model_name in names(combined_results$lambdas)) {
    clean_name <- gsub("[^A-Za-z0-9]", "", model_name)
    
    fname <- paste0(base_pattern, "_lambdas_", model_name, "_COMBINED.csv")
    fpath <- file.path(output_dir, fname)
    
    write.csv(combined_results$lambdas[[model_name]], 
              file = fpath, row.names = FALSE)
    
    saved_paths$lambdas[[model_name]] <- fpath
    
    if (verbose) log_msg("  ", fname, "\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 3. Save SCALED_LAMBDAS as individual CSVs
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("\nSaving scaled_lambdas CSVs...\n")
  
  for (model_name in names(combined_results$scaled_lambdas)) {
    clean_name <- gsub("[^A-Za-z0-9]", "", model_name)
    
    fname <- paste0(base_pattern, "_scaled_lambdas_", model_name, "_COMBINED.csv")
    fpath <- file.path(output_dir, fname)
    
    write.csv(combined_results$scaled_lambdas[[model_name]], 
              file = fpath, row.names = FALSE)
    
    saved_paths$scaled_lambdas[[model_name]] <- fpath
    
    if (verbose) log_msg("  ", fname, "\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 4. Save GAMMAS as individual CSVs (BMA only)
  ## -------------------------------------------------------------------------
  
  if (length(combined_results$gammas) > 0) {
    if (verbose) log_msg("\nSaving gammas CSVs...\n")
    
    for (model_name in names(combined_results$gammas)) {
      clean_name <- gsub("[^A-Za-z0-9]", "", model_name)
      
      fname <- paste0(base_pattern, "_gammas_", model_name, "_COMBINED.csv")
      fpath <- file.path(output_dir, fname)
      
      write.csv(combined_results$gammas[[model_name]], 
                file = fpath, row.names = FALSE)
      
      saved_paths$gammas[[model_name]] <- fpath
      
      if (verbose) log_msg("  ", fname, "\n")
    }
  }
  
  ## -------------------------------------------------------------------------
  ## 5. Save TOP_FACTORS and TOP_MPR_FACTORS as CSVs
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("\nSaving top factors CSVs...\n")
  
  fname_top <- paste0(base_pattern, "_top_factors_COMBINED.csv")
  fpath_top <- file.path(output_dir, fname_top)
  write.csv(combined_results$top_factors, file = fpath_top, row.names = FALSE)
  saved_paths$top_factors <- fpath_top
  if (verbose) log_msg("  ", fname_top, "\n")
  
  fname_mpr <- paste0(base_pattern, "_top_mpr_factors_COMBINED.csv")
  fpath_mpr <- file.path(output_dir, fname_mpr)
  write.csv(combined_results$top_mpr_factors, file = fpath_mpr, row.names = FALSE)
  saved_paths$top_mpr_factors <- fpath_mpr
  if (verbose) log_msg("  ", fname_mpr, "\n")
  
  ## -------------------------------------------------------------------------
  ## 6. Save EVERYTHING as single RDS file
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("\nSaving comprehensive RDS file...\n")
  
  rds_fname <- paste0(base_pattern, "_ALL_RESULTS.rds")
  rds_fpath <- file.path(output_dir, rds_fname)
  
  saveRDS(combined_results, file = rds_fpath, compress = TRUE)
  saved_paths$rds <- rds_fpath
  
  if (verbose) log_msg("  ", rds_fname, "\n")
  
  ## -------------------------------------------------------------------------
  ## 7. Return saved paths
  ## -------------------------------------------------------------------------
  
  if (verbose) {
    log_msg("\nAll combined results saved to: ", output_dir, "\n")
    log_msg("=====================================\n\n")
  }
  
  invisible(saved_paths)
}