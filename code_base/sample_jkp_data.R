#' Sample N Root Variables from Bond/Stock Dataset
#'
#' Given a dataframe with columns: date, B_*, S_*, this function randomly
#' samples N root variable names and returns a subset containing date plus
#' the corresponding B_ and S_ columns.
#'
#' @param data Dataframe with structure: date, B_var1, B_var2, ..., S_var1, S_var2, ...
#' @param n_roots Number of root variables to sample (default 25)
#' @param seed Random seed for reproducibility (default NULL)
#' @param verbose Print summary of sampling? (default TRUE)
#'
#' @return Dataframe with date + 2*n_roots columns (n_roots B_ and n_roots S_ columns)
#'
#' @examples
#' # Sample 25 roots (51 total columns)
#' R_oos_subset <- sample_root_variables(R_oos_data, n_roots = 25, seed = 123)
#' 
#' # Sample 10 roots (21 total columns)
#' R_oos_small <- sample_root_variables(R_oos_data, n_roots = 10, seed = 456)

sample_root_variables <- function(data, 
                                  n_roots = 25, 
                                  seed = NULL, 
                                  verbose = TRUE) {
  
  ## ---- 0. Validation -----------------------------------------------------
  if (!is.data.frame(data) && !is.matrix(data)) {
    stop("data must be a dataframe or matrix")
  }
  
  if (!"date" %in% colnames(data)) {
    stop("First column must be named 'date'")
  }
  
  if (n_roots < 1) {
    stop("n_roots must be at least 1")
  }
  
  ## ---- 1. Extract root variable names ------------------------------------
  col_names <- colnames(data)
  
  # Get all B_ columns (excluding date)
  b_cols <- col_names[grepl("^B_", col_names)]
  
  # Extract root names by removing "B_" prefix
  root_names <- sub("^B_", "", b_cols)
  
  # Validate corresponding S_ columns exist
  s_cols <- paste0("S_", root_names)
  missing_s <- s_cols[!s_cols %in% col_names]
  
  if (length(missing_s) > 0) {
    warning(sprintf("Found %d B_ columns without matching S_ columns:\n  %s",
                    length(missing_s),
                    paste(head(missing_s, 10), collapse = ", ")))
    
    # Filter to only roots that have both B_ and S_
    valid_roots <- root_names[s_cols %in% col_names]
    root_names <- valid_roots
  }
  
  ## ---- 2. Validate n_roots -----------------------------------------------
  n_available <- length(root_names)
  
  if (n_roots > n_available) {
    stop(sprintf("Requested n_roots=%d but only %d root variables available",
                 n_roots, n_available))
  }
  
  ## ---- 3. Sample root variables ------------------------------------------
  if (!is.null(seed)) {
    set.seed(seed)
  }
  
  sampled_roots <- sample(root_names, size = n_roots, replace = FALSE)
  
  ## ---- 4. Construct column names to keep ---------------------------------
  b_keep <- paste0("B_", sampled_roots)
  s_keep <- paste0("S_", sampled_roots)
  
  cols_to_keep <- c("date", b_keep, s_keep)
  
  ## ---- 5. Subset dataframe -----------------------------------------------
  result <- data[, cols_to_keep, drop = FALSE]
  
  ## ---- 6. Print summary --------------------------------------------------
  if (verbose) {
    cat("\n========================================\n")
    cat("Root Variable Sampling Summary\n")
    cat("========================================\n")
    cat(sprintf("Total root variables available: %d\n", n_available))
    cat(sprintf("Roots sampled:                  %d\n", n_roots))
    cat(sprintf("Output columns:                 %d (date + %d B_ + %d S_)\n", 
                ncol(result), n_roots, n_roots))
    cat(sprintf("Random seed:                    %s\n", 
                ifelse(is.null(seed), "NULL (not set)", as.character(seed))))
    cat("\nSampled root variables:\n")
    cat("  ", paste(head(sampled_roots, 10), collapse = ", "))
    if (n_roots > 10) {
      cat(sprintf("\n  ... and %d more", n_roots - 10))
    }
    cat("\n========================================\n\n")
  }
  
  ## ---- 7. Return result --------------------------------------------------
  return(result)
}



