###############################################################################
## _execute_time_varying_estim.R
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
main_path      <- "/Users/ASUS/Dropbox/DJM_replication"   # Project root
data_folder    <- "data"                                  # Your data subfolder
output_folder  <- "output"                                # Results folder
code_folder    <- "code_base"                             # Helper scripts folder

#### 1.2 Model Configuration --------------------------------------------------
model_type     <- "bond"                         # Options: "bond", "stock", "bond_stock_with_sp", "treasury"
return_type    <- "excess"                       # Options: "excess", "duration"

#### 1.3 Data Files (filenames in data_folder) --------------------------------
f1             <- "nontraded.csv"                                  # Non-traded factors

# Multi-file mode
# f2             <- c("traded_bond_excess.csv", "traded_equity.csv")  # Multiple files
# R              <- c("bond_insample_test_assets_50_excess.csv",
#                     "equity_anomalies_composite_33.csv")

f2             <- c("traded_bond_excess.csv")  # Multiple files
R              <- c("bond_insample_test_assets_50_excess.csv")

# Frequentist factors (always single file)
fac_freq       <- "frequentist_factors.csv"  # Factors for frequentist models

# n_bond_factors auto-inferred for multi-file mode
n_bond_factors <- NULL

#### 1.4 Analysis Period (Full Data Range) ------------------------------------
date_start     <- "1986-01-31"   # Start of entire analysis period
date_end       <- "2004-07-31"   # End of entire analysis period

cat("Analysis period: ", date_start, " to ", date_end, "\n\n")

#### 1.5 Time-Varying Parameters ----------------------------------------------

# Initial training window
# OPTION A: Integer (number of months from date_start)
# initial_window <- 222

# OPTION B: Explicit date range (mutually exclusive with integer)
initial_window <- "1986-01-31:2004-06-30"

# Re-estimation frequency
holding_period <- 1  # Re-estimate every 12 months

# Window type
window_type    <- "expanding"  # Options: "expanding" or "rolling"

cat("Initial window : ", initial_window, "\n")
cat("Holding period : ", holding_period, " months\n")
cat("Window type    : ", window_type, "\n\n")

#### 1.6 Frequentist Models ---------------------------------------------------
frequentist_models <- list(
  CAPM  = "MKTS",
  CAPMB = "MKTB"
)

#### 1.7 MCMC Parameters ------------------------------------------------------
ndraws         <- 1000                      # MCMC iterations (use 1000 for testing, 50000 for production)
SRscale        <- c(0.20, 0.40, 0.60, 0.80) # Prior SR multipliers
alpha.w        <- 1                         # Beta prior hyperparameter
beta.w         <- 1                         # Beta prior hyperparameter
kappa          <- 0                         # Factor tilt (0 = no tilt)
kappa_fac      <- NULL                      # Factor-specific kappa

#### 1.8 Other Settings -------------------------------------------------------
tag            <- "ExpandingForward"         # Label for output files
num_cores      <- length(SRscale)            # Parallel processing cores (one per psi)
seed           <- 234                        # Random seed for reproducibility
intercept      <- TRUE                       # Include linear intercept?
save_flag      <- TRUE                       # Save individual window results to .Rdata?
verbose        <- TRUE                       # Print progress messages?
fac_to_drop    <- NULL                       # List of factor names to exclude
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
    weighting     = weighting
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

###############################################################################
## 5. INSPECT COMBINED RESULTS
###############################################################################

cat("\n")
cat("========================================\n")
cat("COMBINED RESULTS INSPECTION\n")
cat("========================================\n\n")

# Check structure
cat("--- Combined Results Structure ---\n")
cat("Top-level elements:\n")
print(names(combined_results))
cat("\n")

# Check metadata
cat("--- Metadata ---\n")
cat("Window type       :", combined_results$metadata$window_type, "\n")
cat("Holding period    :", combined_results$metadata$holding_period, "months\n")
cat("Total windows     :", combined_results$metadata$n_windows_total, "\n")
cat("Successful windows:", combined_results$metadata$n_windows_success, "\n")
if (combined_results$metadata$n_windows_failed > 0) {
  cat("Failed windows    :", combined_results$metadata$n_windows_failed, 
      "(IDs:", paste(combined_results$metadata$failed_window_ids, collapse = ", "), ")\n")
}
cat("\n")

# Inspect weights
cat("--- Available Models (Weights) ---\n")
cat("Models: ", paste(names(combined_results$weights), collapse = ", "), "\n\n")

