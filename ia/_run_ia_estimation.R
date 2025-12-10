#!/usr/bin/env Rscript
###############################################################################
## _run_ia_estimation.R - Internet Appendix Model Estimation
## ---------------------------------------------------------------------------
## This script runs all models required for the Internet Appendix:
##
##   INTERCEPT = TRUE (with constant):
##     1. bond_intercept      - Bond factors with intercept
##     2. stock_intercept     - Stock factors with intercept
##
##   INTERCEPT = FALSE (no constant):
##     3. bond_no_intercept   - Bond factors without intercept
##     4. stock_no_intercept  - Stock factors without intercept
##     5. joint_no_intercept  - Joint bond+stock without intercept
##
## All models use return_type = "excess"
##
## USAGE:
##   From R:
##     source("ia/_run_ia_estimation.R")
##
##   From terminal:
##     Rscript ia/_run_ia_estimation.R [options]
##
## OPTIONS:
##   --models=1,2,3      Run specific models (comma-separated, default: all)
##   --ndraws=N          Number of MCMC draws (default: 50000)
##   --parallel          Run models in parallel (default)
##   --sequential        Run models sequentially
##   --cores=N           Total available cores (default: auto-detect)
##   --cores-per-model=N Cores per model (default: 4)
##   --dry-run           Show what would be run without executing
##   --list              List all available models and exit
##
## OUTPUT:
##   ia/output/unconditional/{model_type}/
##     {return_type}_{model_type}_alpha.w=1_beta.w=1_kappa=0_{tag}.Rdata
##
###############################################################################

###############################################################################
## SECTION 0: SETUP
###############################################################################

gc()

# Ensure we're in project root (handle both sourcing from root and from ia/)
if (basename(getwd()) == "ia") {
  setwd("..")
}
main_path <- getwd()

# Verify we're in the right place
if (!file.exists("code_base/run_bayesian_mcmc.R")) {
  stop("Please run this script from the project root directory (co-pricing-factor-zoo/)")
}

# Generate timestamp for this run
RUN_TIMESTAMP <- format(Sys.time(), "%Y%m%d_%H%M%S")

# Detect operating system
is_windows <- .Platform$OS.type == "windows"

###############################################################################
## SECTION 1: USER CONFIGURATION
###############################################################################

# Default execution settings
DEFAULT_CORES_PER_MODEL <- 4
DEFAULT_TOTAL_CORES     <- parallel::detectCores() - 1
DEFAULT_NDRAWS          <- 50000
RUN_PARALLEL            <- TRUE
MODELS_TO_RUN           <- 1:5
DRY_RUN                 <- FALSE

###############################################################################
## SECTION 2: MODEL DEFINITIONS
###############################################################################

# Define all 5 IA models
MODEL_CONFIGS <- list(

  # Model 1: Bond with intercept
  list(
    id          = 1,
    name        = "bond_intercept",
    description = "Bond factors WITH intercept (excess returns)",
    model_type  = "bond",
    return_type = "excess",
    intercept   = TRUE,
    tag         = "ia_intercept",
    f2          = 'c("traded_bond_excess.csv")',
    R           = 'c("bond_insample_test_assets_50_excess.csv")'
  ),

  # Model 2: Stock with intercept
  list(
    id          = 2,
    name        = "stock_intercept",
    description = "Stock factors WITH intercept (excess returns)",
    model_type  = "stock",
    return_type = "excess",
    intercept   = TRUE,
    tag         = "ia_intercept",
    f2          = 'c("traded_equity.csv")',
    R           = 'c("equity_anomalies_composite_33.csv")'
  ),

  # Model 3: Bond without intercept
  list(
    id          = 3,
    name        = "bond_no_intercept",
    description = "Bond factors WITHOUT intercept (excess returns)",
    model_type  = "bond",
    return_type = "excess",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    f2          = 'c("traded_bond_excess.csv")',
    R           = 'c("bond_insample_test_assets_50_excess.csv")'
  ),

  # Model 4: Stock without intercept
  list(
    id          = 4,
    name        = "stock_no_intercept",
    description = "Stock factors WITHOUT intercept (excess returns)",
    model_type  = "stock",
    return_type = "excess",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    f2          = 'c("traded_equity.csv")',
    R           = 'c("equity_anomalies_composite_33.csv")'
  ),

  # Model 5: Joint bond+stock without intercept
  list(
    id          = 5,
    name        = "joint_no_intercept",
    description = "Joint bond+stock WITHOUT intercept (excess returns)",
    model_type  = "bond_stock_with_sp",
    return_type = "excess",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    f2          = 'c("traded_bond_excess.csv", "traded_equity.csv")',
    R           = 'c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv")'
  )
)

