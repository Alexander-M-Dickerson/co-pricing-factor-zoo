#!/usr/bin/env Rscript
###############################################################################
## _run_all_conditional.R - Run Both Conditional (Time-Varying) Models
## ---------------------------------------------------------------------------
## This script runs 2 conditional models in parallel:
##
##   1. ExpandingForward  - Expanding windows forward in time (reverse_time = FALSE)
##   2. ExpandingBackward - Expanding windows backward in time (reverse_time = TRUE)
##
## Both models use identical settings except for the time direction.
## They run in parallel using 4 cores each (8 cores total).
##
## USAGE:
##   From R:
##     source("_run_all_conditional.R")
##
##   From terminal:
##     Rscript _run_all_conditional.R
##
###############################################################################

cat("\n")
cat("########################################################################\n")
cat("##  CONDITIONAL (TIME-VARYING) MODEL ESTIMATION\n")
cat("########################################################################\n")
cat(sprintf("##  Started: %s\n", Sys.time()))
cat("##  Running: ExpandingForward + ExpandingBackward in parallel\n")
cat("##  Cores:   4 per model (8 total)\n")
cat("########################################################################\n\n")

gc()

###############################################################################
## 1. CONFIGURATION (SHARED BY BOTH MODELS)
###############################################################################

main_path      <- getwd()
data_folder    <- "data"
output_folder  <- "output"
code_folder    <- "code_base"

# Model settings (same for both)
model_type     <- "bond_stock_with_sp"
return_type    <- "excess"

# Data files
f1             <- "nontraded.csv"
f2             <- c("traded_bond_excess.csv", "traded_equity.csv")
R              <- c("bond_insample_test_assets_50_excess.csv",
                    "equity_anomalies_composite_33.csv")
n_bond_factors <- NULL
fac_freq       <- "frequentist_factors.csv"

# Date range
date_start     <- "1986-01-31"
date_end       <- "2022-12-31"

# Time-varying parameters
initial_window <- 222
holding_period <- 12
window_type    <- "expanding"

# Frequentist models
frequentist_models <- list(
  CAPM  = "MKTS",
  CAPMB = "MKTB",
  FF5   = c("MKTS", "SMB", "HML", "DEF", "TERM"),
  HKM   = c("MKTS", "CPTLT")
)

# MCMC parameters
ndraws         <- 50000
drop_draws_pct <- 0
SRscale        <- c(0.20, 0.40, 0.60, 0.80)
alpha.w        <- 1
beta.w         <- 1
kappa          <- 0
kappa_fac      <- NULL

# Other settings
num_cores      <- 4
seed           <- 234
intercept      <- TRUE
save_flag      <- FALSE
save_csv_flag  <- FALSE
verbose        <- TRUE
fac_to_drop    <- NULL
weighting      <- "GLS"

###############################################################################
## 2. SETUP
###############################################################################

setwd(main_path)

if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)
logs_folder <- file.path(output_folder, "logs")
if (!dir.exists(logs_folder)) dir.create(logs_folder, recursive = TRUE)

# Source helper scripts
source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))
source(file.path(code_folder, "run_time_varying_estimation.R"))

###############################################################################
## 3. GENERATE SCRIPTS FOR PARALLEL EXECUTION
###############################################################################

generate_script <- function(reverse_time, tag) {
  sprintf('
###############################################################################
## Auto-generated: %s
###############################################################################

gc()

main_path      <- "%s"
data_folder    <- "data"
output_folder  <- "output"
code_folder    <- "code_base"

model_type     <- "bond_stock_with_sp"
return_type    <- "excess"

f1             <- "nontraded.csv"
f2             <- c("traded_bond_excess.csv", "traded_equity.csv")
R              <- c("bond_insample_test_assets_50_excess.csv",
                    "equity_anomalies_composite_33.csv")
n_bond_factors <- NULL
fac_freq       <- "frequentist_factors.csv"

date_start     <- "1986-01-31"
date_end       <- "2022-12-31"

initial_window <- 222
holding_period <- 12
window_type    <- "expanding"
reverse_time   <- %s

frequentist_models <- list(
  CAPM  = "MKTS",
  CAPMB = "MKTB",
  FF5   = c("MKTS", "SMB", "HML", "DEF", "TERM"),
  HKM   = c("MKTS", "CPTLT")
)

ndraws         <- %d
drop_draws_pct <- 0
SRscale        <- c(0.20, 0.40, 0.60, 0.80)
alpha.w        <- 1
beta.w         <- 1
kappa          <- 0
kappa_fac      <- NULL

tag            <- "%s"
num_cores      <- 4
seed           <- 234
intercept      <- TRUE
save_flag      <- FALSE
save_csv_flag  <- FALSE
verbose        <- TRUE
fac_to_drop    <- NULL
weighting      <- "GLS"

setwd(main_path)
if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)
logs_folder <- file.path(output_folder, "logs")
if (!dir.exists(logs_folder)) dir.create(logs_folder, recursive = TRUE)

source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))
source(file.path(code_folder, "run_time_varying_estimation.R"))