# Sample BMA-80% weights (first 5 dates, first 10 assets)
if ("BMA-80%" %in% names(combined_results$weights)) {
  cat("--- Sample: BMA-80% Weights ---\n")
  cat("Dimensions:", paste(dim(combined_results$weights$`BMA-80%`), collapse = " x "), "\n")
  cat("First 5 dates, first 10 columns:\n")
  print(head(combined_results$weights$`BMA-80%`[, 1:min(11, ncol(combined_results$weights$`BMA-80%`))], 5))
  cat("\n")
}

# Sample KNS weights
if ("KNS" %in% names(combined_results$weights)) {
  cat("--- Sample: KNS Weights ---\n")
  cat("Dimensions:", paste(dim(combined_results$weights$KNS), collapse = " x "), "\n")
  cat("First 5 dates, first 10 columns:\n")
  print(head(combined_results$weights$KNS[, 1:min(11, ncol(combined_results$weights$KNS))], 5))
  cat("\n")
}

# Top factors over time
cat("--- Top Factors (BMA-80%, psi4) ---\n")
cat("First 5 dates:\n")
print(head(combined_results$top_factors[, c("date", "psi4_1", "psi4_2", "psi4_3", "psi4_4", "psi4_5")], 5))
cat("\n")

# Gammas over time
if ("BMA-80%" %in% names(combined_results$gammas)) {
  cat("--- Sample: BMA-80% Gammas ---\n")
  cat("Dimensions:", paste(dim(combined_results$gammas$`BMA-80%`), collapse = " x "), "\n")
  cat("First 5 dates, first 10 factors:\n")
  print(head(combined_results$gammas$`BMA-80%`[, 1:min(11, ncol(combined_results$gammas$`BMA-80%`))], 5))
  cat("\n")
}

###############################################################################
## 6. VERIFY SAVED FILES
###############################################################################

cat("\n")
cat("========================================\n")
cat("FILE VERIFICATION\n")
cat("========================================\n\n")

time_varying_dir <- file.path(output_folder, "time_varying")

if (dir.exists(time_varying_dir)) {
  cat("Combined results directory:", time_varying_dir, "\n\n")
  
  # List CSV files
  csv_files <- list.files(time_varying_dir, pattern = "\\.csv$", full.names = FALSE)
  cat("CSV files created (", length(csv_files), "):\n")
  for (f in csv_files) {
    cat("  ", f, "\n")
  }
  cat("\n")
  
  # List RDS file
  rds_files <- list.files(time_varying_dir, pattern = "\\.rds$", full.names = FALSE)
  if (length(rds_files) > 0) {
    cat("RDS file created:\n")
    for (f in rds_files) {
      fpath <- file.path(time_varying_dir, f)
      cat("  ", f, " (", round(file.info(fpath)$size / 1024, 2), " KB)\n")
    }
  }
  cat("\n")
  
  # Check individual window .Rdata files in main output folder
  rdata_pattern <- sprintf("SS_%s_%s.*%s.*\\.Rdata$", return_type, model_type, tag)
  rdata_files <- list.files(output_folder, pattern = rdata_pattern, full.names = FALSE)
  cat("Individual window .Rdata files (", length(rdata_files), "):\n")
  if (length(rdata_files) > 0) {
    cat("  First 3:\n")
    for (f in head(rdata_files, 3)) {
      cat("    ", f, "\n")
    }
    if (length(rdata_files) > 3) {
      cat("    ... and", length(rdata_files) - 3, "more\n")
    }
  }
  
} else {
  cat("WARNING: Combined results directory not found:", time_varying_dir, "\n")
}

###############################################################################
## 7. SUMMARY
###############################################################################

cat("\n")
cat("========================================\n")
cat("EXECUTION SUMMARY\n")
cat("========================================\n")
cat("Success: All estimations completed and results saved\n")
cat("\n")
cat("Output locations:\n")
cat("  Individual windows:", file.path(output_folder), "\n")
cat("  Combined results  :", file.path(output_folder, "time_varying"), "\n")
cat("\n")
cat("Next steps:\n")
cat("  1. Review combined CSVs in time_varying/ folder\n")
cat("  2. Load ALL_RESULTS.rds for comprehensive analysis:\n")
cat("     combined <- readRDS('", file.path(time_varying_dir, 
                                            sprintf("SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s_ALL_RESULTS.rds",
                                                    return_type, model_type, trunc(alpha.w), trunc(beta.w), tag)), 
    "')\n", sep = "")
cat("========================================\n\n")

gc()
cat("Execution script completed.\n")