###############################################################################
## SECTION 3: HELPER FUNCTIONS
###############################################################################

#' Get environment info for logging
get_environment_info <- function() {
  lines <- character()
  lines <- c(lines, "")
  lines <- c(lines, "========================================")
  lines <- c(lines, "INTERNET APPENDIX ESTIMATION")
  lines <- c(lines, "========================================")
  lines <- c(lines, "")
  lines <- c(lines, sprintf("R Version: %s", R.version.string))
  lines <- c(lines, sprintf("Platform: %s", R.version$platform))
  lines <- c(lines, sprintf("OS: %s %s", Sys.info()["sysname"], Sys.info()["release"]))
  lines <- c(lines, "")
  return(lines)
}

#' Get log file path for a model
get_log_path <- function(cfg, main_path, timestamp) {
  logs_dir <- file.path(main_path, "ia", "output", "logs")
  if (!dir.exists(logs_dir)) dir.create(logs_dir, recursive = TRUE)
  file.path(logs_dir, sprintf("log_ia_model_%d_%s_%s.txt", cfg$id, cfg$name, timestamp))
}

#' Print model list
print_model_list <- function() {
  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  INTERNET APPENDIX MODELS\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")

  for (cfg in MODEL_CONFIGS) {
    intercept_str <- if (cfg$intercept) "YES" else "NO"
    cat(sprintf("  [%d] %-25s\n", cfg$id, cfg$name))
    cat(sprintf("      %s\n", cfg$description))
    cat(sprintf("      model_type: %-20s intercept: %s\n",
                cfg$model_type, intercept_str))
    cat("\n")
  }

  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")
}

#' Parse command-line arguments
parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  result <- list(
    models   = MODELS_TO_RUN,
    ndraws   = DEFAULT_NDRAWS,
    parallel = RUN_PARALLEL,
    cores    = DEFAULT_TOTAL_CORES,
    cores_per_model = DEFAULT_CORES_PER_MODEL,
    dry_run  = DRY_RUN,
    list_only = FALSE
  )

  for (arg in args) {
    if (arg == "--list") {
      result$list_only <- TRUE
    } else if (arg == "--parallel") {
      result$parallel <- TRUE
    } else if (arg == "--sequential") {
      result$parallel <- FALSE
    } else if (arg == "--dry-run") {
      result$dry_run <- TRUE
    } else if (grepl("^--models=", arg)) {
      model_str <- sub("^--models=", "", arg)
      result$models <- as.integer(strsplit(model_str, ",")[[1]])
    } else if (grepl("^--ndraws=", arg)) {
      result$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (grepl("^--cores=", arg)) {
      result$cores <- as.integer(sub("^--cores=", "", arg))
    } else if (grepl("^--cores-per-model=", arg)) {
      result$cores_per_model <- as.integer(sub("^--cores-per-model=", "", arg))
    } else if (arg == "--help" || arg == "-h") {
      cat("\nUsage: Rscript ia/_run_ia_estimation.R [options]\n\n")
      cat("Options:\n")
      cat("  --models=1,2,3      Run specific models (comma-separated)\n")
      cat("  --ndraws=N          Number of MCMC draws (default: 50000)\n")
      cat("  --parallel          Run models in parallel (default)\n")
      cat("  --sequential        Run models sequentially\n")
      cat("  --cores=N           Total available cores\n")
      cat("  --cores-per-model=N Cores per model (default: 4)\n")
      cat("  --dry-run           Show what would be run\n")
      cat("  --list              List all available models\n")
      cat("  --help              Show this help message\n\n")
      quit(save = "no", status = 0)
    }
  }

  return(result)
}

