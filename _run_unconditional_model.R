###############################################################################
## _run_unconditional_model.R - Bayesian Asset Pricing Estimation (Multi-File Support)
## ---------------------------------------------------------------------------
## NEW: Supports multi-file loading for f2 and R parameters
## - Automatically aligns dates across files
## - Auto-infers n_bond_factors for bond_stock_with_sp in multi-file mode
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
main_path      <- "C:/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo"  # Project root
data_folder    <- "data"                                  # Your data subfolder
output_folder  <- "output"                                # Results folder
code_folder    <- "code_base"                             # Helper scripts folder

#### 1.2 Model Configuration --------------------------------------------------
model_type     <- "bond_stock_with_sp"           # Options: "bond", "stock", "bond_stock_with_sp", "treasury"
return_type    <- "excess"             # Options: "excess", "duration"

#### 1.3 Data Files (filenames in data_folder) --------------------------------
# All files MUST have 'date' as first column in YYYY-MM-DD format
# NEW: f2 and R can now be VECTORS of filenames for multi-file mode!

f1             <- "nontraded.csv" # Non-traded factors (or NULL to exclude)

# ---- CHOOSE ONE MODE --------------------------------------------------------

# MODE A: Single file (backward compatible)
# f2             <- "traded_bond_excess.csv"                              # Traded factors
# R              <- "bond_insample_test_assets_50_excess.csv"              # Test assets
# n_bond_factors <- NULL   # Not needed for stock model

# MODE B: Multi-file (NEW!)
f2             <- c("62_drr_factors.csv", "traded_equity.csv")  # Multiple files
R              <- c("bond_insample_test_assets_25_excess.csv",
                    "equity_anomalies_composite_33.csv")
n_bond_factors <- NULL   # Auto-inferred for bond_stock_with_sp!

# MODE B: Multi-file (NEW!)
# f2             <- c("traded_bond_excess.csv")  # Multiple files
# R              <- c("bond_insample_test_assets_50_duration_tmt_tbond.csv")
# n_bond_factors <- NULL   # Auto-inferred for bond_stock_with_sp!

# Frequentist factors (always single file)
fac_freq       <- "frequentist_factors.csv"  # Factors for frequentist models

# -----------------------------------------------------------------------------

#### 1.4 Date Range -----------------------------------------------------------
# Filter data to specific date range (NULL = infer from data)
date_start     <- "1986-01-31"   # e.g., "1990-01-01"
date_end       <- "2022-12-31"   # e.g., "2020-12-31"

#### 1.5 Frequentist Models (REQUIRED) ----------------------------------------
# You MUST specify comparison models. Top, Top-MPR, KNS, RP-PCA are always
# included automatically.
#
# Format: list(ModelName = c("factor1", "factor2", ...))
# All factors must exist in your f1 or f2 files

frequentist_models <- list(
  CAPM = "MKTS",
  CAPMB= "MKTB",
  FF5  = c("MKTS","HML","SMB","DEF","TERM"),
  HKM  = c("MKTS","CPTLT")
)

#### 1.6 MCMC Parameters ------------------------------------------------------
ndraws         <- 25000                     # MCMC iterations
SRscale        <- c(0.20, 0.40, 0.60, 0.80) # Prior SR multipliers
alpha.w        <- 1                         # Beta prior hyperparameter
beta.w         <- 1                         # Beta prior hyperparameter
kappa          <- 0                         # Factor tilt (0 = no tilt)
kappa_fac      <- NULL                      # Factor-specific kappa
drop_draws_pct  <- 0                         # Percentage of initial draws to drop (0-0.5)

#### 1.7 Other Settings -------------------------------------------------------
tag            <- "DRR_61"     # Label for output file (customize as needed)
num_cores      <- length(SRscale)# Parallel processing cores
seed           <- 234            # Random seed for reproducibility
intercept      <- TRUE           # Include linear intercept?
save_flag      <- TRUE           # Save results to .Rdata?
verbose        <- TRUE           #Print progress messages?
fac_to_drop    <- NULL           # List of factor names to exclude
weighting      <- "GLS"          # "GLS" or "OLS"

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
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))  # NEW: Must source this first
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
    
    # Data files (NEW: f2 and R can be vectors!)
    f1            = f1,
    f2            = f2,
    R             = R,
    fac_freq      = fac_freq,
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
    drop_draws_pct = drop_draws_pct,
    
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
  
  
  #### 2.5 Verify Metadata (OPTIONAL TEST) ----------------------------------------
  # Test that metadata was properly created and saved
  if (!is.null(res$saved_path) && file.exists(res$saved_path)) {
    log_message(logger, "")
    log_message(logger, "Verifying metadata structure...")
    
    # Load the saved workspace to verify metadata
    test_env <- new.env()
    load(res$saved_path, envir = test_env)
    
    if (exists("metadata", envir = test_env)) {
      log_message(logger, "[OK] Metadata object exists")
      
      # Check main components
      metadata_test <- get("metadata", envir = test_env)
      components <- c("paths", "data_files", "model_type", "return_type", 
                      "date_start", "date_end", "ndraws", "alpha.w", "beta.w", 
                      "SRscale", "tag", "intercept", "weighting", "frequentist_models")
      
      missing <- components[!components %in% names(metadata_test)]
      if (length(missing) == 0) {
        log_message(logger, "[OK] All expected metadata components present")
      } else {
        log_message(logger, "[WARNING] Missing metadata components: ", paste(missing, collapse = ", "))
      }
      
      # Display key metadata values
      log_message(logger, "")
      log_message(logger, "Key metadata values:")
      log_message(logger, "  Model type: ", metadata_test$model_type)
      log_message(logger, "  Return type: ", metadata_test$return_type)
      log_message(logger, "  MCMC draws: ", metadata_test$ndraws)
      log_message(logger, "  SR scales: ", paste(metadata_test$SRscale, collapse = ", "))
      log_message(logger, "  Date range: ", 
                  ifelse(is.null(metadata_test$date_start), "inferred", metadata_test$date_start),
                  " to ",
                  ifelse(is.null(metadata_test$date_end), "inferred", metadata_test$date_end))
      log_message(logger, "  Tag: ", metadata_test$tag)
      log_message(logger, "  Frequentist models: ", paste(names(metadata_test$frequentist_models), collapse = ", "))
      
    } else {
      log_message(logger, "[ERROR] WARNING: Metadata object not found in saved workspace", level = "ERROR")
    }
    
    # Clean up test environment
    rm(test_env)
    gc()
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