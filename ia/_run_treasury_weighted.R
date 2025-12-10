#!/usr/bin/env Rscript
###############################################################################
## _run_treasury_weighted.R - Treasury Model with DR-Tilt Kappa Weights
## ---------------------------------------------------------------------------
##
## NOTE: This standalone script is deprecated. Use the integrated pipeline:
##   Rscript ia/_run_ia_estimation.R --models=7
##
## This script runs the treasury model with kappa weights loaded from w_all.rds.
## The weights provide DR-tilt (discount rate tilt) to the factor selection.
##
## INPUT:
##   ia/data/w_all.rds - Named numeric vector of kappa weights
##
## OUTPUT:
##   output/unconditional/treasury/
##     excess_treasury_alpha.w=1_beta.w=1_kappa=weighted_bond_treasury.Rdata
##
## USAGE:
##   From R:
##     source("ia/_run_treasury_weighted.R")
##
##   From terminal:
##     Rscript ia/_run_treasury_weighted.R [--ndraws=N]
##
###############################################################################

gc()

###############################################################################
## SECTION 0: SETUP
###############################################################################

# Ensure we're in project root
if (basename(getwd()) == "ia") {
  setwd("..")
}
main_path <- getwd()

# Verify location
if (!file.exists("code_base/run_bayesian_mcmc.R")) {
  stop("Please run this script from the project root directory")
}

###############################################################################
## SECTION 1: CONFIGURATION
###############################################################################

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)
ndraws <- 50000  # default

for (arg in args) {
  if (grepl("^--ndraws=", arg)) {
    ndraws <- as.integer(sub("--ndraws=", "", arg))
  }
}

cat("\n")
cat("========================================\n")
cat("TREASURY WEIGHTED ESTIMATION\n")
cat("========================================\n")
cat("  ndraws: ", ndraws, "\n")
cat("  Started: ", as.character(Sys.time()), "\n")
cat("========================================\n\n")

# Paths
data_folder    <- "data"
output_folder  <- "output/unconditional"
code_folder    <- "code_base"
ia_data_folder <- "ia/data"

# Model configuration
model_type     <- "treasury"
return_type    <- "excess"
tag            <- "bond_treasury"

# Data files (same as base treasury model)
f1             <- "nontraded.csv"
f2             <- 'c("traded_bond_excess.csv")'
R              <- 'c("bond_insample_test_assets_50_duration_tmt_tbond.csv")'
fac_freq       <- "frequentist_factors.csv"

# MCMC parameters
SRscale        <- c(0.20, 0.40, 0.60, 0.80)
alpha.w        <- 1
beta.w         <- 1
drop_draws_pct <- 0
seed           <- 1234
intercept      <- TRUE
save_flag      <- TRUE
verbose        <- TRUE
num_cores      <- max(1, parallel::detectCores() - 1)

# Frequentist models for comparison
frequentist_models <- list(
  CAPM  = c("MKTB"),
  CAPMB = c("MKTB", "MKTBD"),
  HKM   = c("MKTB", "DEF", "TERM"),
  FF5   = c("MKTB", "SZE", "HMLB", "CRF", "DRF")
)

###############################################################################
## SECTION 2: LOAD KAPPA WEIGHTS
###############################################################################

w_all_path <- file.path(ia_data_folder, "w_all.rds")

if (!file.exists(w_all_path)) {
  stop("Kappa weights file not found: ", w_all_path,
       "\n\nPlease create w_all.rds with the DR-tilt weights.")
}

cat("Loading kappa weights from: ", w_all_path, "\n")
w_all <- readRDS(w_all_path)

if (!is.numeric(w_all) || is.null(names(w_all))) {
  stop("w_all.rds must contain a named numeric vector")
}

cat("  Loaded ", length(w_all), " weights\n")
cat("  Factor names: ", paste(head(names(w_all), 5), collapse = ", "),
    if (length(w_all) > 5) ", ..." else "", "\n")
cat("  Weight range: [", min(w_all), ", ", max(w_all), "]\n\n")

# Set kappa parameters
kappa     <- w_all
kappa_fac <- names(w_all)

###############################################################################
## SECTION 3: SOURCE HELPERS AND RUN ESTIMATION
###############################################################################

cat("Sourcing helper files...\n")
source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))

cat("\nStarting MCMC estimation...\n")
cat("  This may take 10-20 minutes depending on hardware.\n\n")

start_time <- Sys.time()

tryCatch({
  res <- run_bayesian_mcmc(
    main_path          = main_path,
    data_folder        = data_folder,
    output_folder      = output_folder,
    code_folder        = code_folder,
    model_type         = model_type,
    return_type        = return_type,
    f1                 = f1,
    f2                 = eval(parse(text = f2)),
    R                  = eval(parse(text = R)),
    fac_freq           = fac_freq,
    n_bond_factors     = NULL,  # Not needed for treasury
    date_start         = NULL,
    date_end           = NULL,
    frequentist_models = frequentist_models,
    ndraws             = ndraws,
    SRscale            = SRscale,
    alpha.w            = alpha.w,
    beta.w             = beta.w,
    kappa              = kappa,
    kappa_fac          = kappa_fac,
    drop_draws_pct     = drop_draws_pct,
    tag                = tag,
    num_cores          = num_cores,
    seed               = seed,
    intercept          = intercept,
    save_flag          = save_flag,
    verbose            = verbose,
    fac_to_drop        = NULL,
    weighting          = "GLS"
  )

  end_time <- Sys.time()
  elapsed <- difftime(end_time, start_time, units = "mins")

  cat("\n")
  cat("========================================\n")
  cat("ESTIMATION COMPLETE\n")
  cat("========================================\n")
  cat("  Results saved to: ", res$saved_path, "\n")
  cat("  Elapsed time: ", round(elapsed, 1), " minutes\n")
  cat("  Finished: ", as.character(end_time), "\n")
  cat("========================================\n")

}, error = function(e) {
  cat("\n")
  cat("========================================\n")
  cat("ERROR IN ESTIMATION\n")
  cat("========================================\n")
  cat(e$message, "\n")
  cat("========================================\n")
  stop(e)
})
