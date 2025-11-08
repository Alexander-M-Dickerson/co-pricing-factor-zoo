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

#' Load test assets based on model type and return type
#'
#' @param model_type Character: "bond", "stock", "bond_stock_with_sp", or "treasury"
#' @param return_type Character: "excess" or "duration"
#' @param path_data_fn Function to construct path to data files
#' @return Matrix of test asset returns
load_test_assets <- function(model_type, return_type, path_data_fn) {
  # Validate inputs
  valid_models <- c("bond", "stock", "bond_stock_with_sp", "treasury")
  if (!model_type %in% valid_models) {
    stop("model_type must be one of: ", paste(valid_models, collapse = ", "))
  }
  
  # Load bond returns
  R_bond <- switch(
    return_type,
    duration = read_mat(path_data_fn, "bond_insample_test_assets_50_duration_tmt.csv"),
    excess   = read_mat(path_data_fn, "bond_insample_test_assets_50_excess.csv")
  )
  
  # Load equity returns if needed
  R_equity <- if (model_type %in% c("bond_stock_with_sp", "stock")) {
    read_mat(path_data_fn, "equity_anomalies_composite_33.csv")
  } else {
    NULL
  }
  
  # Combine based on model type
  R <- switch(
    model_type,
    bond = R_bond,
    stock = R_equity,
    bond_stock_with_sp = cbind(R_bond, R_equity),
    treasury = {
      if (return_type == "excess") {
        read_mat(path_data_fn, "bond_insample_test_assets_50_duration_tmt_tbond.csv")
      } else {
        R_bond
      }
    }
  )
  
  return(R)
}

#' Load factor data based on model configuration
#'
#' @param model_type Character: model specification
#' @param return_type Character: "excess" or "duration"
#' @param path_data_fn Function to construct path to data files
#' @param tag Character: optional tag for special configurations (e.g., "credit")
#' @return List with factor matrices and metadata
load_factors <- function(model_type, return_type, path_data_fn, tag = "baseline") {
  
  # Load all base factor files
  NT   <- read_mat_named(path_data_fn, "nontraded.csv")
  BD_D <- read_mat_named(path_data_fn, "traded_bond_duration_tmt.csv")
  BD_E <- read_mat_named(path_data_fn, "traded_bond_excess.csv")
  EQ_T <- read_mat_named(path_data_fn, "traded_equity.csv")
  
  # Select bond factors based on return type
  bond_factors <- if (return_type == "duration") BD_D else BD_E
  
  # Build factor configuration based on model type
  result <- switch(
    model_type,
    
    # Bond only model
    bond = list(
      f1          = NT,
      f2          = bond_factors,
      f_all_raw   = cbind(NT, bond_factors, EQ_T),
      n_nontraded = ncol(NT),
      n_bondfac   = ncol(bond_factors),
      n_stockfac  = NULL,
      nontraded_names = get_names(NT),
      bond_names      = get_names(bond_factors),
      stock_names     = NULL,
      all_factor_names = c(get_names(NT), get_names(bond_factors))
    ),
    
    # Stock only model
    stock = list(
      f1          = NT,
      f2          = EQ_T,
      f_all_raw   = cbind(NT, BD_E, EQ_T),
      R           = read_mat(path_data_fn, "equity_anomalies_composite_33.csv"),
      n_nontraded = ncol(NT),
      n_bondfac   = NULL,
      n_stockfac  = ncol(EQ_T),
      nontraded_names = get_names(NT),
      bond_names      = NULL,
      stock_names     = get_names(EQ_T),
      all_factor_names = c(get_names(NT), get_names(EQ_T))
    ),
    
    # Bond + Stock with self-pricing
    bond_stock_with_sp = {
      # Handle credit column override if specified
      f1 <- NT
      if (identical(tag, "credit")) {
        f_credit <- read_mat(path_data_fn, "CREDIT_DJM_Corrected.csv")
        f1[, "CREDIT"] <- f_credit
      }
      
      f2 <- cbind(bond_factors, EQ_T)
      
      list(
        f1          = f1,
        f2          = f2,
        f_all_raw   = cbind(f1, f2),
        n_nontraded = ncol(f1),
        n_bondfac   = ncol(bond_factors),
        n_stockfac  = ncol(EQ_T),
        nontraded_names = get_names(f1),
        bond_names      = get_names(bond_factors),
        stock_names     = get_names(EQ_T),
        all_factor_names = c(get_names(f1), get_names(f2))
      )
    },
    
    # Treasury model
    treasury = {
      b_trd <- bond_factors
      f1 <- cbind(NT, b_trd)
      
      list(
        f1          = f1,
        f2          = NULL,
        f_all_raw   = cbind(NT, b_trd, EQ_T),
        n_nontraded = ncol(NT),
        n_bondfac   = ncol(b_trd),
        n_stockfac  = NULL,
        nontraded_names = get_names(NT),
        bond_names      = get_names(b_trd),
        stock_names     = NULL,
        all_factor_names = c(get_names(NT), get_names(b_trd))
      )
    },
    
    stop("Unsupported model_type: ", model_type, 
         ". Must be one of: bond, stock, bond_stock_with_sp, treasury")
  )
  
  return(result)
}