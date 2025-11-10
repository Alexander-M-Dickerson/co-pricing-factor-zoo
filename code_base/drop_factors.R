# ─────────────────────────────────────────────────────────────────────────────
#  Helper: remove selected factors from the fac list produced by load_factors()
# ─────────────────────────────────────────────────────────────────────────────
drop_factors <- function(fac, fac_to_drop = NULL, verbose = TRUE) {
  
  if (is.null(fac_to_drop) ||
      (length(fac_to_drop$top_gamma)  == 0L &&
       length(fac_to_drop$top_lambda) == 0L)) {
    return(fac)                       # nothing to do
  }
  
  # 1. build the drop set -----------------------------------------------------
  drop_set <- unique( unlist(fac_to_drop, use.names = FALSE) )
  
  # 2. quick helper to strip columns from a matrix ---------------------------
  strip_cols <- function(mat) {
    if (is.null(mat)) return(NULL)
    keep <- !colnames(mat) %in% drop_set
    mat[ , keep, drop = FALSE]
  }
  
  fac$f1        <- strip_cols(fac$f1)
  fac$f2        <- strip_cols(fac$f2)
  fac$f_all_raw <- strip_cols(fac$f_all_raw)
  
  # 3. update name vectors ----------------------------------------------------
  fac$nontraded_names <- setdiff(fac$nontraded_names, drop_set)
  fac$bond_names      <- if (!is.null(fac$bond_names))
    setdiff(fac$bond_names, drop_set) else NULL
  fac$stock_names     <- if (!is.null(fac$stock_names))
    setdiff(fac$stock_names, drop_set) else NULL
  
  # 4. refresh counts & master name list --------------------------------------
  fac$n_nontraded <- length(fac$nontraded_names)
  fac$n_bondfac   <- if (!is.null(fac$bond_names))
    length(fac$bond_names) else NULL
  fac$n_stockfac  <- if (!is.null(fac$stock_names))
    length(fac$stock_names) else NULL
  
  fac$all_factor_names <- c(fac$nontraded_names,
                            fac$bond_names  %||% character(0),
                            fac$stock_names %||% character(0))
  
  # 5. warn about any requested drops that were not present -------------------
  if (verbose) {
    missing <- setdiff(drop_set, fac$all_factor_names)
    if (length(missing))
      message("Dropped factors are: ",
              paste(missing, collapse = ", "))
  }
  
  fac
}

# utility used above (acts like dplyr’s %||%)
# `%||%` <- function(x, y) if (is.null(x)) y else x
