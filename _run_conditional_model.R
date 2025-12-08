###############################################################################
## _run_conditional_model.R
## 
## Execution script for time-varying Bayesian asset pricing estimation
## This script runs run_time_varying_estimation() to perform expanding or
## rolling window estimation over multiple time periods
###############################################################################

cat("\n")
cat("========================================\n")
cat("TIME-VARYING ESTIMATION EXECUTION\n")
cat("========================================\n\n")

gc()

###############################################################################
## 1. CONFIGURATION
###############################################################################

#### 1.1 Paths ----------------------------------------------------------------
main_path      <- "/home/aldi/DJM_replication_2"          # Project root
data_folder    <- "data"                                  # Your data subfolder
output_folder  <- "output"                                # Results folder
code_folder    <- "code_base"                             # Helper scripts folder

#### 1.2 Model Configuration --------------------------------------------------
model_type     <- "stock"                         # Options: "bond", "stock", "bond_stock_with_sp", "treasury"
return_type    <- "excess"                        # Options: "excess", "duration"

#### 1.3 Data Files (filenames in data_folder) --------------------------------
f1             <- NULL                           # Non-traded factors

# Multi-file mode
# f2             <- c("traded_bond_excess.csv", "traded_equity.csv")  # Multiple files
# R              <- c("bond_insample_test_assets_50_excess.csv",
#                     "equity_anomalies_composite_33.csv")

f2             <- c("jkp_60_test1.csv")  # Multiple files
R              <- c("jkp_30_test1.csv")

# f2             <- c("traded_equity.csv")  # Multiple files
# R              <- c("equity_anomalies_composite_33.csv")

# Frequentist factors (always single file)
fac_freq       <- "frequentist_factors.csv"  # Factors for frequentist models

# n_bond_factors auto-inferred for multi-file mode
n_bond_factors <- NULL

#### 1.4 Analysis Period (Full Data Range) ------------------------------------
date_start     <- "1986-01-31"   # Start of entire analysis period
date_end       <- "2022-12-31"   # End of entire analysis period

cat("Analysis period: ", date_start, " to ", date_end, "\n\n")

#### 1.5 Time-Varying Parameters ----------------------------------------------

# Initial training window
# OPTION A: Integer (number of months from date_start)
initial_window <- 222

# OPTION B: Explicit date range (mutually exclusive with integer)
# initial_window <- "1986-01-31:2004-06-30"

# Re-estimation frequency
holding_period <- 12  # Re-estimate every 12 months

# Window type
window_type    <- "expanding"  # Options: "expanding" or "rolling"

# Time direction
reverse_time   <- FALSE  # If TRUE, expand windows backward from date_end
                         # Forward: [1986→2004], [1986→2005], ..., [1986→2022]
                         # Backward: [2004→2022], [2003→2022], ..., [1986→2022]

cat("Initial window : ", initial_window, "\n")
cat("Holding period : ", holding_period, " months\n")
cat("Window type    : ", window_type, "\n")
cat("Reverse time   : ", reverse_time, "\n\n")

#### 1.6 Frequentist Models ---------------------------------------------------
frequentist_models <- list(
  CAPM  = "MKTS",
  CAPMB = "MKTB",
  FF5   = c("MKTS","SMB","HML","DEF","TERM"),
  HKM   = c("MKTS","CPTLT")
)

#### 1.7 MCMC Parameters ------------------------------------------------------
ndraws         <- 50000                      # MCMC iterations (use 1000 for testing, 50000 for production)
drop_draws_pct <- 0
SRscale        <- c(0.20, 0.40, 0.60, 0.80) # Prior SR multipliers
alpha.w        <- 1                         # Beta prior hyperparameter
beta.w         <- 1                         # Beta prior hyperparameter
kappa          <- 0                         # Factor tilt (0 = no tilt)
kappa_fac      <- NULL                      # Factor-specific kappa

#### 1.8 Other Settings -------------------------------------------------------
tag            <- "JKP_1"         # Label for output files
num_cores      <- length(SRscale)            # Parallel processing cores (one per psi)
seed           <- 234                        # Random seed for reproducibility
intercept      <- TRUE                       # Include linear intercept?
save_flag      <- FALSE                      # Save individual window results to .Rdata?
save_csv_flag  <- FALSE
verbose        <- TRUE                       # Print progress messages?
fac_to_drop    <- c("PEAD","PEADB","MOMBS")                       # List of factor names to exclude
weighting      <- "GLS"                      # "GLS" or "OLS"

###############################################################################
## 2. SETUP
###############################################################################

setwd(main_path)

if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)

# Create logs subfolder
logs_folder <- file.path(output_folder, "logs")
if (!dir.exists(logs_folder)) dir.create(logs_folder, recursive = TRUE)

###############################################################################
## 3. SOURCE PROJECT CODE
###############################################################################

cat("Sourcing project code...\n")

# Source helper functions
source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))
source(file.path(code_folder, "insample_asset_pricing_time_varying.R"))
source(file.path(code_folder, "run_bayesian_mcmc_time_varying.R"))

# Source the NEW time-varying estimation wrapper
source(file.path(code_folder, "run_time_varying_estimation.R"))

cat("All code sourced successfully.\n\n")

###############################################################################
## 4. RUN TIME-VARYING ESTIMATION
###############################################################################

cat("Starting time-varying estimation process...\n")
cat("This will execute multiple MCMC estimations.\n")
cat("Progress will be displayed for each window.\n\n")

t_start <- Sys.time()

tryCatch({
  
  combined_results <- run_time_varying_estimation(
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
    
    # Analysis period
    date_start    = date_start,
    date_end      = date_end,
    
    # Time-varying parameters
    initial_window = initial_window,
    holding_period = holding_period,
    window_type    = window_type,
    reverse_time   = reverse_time,

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
    num_cores     = num_cores,
    seed          = seed,
    intercept     = intercept,
    save_flag     = save_flag,
    verbose       = verbose,
    fac_to_drop   = fac_to_drop,
    weighting     = weighting,
    drop_draws_pct = drop_draws_pct
  )
  
  t_end <- Sys.time()
  cat("\n")
  cat("========================================\n")
  cat("EXECUTION COMPLETED SUCCESSFULLY!\n")
  cat("Total time: ", round(difftime(t_end, t_start, units = "mins"), 2), " minutes\n")
  cat("========================================\n\n")
  
}, error = function(e) {
  cat("\n")
  cat("========================================\n")
  cat("ERROR OCCURRED:\n")
  cat("========================================\n")
  cat(e$message, "\n\n")
  cat("Stack trace:\n")
  print(e)
  stop(e)
})
