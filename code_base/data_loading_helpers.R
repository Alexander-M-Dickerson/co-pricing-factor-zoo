#' Data Loading Helper Functions
#'
#' Extracted helper functions for cleaner code organization

#' Read matrix from CSV file
#'
#' @param path_data_fn Function that constructs path to data file
#' @param fname Filename to read
#' @return Matrix with row and column names
read_mat <- function(path_data_fn, fname) {
  as.matrix(utils::read.csv(path_data_fn(fname), check.names = FALSE)[, -1])
}

#' Read matrix with names attribute
#'
#' @param path_data_fn Function that constructs path to data file
#' @param file Filename to read
#' @return Matrix with "fname" attribute containing column names
read_mat_named <- function(path_data_fn, file) {
  m <- read_mat(path_data_fn, file)
  attr(m, "fname") <- colnames(m)
  m
}

#' Get column names from matrix with fname attribute
#'
#' @param x Matrix with fname attribute
#' @return Character vector of column names
get_names <- function(x) {
  attr(x, "fname")
}

#' Calculate Sharpe Ratio from returns matrix
#'
#' @param R Returns matrix (T x N)
#' @return Numeric scalar - squared Sharpe ratio
SharpeRatio <- function(R) {
  mu <- colMeans(R)
  as.numeric(t(mu) %*% solve(stats::cov(R)) %*% mu)
}

#' Format integer with commas or scientific notation
#'
#' @param x Numeric value
#' @return Formatted character string
pretty_int <- function(x) {
  if (abs(x) < 1e9) {
    formatC(x, format = "d", big.mark = ",")
  } else {
    format(x, scientific = TRUE, digits = 3)
  }
}

#' Load and Combine Multiple CSV Files with Date Alignment
#'
#' @param filenames Character vector of filenames to load and combine
#' @param path_data_fn Function that constructs path to data file
#' @param label Character label for error messages (e.g., "f2", "R")
#' @param verbose Logical, print progress messages
#' @return Data frame with date column and combined data from all files
#' 
#' @details
#' - Each file must have 'date' as first column
#' - Dates are parsed and aligned across all files
#' - Columns from all files are combined (cbind) after date alignment
#' - Returns data frame with structure: date, file1_cols, file2_cols, ...
#' 
#' @examples
#' \dontrun{
#' f2_combined <- load_and_combine_files(
#'   c("traded_bond.csv", "traded_equity.csv"),
#'   path_data,
#'   "f2",
#'   verbose = TRUE
#' )
#' }
load_and_combine_files <- function(filenames, path_data_fn, label, verbose = TRUE) {
  
  if (length(filenames) == 0) {
    stop(sprintf("%s: No filenames provided", label))
  }
  
  # Single file - simple case
  if (length(filenames) == 1) {
    filepath <- path_data_fn(filenames[1])
    if (!file.exists(filepath)) {
      stop(sprintf("%s file not found: %s", label, filepath))
    }
    
    data <- read.csv(filepath, check.names = FALSE)
    
    if (!"date" %in% colnames(data)) {
      stop(sprintf("%s file '%s' must have 'date' as first column", label, filenames[1]))
    }
    
    if (verbose) message(sprintf("  Loaded %s: %s (%d columns)", 
                                 label, filenames[1], ncol(data) - 1))
    return(data)
  }
  
  # Multi-file case - load each file
  if (verbose) message(sprintf("  Loading %d files for %s...", length(filenames), label))
  
  data_list <- list()
  for (i in seq_along(filenames)) {
    fname <- filenames[i]
    filepath <- path_data_fn(fname)
    
    if (!file.exists(filepath)) {
      stop(sprintf("%s file not found: %s", label, filepath))
    }
    
    data <- read.csv(filepath, check.names = FALSE)
    
    if (!"date" %in% colnames(data)) {
      stop(sprintf("%s file '%s' must have 'date' as first column", label, fname))
    }
    
    data_list[[fname]] <- data
    
    if (verbose) {
      message(sprintf("    [%d/%d] %s: %d columns", 
                      i, length(filenames), fname, ncol(data) - 1))
    }
  }
  
  # Use validate_and_align_dates to align all files
  if (!exists("validate_and_align_dates", mode = "function")) {
    stop("Function 'validate_and_align_dates' not found. Please source validate_and_align_dates.R first.")
  }
  
  aligned <- validate_and_align_dates(
    data_list,
    date_start = NULL,
    date_end = NULL,
    verbose = FALSE  # Suppress internal messages
  )
  
  # Combine all aligned data (drop date column from all except first)
  combined_data <- aligned$data[[1]]  # Start with first file (includes date)
  
  for (i in 2:length(aligned$data)) {
    # Add columns from subsequent files (excluding date column)
    next_data <- aligned$data[[i]][, -1, drop = FALSE]
    combined_data <- cbind(combined_data, next_data)
  }
  
  # CRITICAL: Convert date column back to character string
  # The internal validate_and_align_dates() converted it to Date,
  # but the main function expects character format for re-parsing
  combined_data[[1]] <- as.character(combined_data[[1]])
  
  if (verbose) {
    message(sprintf("  Combined %s: %d total columns across %d files", 
                    label, ncol(combined_data) - 1, length(filenames)))
  }
  
  return(combined_data)
}