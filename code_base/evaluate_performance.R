#' Evaluate Out-of-Sample Performance of Time-Varying Models
#'
#' Computes out-of-sample portfolio returns using estimated weights from
#' time-varying estimation. Applies weights at time t to returns over t+1
#' through t+holding_period.
#'
#' @param combined_results List returned by run_time_varying_estimation()
#'                        containing weights_panel, metadata, etc.
#' @param main_path       Project root path (temporary - will move to metadata)
#' @param data_folder     Data subfolder (temporary - will move to metadata)
#' @param f2              File name(s) for traded factors (temporary)
#' @param R               File name(s) for test assets (temporary)
#' @param fac_freq        File name for frequentist factors (temporary)
#' @param verbose         Print progress messages?
#'
#' @return data.frame with columns:
#'   - date: Return date (t+1, t+2, ..., t+holding_period)
#'   - One column per model containing out-of-sample returns
#'
#' @details
#' Model-specific data sources:
#'   - BMA, TOP, Optimal: f2 only
#'   - Frequentist: fac_freq
#'   - RP-PCA, PCA, KNS: R + f2 combined
#'   - RP-PCAf2, PCAf2, KNSf2: f2 only
#'
#' IMPORTANT: For PC-based models (RP-PCA, PCA, KNS), weights must be for
#' investable assets, not principal components. If weights are for PCs,
#' they need to be transformed to asset weights using PC loadings during
#' the estimation phase. Column names in weights_panel must match column
#' names in the data files.

