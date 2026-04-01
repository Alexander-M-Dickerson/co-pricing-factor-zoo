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
  reverse_time    = FALSE,

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
  save_flag     = FALSE,
  save_csv_flag = FALSE,
  verbose       = TRUE,
  fac_to_drop   = NULL,
  weighting     = "GLS",
  drop_draws_pct = 0,
  self_pricing_engine = c("fast", "reference"),
  parallel_type = "auto",
  cluster_timeout = 30,
  require_all_windows = TRUE
) {
  self_pricing_engine <- match.arg(self_pricing_engine)
  parallel_type <- match.arg(parallel_type, c("auto", "PSOCK", "FORK", "sequential"))
  f1_input <- f1
  f2_input <- f2
  R_input <- R
  fac_freq_input <- fac_freq
  
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
  
  # Create logs subdirectory (shared across all model types)
  logs_dir <- file.path(time_varying_dir, "logs")
  if (!dir.exists(logs_dir)) {
    dir.create(logs_dir, recursive = TRUE)
  }
  
  # Create model-specific output directory for panel results
  model_output_dir <- file.path(time_varying_dir, model_type)
  if (!dir.exists(model_output_dir)) {
    dir.create(model_output_dir, recursive = TRUE)
  }
  
  # Execution log file with timestamp
  log_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  
  # Keep per-run error logs separate so paired forward/backward runs do not
  # overwrite each other's diagnostics.
  error_log_path <- file.path(
    logs_dir,
    sprintf("estimation_errors_%s_%s.log", tag, log_timestamp)
  )
  if (file.exists(error_log_path)) file.remove(error_log_path)

  exec_log_path <- file.path(logs_dir, 
                             sprintf("execution_%s_%s_%s.log", 
                                     window_type, tag, log_timestamp))
  
  # Open log file
  log_con <- file(exec_log_path, open = "wt")
  run_started_at <- Sys.time()
  
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
    log_msg("Reverse time   : ", reverse_time, "\n")
    log_msg("Holding period : ", holding_period, " months\n")
    log_msg("Analysis period: ", date_start, " to ", date_end, "\n")
  }

  window_schedule <- generate_window_schedule(
    date_start      = date_start,
    date_end        = date_end,
    initial_window  = initial_window,
    holding_period  = holding_period,
    window_type     = window_type,
    reverse_time    = reverse_time,
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
  IS_AP_list <- list()  # Store IS_AP objects directly
  
  for (i in 1:n_windows) {
    window_start <- window_schedule$start_date[i]
    window_end   <- window_schedule$end_date[i]
    
    if (verbose) {
      log_msg(sprintf("Window %d/%d: %s to %s\n", i, n_windows, window_start, window_end))
    }
    
    window_start_time <- Sys.time()
    
    tryCatch({
      # Call run_bayesian_mcmc_time_varying for this window
      IS_AP <- run_bayesian_mcmc_time_varying(
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
        holding_period = holding_period,
        num_cores     = num_cores,
        seed          = i,
        intercept     = intercept,
        save_flag     = save_flag,
        verbose       = verbose,  # Show summary for each window
        fac_to_drop   = fac_to_drop,
        weighting     = weighting,
        drop_draws_pct = drop_draws_pct,
        self_pricing_engine = self_pricing_engine,
        parallel_type = parallel_type,
        cluster_timeout = cluster_timeout
      )
      
      
      # Store IS_AP directly in list
      # For forward mode: key by window_end (the expanding boundary)
      # For backward mode: key by window_start (the expanding boundary)
      date_key <- if (reverse_time) as.character(window_start) else as.character(window_end)
      IS_AP_list[[date_key]] <- IS_AP
      gc(verbose = FALSE)
      
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

      if (isTRUE(require_all_windows)) {
        stop(
          "Window ",
          i,
          " failed and require_all_windows=TRUE.\n",
          "Period: ",
          window_start,
          " to ",
          window_end,
          "\n",
          "Error: ",
          e$message,
          call. = FALSE
        )
      }
    })
  }
  
  ## =========================================================================
  ## 4. VALIDATE RESULTS
  ## =========================================================================
  
  # Calculate successful windows
  successful_windows <- setdiff(1:n_windows, failed_windows)
  
  if (length(IS_AP_list) == 0) {
    stop("All windows failed. Check error log: ", error_log_path)
  }
  
  if (length(failed_windows) > 0 && verbose) {
    log_msg("\nWARNING: ", length(failed_windows), " window(s) failed. See: ", error_log_path, "\n\n")
  }

  if (length(failed_windows) > 0 && isTRUE(require_all_windows)) {
    stop(
      "Time-varying estimation failed for ",
      length(failed_windows),
      " window(s); refusing to save a partial ALL_RESULTS.rds.\n",
      "Failed windows: ",
      paste(failed_windows, collapse = ", "),
      "\nSee error log: ",
      error_log_path
    )
  }
  
  if (verbose) {
    log_msg("Successfully collected ", length(IS_AP_list), " IS_AP objects\n\n")
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
  
  # Resolve absolute paths for metadata
  resolved_data_folder <- if (dir.exists(data_folder)) {
    normalizePath(data_folder, winslash = "/", mustWork = FALSE)
  } else {
    normalizePath(file.path(main_path, data_folder), winslash = "/", mustWork = FALSE)
  }
  
  resolved_output_folder <- if (dir.exists(output_folder)) {
    normalizePath(output_folder, winslash = "/", mustWork = FALSE)
  } else {
    normalizePath(file.path(main_path, output_folder), winslash = "/", mustWork = FALSE)
  }
  
  resolved_code_folder <- if (dir.exists(code_folder)) {
    normalizePath(code_folder, winslash = "/", mustWork = FALSE)
  } else {
    normalizePath(file.path(main_path, code_folder), winslash = "/", mustWork = FALSE)
  }
  run_completed_at <- Sys.time()
  
  combined_results$metadata <- list(
    # Paths (resolved absolute paths)
    paths = list(
      main_path      = normalizePath(main_path, winslash = "/", mustWork = FALSE),
      data_folder    = resolved_data_folder,
      output_folder  = resolved_output_folder,
      code_folder    = resolved_code_folder
    ),
    
    # Data files
    data_files = list(
      f1             = f1_input,
      f2             = f2_input,
      R              = R_input,
      fac_freq       = fac_freq_input,
      n_bond_factors = n_bond_factors
    ),
    
    # Model configuration
    model_type         = model_type,
    return_type        = return_type,
    
    # Time-varying parameters
    window_type        = window_type,
    reverse_time       = reverse_time,
    holding_period     = holding_period,
    initial_window     = initial_window,
    date_start         = date_start,
    date_end           = date_end,

    # MCMC parameters
    ndraws             = ndraws,
    alpha.w            = alpha.w,
    beta.w             = beta.w,
    SRscale            = SRscale,
    drop_draws_pct     = drop_draws_pct,
    
    # Additional parameters
    tag                = tag,
    intercept          = intercept,
    weighting          = weighting,
    self_pricing_engine = self_pricing_engine,
    parallel_type_requested = parallel_type,
    cluster_timeout     = cluster_timeout,
    require_all_windows = require_all_windows,
    kappa              = kappa,
    kappa_fac          = kappa_fac,
    seed               = seed,
    num_cores          = num_cores,
    verbose            = verbose,
    save_flag          = save_flag,
    fac_to_drop        = fac_to_drop,
    
    # Frequentist models
    frequentist_models = frequentist_models,
    
    # Estimation results summary
    n_windows_total    = n_windows,
    n_windows_success  = length(successful_windows),
    n_windows_failed   = length(failed_windows),
    failed_window_ids  = failed_windows,
    estimation_windows = window_schedule,
    run_started_at     = run_started_at,
    run_completed_at   = run_completed_at
  )
  
  ## =========================================================================
  ## 7. SAVE COMBINED RESULTS
  ## =========================================================================
  
  # Compute f1 flag for filenames
  f1_flag <- if (is.null(f1)) "FALSE" else "TRUE"
  
  saved_paths <- save_combined_results(
    combined_results = combined_results,
    output_dir       = model_output_dir,
    return_type      = return_type,
    model_type       = model_type,
    alpha.w          = alpha.w,
    beta.w           = beta.w,
    tag              = tag,
    holding_period   = holding_period,
    f1_flag          = f1_flag,
    reverse_time     = reverse_time,
    save_csv_flag    = save_csv_flag,
    verbose          = verbose,
    log_msg          = log_msg
  )

  attr(combined_results, "saved_paths") <- saved_paths
  attr(combined_results, "execution_log_path") <- exec_log_path
  
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
    log_msg("Results saved to : ", model_output_dir, "\n")
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
                                     holding_period, window_type,
                                     reverse_time = FALSE, verbose = TRUE,
                                     log_msg = cat) {

  library(lubridate)

  # Parse dates
  start_date <- as.Date(date_start)
  end_date   <- as.Date(date_end)

  ## =========================================================================
  ## FORWARD MODE (reverse_time = FALSE)
  ## Fix START at date_start, expand END forward
  ## Example: [1986→2004], [1986→2005], ..., [1986→2022]
  ## =========================================================================

  if (!reverse_time) {

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

    # Build window schedule (forward)
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

    # Subsequent windows (expanding END forward)
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

  } else {

    ## =========================================================================
    ## BACKWARD MODE (reverse_time = TRUE)
    ## Fix END at date_end, expand START backward
    ## Example: [2004→2022], [2003→2022], ..., [1986→2022]
    ## =========================================================================

    # Determine initial window START (counting backward from date_end)
    if (is.character(initial_window)) {
      # Parse date range format "YYYY-MM-DD:YYYY-MM-DD"
      parts <- strsplit(initial_window, ":")[[1]]
      initial_start <- as.Date(parts[1])
      initial_end   <- as.Date(parts[2])

      if (initial_start < start_date || initial_end > end_date) {
        stop("initial_window dates must be within date_start and date_end range")
      }
    } else {
      # Integer: count months BACKWARD from end_date
      initial_end   <- end_date
      initial_start <- end_date %m-% months(initial_window - 1)

      # Adjust to start of month (first day)
      initial_start <- floor_date(initial_start, "month")

      if (initial_start < start_date) {
        stop("initial_window (backward) extends before date_start")
      }
    }

    # Build window schedule (backward)
    windows <- data.frame(
      window_id  = integer(0),
      start_date = character(0),
      end_date   = character(0),
      stringsAsFactors = FALSE
    )

    current_start <- initial_start
    current_end   <- initial_end
    window_id     <- 1

    # First window (most recent data, smallest training window)
    windows <- rbind(windows, data.frame(
      window_id  = window_id,
      start_date = as.character(current_start),
      end_date   = as.character(current_end),
      stringsAsFactors = FALSE
    ))

    # Subsequent windows (expanding START backward, END fixed for expanding)
    while (TRUE) {
      # Calculate next window start (moving backward)
      next_start <- current_start %m-% months(holding_period)
      next_start <- floor_date(next_start, "month")

      # If we've reached or passed the earliest date
      if (next_start <= start_date) {
        # Include final window using all data from start_date
        if (current_start > start_date) {
          window_id <- window_id + 1
          next_end <- if (window_type == "rolling") {
            current_end %m-% months(holding_period)
          } else {
            initial_end  # expanding: keep original end
          }

          windows <- rbind(windows, data.frame(
            window_id  = window_id,
            start_date = as.character(start_date),
            end_date   = as.character(next_end),
            stringsAsFactors = FALSE
          ))
        }
        break
      }

      # Regular window
      window_id <- window_id + 1

      if (window_type == "rolling") {
        # Rolling: shift both start and end backward
        next_end <- current_end %m-% months(holding_period)
      } else {
        # Expanding: keep original end
        next_end <- initial_end
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
  }

  if (verbose) {
    direction_label <- if (reverse_time) "(backward)" else "(forward)"
    log_msg("Window schedule generated ", direction_label, ":\n")
    log_msg("  First window: ", windows$start_date[1], " to ", windows$end_date[1], "\n")
    log_msg("  Last window : ", windows$start_date[nrow(windows)], " to ", windows$end_date[nrow(windows)], "\n")
  }

  return(windows)
}



## =============================================================================
## HELPER FUNCTION: Stack Window Results into 5 Panel Datasets
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
  all_model_names <- unique(c(names(first_IS_AP$weights), names(first_IS_AP$lambdas)))
  
  # Helper function: Classify model type
  classify_model_type <- function(model_name) {
    if (grepl("^BMA-", model_name)) {
      return("BMA")
    } else if (grepl("^Top-MPR-", model_name)) {
      return("Top-MPR")
    } else if (grepl("^Top-", model_name)) {
      return("Top")
    } else if (model_name == "RP-PCA") {
      return("RP-PCA")
    } else if (model_name == "RP-PCAf2") {
      return("RP-PCAf2")
    } else if (model_name == "PCA") {
      return("PCA")
    } else if (model_name == "PCAf2") {
      return("PCAf2")
    } else if (model_name == "KNS") {
      return("KNS")
    } else if (model_name == "KNSf2") {
      return("KNSf2")
    } else if (model_name == "Tangency") {
      return("Optimal")
    } else if (model_name == "MinVar") {
      return("Optimal")
    } else if (model_name == "EqualWeight") {
      return("Optimal")
    } else {
      return("Frequentist")
    }
  }
  
  # Helper function: Extract psi_level
  extract_psi_level <- function(model_name) {
    if (grepl("^(BMA|Top|Top-MPR)-(\\d+)%", model_name)) {
      return(as.numeric(sub("^(BMA|Top|Top-MPR)-(\\d+)%.*", "\\2", model_name)) / 100)
    } else {
      return(1)  # Non-BMA/Top models get psi_level = 1
    }
  }
  
  # Helper function: Safe factor renaming for PC-based models
  safe_factor_names <- function(factor_names_or_count, model_name) {
    # If factor_names_or_count is numeric, treat it as count
    if (is.numeric(factor_names_or_count) && length(factor_names_or_count) == 1) {
      n <- factor_names_or_count
    } else {
      n <- length(factor_names_or_count)
    }
    
    if (grepl("^KNS", model_name)) {
      # KNS models: rename to KNS_PC1, KNS_PC2, etc.
      return(paste0("KNS_PC", seq_len(n)))
    } else if (grepl("^RP-PCA", model_name)) {
      # RP-PCA models: rename to RPPCA_PC1, RPPCA_PC2, etc.
      return(paste0("RPPCA_PC", seq_len(n)))
    } else if (grepl("^PCA", model_name)) {
      # PCA models: rename to PCA_PC1, PCA_PC2, etc.
      return(paste0("PCA_PC", seq_len(n)))
    } else {
      # Keep original names
      if (is.numeric(factor_names_or_count) && length(factor_names_or_count) == 1) {
        return(paste0("Factor", seq_len(n)))
      } else {
        return(factor_names_or_count)
      }
    }
  }
  
  ## -------------------------------------------------------------------------
  ## PANEL 1: Weights Only
  ## Columns: date, model, model_type, psi_level, factor, weight
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Building Panel 1: Weights...\n")
  
  weights_panel_list <- list()
  
  # Get models that have weights
  models_with_weights <- names(first_IS_AP$weights)
  
  for (model_name in models_with_weights) {
    
    model_type_str <- classify_model_type(model_name)
    psi_level_val <- extract_psi_level(model_name)
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      current_date <- dates[i]
      
      weights_mat <- IS_AP_list[[date_label]]$weights[[model_name]]
      
      # Skip if no weights data
      if (is.null(weights_mat) || ncol(weights_mat) == 0) next
      
      # Preserve column names BEFORE dropping (critical for 1x1 matrices)
      col_names <- colnames(weights_mat)
      
      # Extract as vector
      weights_vec <- drop(weights_mat)
      
      # Use preserved column names (handles 1x1 case where drop() loses names)
      factor_names <- col_names
      
      # Handle missing or empty names (should not happen for weights, but be defensive)
      if (is.null(factor_names) || length(factor_names) == 0) next
      
      # Filter out empty-string names, NA names, and intercept
      valid_idx <- nzchar(factor_names) & !is.na(factor_names) & factor_names != "(Intercept)"
      if (!any(valid_idx)) next
      
      weights_vec <- weights_vec[valid_idx]
      factor_names <- factor_names[valid_idx]
      
      # DO NOT RENAME - use original asset names for weights
      # (PC renaming is ONLY for lambdas, not weights)
      
      # Build rows for this model/date
      weight_rows <- data.frame(
        date = current_date,
        model = model_name,
        model_type = model_type_str,
        psi_level = psi_level_val,
        factor = factor_names,
        weight = as.numeric(weights_vec),
        stringsAsFactors = FALSE
      )
      
      weights_panel_list[[length(weights_panel_list) + 1]] <- weight_rows
    }
  }
  
  # Combine all rows
  weights_panel <- if (length(weights_panel_list) > 0) {
    df <- do.call(rbind, weights_panel_list)
    rownames(df) <- NULL
    df
  } else {
    data.frame(date = as.Date(character()), model = character(), 
               model_type = character(), psi_level = numeric(),
               factor = character(), weight = numeric(),
               stringsAsFactors = FALSE)[0, ]
  }
  
  if (verbose) log_msg("Panel 1 built: ", nrow(weights_panel), " rows\n")
  
  ## -------------------------------------------------------------------------
  ## PANEL 2: f2-only Lambdas (Main Lambdas Panel)
  ## Columns: date, model, model_type, psi_level, factor, lambda, scaled_lambda
  ## Excludes: Top-*-All and Top-MPR-*-All models
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Building Panel 2: f2-only Lambdas...\n")
  
  lambdas_panel_list <- list()
  
  # Get models that have lambdas, excluding "-All" suffix models
  models_for_lambdas <- names(first_IS_AP$lambdas)
  models_for_lambdas <- models_for_lambdas[!grepl("-All$", models_for_lambdas)]
  
  for (model_name in models_for_lambdas) {
    
    model_type_str <- classify_model_type(model_name)
    psi_level_val <- extract_psi_level(model_name)
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      current_date <- dates[i]
      
      lambdas_mat <- IS_AP_list[[date_label]]$lambdas[[model_name]]
      scaled_lambdas_mat <- IS_AP_list[[date_label]]$scaled_lambdas[[model_name]]
      
      # Skip if no data
      if (is.null(lambdas_mat) || ncol(lambdas_mat) == 0) next
      
      # Extract as vectors with names
      lambdas_vec <- drop(lambdas_mat)
      scaled_lambdas_vec <- if (!is.null(scaled_lambdas_mat) && ncol(scaled_lambdas_mat) > 0) {
        drop(scaled_lambdas_mat)
      } else {
        rep(NA_real_, length(lambdas_vec))
      }
      
      # Get factor names - handle missing/numeric names for KNS/RP-PCA/PCA
      factor_names <- names(lambdas_vec)
      
      # If names are missing or not informative, assign PC names
      if (is.null(factor_names) || length(factor_names) == 0 || 
          all(factor_names == "") || all(is.na(factor_names))) {
        # Assign PC names based on model type and vector length
        factor_names <- safe_factor_names(length(lambdas_vec), model_name)
        names(lambdas_vec) <- factor_names
        names(scaled_lambdas_vec) <- factor_names
      } else {
        # Apply safe renaming for PC-based models
        factor_names <- safe_factor_names(factor_names, model_name)
      }
      
      # Filter out empty-string names, NA names, and intercept
      valid_idx <- nzchar(factor_names) & !is.na(factor_names) & factor_names != "(Intercept)"
      if (!any(valid_idx)) next
      
      lambdas_vec <- lambdas_vec[valid_idx]
      scaled_lambdas_vec <- scaled_lambdas_vec[valid_idx]
      factor_names <- factor_names[valid_idx]
      
      # Build rows for this model/date
      lambda_rows <- data.frame(
        date = current_date,
        model = model_name,
        model_type = model_type_str,
        psi_level = psi_level_val,
        factor = factor_names,
        lambda = as.numeric(lambdas_vec),
        scaled_lambda = as.numeric(scaled_lambdas_vec),
        stringsAsFactors = FALSE
      )
      
      lambdas_panel_list[[length(lambdas_panel_list) + 1]] <- lambda_rows
    }
  }
  
  # Combine all rows
  lambdas_panel <- if (length(lambdas_panel_list) > 0) {
    df <- do.call(rbind, lambdas_panel_list)
    rownames(df) <- NULL
    df
  } else {
    data.frame(date = as.Date(character()), model = character(),
               model_type = character(), psi_level = numeric(),
               factor = character(), lambda = numeric(), scaled_lambda = numeric(),
               stringsAsFactors = FALSE)[0, ]
  }
  
  if (verbose) log_msg("Panel 2 built: ", nrow(lambdas_panel), " rows\n")
  
  ## -------------------------------------------------------------------------
  ## PANEL 3: All-factor Lambdas (Top models only)
  ## Columns: date, model, model_type, psi_level, factor, lambda, scaled_lambda
  ## Includes ONLY: Top-*-All and Top-MPR-*-All models
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Building Panel 3: All-factor Lambdas (Top models only)...\n")
  
  lambdas_all_panel_list <- list()
  
  # Get models that have "-All" suffix
  models_for_lambdas_all <- names(first_IS_AP$lambdas)
  models_for_lambdas_all <- models_for_lambdas_all[grepl("-All$", models_for_lambdas_all)]
  
  for (model_name in models_for_lambdas_all) {
    
    model_type_str <- classify_model_type(model_name)
    psi_level_val <- extract_psi_level(model_name)
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      current_date <- dates[i]
      
      lambdas_mat <- IS_AP_list[[date_label]]$lambdas[[model_name]]
      scaled_lambdas_mat <- IS_AP_list[[date_label]]$scaled_lambdas[[model_name]]
      
      # Skip if no data
      if (is.null(lambdas_mat) || ncol(lambdas_mat) == 0) next
      
      # Extract as vectors with names
      lambdas_vec <- drop(lambdas_mat)
      scaled_lambdas_vec <- if (!is.null(scaled_lambdas_mat) && ncol(scaled_lambdas_mat) > 0) {
        drop(scaled_lambdas_mat)
      } else {
        rep(NA_real_, length(lambdas_vec))
      }
      
      # Get factor names
      factor_names <- names(lambdas_vec)
      
      # If names are missing, this shouldn't happen for -All models, but handle it
      if (is.null(factor_names) || length(factor_names) == 0 || 
          all(factor_names == "") || all(is.na(factor_names))) {
        warning("Missing factor names for model: ", model_name)
        next
      }
      
      # Filter out empty-string names, NA names, and intercept
      valid_idx <- nzchar(factor_names) & !is.na(factor_names) & factor_names != "(Intercept)"
      if (!any(valid_idx)) next
      
      lambdas_vec <- lambdas_vec[valid_idx]
      scaled_lambdas_vec <- scaled_lambdas_vec[valid_idx]
      factor_names <- factor_names[valid_idx]
      
      # Build rows for this model/date
      lambda_all_rows <- data.frame(
        date = current_date,
        model = model_name,
        model_type = model_type_str,
        psi_level = psi_level_val,
        factor = factor_names,
        lambda = as.numeric(lambdas_vec),
        scaled_lambda = as.numeric(scaled_lambdas_vec),
        stringsAsFactors = FALSE
      )
      
      lambdas_all_panel_list[[length(lambdas_all_panel_list) + 1]] <- lambda_all_rows
    }
  }
  
  # Combine all rows
  lambdas_all_panel <- if (length(lambdas_all_panel_list) > 0) {
    df <- do.call(rbind, lambdas_all_panel_list)
    rownames(df) <- NULL
    df
  } else {
    data.frame(date = as.Date(character()), model = character(),
               model_type = character(), psi_level = numeric(),
               factor = character(), lambda = numeric(), scaled_lambda = numeric(),
               stringsAsFactors = FALSE)[0, ]
  }
  
  if (verbose) log_msg("Panel 3 built: ", nrow(lambdas_all_panel), " rows\n")
  
  ## -------------------------------------------------------------------------
  ## PANEL 4: Gammas (BMA only - unchanged from original)
  ## Columns: date, factor, psi_level, prob
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Building Panel 4: Gammas...\n")
  
  gammas_panel_list <- list()
  
  # Only process BMA models
  bma_models <- grep("^BMA-", names(first_IS_AP$gammas), value = TRUE)
  
  for (model_name in bma_models) {
    
    psi_level_val <- extract_psi_level(model_name)
    
    for (i in seq_along(dates)) {
      date_label <- date_labels[i]
      current_date <- dates[i]
      
      gamma_mat <- IS_AP_list[[date_label]]$gammas[[model_name]]
      
      if (is.null(gamma_mat) || ncol(gamma_mat) == 0) next
      
      # Extract as vector with names
      gamma_vec <- drop(gamma_mat)
      
      # Filter out empty-string names
      valid_idx <- nzchar(names(gamma_vec))
      if (!any(valid_idx)) next
      
      gamma_vec <- gamma_vec[valid_idx]
      factor_names <- names(gamma_vec)
      
      # Build rows
      gamma_rows <- data.frame(
        date = current_date,
        factor = factor_names,
        psi_level = psi_level_val,
        prob = as.numeric(gamma_vec),
        stringsAsFactors = FALSE
      )
      
      gammas_panel_list[[length(gammas_panel_list) + 1]] <- gamma_rows
    }
  }
  
  # Combine all rows
  gammas_panel <- if (length(gammas_panel_list) > 0) {
    df <- do.call(rbind, gammas_panel_list)
    rownames(df) <- NULL
    df
  } else {
    data.frame(date = as.Date(character()), factor = character(),
               psi_level = numeric(), prob = numeric(),
               stringsAsFactors = FALSE)[0, ]
  }
  
  if (verbose) log_msg("Panel 4 built: ", nrow(gammas_panel), " rows\n")
  
  ## -------------------------------------------------------------------------
  ## PANEL 5: Top Factors (both f2-only and all-factors)
  ## Columns: date, top_type, factor_set, psi_level, rank, factor
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Building Panel 5: Top Factors (both f2 and all)...\n")
  
  top_factors_panel_list <- list()
  
  for (i in seq_along(dates)) {
    date_label <- date_labels[i]
    current_date <- dates[i]
    
    # Process top_factors (f2-only)
    top_factors_list <- IS_AP_list[[date_label]]$top_factors
    if (!is.null(top_factors_list)) {
      for (psi_idx in 1:4) {
        psi_level_val <- c(0.20, 0.40, 0.60, 0.80)[psi_idx]
        top_facs <- top_factors_list[[psi_idx]]
        
        if (!is.null(top_facs) && length(top_facs) > 0) {
          rows <- data.frame(
            date = current_date,
            top_type = "top_prob",
            factor_set = "f2_only",
            psi_level = psi_level_val,
            rank = seq_along(top_facs),
            factor = top_facs,
            stringsAsFactors = FALSE
          )
          top_factors_panel_list[[length(top_factors_panel_list) + 1]] <- rows
        }
      }
    }
    
    # Process top_factors_all (all factors)
    top_factors_all_list <- IS_AP_list[[date_label]]$top_factors_all
    if (!is.null(top_factors_all_list)) {
      for (psi_idx in 1:4) {
        psi_level_val <- c(0.20, 0.40, 0.60, 0.80)[psi_idx]
        top_facs <- top_factors_all_list[[psi_idx]]
        
        if (!is.null(top_facs) && length(top_facs) > 0) {
          rows <- data.frame(
            date = current_date,
            top_type = "top_prob",
            factor_set = "all_factors",
            psi_level = psi_level_val,
            rank = seq_along(top_facs),
            factor = top_facs,
            stringsAsFactors = FALSE
          )
          top_factors_panel_list[[length(top_factors_panel_list) + 1]] <- rows
        }
      }
    }
    
    # Process top_mpr_factors (f2-only)
    top_mpr_factors_list <- IS_AP_list[[date_label]]$top_mpr_factors
    if (!is.null(top_mpr_factors_list)) {
      for (psi_idx in 1:4) {
        psi_level_val <- c(0.20, 0.40, 0.60, 0.80)[psi_idx]
        top_facs <- top_mpr_factors_list[[psi_idx]]
        
        if (!is.null(top_facs) && length(top_facs) > 0) {
          rows <- data.frame(
            date = current_date,
            top_type = "top_mpr",
            factor_set = "f2_only",
            psi_level = psi_level_val,
            rank = seq_along(top_facs),
            factor = top_facs,
            stringsAsFactors = FALSE
          )
          top_factors_panel_list[[length(top_factors_panel_list) + 1]] <- rows
        }
      }
    }
    
    # Process top_mpr_factors_all (all factors)
    top_mpr_factors_all_list <- IS_AP_list[[date_label]]$top_mpr_factors_all
    if (!is.null(top_mpr_factors_all_list)) {
      for (psi_idx in 1:4) {
        psi_level_val <- c(0.20, 0.40, 0.60, 0.80)[psi_idx]
        top_facs <- top_mpr_factors_all_list[[psi_idx]]
        
        if (!is.null(top_facs) && length(top_facs) > 0) {
          rows <- data.frame(
            date = current_date,
            top_type = "top_mpr",
            factor_set = "all_factors",
            psi_level = psi_level_val,
            rank = seq_along(top_facs),
            factor = top_facs,
            stringsAsFactors = FALSE
          )
          top_factors_panel_list[[length(top_factors_panel_list) + 1]] <- rows
        }
      }
    }
  }
  
  # Combine all rows
  top_factors_panel <- if (length(top_factors_panel_list) > 0) {
    df <- do.call(rbind, top_factors_panel_list)
    rownames(df) <- NULL
    df
  } else {
    data.frame(date = as.Date(character()), top_type = character(),
               factor_set = character(), psi_level = numeric(),
               rank = integer(), factor = character(),
               stringsAsFactors = FALSE)[0, ]
  }
  
  if (verbose) log_msg("Panel 5 built: ", nrow(top_factors_panel), " rows\n")
  
  ## -------------------------------------------------------------------------
  ## Return All Panels
  ## -------------------------------------------------------------------------
  
  if (verbose) log_msg("Panel construction complete.\n\n")
  
  return(list(
    weights_panel = weights_panel,           # Panel 1: weights only
    lambdas_panel = lambdas_panel,           # Panel 2: f2-only lambdas
    lambdas_all_panel = lambdas_all_panel,   # Panel 3: all-factor lambdas (Top only)
    gammas_panel = gammas_panel,             # Panel 4: BMA gammas
    top_factors_panel = top_factors_panel    # Panel 5: top factors (both f2 and all)
  ))
}



