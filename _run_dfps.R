#!/usr/bin/env Rscript
###############################################################################
## _run_dfps.R - Bayesian Asset Pricing Estimation (Extensible Version)
## ---------------------------------------------------------------------------
## Maximum Extensibility - NO Hard-Coded Data
##
## This script demonstrates how to run Bayesian asset pricing estimation with
## your own custom data. All data must be provided by the user.
##
## INSTRUCTIONS:
##   - Configure all parameters in Section 1 below
##   - Place your data files in the data_folder directory
##   - All data files MUST have 'date' as first column (YYYY-MM-DD format)
##   - Specify frequentist models for comparison (REQUIRED)
###############################################################################

gc()

###############################################################################
## SECTION 1: USER CONFIGURATION (EDIT HERE)
###############################################################################

#### 1.1 Paths ----------------------------------------------------------------
main_path      <- "/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo" # Project root
data_folder    <- "data"                                  # Your data subfolder
output_folder  <- "output"                                # Results folder
code_folder    <- "code_base"                             # Helper scripts folder

#### 1.2 Model Configuration --------------------------------------------------
model_type     <- "stock"           # Options: "bond", "stock", "bond_stock_with_sp", "treasury"
return_type    <- "excess"          # Options: "excess", "duration"

#### 1.3 Data Files (filenames in data_folder) --------------------------------
# All files MUST have 'date' as first column in YYYY-MM-DD format

f1             <- "nontraded.csv"                                  # Non-traded factors
f2             <- "traded_equity.csv"                              # Traded factors  
R              <- "equity_anomalies_composite_33.csv"              # Test assets (returns)

# For bond_stock_with_sp only: How many of f2 columns are bond factors?
# (Bond factors MUST come first, rest are stock factors)
n_bond_factors <- NULL   # e.g., 10 means first 10 columns of f2 are bonds

#### 1.4 Date Range -----------------------------------------------------------
# Filter data to specific date range (NULL = infer from data)
date_start     <- NULL   # e.g., "1990-01-01"
date_end       <- NULL   # e.g., "2020-12-31"

#### 1.5 Frequentist Models (REQUIRED) ----------------------------------------
# You MUST specify comparison models. Top, Top-MPR, KNS, RP-PCA are always
# included automatically.
#
# Format: list(ModelName = c("factor1", "factor2", ...))
# All factors must exist in your f1 or f2 files

frequentist_models <- list(
  #CAPM = "MKT",
  CAPM= "MKTS"
  #FF3  = c("MKT", "SMB", "HML"),
  #FF5  = c("MKT", "SMB", "HML", "RMW", "CMA")
)

# More examples:
# frequentist_models <- list(
#   CAPM = "MKTS",
#   Q4   = c("MKTS", "ME", "IA", "ROE"),
#   HXZ4 = c("MKTS", "ME", "IA", "ROE")
# )

#### 1.6 MCMC Parameters ------------------------------------------------------
ndraws         <- 1000                     # MCMC iterations
SRscale        <- c(0.20, 0.40, 0.60, 0.80) # Prior SR multipliers
alpha.w        <- 1                         # Beta prior hyperparameter
beta.w         <- 1                         # Beta prior hyperparameter
kappa          <- 0                         # Factor tilt (0 = no tilt)
kappa_fac      <- NULL                      # Factor-specific kappa

#### 1.7 Other Settings -------------------------------------------------------
tag            <- "baseline"    # Label for output file (customize as needed)
num_cores      <- 4             # Parallel processing cores
seed           <- 234           # Random seed for reproducibility
intercept      <- TRUE          # Include linear intercept?
save_flag      <- TRUE          # Save results to .Rdata?
verbose        <- TRUE          # Print progress messages?
fac_to_drop    <- NULL          # List of factor names to exclude
weighting      <- "GLS"         # "GLS" or "OLS"

###############################################################################
## SECTION 2: EXECUTION (DO NOT EDIT BELOW)
###############################################################################

#### 2.1 Setup ----------------------------------------------------------------
setwd(main_path)

if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)

# Create logs subfolder
logs_folder <- file.path(output_folder, "logs")
if (!dir.exists(logs_folder)) dir.create(logs_folder, recursive = TRUE)

#### 2.2 Initialize Logging ---------------------------------------------------
source(file.path(code_folder, "logging_helpers.R"))

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
log_file  <- file.path(logs_folder, sprintf("run_mcmc_%s.log", timestamp))

logger <- init_logger(log_file)

log_message(logger, "Starting Bayesian MCMC estimation")
log_message(logger, "Log file: ", log_file)
log_message(logger, "Main path: ", main_path)
log_message(logger, "Output folder: ", output_folder)

#### 2.3 Source Project Code --------------------------------------------------
log_message(logger, "Sourcing project code...")
source(file.path(code_folder, "run_bayesian_mcmc.R"), chdir = TRUE)

#### 2.4 Run MCMC -------------------------------------------------------------
log_message(logger, "Starting MCMC run...")

gc()
tryCatch({
  res <- run_bayesian_mcmc(
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
    n_bond_factors = n_bond_factors,
    
    # Date range
    date_start    = date_start,
    date_end      = date_end,
    
    # Frequentist models (REQUIRED)
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
    seed          = seed,
    intercept     = intercept,
    save_flag     = save_flag,
    verbose       = verbose,
    fac_to_drop   = fac_to_drop,
    weighting     = weighting
  )
  
  log_message(logger, "MCMC completed successfully")
  if (!is.null(res$saved_path)) {
    log_message(logger, "Results saved to: ", res$saved_path)
  }
  
}, error = function(e) {
  log_message(logger, "ERROR: ", e$message, level = "ERROR")
  close_logger(logger)
  stop(e)
})

gc()
log_message(logger, "Script completed")

# Close logger
close_logger(logger)

###############################################################################
## USAGE EXAMPLES
###############################################################################

# Example 1: Bond Model
# ----------------------
# model_type <- "bond"
# return_type <- "excess"
# f1 <- "nontraded_factors.csv"
# f2 <- "bond_factors.csv"
# R  <- "bond_portfolios.csv"
# frequentist_models <- list(
#   CAPM = "MKTB",
#   FF5  = c("MKTB", "TERM", "DEF", "LIQ", "VOL")
# )


# Example 2: Stock Model
# -----------------------
# model_type <- "stock"
# return_type <- "excess"
# f1 <- "nontraded_factors.csv"
# f2 <- "stock_factors.csv"
# R  <- "stock_portfolios.csv"
# frequentist_models <- list(
#   CAPM = "MKTS",
#   FF5  = c("MKTS", "SMB", "HML", "RMW", "CMA")
# )


# Example 3: Bond + Stock with Self-Pricing
# -------------------------------------------
# model_type <- "bond_stock_with_sp"
# f1 <- "nontraded_factors.csv"
# f2 <- "combined_factors.csv"  # First 8 cols are bonds, rest are stocks
# R  <- "combined_portfolios.csv"
# n_bond_factors <- 8  # REQUIRED: specifies split point
# frequentist_models <- list(
#   CAPM_B = "MKTB",
#   CAPM_S = "MKTS",
#   Combined = c("MKTB", "MKTS", "SMB", "HML")
# )


# Example 4: Custom Date Range
# ------------------------------
# date_start <- "2000-01-01"
# date_end   <- "2020-12-31"


# Example 5: Custom Tag
# ----------------------
# tag <- "robustness_check_1"
# Output: excess_bond_alpha.w=1_beta.w=1_kappa=0_robustness_check_1.Rdata