#' Generate R script for a single model
generate_model_script <- function(cfg, main_path, cores_per_model, ndraws) {
  main_path_escaped <- gsub("\\\\", "/", main_path)
  env_info <- paste(get_environment_info(), collapse = "\\n")
  intercept_str <- if (cfg$intercept) "TRUE" else "FALSE"

  script <- sprintf('
###############################################################################
## Auto-generated script for IA model: %s
## Generated at: %s
###############################################################################

gc()

cat("%s\\n")
cat("Model: %s\\n")
cat("Intercept: %s\\n")
cat("Started: ", as.character(Sys.time()), "\\n\\n")

#### Paths
main_path      <- "%s"
data_folder    <- "data"
output_folder  <- "ia/output"
code_folder    <- "code_base"

#### Model Configuration
model_type     <- "%s"
return_type    <- "%s"

#### Data Files
f1             <- "nontraded.csv"
f2             <- %s
R              <- %s
n_bond_factors <- NULL
fac_freq       <- "frequentist_factors.csv"

#### Date Range
date_start     <- "1986-01-31"
date_end       <- "2022-12-31"

#### Frequentist Models
frequentist_models <- list(
  CAPM = "MKTS",
  CAPMB= "MKTB",
  FF5  = c("MKTS","HML","SMB","DEF","TERM"),
  HKM  = c("MKTS","CPTLT")
)

#### MCMC Parameters
ndraws         <- %d
SRscale        <- c(0.20, 0.40, 0.60, 0.80)
alpha.w        <- 1
beta.w         <- 1
kappa          <- 0
kappa_fac      <- NULL
drop_draws_pct <- 0

#### Other Settings
tag            <- "%s"
num_cores      <- %d
seed           <- 234
intercept      <- %s
save_flag      <- TRUE
verbose        <- TRUE
fac_to_drop    <- NULL
weighting      <- "GLS"

#### Source helper files
setwd(main_path)

source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))

#### Run the estimation
tryCatch({
  res <- run_bayesian_mcmc(
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
    fac_to_drop        = fac_to_drop,
    weighting          = weighting
  )

  cat("\\n========================================\\n")
  cat("MODEL COMPLETE: %s\\n")
  cat("Results saved to: ", res$saved_path, "\\n")
  cat("Finished: ", as.character(Sys.time()), "\\n")
  cat("========================================\\n")

}, error = function(e) {
  cat("\\n========================================\\n")
  cat("ERROR in model %s:\\n")
  cat(e$message, "\\n")
  cat("========================================\\n")
  stop(e)
})
',
    cfg$name,
    as.character(Sys.time()),
    env_info,
    cfg$name,
    intercept_str,
    main_path_escaped,
    cfg$model_type,
    cfg$return_type,
    cfg$f2,
    cfg$R,
    ndraws,
    cfg$tag,
    cores_per_model,
    intercept_str,
    cfg$name,
    cfg$name
  )

  return(script)
}

#' Launch background process (cross-platform)
launch_background_process <- function(script_path, log_path, is_windows, working_dir = NULL) {
  script_path <- normalizePath(script_path, winslash = "/", mustWork = FALSE)
  log_path <- normalizePath(log_path, winslash = "/", mustWork = FALSE)

  if (is.null(working_dir)) {
    working_dir <- dirname(script_path)
  }
  working_dir <- normalizePath(working_dir, winslash = "/", mustWork = FALSE)

  if (is_windows) {
    script_win <- normalizePath(script_path, winslash = "\\", mustWork = FALSE)
    log_win <- normalizePath(log_path, winslash = "\\", mustWork = FALSE)
    work_win <- normalizePath(working_dir, winslash = "\\", mustWork = FALSE)
    cmd <- sprintf('start /B cmd /C "cd /d "%s" && Rscript "%s" > "%s" 2>&1"', work_win, script_win, log_win)
    shell(cmd, wait = FALSE)
  } else {
    cmd <- sprintf('nohup bash -c \'cd "%s" && Rscript "%s" > "%s" 2>&1\' &',
                   working_dir, script_path, log_path)
    system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE, wait = FALSE)
  }
}

#' Run a single model (sequential mode)
run_single_model <- function(cfg, main_path, cores_per_model, ndraws, timestamp, dry_run = FALSE) {

  log_file <- get_log_path(cfg, main_path, timestamp)
  intercept_str <- if (cfg$intercept) "YES" else "NO"

  cat("\n")
  cat("-", rep("-", 70), "\n", sep = "")
  cat(sprintf("  MODEL %d: %s\n", cfg$id, cfg$name))
  cat(sprintf("  %s\n", cfg$description))
  cat(sprintf("  Intercept: %s\n", intercept_str))
  cat(sprintf("  Log: %s\n", log_file))
  cat("-", rep("-", 70), "\n", sep = "")

  if (dry_run) {
    cat("  [DRY RUN] Would execute with:\n")
    cat(sprintf("    model_type:  %s\n", cfg$model_type))
    cat(sprintf("    return_type: %s\n", cfg$return_type))
    cat(sprintf("    intercept:   %s\n", intercept_str))
    cat(sprintf("    tag:         %s\n", cfg$tag))
    cat(sprintf("    ndraws:      %d\n", ndraws))
    return(list(success = TRUE, time = 0, log_file = log_file))
  }

  # Generate and run script
  script_content <- generate_model_script(cfg, main_path, cores_per_model, ndraws)
  temp_script <- tempfile(pattern = paste0("ia_model_", cfg$id, "_"), fileext = ".R")
  writeLines(script_content, temp_script)

  cat(sprintf("  Starting at: %s\n", Sys.time()))
  start_time <- Sys.time()

  tryCatch({
    log_con <- file(log_file, open = "wt")
    sink(log_con, type = "output")
    sink(log_con, type = "message", append = TRUE)

    source(temp_script, local = new.env())

    sink(type = "message")
    sink(type = "output")
    close(log_con)

    end_time <- Sys.time()
    elapsed <- difftime(end_time, start_time, units = "mins")
    cat(sprintf("  Completed at: %s (%.1f minutes)\n", end_time, as.numeric(elapsed)))
    unlink(temp_script)
    return(list(success = TRUE, time = as.numeric(elapsed), log_file = log_file))
  }, error = function(e) {
    try(sink(type = "message"), silent = TRUE)
    try(sink(type = "output"), silent = TRUE)
    cat(sprintf("  ERROR: %s\n", e$message))
    unlink(temp_script)
    return(list(success = FALSE, time = NA, error = e$message, log_file = log_file))
  })
}

