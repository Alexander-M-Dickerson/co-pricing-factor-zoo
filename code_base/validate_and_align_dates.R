#' Validate and Align Dates Across Multiple Datasets (Redesigned)
#'
#' Robust date validation with automatic first-column detection and format parsing.
#' All dates MUST successfully convert to YYYY-MM-DD format or function stops.
#'
#' @param data_list Named list of datasets (data.frames or matrices)
#' @param date_start Optional start date (YYYY-MM-DD format)
#' @param date_end Optional end date (YYYY-MM-DD format)
#' @param verbose Print warnings and info messages
#' @return List with aligned datasets and metadata
#'
#' @details
#' Key features:
#' - First column is always treated as date column (auto-renamed if needed)
#' - Checks for NaN/NA in dates and all numeric columns
#' - Intelligently parses mixed date formats (DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD)
#' - All dates must convert to YYYY-MM-DD or function stops with error
#'
#' @examples
#' \dontrun{
#'   aligned <- validate_and_align_dates(
#'     list(R = R_data, f1 = f1_data, f2 = f2_data),
#'     date_start = "1990-01-01",
#'     date_end = "2020-12-31"
#'   )
#' }

validate_and_align_dates <- function(data_list, 
                                     date_start = NULL, 
                                     date_end = NULL,
                                     verbose = TRUE) {
  
  # Load required package
  if (!requireNamespace("lubridate", quietly = TRUE)) {
    stop("Package 'lubridate' is required. Install with: install.packages('lubridate')")
  }
  
  ## ---- 1. Validate inputs ----------------------------------------------------
  if (!is.list(data_list) || length(data_list) == 0) {
    stop("data_list must be a non-empty named list of datasets")
  }
  
  if (is.null(names(data_list)) || any(names(data_list) == "")) {
    stop("data_list must have names for all elements (e.g., list(R = ..., f1 = ...))")
  }
  
  if (verbose) message("Validating and aligning dates across ", length(data_list), " datasets...")
  
  ## ---- 2. Process each dataset -----------------------------------------------
  processed_data <- list()
  date_ranges <- list()
  
  for (name in names(data_list)) {
    if (verbose) message("  Processing: ", name)
    
    dataset <- data_list[[name]]
    
    # Convert matrix to data.frame
    if (is.matrix(dataset)) {
      dataset <- as.data.frame(dataset, stringsAsFactors = FALSE)
    }
    
    if (!is.data.frame(dataset)) {
      stop(sprintf("Dataset '%s' must be a data.frame or matrix", name))
    }
    
    if (ncol(dataset) < 2) {
      stop(sprintf("Dataset '%s' must have at least 2 columns (date + data)", name))
    }
    
    # Check if first column is named "date" (case-insensitive)
    first_col_name <- colnames(dataset)[1]
    if (tolower(first_col_name) != "date") {
      if (verbose) {
        message(sprintf("    WARNING: First column '%s' is not named 'date'. Renaming to 'date'.", 
                        first_col_name))
      }
      colnames(dataset)[1] <- "date"
    }
    
    # Extract date column
    date_col <- dataset[[1]]
    
    # Check for NaN/NA in date column
    if (any(is.na(date_col))) {
      na_count <- sum(is.na(date_col))
      stop(sprintf("Dataset '%s': Date column contains %d NA/NaN values. Please clean your data.", 
                   name, na_count))
    }
    
    # Parse dates robustly
    parsed_dates <- parse_dates_robust(date_col, dataset_name = name, verbose = verbose)
    
    # Validate all dates parsed successfully
    if (any(is.na(parsed_dates))) {
      na_count <- sum(is.na(parsed_dates))
      stop(sprintf("Dataset '%s': %d dates failed to parse. Check date format.", name, na_count))
    }
    
    # Replace date column with parsed dates
    dataset[[1]] <- parsed_dates
    
    # Check for NaN/NA in numeric columns
    numeric_cols <- sapply(dataset[, -1, drop = FALSE], is.numeric)
    if (any(numeric_cols)) {
      numeric_data <- dataset[, -1, drop = FALSE][, numeric_cols, drop = FALSE]
      na_check <- sapply(numeric_data, function(x) sum(is.na(x)))
      
      if (any(na_check > 0)) {
        na_cols <- names(na_check[na_check > 0])
        na_summary <- paste(sprintf("  - %s: %d NAs", na_cols, na_check[na_check > 0]), 
                            collapse = "\n")
        stop(sprintf("Dataset '%s': Found NA/NaN values in numeric columns:\n%s\nPlease clean your data.", 
                     name, na_summary))
      }
    }
    
    # Store processed dataset and date range
    processed_data[[name]] <- dataset
    date_ranges[[name]] <- range(parsed_dates)
  }
  
  ## ---- 3. Find common date range ---------------------------------------------
  if (verbose) message("Finding common date range...")
  
  all_starts <- sapply(date_ranges, function(x) x[1])
  all_ends   <- sapply(date_ranges, function(x) x[2])
  
  common_start <- max(all_starts)
  common_end   <- min(all_ends)
  
  if (common_start > common_end) {
    date_summary <- sapply(names(date_ranges), function(nm) {
      rng <- date_ranges[[nm]]
      sprintf("  %s: %s to %s", nm, rng[1], rng[2])
    })
    stop(sprintf("ERROR: No overlapping dates found across datasets. Check date ranges:\n%s", 
                 paste(date_summary, collapse = "\n")))
  }
  
  ## ---- 4. Apply user-specified date filters ----------------------------------
  filter_start <- common_start
  filter_end   <- common_end
  
  if (!is.null(date_start)) {
    date_start_parsed <- as.Date(date_start)
    if (is.na(date_start_parsed)) {
      stop("date_start must be in YYYY-MM-DD format, got: ", date_start)
    }
    if (date_start_parsed < common_start) {
      if (verbose) {
        message(sprintf("  WARNING: date_start (%s) is before common start (%s). Using common start.", 
                        date_start, common_start))
      }
    } else {
      filter_start <- date_start_parsed
    }
  }
  
  if (!is.null(date_end)) {
    date_end_parsed <- as.Date(date_end)
    if (is.na(date_end_parsed)) {
      stop("date_end must be in YYYY-MM-DD format, got: ", date_end)
    }
    if (date_end_parsed > common_end) {
      if (verbose) {
        message(sprintf("  WARNING: date_end (%s) is after common end (%s). Using common end.", 
                        date_end, common_end))
      }
    } else {
      filter_end <- date_end_parsed
    }
  }
  
  if (filter_start > filter_end) {
    stop(sprintf("Invalid date range: start (%s) is after end (%s)", filter_start, filter_end))
  }
  
  ## ---- 5. Align datasets to common dates -------------------------------------
  if (verbose) message("Aligning datasets to common dates...")
  
  aligned_data <- list()
  
  for (name in names(processed_data)) {
    dataset <- processed_data[[name]]
    date_col <- dataset[[1]]
    
    # Filter to common date range
    in_range <- (date_col >= filter_start) & (date_col <= filter_end)
    
    if (sum(in_range) == 0) {
      stop(sprintf("Dataset '%s': No observations in date range [%s, %s]", 
                   name, filter_start, filter_end))
    }
    
    aligned_data[[name]] <- dataset[in_range, , drop = FALSE]
  }
  
  # Verify all datasets have same dates
  date_counts <- sapply(aligned_data, nrow)
  if (length(unique(date_counts)) > 1) {
    count_summary <- paste(sprintf("  %s: %d rows", names(date_counts), date_counts), 
                           collapse = "\n")
    stop(sprintf("ERROR: Datasets have different numbers of observations after alignment:\n%s", 
                 count_summary))
  }
  
  # Check that dates are identical across datasets
  first_dates <- aligned_data[[1]][[1]]
  for (name in names(aligned_data)[-1]) {
    if (!identical(aligned_data[[name]][[1]], first_dates)) {
      stop(sprintf("Dataset '%s': Dates do not match first dataset after alignment", name))
    }
  }
  
  n_periods <- nrow(aligned_data[[1]])
  
  # Extract actual date range from aligned data (all datasets have same dates)
  aligned_dates <- aligned_data[[1]][[1]]  # First column (date) of first dataset
  actual_start <- min(aligned_dates)
  actual_end <- max(aligned_dates)
  
  if (verbose) {
    message(sprintf("  SUCCESS: All datasets aligned to %d periods [%s to %s]", 
                    n_periods, format(actual_start, format = "%Y-%m-%d"), 
                    format(actual_end, format = "%Y-%m-%d")))
  }
  
  ## ---- 6. Return results -----------------------------------------------------
  return(list(
    data = aligned_data,
    date_range = c(start = format(actual_start, format = "%Y-%m-%d"), 
                   end = format(actual_end, format = "%Y-%m-%d")),
    n_periods = n_periods,
    original_ranges = date_ranges
  ))
}


