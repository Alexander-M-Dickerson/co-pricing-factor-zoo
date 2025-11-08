#' Logging Helper Functions
#'
#' Simple logging system without using sink()

#' Initialize logger with output file
#'
#' @param log_file Path to log file
#' @return Environment containing logger state
init_logger <- function(log_file) {
  # Create logger environment
  logger <- new.env(parent = emptyenv())
  logger$file <- log_file
  logger$con <- file(log_file, open = "wt")
  
  # Write header
  cat("### Log file:", log_file, "\n", file = logger$con)
  cat("### Started at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n", 
      file = logger$con)
  flush(logger$con)
  
  return(logger)
}

#' Write message to log file and console
#'
#' @param logger Logger environment from init_logger()
#' @param ... Message components to paste together
#' @param level Character: "INFO", "WARNING", or "ERROR"
log_message <- function(logger, ..., level = "INFO") {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg <- paste0("[", timestamp, "] ", level, ": ", paste(..., sep = ""))
  
  # Write to console
  message(msg)
  
  # Write to file if connection is valid
  if (!is.null(logger$con) && isOpen(logger$con)) {
    tryCatch({
      cat(msg, "\n", file = logger$con)
      flush(logger$con)
    }, error = function(e) {
      warning("Failed to write to log file: ", e$message)
    })
  }
}

#' Close logger
#'
#' @param logger Logger environment from init_logger()
close_logger <- function(logger) {
  if (!is.null(logger$con) && isOpen(logger$con)) {
    tryCatch({
      cat("\n### Finished at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n", 
          file = logger$con)
      flush(logger$con)
      close(logger$con)
      logger$con <- NULL
    }, error = function(e) {
      warning("Error closing logger: ", e$message)
    })
  }
}