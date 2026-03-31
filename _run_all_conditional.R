#!/usr/bin/env Rscript
###############################################################################
## _run_all_conditional.R - Run Both Conditional (Time-Varying) Models
## ---------------------------------------------------------------------------
## This script runs 2 conditional models in parallel:
##
## Paper role: Conditional estimation orchestrator for the investing exercise.
## Paper refs: Sec. 3.4; Table 6 Panel B; Figure 7; Appendix D benchmark
##   comparisons; docs/paper/co-pricing-factor-zoo.ai-optimized.md
## Outputs: output/time_varying/bond_stock_with_sp/...ALL_RESULTS.rds and
##   output/logs/
##
##   1. ExpandingForward  - Expanding windows forward in time (reverse_time = FALSE)
##   2. ExpandingBackward - Expanding windows backward in time (reverse_time = TRUE)
##
## Both models use identical settings except for the time direction.
## They run in parallel using 4 cores each (8 cores total).
##
## EXPECTED RUNTIME (per model, 50,000 MCMC draws):
##   - Laptop:  ~20 minutes
##   - Server:  ~6 minutes
##
## PLATFORM: Works on Windows, macOS, and Linux
##
## USAGE:
##   From R:
##     source("_run_all_conditional.R")
##
##   From terminal:
##     Rscript _run_all_conditional.R [options]
##
## OPTIONS:
##   --ndraws=N    Number of MCMC draws (default: 50000, use 5000 for quick test)
##
## LOG FILES:
##   output/logs/
##     log_conditional_ExpandingForward_YYYYMMDD_HHMMSS.txt
##     log_conditional_ExpandingBackward_YYYYMMDD_HHMMSS.txt
##
## OUTPUT FILES:
##   output/time_varying/bond_stock_with_sp/
##     SS_excess_bond_stock_with_sp_..._ExpandingForward_..._ALL_RESULTS.rds
##     SS_excess_bond_stock_with_sp_..._ExpandingBackward_..._ALL_RESULTS.rds
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
## 0. ENVIRONMENT INFO (for replication)
###############################################################################

print_environment_info <- function() {
  cat("========================================\n")
  cat("ENVIRONMENT INFORMATION\n")
  cat("========================================\n")

  # R version
  cat("\nR Version:\n")
  cat("  ", R.version.string, "\n")
  cat("  Platform: ", R.version$platform, "\n")
  cat("  OS:       ", Sys.info()["sysname"], Sys.info()["release"], "\n")

  # Required packages and versions
  cat("\nRequired Package Versions:\n")

  required_packages <- c(
    # Data manipulation
    "lubridate", "dplyr", "tidyr", "purrr", "tibble", "data.table", "rlang",
    # Visualization
    "ggplot2", "RColorBrewer", "scales", "patchwork",
    # Parallel processing
    "parallel", "doParallel", "foreach", "doRNG",
    # Statistics and linear algebra
    "MASS", "Matrix", "matrixStats", "Hmisc", "proxyC",
    # Bayesian estimation
    "BayesianFactorZoo",
    # Output formatting
    "xtable"
  )

  for (pkg in required_packages) {
    if (requireNamespace(pkg, quietly = TRUE)) {
      ver <- as.character(packageVersion(pkg))
      cat(sprintf("  %-15s %s\n", pkg, ver))
    } else {
      cat(sprintf("  %-15s NOT INSTALLED\n", pkg))
    }
  }

  cat("\n========================================\n\n")
}

print_environment_info()

###############################################################################
## 0.5. PARSE COMMAND-LINE ARGUMENTS
###############################################################################

# Default MCMC draws (can be overridden by --ndraws)
DEFAULT_NDRAWS <- 50000

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  result <- list(ndraws = DEFAULT_NDRAWS)

  for (arg in args) {
    if (grepl("^--ndraws=", arg)) {
      result$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (arg == "--help" || arg == "-h") {
      cat("\nUsage: Rscript _run_all_conditional.R [options]\n\n")
      cat("Options:\n")
      cat("  --ndraws=N    Number of MCMC draws (default: 50000, use 5000 for quick test)\n")
      cat("  --help, -h    Show this help message\n\n")
      quit(save = "no", status = 0)
    }
  }

  return(result)
}

cmd_args <- parse_args()

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
ndraws         <- cmd_args$ndraws
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

# Detect operating system for cross-platform compatibility
is_windows <- .Platform$OS.type == "windows"

# Generate timestamp for this run (used for log file names)
RUN_TIMESTAMP <- format(Sys.time(), "%Y%m%d_%H%M%S")

cat("Platform detected:", if (is_windows) "Windows" else "Unix/macOS/Linux", "\n")
cat("Run timestamp:    ", RUN_TIMESTAMP, "\n")
cat("MCMC draws:       ", ndraws, "\n")
if (ndraws != 50000) {
  cat("  (Quick test mode - using fewer draws)\n")
}
cat("\n")

# Source helper scripts
source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))
source(file.path(code_folder, "run_bayesian_mcmc_time_varying.R"))
source(file.path(code_folder, "run_time_varying_estimation.R"))

###############################################################################
## 3. GENERATE SCRIPTS FOR PARALLEL EXECUTION
###############################################################################