#' Run models in parallel
run_parallel_models <- function(configs, main_path, cores_per_model, ndraws, timestamp, dry_run = FALSE) {

  temp_dir <- file.path(main_path, "ia", "output", "temp_scripts")
  if (!dir.exists(temp_dir)) dir.create(temp_dir, recursive = TRUE)

  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  LAUNCHING PARALLEL ESTIMATION\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")

  for (cfg in configs) {
    log_file <- get_log_path(cfg, main_path, timestamp)
    intercept_str <- if (cfg$intercept) "YES" else "NO"

    cat(sprintf("  [%d] %s (intercept=%s)\n", cfg$id, cfg$name, intercept_str))
    cat(sprintf("      Log: %s\n", basename(log_file)))

    if (!dry_run) {
      script_content <- generate_model_script(cfg, main_path, cores_per_model, ndraws)
      script_path <- file.path(temp_dir, sprintf("ia_model_%d_%s.R", cfg$id, cfg$name))
      writeLines(script_content, script_path)
      launch_background_process(script_path, log_file, is_windows, main_path)
    }
  }

  cat("\n")
  if (dry_run) {
    cat("  [DRY RUN] No processes launched.\n")
  } else {
    cat(sprintf("  %d models launched in background.\n", length(configs)))
    cat("  Monitor progress with: tail -f ia/output/logs/log_ia_model_*.txt\n")
  }
  cat("\n")
}

###############################################################################
## SECTION 4: MAIN EXECUTION
###############################################################################

# Parse arguments
opts <- parse_args()

# Handle --list
if (opts$list_only) {
  print_model_list()
  quit(save = "no", status = 0)
}

# Filter to requested models
selected_configs <- MODEL_CONFIGS[opts$models]

# Print header
cat("\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("  INTERNET APPENDIX MODEL ESTIMATION\n")
cat("=", rep("=", 70), "\n", sep = "")
cat("\n")
cat(sprintf("  Models to run: %s\n", paste(opts$models, collapse = ", ")))
cat(sprintf("  MCMC draws:    %d\n", opts$ndraws))
cat(sprintf("  Parallel:      %s\n", if (opts$parallel) "YES" else "NO"))
cat(sprintf("  Dry run:       %s\n", if (opts$dry_run) "YES" else "NO"))
cat("\n")

# Create output directories
ia_output <- file.path(main_path, "ia", "output")
if (!dir.exists(ia_output)) {
  dir.create(ia_output, recursive = TRUE)
  cat("  Created: ", ia_output, "\n")
}

# Run models
if (opts$parallel && length(selected_configs) > 1) {
  run_parallel_models(selected_configs, main_path, opts$cores_per_model,
                      opts$ndraws, RUN_TIMESTAMP, opts$dry_run)
} else {
  # Sequential execution
  results <- list()
  for (cfg in selected_configs) {
    results[[cfg$name]] <- run_single_model(cfg, main_path, opts$cores_per_model,
                                             opts$ndraws, RUN_TIMESTAMP, opts$dry_run)
  }

  # Summary
  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  ESTIMATION SUMMARY\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")

  for (name in names(results)) {
    r <- results[[name]]
    status <- if (r$success) "SUCCESS" else "FAILED"
    time_str <- if (!is.na(r$time)) sprintf("%.1f min", r$time) else "N/A"
    cat(sprintf("  %-25s %s (%s)\n", name, status, time_str))
  }
  cat("\n")
}

cat("Done.\n")
