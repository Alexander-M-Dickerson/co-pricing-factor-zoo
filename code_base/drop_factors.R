# ─────────────────────────────────────────────────────────────────────────────
#  Helper: remove selected factors from the fac list produced by load_factors()
# ─────────────────────────────────────────────────────────────────────────────
#' Drop Specified Factors from Factor Structure
#'
#' Removes factors from the fac list structure used in Bayesian MCMC estimation.
#'
#' @param fac List containing factor matrices and metadata (f1, f2, f_all_raw, etc.)
#' @param fac_to_drop Factors to remove. Can be:
#'   - A character vector: c("PEAD", "PEADB")
#'   - A named list: list(top_gamma = c("PEAD"), top_lambda = c("PEADB"))
#'   - NULL to skip dropping
#' @param verbose Print messages about dropped factors
#' @return Updated fac list with specified factors removed
#'
#' @examples
#' # Character vector (simple)
#' fac <- drop_factors(fac, c("PEAD", "PEADB"))
#'
#' # Named list (legacy format)
#' fac <- drop_factors(fac, list(top_gamma = c("PEAD"), top_lambda = c("PEADB")))

drop_factors <- function(fac, fac_to_drop = NULL, verbose = TRUE) {
  
  
  # Handle NULL or empty input
  if (is.null(fac_to_drop)) {
    return(fac)
  }
  
  # Build the drop set - handle both character vector and list inputs
  if (is.character(fac_to_drop)) {
    # Simple character vector: c("PEAD", "PEADB")
    drop_set <- unique(fac_to_drop)
  } else if (is.list(fac_to_drop)) {
    # Named list format: list(top_gamma = ..., top_lambda = ...)
    # Check if list is empty
    if (length(fac_to_drop$top_gamma) == 0L && 
        length(fac_to_drop$top_lambda) == 0L &&
        length(unlist(fac_to_drop)) == 0L) {
      return(fac)
    }
    drop_set <- unique(unlist(fac_to_drop, use.names = FALSE))
  } else {
    warning("fac_to_drop must be a character vector or list. Ignoring.")
    return(fac)
  }
  
  # If drop_set is empty after processing, return unchanged
  if (length(drop_set) == 0L) {
    return(fac)
  }
  
  # Store original factor names for comparison
  original_names <- fac$all_factor_names
  
  # Helper to strip columns from a matrix
  strip_cols <- function(mat) {
    if (is.null(mat)) return(NULL)
    if (ncol(mat) == 0) return(mat)
    keep <- !colnames(mat) %in% drop_set
    mat[, keep, drop = FALSE]
  }
  
  # Apply stripping to factor matrices
  fac$f1        <- strip_cols(fac$f1)
  fac$f2        <- strip_cols(fac$f2)
  fac$f_all_raw <- strip_cols(fac$f_all_raw)
  
  # Update name vectors
  fac$nontraded_names <- setdiff(fac$nontraded_names, drop_set)
  fac$bond_names      <- if (!is.null(fac$bond_names)) {
    setdiff(fac$bond_names, drop_set)
  } else {
    NULL
  }
  fac$stock_names     <- if (!is.null(fac$stock_names)) {
    setdiff(fac$stock_names, drop_set)
  } else {
    NULL
  }
  
  # Refresh counts & master name list
  fac$n_nontraded <- length(fac$nontraded_names)
  fac$n_bondfac   <- if (!is.null(fac$bond_names)) length(fac$bond_names) else NULL
  fac$n_stockfac  <- if (!is.null(fac$stock_names)) length(fac$stock_names) else NULL
  
  # Rebuild all_factor_names
  fac$all_factor_names <- c(
    fac$nontraded_names,
    if (!is.null(fac$bond_names)) fac$bond_names else character(0),
    if (!is.null(fac$stock_names)) fac$stock_names else character(0)
  )
  
  # Report what was dropped
  if (verbose) {
    actually_dropped <- setdiff(original_names, fac$all_factor_names)
    not_found <- setdiff(drop_set, original_names)
    
    if (length(actually_dropped) > 0) {
      message("Dropped factors: ", paste(actually_dropped, collapse = ", "))
    }
    if (length(not_found) > 0) {
      message("Factors not found (ignored): ", paste(not_found, collapse = ", "))
    }
  }
  
  fac
}