generate_script <- function(reverse_time, tag) {
  # Escape backslashes for Windows paths
  main_path_escaped <- gsub("\\\\", "/", main_path)

  sprintf('
###############################################################################
## Auto-generated: %s
###############################################################################

gc()

# Print environment info for replication
cat("\\n========================================\\n")
cat("ENVIRONMENT INFO\\n")
cat("========================================\\n")
cat("R Version: ", R.version.string, "\\n")
cat("Platform:  ", R.version$platform, "\\n")
cat("OS:        ", Sys.info()["sysname"], "\\n")
cat("========================================\\n\\n")

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
source(file.path(code_folder, "data_loading_helpers.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))
source(file.path(code_folder, "run_bayesian_mcmc_time_varying.R"))
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
    tag, main_path_escaped, toupper(as.character(reverse_time)), ndraws, tag, tag, tag
  )
}

###############################################################################
## 4. CROSS-PLATFORM BACKGROUND PROCESS LAUNCHER
###############################################################################

launch_background_process <- function(script_path, log_path, is_windows, working_dir = NULL) {
  # Normalize paths to absolute paths
  script_path <- normalizePath(script_path, winslash = "/", mustWork = FALSE)
  log_path <- normalizePath(log_path, winslash = "/", mustWork = FALSE)

  if (is.null(working_dir)) {
    working_dir <- dirname(script_path)
  }
  working_dir <- normalizePath(working_dir, winslash = "/", mustWork = FALSE)

  if (is_windows) {
    # Windows: use start /B with cmd; must use full Rscript path since child
    # cmd.exe may not have R on its PATH
    rscript_exe <- file.path(R.home("bin"), "Rscript.exe")
    rscript_win <- normalizePath(rscript_exe, winslash = "\\", mustWork = TRUE)
    script_win <- normalizePath(script_path, winslash = "\\", mustWork = FALSE)
    log_win <- normalizePath(log_path, winslash = "\\", mustWork = FALSE)
    work_win <- normalizePath(working_dir, winslash = "\\", mustWork = FALSE)
    cmd <- sprintf('start /B cmd /C "cd /d "%s" && "%s" "%s" > "%s" 2>&1"', work_win, rscript_win, script_win, log_win)
    shell(cmd, wait = FALSE)
  } else {
    # Unix/macOS/Linux: use nohup with explicit bash for reliable backgrounding
    # cd to working directory first, then run Rscript
    cmd <- sprintf('nohup bash -c \'cd "%s" && Rscript "%s" > "%s" 2>&1\' &',
                   working_dir, script_path, log_path)
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE, wait = FALSE)
  }
}

###############################################################################
## 5. RUN BOTH MODELS IN PARALLEL
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

# Log files (in output/logs/ with timestamp)
log_forward  <- file.path(logs_folder, sprintf("log_conditional_ExpandingForward_%s.txt", RUN_TIMESTAMP))
log_backward <- file.path(logs_folder, sprintf("log_conditional_ExpandingBackward_%s.txt", RUN_TIMESTAMP))

# Launch both in background (cross-platform)
cat("  [1] ExpandingForward  -> ", log_forward, "\n")
launch_background_process(temp_forward, log_forward, is_windows, working_dir = main_path)

Sys.sleep(2)

cat("  [2] ExpandingBackward -> ", log_backward, "\n")
launch_background_process(temp_backward, log_backward, is_windows, working_dir = main_path)

cat("\n")
cat("========================================\n")
cat("Both models now running in parallel\n")
cat("========================================\n")
cat("  Cores per model: 4\n")
cat("  Total cores:     8\n")
cat("  MCMC draws:      ", ndraws, "\n")
cat("\n")
cat("Expected runtime per estimation window:\n")
cat("  Laptop: ~20 minutes\n")
cat("  Server: ~6 minutes\n")
cat("\n")
cat("Monitor progress:\n")
if (is_windows) {
  cat("  type ", log_forward, "\n")
  cat("  type ", log_backward, "\n")
} else {
  cat("  tail -f ", log_forward, "\n")
  cat("  tail -f ", log_backward, "\n")
}
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

  elapsed <- difftime(Sys.time(), start_time, units = "mins")
  status_f <- if (done_forward) "DONE" else "running"
  status_b <- if (done_backward) "DONE" else "running"

  cat(sprintf("\r  Forward: %-8s | Backward: %-8s | Elapsed: %.1f min    ",
              status_f, status_b, as.numeric(elapsed)))

  if (done_forward && done_backward) {
    all_done <- TRUE
  }

  # Timeout after 3 hours (generous for slow machines)
  if (as.numeric(elapsed) > 180) {
    cat("\n  WARNING: Timeout reached (3 hours)\n")
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
cat(sprintf("##  Total time: %.1f minutes\n", as.numeric(difftime(Sys.time(), start_time, units = "mins"))))
cat("########################################################################\n")
cat("\n")
cat("LOG FILES:\n")
cat(sprintf("  %s\n", log_forward))
cat(sprintf("  %s\n", log_backward))
cat("\n")
cat("OUTPUT FILES:\n")
cat("  output/time_varying/bond_stock_with_sp/\n")
cat("    SS_excess_bond_stock_with_sp_..._ExpandingForward_..._ALL_RESULTS.rds\n")
cat("    SS_excess_bond_stock_with_sp_..._ExpandingBackward_..._ALL_RESULTS.rds\n")
cat("\n")