evaluate_performance <- function(
    combined_results,
    # Temporary parameters (will be extracted from metadata in future)
    main_path   = NULL,
    data_folder = NULL,
    f2          = NULL,
    R           = NULL,
    fac_freq    = NULL,
    vol_scale   = "MKTS",
    # Plot parameters
    factor_vec       = NULL,
    color_vec        = NULL,
    line_types_vec   = NULL,
    legend_position  = c(0.02, 0.98),
    dollar_step      = 50,
    fig_name         = "oos_cumret.pdf",
    fig_width        = 12,
    fig_height       = 7,
    verbose     = TRUE
) {
  
  library(dplyr)
  library(lubridate)
  library(xtable)
  
  ## -------------------------------------------------------------------------
  ## 1. Extract Metadata and Validate
  ## -------------------------------------------------------------------------
  
  if (!"metadata" %in% names(combined_results)) {
    stop("combined_results must contain 'metadata' element")
  }
  
  metadata <- combined_results$metadata
  holding_period <- metadata$holding_period
  
  if (verbose) {
    cat("\n")
    cat("=====================================\n")
    cat("OUT-OF-SAMPLE PERFORMANCE EVALUATION\n")
    cat("=====================================\n\n")
    cat("Holding period: ", holding_period, " months\n")
    cat("Analysis period: ", metadata$date_start, " to ", metadata$date_end, "\n\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 2. Future-Proof: Check Metadata for File Paths (Not Yet Implemented)
  ## -------------------------------------------------------------------------
  
  # TODO: Once metadata contains file names, use them as defaults
  if (is.null(f2) && !is.null(metadata$f2_files)) {
    f2 <- metadata$f2_files
    if (verbose) cat("Using f2 files from metadata\n")
  }
  
  if (is.null(R) && !is.null(metadata$R_files)) {
    R <- metadata$R_files
    if (verbose) cat("Using R files from metadata\n")
  }
  
  if (is.null(fac_freq) && !is.null(metadata$fac_freq_file)) {
    fac_freq <- metadata$fac_freq_file
    if (verbose) cat("Using fac_freq file from metadata\n")
  }
  
  if (is.null(main_path) && !is.null(metadata$main_path)) {
    main_path <- metadata$main_path
  }
  
  if (is.null(data_folder) && !is.null(metadata$data_folder)) {
    data_folder <- metadata$data_folder
  }
  
  # Validate required parameters
  if (is.null(main_path)) stop("main_path must be provided")
  if (is.null(data_folder)) stop("data_folder must be provided")
  if (is.null(f2)) stop("f2 file name(s) must be provided")
  if (is.null(R)) stop("R file name(s) must be provided")
  if (is.null(fac_freq)) stop("fac_freq file name must be provided")
  
  ## -------------------------------------------------------------------------
  ## 3. Setup Path Helpers
  ## -------------------------------------------------------------------------
  
  data_path <- if (dir.exists(data_folder)) {
    data_folder
  } else {
    file.path(main_path, data_folder)
  }
  
  if (!dir.exists(data_path)) {
    stop("data_folder does not exist: ", data_path)
  }
  
  path_data <- function(file) file.path(data_path, file)
  
  ## -------------------------------------------------------------------------
  ## 4. Load Asset Return Data Using Safe Merging
  ## -------------------------------------------------------------------------
  
  if (verbose) cat("Loading asset return data...\n")
  
  # Check if required helper functions exist
  if (!exists("load_and_combine_files", mode = "function")) {
    stop("Function 'load_and_combine_files' not found. Please source data_loading_helpers.R")
  }
  if (!exists("validate_and_align_dates", mode = "function")) {
    stop("Function 'validate_and_align_dates' not found. Please source validate_and_align_dates.R")
  }
  
  # Load f2, R, and fac_freq using existing helper
  # This handles multi-file mode and date parsing automatically
  # CRITICAL: load_and_combine_files uses MERGE internally, preserving all column names
  f2_data <- load_and_combine_files(f2, path_data, "f2", verbose = verbose)
  R_data <- load_and_combine_files(R, path_data, "R", verbose = verbose)
  fac_freq_data <- load_and_combine_files(fac_freq, path_data, "fac_freq", verbose = verbose)
  
  # Validate and align all three datasets to common dates
  # This uses merge internally and preserves all column names exactly
  aligned <- validate_and_align_dates(
    data_list = list(
      f2 = f2_data,
      R = R_data,
      fac_freq = fac_freq_data
    ),
    date_start = NULL,  # Use full data range
    date_end = NULL,
    verbose = FALSE
  )
  
  # Extract aligned data (these are data.frames with date column)
  f2_aligned <- aligned$data$f2
  R_aligned <- aligned$data$R
  fac_freq_aligned <- aligned$data$fac_freq
  
  # Create combined R + f2 dataset for RP-PCA, PCA, KNS models
  # Use MERGE to preserve all column names exactly
  Rc_aligned <- merge(R_aligned, f2_aligned, by = "date", all = FALSE, sort = TRUE)
  
  # Verify merge worked correctly
  if (nrow(Rc_aligned) != nrow(R_aligned)) {
    stop("Merge of R and f2 failed - row counts don't match after merge")
  }
  
  # Convert to matrices (excluding date column) and extract dates
  f2_returns <- as.matrix(f2_aligned[, -1, drop = FALSE])
  f2_dates <- f2_aligned$date
  
  R_returns <- as.matrix(R_aligned[, -1, drop = FALSE])
  R_dates <- R_aligned$date
  
  fac_freq_returns <- as.matrix(fac_freq_aligned[, -1, drop = FALSE])
  fac_freq_dates <- fac_freq_aligned$date
  
  Rc_returns <- as.matrix(Rc_aligned[, -1, drop = FALSE])
  Rc_dates <- Rc_aligned$date
  
  if (verbose) {
    cat("  Aligned data period: ", aligned$date_range["start"], " to ", 
        aligned$date_range["end"], "\n")
    cat("  f2: ", nrow(f2_aligned), " dates x ", ncol(f2_returns), " factors\n")
    cat("  R: ", nrow(R_aligned), " dates x ", ncol(R_returns), " assets\n")
    cat("  fac_freq: ", nrow(fac_freq_aligned), " dates x ", ncol(fac_freq_returns), " factors\n")
    cat("  Rc (R+f2 merged): ", nrow(Rc_aligned), " dates x ", ncol(Rc_returns), " columns\n")
    cat("  Sample f2 columns: ", paste(head(colnames(f2_returns), 5), collapse = ", "), "\n")
    cat("  Sample R columns: ", paste(head(colnames(R_returns), 5), collapse = ", "), "\n")
    cat("  Sample Rc columns: ", paste(head(colnames(Rc_returns), 10), collapse = ", "), "\n\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 5. Extract Weights Panel
  ## -------------------------------------------------------------------------
  
  df_weights <- combined_results$weights_panel
  
  if (verbose) {
    cat("Weights panel: ", nrow(df_weights), " rows\n")
    cat("Unique models: ", length(unique(df_weights$model)), "\n")
    cat("Unique dates: ", length(unique(df_weights$date)), "\n")
    
    # Diagnostic: Show sample factor names in weights_panel
    sample_factors <- unique(df_weights$factor)[1:min(10, length(unique(df_weights$factor)))]
    cat("Sample factors in weights: ", paste(sample_factors, collapse = ", "), "\n\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 6. Helper Function: Determine Data Source for Each Model
  ## -------------------------------------------------------------------------
  
  get_model_data <- function(model_name) {
    # Use exact matching for specific models, pattern matching only for BMA/Top variants
    
    # BMA models (all psi levels)
    if (grepl("^BMA-", model_name)) {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    
    # Top models (both regular and MPR, all psi levels)
    if (grepl("^Top-", model_name)) {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    
    # Exact matches for PC-based models (order matters: check f2-only versions first)
    if (model_name == "RP-PCAf2") {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (model_name == "RP-PCA") {
      return(list(returns = Rc_returns, dates = Rc_dates, name = "Rc"))
    }
    
    if (model_name == "PCAf2") {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (model_name == "PCA") {
      return(list(returns = Rc_returns, dates = Rc_dates, name = "Rc"))
    }
    
    if (model_name == "KNSf2") {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (model_name == "KNS") {
      return(list(returns = Rc_returns, dates = Rc_dates, name = "Rc"))
    }
    
    # Other specific models that use f2
    if (model_name %in% c("Tangency", "MinVar", "EqualWeight", "Optimal")) {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    
    # Default: assume it's a frequentist model (FF5, CAPM, etc.)
    return(list(returns = fac_freq_returns, dates = fac_freq_dates, name = "fac_freq"))
  }
  
  ## -------------------------------------------------------------------------
  ## 7. Compute Out-of-Sample Returns
  ## -------------------------------------------------------------------------
  
  if (verbose) cat("Computing out-of-sample portfolio returns...\n")
  
  # Get unique models and dates
  unique_models <- unique(df_weights$model)
  unique_weight_dates <- sort(unique(df_weights$date))
  
  # Ensure weight dates are Date objects
  if (!inherits(unique_weight_dates, "Date")) {
    unique_weight_dates <- as.Date(unique_weight_dates)
  }
  
  # Initialize storage: list of data.frames (one per model)
  oos_results_list <- list()
  
  for (model_name in unique_models) {
    
    if (verbose) cat("  Processing model: ", model_name, "\n")
    
    # Get appropriate data source for this model
    model_data <- get_model_data(model_name)
    returns_matrix <- model_data$returns
    returns_dates <- model_data$dates
    asset_names <- colnames(returns_matrix)
    
    # Diagnostic: Show first few asset names for this model
    if (verbose && length(unique_models) <= 5) {  # Only for small number of models
      cat("    Data source: ", model_data$name, " (", length(asset_names), " assets)\n")
      cat("    Sample assets: ", paste(head(asset_names, 5), collapse = ", "), "\n")
    }
    
    # Filter weights for this model
    model_weights <- df_weights %>%
      filter(model == model_name) %>%
      arrange(date)
    
    # Ensure model_weights date is Date class
    if (!inherits(model_weights$date, "Date")) {
      model_weights$date <- as.Date(model_weights$date)
    }
    
    # Initialize result storage for this model
    model_oos_returns <- list()
    
    # For each weight date
    for (i in seq_along(unique_weight_dates)) {
      
      weight_date <- unique_weight_dates[i]
      
      # Get weights at this date (use direct indexing to avoid filter issues)
      wts_at_date <- model_weights[model_weights$date == weight_date, ]
      
      if (nrow(wts_at_date) == 0) next
      
      # Create weight vector (named)
      weight_vec <- setNames(wts_at_date$weight, wts_at_date$factor)
      
      # Validate all factors exist in asset universe
      missing_factors <- setdiff(names(weight_vec), asset_names)
      if (length(missing_factors) > 0) {
        missing_pct <- length(missing_factors) / length(weight_vec) * 100
        
        # If more than 90% of factors are missing, skip this model (likely data issue)
        if (missing_pct > 90) {
          if (verbose) {
            cat("    ERROR: Skipping model at ", format(weight_date, "%Y-%m-%d"), 
                " - ", round(missing_pct, 1), "% of factors missing\n")
          }
          next
        }
        
        if (verbose) {
          cat("    WARNING: ", round(missing_pct, 1), "% of factors missing at ", 
              format(weight_date, "%Y-%m-%d"), " (", length(missing_factors), " factors)\n")
          cat("      Sample missing: ", paste(head(missing_factors, 5), collapse = ", "), "\n")
        }
        
        # Remove missing factors and renormalize weights
        weight_vec <- weight_vec[names(weight_vec) %in% asset_names]
        if (length(weight_vec) > 0) {
          weight_vec <- weight_vec / sum(weight_vec)  # Renormalize to sum to 1
        }
      }
      
      if (length(weight_vec) == 0) {
        warning("Model ", model_name, " at ", weight_date, ": no valid weights")
        next
      }
      
      # Find return dates from t+1 to t+holding_period
      # t+1 is the first month after weight_date
      weight_date_obj <- as.Date(weight_date, origin = "1970-01-01")
      return_start_date <- weight_date_obj %m+% months(1)
      return_end_date <- weight_date_obj %m+% months(holding_period)
      
      # Get indices for these return dates
      return_period_idx <- which(returns_dates >= return_start_date & 
                                   returns_dates <= return_end_date)
      
      if (length(return_period_idx) == 0) {
        # No return data available for this holding period
        next
      }
      
      # For each month in the holding period, compute portfolio return
      for (ret_idx in return_period_idx) {
        
        ret_date <- returns_dates[ret_idx]
        ret_row <- returns_matrix[ret_idx, , drop = FALSE]
        
        # Extract returns for factors in weight vector (in same order)
        factor_returns <- ret_row[1, names(weight_vec)]
        
        # Check for missing returns
        if (any(is.na(factor_returns))) {
          warning("Model ", model_name, " at ", ret_date, 
                  ": NA returns for some factors")
          factor_returns[is.na(factor_returns)] <- 0
        }
        
        # Compute portfolio return: sum of weight * return
        portfolio_return <- sum(weight_vec * factor_returns)
        
        # Store result
        model_oos_returns[[length(model_oos_returns) + 1]] <- data.frame(
          date = ret_date,
          weight_date = as.Date(weight_date, origin = "1970-01-01"),
          return = portfolio_return,
          stringsAsFactors = FALSE
        )
      }
    }
    
    # Combine all returns for this model
    if (length(model_oos_returns) > 0) {
      model_df <- do.call(rbind, model_oos_returns)
      model_df$model <- model_name
      oos_results_list[[model_name]] <- model_df
    }
  }
  
  if (verbose) cat("  All models processed.\n\n")
  
  ## -------------------------------------------------------------------------
  ## 8. Combine Results into Wide Format
  ## -------------------------------------------------------------------------
  
  if (length(oos_results_list) == 0) {
    stop("No out-of-sample returns computed for any model")
  }
  
  # Stack all model results
  oos_long <- do.call(rbind, oos_results_list)
  rownames(oos_long) <- NULL
  
  # Pivot to wide format: date x model columns
  oos_wide <- oos_long %>%
    select(date, model, return) %>%
    tidyr::pivot_wider(names_from = model, values_from = return, values_fn = mean)
  
  # Sort by date
  oos_wide <- oos_wide %>% arrange(date)
  
  if (verbose) {
    cat("Out-of-sample returns computed:\n")
    cat("  Date range: ", format(min(oos_wide$date), "%Y-%m-%d"), " to ", 
        format(max(oos_wide$date), "%Y-%m-%d"), "\n")
    cat("  Number of dates: ", nrow(oos_wide), "\n")
    cat("  Number of models: ", ncol(oos_wide) - 1, "\n\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 8.1 Add Raw Benchmark Factors (MKTS, MKTB, EW)
  ## -------------------------------------------------------------------------
  
  # Add raw factor returns from fac_freq for use as benchmarks/vol scaling
  # These are NOT model portfolios, but raw factor returns
  
  if (verbose) cat("Adding raw benchmark factors from fac_freq...\n")
  
  # Get the dates in oos_wide
  oos_dates <- oos_wide$date
  
  # Create a lookup from fac_freq with matching dates
  fac_freq_df <- data.frame(date = fac_freq_dates, fac_freq_returns, check.names = FALSE)
  
  # Merge to get raw factor returns for OOS dates
  benchmark_factors <- c("MKTS", "MKTB")  # Add more if needed
  available_benchmarks <- intersect(benchmark_factors, colnames(fac_freq_df))
  
  if (length(available_benchmarks) > 0) {
    # Only add factors that don't already exist as model columns
    existing_cols <- colnames(oos_wide)
    new_benchmarks <- setdiff(available_benchmarks, existing_cols)
    
    if (length(new_benchmarks) > 0) {
      benchmark_df <- fac_freq_df %>%
        dplyr::select(date, all_of(new_benchmarks)) %>%
        dplyr::filter(date %in% oos_dates)
      
      oos_wide <- oos_wide %>%
        dplyr::left_join(benchmark_df, by = "date")
      
      if (verbose) cat("  Added raw factors: ", paste(new_benchmarks, collapse = ", "), "\n")
    }
  }
  
  # Add EW (equal-weight of f2) if not already present
  if (!"EW" %in% colnames(oos_wide) && "EqualWeight" %in% colnames(oos_wide)) {
    # Rename EqualWeight to EW for consistency
    if (verbose) cat("  Note: EqualWeight model present (use as EW benchmark)\n")
  } else if (!"EW" %in% colnames(oos_wide) && !"EqualWeight" %in% colnames(oos_wide)) {
    # Compute EW from f2 returns
    f2_df <- data.frame(date = f2_dates, f2_returns, check.names = FALSE)
    ew_returns <- f2_df %>%
      dplyr::filter(date %in% oos_dates) %>%
      dplyr::mutate(EW = rowMeans(dplyr::select(., -date), na.rm = TRUE)) %>%
      dplyr::select(date, EW)
    
    oos_wide <- oos_wide %>%
      dplyr::left_join(ew_returns, by = "date")
    
    if (verbose) cat("  Added EW (equal-weight of f2 factors)\n")
  }
  
  if (verbose) cat("\n")
  
  ## -------------------------------------------------------------------------
  ## 9. Volatility Scaling
  ## -------------------------------------------------------------------------
  
  oos_returns_raw <- as.data.frame(oos_wide)
  model_cols <- setdiff(colnames(oos_returns_raw), "date")
  
  # Apply volatility scaling if specified
  if (!is.null(vol_scale) && vol_scale %in% model_cols) {
    if (verbose) cat("Applying volatility scaling to match: ", vol_scale, "\n")
    
    target_vol <- sd(oos_returns_raw[[vol_scale]], na.rm = TRUE)
    
    if (verbose) cat("  Target monthly volatility (", vol_scale, "): ", round(target_vol * 100, 4), "%\n")
    
    oos_returns_scaled <- oos_returns_raw
    for (col in model_cols) {
      col_vol <- sd(oos_returns_raw[[col]], na.rm = TRUE)
      if (col_vol > 0) {
        scale_factor <- target_vol / col_vol
        oos_returns_scaled[[col]] <- oos_returns_raw[[col]] * scale_factor
      }
    }
    
    # Verify scaling worked
    if (verbose) {
      scaled_vols <- sapply(model_cols, function(col) sd(oos_returns_scaled[[col]], na.rm = TRUE))
      cat("  Verification - all scaled vols should equal target:\n")
      cat("    Min scaled vol: ", round(min(scaled_vols) * 100, 4), "%\n")
      cat("    Max scaled vol: ", round(max(scaled_vols) * 100, 4), "%\n\n")
    }
  } else {
    if (!is.null(vol_scale)) {
      if (verbose) {
        cat("WARNING: vol_scale column '", vol_scale, "' not found in model columns.\n")
        cat("  Available columns: ", paste(head(model_cols, 10), collapse = ", "), "...\n")
        cat("  Using unscaled returns.\n\n")
      }
    }
    oos_returns_scaled <- oos_returns_raw
    target_vol <- NA
  }
  
  ## -------------------------------------------------------------------------
  ## 10. Compute Performance Metrics
  ## -------------------------------------------------------------------------
  
  if (verbose) cat("Computing performance metrics...\n")
  
  # Helper functions for performance metrics
  calc_mean_ann <- function(x) mean(x, na.rm = TRUE) * 12 * 100  # Annualized, in percent
  calc_vol_ann <- function(x) sd(x, na.rm = TRUE) * sqrt(12) * 100  # Annualized, in percent
  calc_sr <- function(x) (mean(x, na.rm = TRUE) / sd(x, na.rm = TRUE)) * sqrt(12)
  
  calc_sortino <- function(x) {
    # Sortino ratio: mean / downside deviation, annualized
    mu <- mean(x, na.rm = TRUE)
    downside <- x[x < 0]
    if (length(downside) < 2) return(NA)
    downside_vol <- sd(downside, na.rm = TRUE)
    if (downside_vol == 0) return(NA)
    (mu / downside_vol) * sqrt(12)
  }
  
  calc_skew <- function(x) {
    # Sample skewness
    n <- sum(!is.na(x))
    if (n < 3) return(NA)
    x_clean <- x[!is.na(x)]
    x_centered <- x_clean - mean(x_clean)
    s <- sd(x_clean)
    if (s == 0) return(NA)
    mean(x_centered^3) / s^3
  }
  
  calc_excess_kurt <- function(x) {
    # Excess kurtosis (Fisher's definition: kurtosis - 3)
    n <- sum(!is.na(x))
    if (n < 4) return(NA)
    x_clean <- x[!is.na(x)]
    x_centered <- x_clean - mean(x_clean)
    s <- sd(x_clean)
    if (s == 0) return(NA)
    mean(x_centered^4) / s^4 - 3
  }
  
  calc_ir <- function(y, benchmark) {
    # Information Ratio: regression alpha / residual volatility, annualized
    # IR = (alpha / sigma_residual) * sqrt(12)
    # This is the CORRECT definition using CAPM-style regression
    if (all(is.na(benchmark)) || all(is.na(y))) return(NA)
    
    # Remove NAs pairwise
    valid_idx <- !is.na(y) & !is.na(benchmark)
    if (sum(valid_idx) < 10) return(NA)  # Need minimum observations
    
    y_clean <- y[valid_idx]
    x_clean <- benchmark[valid_idx]
    
    # Run regression: y = alpha + beta * benchmark + epsilon
    fit <- lm(y_clean ~ x_clean)
    
    alpha_month <- coef(fit)["(Intercept)"]
    resid_vol <- sd(resid(fit))
    
    if (resid_vol == 0) return(NA)
    
    # Annualize: alpha / residual_vol * sqrt(12)
    ir <- (alpha_month / resid_vol) * sqrt(12)
    return(ir)
  }
  
  calc_maxdd <- function(x) {
    # Maximum drawdown from cumulative returns
    x_clean <- x[!is.na(x)]
    if (length(x_clean) < 2) return(NA)
    cum_ret <- cumprod(1 + x_clean)
    running_max <- cummax(cum_ret)
    drawdown <- (cum_ret - running_max) / running_max
    min(drawdown) * 100  # In percent (will be negative)
  }
  
  # Get EW as benchmark for IR (use EqualWeight if EW doesn't exist)
  ew_col <- if ("EW" %in% model_cols) "EW" else if ("EqualWeight" %in% model_cols) "EqualWeight" else NULL
  ew_returns <- if (!is.null(ew_col)) oos_returns_scaled[[ew_col]] else rep(NA, nrow(oos_returns_scaled))
  
  # Compute metrics for all models
  perf_list <- list()
  for (col in model_cols) {
    x <- oos_returns_scaled[[col]]
    perf_list[[col]] <- data.frame(
      Model = col,
      Mean = calc_mean_ann(x),
      Vol = calc_vol_ann(x),
      SR = calc_sr(x),
      ST = calc_sortino(x),
      IR = if (col == ew_col) NA else calc_ir(x, ew_returns),
      Skew = calc_skew(x),
      Kurt = calc_excess_kurt(x),
      MaxDD = calc_maxdd(x),
      stringsAsFactors = FALSE
    )
  }
  
  perf_df <- do.call(rbind, perf_list)
  rownames(perf_df) <- NULL
  
  ## -------------------------------------------------------------------------
  ## 11. Generate Performance Tables
  ## -------------------------------------------------------------------------
  
  # Define short model list
  short_models <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%", 
                    "Top-80%", "Top-MPR-80%", "KNS", "RP-PCA", 
                    "FF5", "HKM", "MKTB", "MKTS", "EW", "EqualWeight")
  
  # Filter to available models
  short_models_avail <- intersect(short_models, model_cols)
  
  # Replace EqualWeight with EW for display if needed
  perf_df_display <- perf_df
  perf_df_display$Model[perf_df_display$Model == "EqualWeight"] <- "EW"
  
  # Create short table
  perf_short <- perf_df_display %>%
    filter(Model %in% c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%", 
                        "Top-80%", "Top-MPR-80%", "KNS", "RP-PCA", 
                        "FF5", "HKM", "MKTB", "MKTS", "EW"))
  
  # Order columns properly
  desired_order <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%", 
                     "Top-80%", "Top-MPR-80%", "KNS", "RP-PCA", 
                     "FF5", "HKM", "MKTB", "MKTS", "EW")
  perf_short <- perf_short[match(intersect(desired_order, perf_short$Model), perf_short$Model), ]
  
  ## -------------------------------------------------------------------------
  ## 12. Print Console Tables
  ## -------------------------------------------------------------------------
  
  if (verbose) {
    cat("\n")
    cat("=========================================================================\n")
    cat("OUT-OF-SAMPLE PERFORMANCE (VOLATILITY SCALED)\n")
    cat("=========================================================================\n\n")
    
    # Format for console printing
    print_perf <- function(df, title) {
      cat(title, "\n")
      cat(paste(rep("-", nchar(title)), collapse = ""), "\n\n")
      
      # Transpose for display
      metrics <- c("Mean", "Vol", "SR", "ST", "IR", "Skew", "Kurt", "MaxDD")
      metric_labels <- c("Mean (%)", "Vol (%)", "SR", "ST", "IR", "Skew", "Kurt", "MaxDD (%)")
      
      # Create transposed matrix
      n_models <- nrow(df)
      out_mat <- matrix(NA, nrow = length(metrics), ncol = n_models)
      colnames(out_mat) <- df$Model
      rownames(out_mat) <- metric_labels
      
      for (i in seq_along(metrics)) {
        out_mat[i, ] <- round(df[[metrics[i]]], 2)
      }
      
      # Handle IR for EW (show "--")
      if ("EW" %in% colnames(out_mat)) {
        out_mat["IR", "EW"] <- NA
      }
      
      # Print with formatting
      print(out_mat, na.print = "--", quote = FALSE)
      cat("\n")
    }
    
    # Print short table
    if (nrow(perf_short) > 0) {
      print_perf(perf_short, "SHORT TABLE: Key Models")
    }
    
    # Print full table
    cat("\n")
    print_perf(perf_df_display, "FULL TABLE: All Models")
  }
  
  ## -------------------------------------------------------------------------
  ## 13. Generate LaTeX Tables
  ## -------------------------------------------------------------------------
  
  generate_latex_table <- function(perf_df, metadata, table_type = "short") {
    
    # Get date range from data
    date_start <- format(min(oos_wide$date), "%Y:%m")
    date_end <- format(max(oos_wide$date), "%Y:%m")
    T_obs <- nrow(oos_wide)
    
    # Determine models and their order
    if (table_type == "short") {
      model_order <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%", 
                       "Top-80%", "Top-MPR-80%", "KNS", "RP-PCA", 
                       "FF5", "HKM", "MKTB", "MKTS", "EW")
      models_avail <- intersect(model_order, perf_df$Model)
      # Filter and order
      df <- perf_df %>% filter(Model %in% models_avail)
      df <- df[match(intersect(model_order, df$Model), df$Model), ]
    } else {
      # Full table: use all models, order BMA first then alphabetically
      df <- perf_df
      bma_rows <- df %>% filter(grepl("^BMA-", Model)) %>% arrange(Model)
      other_rows <- df %>% filter(!grepl("^BMA-", Model)) %>% arrange(Model)
      df <- rbind(bma_rows, other_rows)
    } 
    
    n_models <- nrow(df)
    if (n_models == 0) return(NULL)
    
    # Count BMA models for column grouping
    bma_models <- sum(grepl("^BMA-", df$Model))
    other_models <- n_models - bma_models
    
    # Format numbers with proper negative sign handling
    fmt_num <- function(x, digits = 2) {
      if (is.na(x)) return("--")
      val <- round(x, digits)
      if (val < 0) {
        paste0("$-$", abs(val))
      } else {
        as.character(val)
      }
    }
    
    # Build LaTeX string
    latex <- character()
    
    # Header
    latex <- c(latex, "\\begin{table}[tbh!]")
    latex <- c(latex, "\\begin{center}")
    
    if (table_type == "short") {
      latex <- c(latex, "\\caption{Out-of-Sample Performance: Key Models}\\label{tab:oos-perf-short}\\vspace{-2mm}")
    } else {
      latex <- c(latex, "\\caption{Out-of-Sample Performance: All Models}\\label{tab:oos-perf-full}\\vspace{-2mm}")
    }
    
    latex <- c(latex, "\\resizebox{\\textwidth}{!}{")
    
    # Column spec: l for metric name, then c for each model
    col_spec <- paste0("l", paste(rep("c", n_models), collapse = ""))
    
    # Build header row with proper grouping
    latex <- c(latex, paste0("\\begin{tabular}{", col_spec, "}\\toprule"))
    
    # First header row: BMA-SDF prior Sharpe ratio group + other model names
    if (bma_models > 0) {
      bma_header <- paste0(" & \\multicolumn{", bma_models, "}{c}{BMA-SDF prior Sharpe ratio}")
      other_names <- df$Model[(bma_models + 1):n_models]
      # Clean model names for LaTeX
      other_names <- gsub("Top-80%", "TOP $\\\\gamma$", other_names)
      other_names <- gsub("Top-MPR-80%", "TOP $\\\\lambda$", other_names)
      other_names <- gsub("RP-PCA", "RPPCA", other_names)
      other_names <- gsub("%", "\\\\%", other_names)  # Escape remaining % for LaTeX
      other_header <- paste(paste0(" & ", other_names), collapse = "")
      latex <- c(latex, paste0(bma_header, other_header, " \\\\ \\cmidrule(lr){2-", bma_models + 1, "}"))
      
      # Second header row: percentage labels for BMA
      bma_labels <- gsub("BMA-", "", df$Model[1:bma_models])
      bma_labels <- gsub("%", "\\\\%", bma_labels)  # Escape % for LaTeX
      bma_row <- paste(paste0(" & ", bma_labels), collapse = "")
      empty_cols <- paste(rep(" & ", other_models), collapse = "")
      latex <- c(latex, paste0(bma_row, empty_cols, " \\\\ \\midrule"))
    } else {
      # No BMA models - just list all
      header_names <- df$Model
      header_names <- gsub("Top-80%", "TOP $\\\\gamma$", header_names)
      header_names <- gsub("Top-MPR-80%", "TOP $\\\\lambda$", header_names)
      header_names <- gsub("RP-PCA", "RPPCA", header_names)
      header_names <- gsub("%", "\\\\%", header_names)  # Escape remaining % for LaTeX
      latex <- c(latex, paste0(" & ", paste(header_names, collapse = " & "), " \\\\ \\midrule"))
    }
    
    # Panel header
    latex <- c(latex, paste0(" \\multicolumn{", n_models + 1, "}{c}{\\textbf{Out-of-sample} -- ", 
                             date_start, " to ", date_end, " ($T=", T_obs, "$)} \\\\"))
    latex <- c(latex, " \\midrule")
    
    # Data rows
    metrics <- c("Mean", "SR", "ST", "IR", "Skew", "Kurt")
    metric_labels <- c("Mean", "SR", "ST", "IR", "Skew", "Kurt")
    
    for (i in seq_along(metrics)) {
      row_vals <- sapply(df[[metrics[i]]], fmt_num)
      # Special handling for IR on EW
      if (metrics[i] == "IR" && "EW" %in% df$Model) {
        row_vals[df$Model == "EW"] <- "--"
      }
      latex <- c(latex, paste0(metric_labels[i], " & ", paste(row_vals, collapse = " & "), " \\\\"))
    }
    
    latex <- c(latex, "\\midrule")
    latex <- c(latex, "\\end{tabular}")
    latex <- c(latex, "}")
    latex <- c(latex, "\\end{center}")
    
    # Footnote
    latex <- c(latex, "\\begin{spacing}{1}")
    latex <- c(latex, "{\\footnotesize")
    latex <- c(latex, paste0("Out-of-sample performance of trading strategies. ",
                             "Mean is annualized and presented in percent. ",
                             "SR is the annualized Sharpe ratio. ",
                             "ST is the annualized Sortino ratio. ",
                             "IR is the annualized Information ratio using EW as benchmark. ",
                             "Skew is skewness. Kurt is excess kurtosis. ",
                             "All portfolios are scaled to have the same volatility as ", vol_scale, "."))
    latex <- c(latex, "}")
    latex <- c(latex, "\\end{spacing}")
    latex <- c(latex, "\\vspace{-4mm}")
    latex <- c(latex, "\\end{table}")
    
    return(paste(latex, collapse = "\n"))
  }
  
  # Generate both tables
  latex_short <- generate_latex_table(perf_df_display, metadata, "short")
  latex_full <- generate_latex_table(perf_df_display, metadata, "full")
  
  ## -------------------------------------------------------------------------
  ## 14. Save LaTeX Tables
  ## -------------------------------------------------------------------------
  
  # Create output directory
  output_base <- metadata$paths$output_folder
  model_type <- metadata$model_type
  tables_dir <- file.path(output_base, "time_varying", model_type, "tables")
  
  if (!dir.exists(tables_dir)) {
    dir.create(tables_dir, recursive = TRUE)
    if (verbose) cat("Created tables directory: ", tables_dir, "\n")
  }
  
  # Save short table
  short_file <- file.path(tables_dir, "oos_performance_short.tex")
  writeLines(latex_short, short_file)
  if (verbose) cat("Short LaTeX table saved to: ", short_file, "\n")
  
  # Save full table
  full_file <- file.path(tables_dir, "oos_performance_full.tex")
  writeLines(latex_full, full_file)
  if (verbose) cat("Full LaTeX table saved to: ", full_file, "\n")
  
  ## -------------------------------------------------------------------------
  ## 15. Generate Cumulative Return Plot
  ## -------------------------------------------------------------------------
  
  cumret_plot <- NULL
  
  if (!is.null(factor_vec) && length(factor_vec) > 0) {
    
    if (verbose) cat("\nGenerating cumulative return plot...\n")
    
    # Check if plot_cumret function exists
    if (!exists("plot_cumret", mode = "function")) {
      warning("plot_cumret() function not found. Please source plot_cumret.R. Skipping plot generation.")
    } else {
      
      # Determine output directory for figures
      figures_base <- file.path(output_base, "time_varying", model_type)
      
      # Generate the plot
      cumret_plot <- plot_cumret(
        df_scaled          = oos_returns_scaled,
        factor_vec         = factor_vec,
        color_vec          = color_vec,
        line_types_vec     = line_types_vec,
        legend_position    = legend_position,
        dollar_step        = dollar_step,
        output_dir         = figures_base,
        fig_name           = fig_name,
        width              = fig_width,
        height             = fig_height,
        save_plot          = TRUE,
        verbose            = verbose
      )
    }
  } else {
    if (verbose) cat("\nNo factor_vec specified. Skipping cumulative return plot.\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 16. Return Results
  ## -------------------------------------------------------------------------
  
  return(list(
    oos_returns_raw = oos_returns_raw,
    oos_returns_scaled = oos_returns_scaled,
    performance = perf_df,
    performance_short = perf_short,
    latex_short = latex_short,
    latex_full = latex_full,
    vol_scale = vol_scale,
    target_vol = if (exists("target_vol", inherits = FALSE)) target_vol else NA,
    cumret_plot = cumret_plot
  ))
}