## =============================================================================
## HELPER FUNCTION: Save Combined Panel Results
## =============================================================================

save_combined_results <- function(combined_results, output_dir, return_type,
                                  model_type, alpha.w, beta.w, tag,
                                  holding_period, f1_flag, reverse_time = FALSE,
                                  save_csv_flag = FALSE,
                                  verbose = TRUE, log_msg = cat) {

  if (verbose) {
    log_msg("=====================================\n")
    log_msg("SAVING PANEL RESULTS\n")
    log_msg("=====================================\n\n")
  }

  saved_paths <- list()

  # Base filename pattern (add _backward suffix if reverse_time = TRUE)
  direction_suffix <- if (reverse_time) "_backward" else ""
  base_pattern <- sprintf(
    "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s_holding_period=%d_f1=%s%s",
    return_type, model_type, trunc(alpha.w), trunc(beta.w), tag,
    holding_period, f1_flag, direction_suffix
  )
  
  ## -------------------------------------------------------------------------
  ## 1. Save Weights Panel as CSV
  ## -------------------------------------------------------------------------
  
  if (save_csv_flag) {
    if (verbose) log_msg("Saving weights panel CSV...\n")
    
    fname_weights <- paste0(base_pattern, "_weights_panel.csv")
    fpath_weights <- file.path(output_dir, fname_weights)
    
    write.csv(combined_results$weights_panel, file = fpath_weights, row.names = FALSE)
    saved_paths$weights_panel <- fpath_weights
    
    if (verbose) log_msg("  ", fname_weights, "\n")
    if (verbose) log_msg("  (", nrow(combined_results$weights_panel), " rows)\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 2. Save f2-only Lambdas Panel as CSV
  ## -------------------------------------------------------------------------
  
  if (save_csv_flag) {
    if (verbose) log_msg("\nSaving f2-only lambdas panel CSV...\n")
    
    fname_lambdas <- paste0(base_pattern, "_lambdas_panel.csv")
    fpath_lambdas <- file.path(output_dir, fname_lambdas)
    
    write.csv(combined_results$lambdas_panel, file = fpath_lambdas, row.names = FALSE)
    saved_paths$lambdas_panel <- fpath_lambdas
    
    if (verbose) log_msg("  ", fname_lambdas, "\n")
    if (verbose) log_msg("  (", nrow(combined_results$lambdas_panel), " rows)\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 3. Save All-factor Lambdas Panel as CSV (Top models only)
  ## -------------------------------------------------------------------------
  
  if (save_csv_flag) {
    if (verbose) log_msg("\nSaving all-factor lambdas panel CSV (Top models only)...\n")
    
    fname_lambdas_all <- paste0(base_pattern, "_lambdas_all_panel.csv")
    fpath_lambdas_all <- file.path(output_dir, fname_lambdas_all)
    
    write.csv(combined_results$lambdas_all_panel, file = fpath_lambdas_all, row.names = FALSE)
    saved_paths$lambdas_all_panel <- fpath_lambdas_all
    
    if (verbose) log_msg("  ", fname_lambdas_all, "\n")
    if (verbose) log_msg("  (", nrow(combined_results$lambdas_all_panel), " rows)\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 4. Save Gammas Panel as CSV
  ## -------------------------------------------------------------------------
  
  if (save_csv_flag) {
    if (verbose) log_msg("\nSaving gammas panel CSV...\n")
    
    fname_gammas <- paste0(base_pattern, "_gammas_panel.csv")
    fpath_gammas <- file.path(output_dir, fname_gammas)
    
    write.csv(combined_results$gammas_panel, file = fpath_gammas, row.names = FALSE)
    saved_paths$gammas_panel <- fpath_gammas
    
    if (verbose) log_msg("  ", fname_gammas, "\n")
    if (verbose) log_msg("  (", nrow(combined_results$gammas_panel), " rows)\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 5. Save Top Factors Panel as CSV
  ## -------------------------------------------------------------------------
  
  if (save_csv_flag) {
    if (verbose) log_msg("\nSaving top factors panel CSV...\n")
    
    fname_top <- paste0(base_pattern, "_top_factors_panel.csv")
    fpath_top <- file.path(output_dir, fname_top)
    
    write.csv(combined_results$top_factors_panel, file = fpath_top, row.names = FALSE)
    saved_paths$top_factors_panel <- fpath_top
    
    if (verbose) log_msg("  ", fname_top, "\n")
    if (verbose) log_msg("  (", nrow(combined_results$top_factors_panel), " rows)\n")
  }
  
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
    if (save_csv_flag) {
      log_msg("\nAll 5 panel CSVs + RDS saved to: ", output_dir, "\n")
    } else {
      log_msg("\nRDS results saved to: ", output_dir, "\n")
    }
    log_msg("=====================================\n\n")
  }
  
  invisible(saved_paths)
}