#' Parse Dates Robustly Using Multiple Formats
#'
#' Tries multiple date parsing strategies using lubridate.
#' All dates must convert to YYYY-MM-DD format or function fails.
#'
#' @param date_col Vector of dates (character, factor, or numeric)
#' @param dataset_name Name of dataset (for error messages)
#' @param verbose Print parsing info
#' @return Vector of Date objects in YYYY-MM-DD format

parse_dates_robust <- function(date_col, dataset_name = "unknown", verbose = TRUE) {
  
  # Convert factor or numeric to character
  if (is.factor(date_col)) {
    date_col <- as.character(date_col)
  } else if (is.numeric(date_col)) {
    date_col <- as.character(date_col)
  }
  
  if (!is.character(date_col)) {
    stop(sprintf("Dataset '%s': Date column must be character, factor, or numeric. Got: %s", 
                 dataset_name, class(date_col)[1]))
  }
  
  # Remove leading/trailing whitespace
  date_col <- trimws(date_col)
  
  # Strategy 1: Try dmy (DD/MM/YYYY) - Europe/Australia format
  parsed <- lubridate::dmy(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using DD/MM/YYYY format"))
    return(parsed)
  }
  
  # Strategy 2: Try mdy (MM/DD/YYYY) - US format
  parsed <- lubridate::mdy(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using MM/DD/YYYY format"))
    return(parsed)
  }
  
  # Strategy 3: Try ymd (YYYY-MM-DD) - ISO format
  parsed <- lubridate::ymd(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using YYYY-MM-DD format"))
    return(parsed)
  }
  
  # Strategy 4: Try ydm (YYYY-DD-MM)
  parsed <- lubridate::ydm(date_col, quiet = TRUE)
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using YYYY-DD-MM format"))
    return(parsed)
  }
  
  # Strategy 5: Try multiple formats with parse_date_time
  formats <- c("dmy", "mdy", "ymd", "ydm", "dmy HMS", "mdy HMS", "ymd HMS")
  parsed <- lubridate::parse_date_time(date_col, orders = formats, quiet = TRUE)
  
  if (all(!is.na(parsed))) {
    if (verbose) message(sprintf("    Parsed dates using mixed format detection"))
    return(as.Date(parsed))
  }
  
  # If we get here, parsing failed
  failed_samples <- head(date_col[is.na(parsed)], 5)
  stop(sprintf("Dataset '%s': Could not parse dates. Examples of failed dates:\n  %s\n\nSupported formats: DD/MM/YYYY, MM/DD/YYYY, YYYY-MM-DD", 
               dataset_name, paste(failed_samples, collapse = ", ")))
}