cat("\\n========================================\\n")
cat("RUNNING: %s\\n")
cat("========================================\\n\\n")

time_varying_results <- run_time_varying_estimation(
  main_path          = main_path,
  data_folder        = data_folder,
  output_folder      = output_folder,
  code_folder        = code_folder,
  model_type         = model_type,
  return_type        = return_type,
  f1                 = f1,
  f2                 = f2,
  R                  = R,
  fac_freq           = fac_freq,
  n_bond_factors     = n_bond_factors,
  date_start         = date_start,
  date_end           = date_end,
  initial_window     = initial_window,
  holding_period     = holding_period,
  window_type        = window_type,
  reverse_time       = reverse_time,
  frequentist_models = frequentist_models,
  ndraws             = ndraws,
  drop_draws_pct     = drop_draws_pct,
  SRscale            = SRscale,
  alpha.w            = alpha.w,
  beta.w             = beta.w,
  kappa              = kappa,
  kappa_fac          = kappa_fac,
  tag                = tag,
  num_cores          = num_cores,
  seed               = seed,
  intercept          = intercept,
  save_flag          = save_flag,
  save_csv_flag      = save_csv_flag,
  fac_to_drop        = fac_to_drop,
  weighting          = weighting,
  verbose            = verbose
)

cat("\\n========================================\\n")
cat("COMPLETE: %s\\n")
cat("========================================\\n")
',
    tag, main_path, toupper(as.character(reverse_time)), ndraws, tag, tag, tag
  )
}

###############################################################################
## 4. RUN BOTH MODELS IN PARALLEL
###############################################################################

cat("Launching both models in parallel...\n\n")

# Generate scripts
script_forward  <- generate_script(reverse_time = FALSE, tag = "ExpandingForward")
script_backward <- generate_script(reverse_time = TRUE,  tag = "ExpandingBackward")

# Write to temp files
temp_forward  <- file.path(main_path, ".temp_expanding_forward.R")
temp_backward <- file.path(main_path, ".temp_expanding_backward.R")

writeLines(script_forward,  temp_forward)
writeLines(script_backward, temp_backward)

# Log files
log_forward  <- file.path(output_folder, "log_expanding_forward.txt")
log_backward <- file.path(output_folder, "log_expanding_backward.txt")

# Launch both in background
cat("  [1] ExpandingForward  -> ", log_forward, "\n")
system(sprintf('Rscript "%s" > "%s" 2>&1 &', temp_forward, log_forward), wait = FALSE)

Sys.sleep(2)

cat("  [2] ExpandingBackward -> ", log_backward, "\n")
system(sprintf('Rscript "%s" > "%s" 2>&1 &', temp_backward, log_backward), wait = FALSE)

cat("\n")
cat("========================================\n")
cat("Both models now running in parallel\n")
cat("========================================\n")
cat("  Cores per model: 4\n")
cat("  Total cores:     8\n")
cat("  MCMC draws:      ", ndraws, "\n")
cat("\n")
cat("Monitor progress:\n")
cat("  tail -f ", log_forward, "\n")
cat("  tail -f ", log_backward, "\n")
cat("\n")
cat("Waiting for completion...\n")

# Wait for both to complete
start_time <- Sys.time()
all_done <- FALSE

while (!all_done) {
  Sys.sleep(60)  # Check every minute

  done_forward <- FALSE
  done_backward <- FALSE

  if (file.exists(log_forward)) {
    log_text <- paste(readLines(log_forward, warn = FALSE), collapse = "\n")
    if (grepl("COMPLETE: ExpandingForward|Error|error|ERROR", log_text)) {
      done_forward <- TRUE
    }
  }

  if (file.exists(log_backward)) {
    log_text <- paste(readLines(log_backward, warn = FALSE), collapse = "\n")
    if (grepl("COMPLETE: ExpandingBackward|Error|error|ERROR", log_text)) {
      done_backward <- TRUE
    }
  }

  elapsed <- difftime(Sys.time(), start_time, units = "hours")
  status_f <- if (done_forward) "DONE" else "running"
  status_b <- if (done_backward) "DONE" else "running"

  cat(sprintf("\r  Forward: %-8s | Backward: %-8s | Elapsed: %.1f hours    ",
              status_f, status_b, as.numeric(elapsed)))

  if (done_forward && done_backward) {
    all_done <- TRUE
  }

  # Timeout after 12 hours
  if (as.numeric(elapsed) > 12) {
    cat("\n  WARNING: Timeout reached (12 hours)\n")
    all_done <- TRUE
  }
}

# Cleanup temp scripts
if (file.exists(temp_forward))  unlink(temp_forward)
if (file.exists(temp_backward)) unlink(temp_backward)

cat("\n\n")
cat("########################################################################\n")
cat("##  CONDITIONAL MODEL ESTIMATION COMPLETE\n")
cat(sprintf("##  Finished: %s\n", Sys.time()))
cat(sprintf("##  Total time: %.2f hours\n", as.numeric(difftime(Sys.time(), start_time, units = "hours"))))
cat("########################################################################\n")
