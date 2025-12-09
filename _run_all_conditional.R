#!/usr/bin/env Rscript
###############################################################################
## _run_all_conditional.R - Run All Conditional (Time-Varying) Models
## ---------------------------------------------------------------------------
## This script runs conditional models with expanding windows for the paper:
##
##   1. joint_forward   - Joint bond+stock, expanding forward in time
##   2. joint_backward  - Joint bond+stock, expanding backward in time
##
## These produce Figure 6 (Panel A: forward, Panel B: backward) and
## Figure 7 / Table 6 Panel B (trading performance).
##
## USAGE:
##   From R:
##     source("_run_all_conditional.R")
##
##   From terminal:
##     Rscript _run_all_conditional.R [options]
##
## OPTIONS:
##   --models=1,2        Run specific models (comma-separated, default: all)
##   --parallel          Run models in parallel (default: sequential)
##   --cores=N           Total available cores (default: auto-detect)
##   --cores-per-model=N Cores per model (default: 4)
##   --ndraws=N          MCMC iterations (default: 50000)
##   --dry-run           Show what would be run without executing
##   --list              List all available models and exit
##
## EXAMPLES:
##   Rscript _run_all_conditional.R --list
##   Rscript _run_all_conditional.R --models=1 --ndraws=1000
##   Rscript _run_all_conditional.R --parallel --cores=9
##   Rscript _run_all_conditional.R --dry-run
##
## NOTE: Conditional models are computationally intensive as they run
##       MCMC estimation for multiple time windows. Expect ~2-4 hours
##       per model with 50000 draws on a modern multi-core machine.
##
###############################################################################

###############################################################################
## SECTION 1: USER CONFIGURATION
###############################################################################

# Project paths (adjust if needed)
main_path <- getwd()  # Assumes script is run from project root

# Default execution settings (can be overridden by command-line args)
DEFAULT_CORES_PER_MODEL <- 4
DEFAULT_TOTAL_CORES     <- parallel::detectCores() - 1
DEFAULT_NDRAWS          <- 50000
RUN_PARALLEL            <- FALSE
MODELS_TO_RUN           <- 1:2  # All models by default
DRY_RUN                 <- FALSE

###############################################################################
## SECTION 2: MODEL DEFINITIONS
###############################################################################

# Define conditional models as a list of configurations
MODEL_CONFIGS <- list(

  # Model 1: Joint bond+stock - Forward expanding
  list(
    id           = 1,
    name         = "joint_forward",
    description  = "Joint bond+stock factors, expanding forward in time",
    model_type   = "bond_stock_with_sp",
    return_type  = "excess",
    tag          = "ExpandingForward",
    reverse_time = FALSE,
    f2           = 'c("traded_bond_excess.csv", "traded_equity.csv")',
    R            = 'c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv")'
  ),

  # Model 2: Joint bond+stock - Backward expanding
  list(
    id           = 2,
    name         = "joint_backward",
    description  = "Joint bond+stock factors, expanding backward in time",
    model_type   = "bond_stock_with_sp",
    return_type  = "excess",
    tag          = "ExpandingBackward",
    reverse_time = TRUE,
    f2           = 'c("traded_bond_excess.csv", "traded_equity.csv")',
    R            = 'c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv")'
  )
)

###############################################################################
## SECTION 3: HELPER FUNCTIONS
###############################################################################

#' Print model list
print_model_list <- function() {
  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  AVAILABLE CONDITIONAL (TIME-VARYING) MODELS\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")

  for (cfg in MODEL_CONFIGS) {
    cat(sprintf("  [%d] %-20s - %s\n", cfg$id, cfg$name, cfg$description))
    cat(sprintf("      model_type:   %-20s return_type: %s\n",
                cfg$model_type, cfg$return_type))
    cat(sprintf("      reverse_time: %-20s tag: %s\n",
                cfg$reverse_time, cfg$tag))
    cat("\n")
  }

  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")
  cat("  Note: Each model runs MCMC estimation for ~19 time windows.\n")
  cat("        Expect ~2-4 hours per model with 50000 MCMC draws.\n")
  cat("\n")
}

#' Parse command-line arguments
parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  result <- list(
    models   = MODELS_TO_RUN,
    parallel = RUN_PARALLEL,
    cores    = DEFAULT_TOTAL_CORES,
    cores_per_model = DEFAULT_CORES_PER_MODEL,
    ndraws   = DEFAULT_NDRAWS,
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
    } else if (grepl("^--cores=", arg)) {
      result$cores <- as.integer(sub("^--cores=", "", arg))
    } else if (grepl("^--cores-per-model=", arg)) {
      result$cores_per_model <- as.integer(sub("^--cores-per-model=", "", arg))
    } else if (grepl("^--ndraws=", arg)) {
      result$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (arg == "--help" || arg == "-h") {
      cat("\nUsage: Rscript _run_all_conditional.R [options]\n\n")
      cat("Options:\n")
      cat("  --models=1,2        Run specific models (comma-separated)\n")
      cat("  --parallel          Run models in parallel\n")
      cat("  --sequential        Run models sequentially (default)\n")
      cat("  --cores=N           Total available cores (default: auto-detect)\n")
      cat("  --cores-per-model=N Cores per model (default: 4)\n")
      cat("  --ndraws=N          MCMC iterations (default: 50000)\n")
      cat("  --dry-run           Show what would be run without executing\n")
      cat("  --list              List all available models\n")
      cat("  --help, -h          Show this help message\n\n")
      quit(save = "no", status = 0)
    }
  }

  return(result)
}

#' Generate R script for a single conditional model
generate_model_script <- function(cfg, main_path, cores_per_model, ndraws) {

  script <- sprintf('
###############################################################################
## Auto-generated script for conditional model: %s
###############################################################################

cat("\\n")
cat("========================================\\n")
cat("TIME-VARYING ESTIMATION: %s\\n")
cat("========================================\\n\\n")

gc()

#### Paths
main_path      <- "%s"
data_folder    <- "data"
output_folder  <- "output"
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

#### Time-Varying Parameters
initial_window <- 222           # ~18.5 years initial training window
holding_period <- 12            # Re-estimate every 12 months
window_type    <- "expanding"   # Expanding window
reverse_time   <- %s            # Direction: %s

#### Frequentist Models
frequentist_models <- list(
  CAPM  = "MKTS",
  CAPMB = "MKTB",
  FF5   = c("MKTS", "SMB", "HML", "DEF", "TERM"),
  HKM   = c("MKTS", "CPTLT")
)

#### MCMC Parameters
ndraws         <- %d
drop_draws_pct <- 0
SRscale        <- c(0.20, 0.40, 0.60, 0.80)
alpha.w        <- 1
beta.w         <- 1
kappa          <- 0
kappa_fac      <- NULL

#### Other Settings
tag            <- "%s"
num_cores      <- %d
seed           <- 234
intercept      <- TRUE
save_flag      <- FALSE
save_csv_flag  <- FALSE
verbose        <- TRUE
fac_to_drop    <- NULL
weighting      <- "GLS"

#### Setup
setwd(main_path)
if (!dir.exists(output_folder)) dir.create(output_folder, recursive = TRUE)
logs_folder <- file.path(output_folder, "logs")
if (!dir.exists(logs_folder)) dir.create(logs_folder, recursive = TRUE)

#### Source helper scripts
source(file.path(code_folder, "logging_helpers.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "run_bayesian_mcmc.R"))
source(file.path(code_folder, "run_time_varying_estimation.R"))

#### Run time-varying estimation
cat("\\nStarting time-varying estimation...\\n")
cat("Direction: %s\\n")
cat("MCMC draws: ", ndraws, "\\n\\n")

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
cat("ESTIMATION COMPLETE: %s\\n")
cat("========================================\\n")
',
    cfg$name,
    cfg$name,
    main_path,
    cfg$model_type,
    cfg$return_type,
    cfg$f2,
    cfg$R,
    toupper(as.character(cfg$reverse_time)),
    if (cfg$reverse_time) "backward" else "forward",
    ndraws,
    cfg$tag,
    cores_per_model,
    if (cfg$reverse_time) "backward (from end to start)" else "forward (from start to end)",
    cfg$name
  )

  return(script)
}

#' Run a single model
run_single_model <- function(cfg, main_path, cores_per_model, ndraws, dry_run = FALSE) {

  cat("\n")
  cat("-", rep("-", 70), "\n", sep = "")
  cat(sprintf("  MODEL %d: %s\n", cfg$id, cfg$name))
  cat(sprintf("  %s\n", cfg$description))
  cat("-", rep("-", 70), "\n", sep = "")

  if (dry_run) {
    cat("  [DRY RUN] Would execute with:\n")
    cat(sprintf("    model_type:   %s\n", cfg$model_type))
    cat(sprintf("    return_type:  %s\n", cfg$return_type))
    cat(sprintf("    tag:          %s\n", cfg$tag))
    cat(sprintf("    reverse_time: %s\n", cfg$reverse_time))
    cat(sprintf("    ndraws:       %d\n", ndraws))
    cat(sprintf("    cores:        %d\n", cores_per_model))
    return(list(success = TRUE, time = 0))
  }

  # Generate temporary script
  script_content <- generate_model_script(cfg, main_path, cores_per_model, ndraws)
  temp_script <- tempfile(pattern = paste0("cond_model_", cfg$id, "_"), fileext = ".R")
  writeLines(script_content, temp_script)

  cat(sprintf("  Starting at: %s\n", Sys.time()))
  cat(sprintf("  Temp script: %s\n", temp_script))
  cat(sprintf("  MCMC draws:  %d\n", ndraws))

  start_time <- Sys.time()

  # Run the script
  tryCatch({
    source(temp_script, local = new.env())
    end_time <- Sys.time()
    elapsed <- difftime(end_time, start_time, units = "mins")
    cat(sprintf("  Completed at: %s (%.1f minutes)\n", end_time, as.numeric(elapsed)))
    unlink(temp_script)
    return(list(success = TRUE, time = as.numeric(elapsed)))
  }, error = function(e) {
    cat(sprintf("  ERROR: %s\n", e$message))
    unlink(temp_script)
    return(list(success = FALSE, time = NA, error = e$message))
  })
}

#' Run models in parallel using system calls
run_parallel_models <- function(configs, main_path, total_cores, cores_per_model, ndraws, dry_run = FALSE) {

  # Calculate how many models can run simultaneously
  available_cores <- total_cores - 1
  max_concurrent <- floor(available_cores / cores_per_model)
  max_concurrent <- max(1, max_concurrent)

  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  PARALLEL EXECUTION MODE\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat(sprintf("  Total cores available: %d\n", total_cores))
  cat(sprintf("  Reserved cores:        1\n"))
  cat(sprintf("  Cores per model:       %d\n", cores_per_model))
  cat(sprintf("  Max concurrent models: %d\n", max_concurrent))
  cat(sprintf("  Models to run:         %d\n", length(configs)))
  cat(sprintf("  MCMC draws per window: %d\n", ndraws))
  cat("=", rep("=", 70), "\n", sep = "")

  if (dry_run) {
    cat("\n[DRY RUN] Would run the following batches:\n\n")
    batch_num <- 1
    for (i in seq(1, length(configs), by = max_concurrent)) {
      batch_end <- min(i + max_concurrent - 1, length(configs))
      batch_configs <- configs[i:batch_end]
      cat(sprintf("  Batch %d: Models %s\n", batch_num,
                  paste(sapply(batch_configs, function(x) x$name), collapse = ", ")))
      batch_num <- batch_num + 1
    }
    return(invisible(NULL))
  }

  # Process in batches
  batch_num <- 1

  for (i in seq(1, length(configs), by = max_concurrent)) {
    batch_end <- min(i + max_concurrent - 1, length(configs))
    batch_configs <- configs[i:batch_end]

    cat("\n")
    cat("*", rep("*", 70), "\n", sep = "")
    cat(sprintf("  BATCH %d: Running %d model(s) in parallel\n",
                batch_num, length(batch_configs)))
    cat(sprintf("  Models: %s\n", paste(sapply(batch_configs, function(x) x$name), collapse = ", ")))
    cat("*", rep("*", 70), "\n", sep = "")

    # Generate scripts and launch processes
    temp_scripts <- character()
    log_files <- character()

    for (cfg in batch_configs) {
      # Generate script
      script_content <- generate_model_script(cfg, main_path, cores_per_model, ndraws)
      temp_script <- file.path(main_path, sprintf(".temp_cond_%d_%s.R", cfg$id, cfg$name))
      log_file <- file.path(main_path, "output", sprintf("log_cond_%d_%s.txt", cfg$id, cfg$name))

      writeLines(script_content, temp_script)
      temp_scripts <- c(temp_scripts, temp_script)
      log_files <- c(log_files, log_file)

      # Launch R process in background
      cmd <- sprintf('Rscript "%s" > "%s" 2>&1 &', temp_script, log_file)

      cat(sprintf("  Launching model %d (%s)...\n", cfg$id, cfg$name))
      system(cmd, wait = FALSE)

      Sys.sleep(2)
    }

    cat("\n  Waiting for batch to complete...\n")
    cat(sprintf("  Log files in: %s/output/\n", main_path))

    # Wait for all processes to complete
    all_done <- FALSE
    start_time <- Sys.time()

    while (!all_done) {
      Sys.sleep(60)  # Check every minute

      done_count <- 0
      for (j in seq_along(log_files)) {
        if (file.exists(log_files[j])) {
          log_content <- tryCatch(readLines(log_files[j]), error = function(e) "")
          log_text <- paste(log_content, collapse = "\n")
          if (grepl("ESTIMATION COMPLETE|Error|error|ERROR", log_text, ignore.case = FALSE)) {
            done_count <- done_count + 1
          }
        }
      }

      elapsed <- difftime(Sys.time(), start_time, units = "hours")
      cat(sprintf("\r  Progress: %d/%d models complete (%.1f hours elapsed)    ",
                  done_count, length(batch_configs), as.numeric(elapsed)))

      if (done_count >= length(batch_configs)) {
        all_done <- TRUE
      }

      # Timeout after 12 hours per batch
      if (as.numeric(elapsed) > 12) {
        cat("\n  WARNING: Batch timeout reached (12 hours)\n")
        all_done <- TRUE
      }
    }

    cat("\n  Batch %d complete!\n", batch_num)

    # Cleanup temp scripts
    for (ts in temp_scripts) {
      if (file.exists(ts)) unlink(ts)
    }

    batch_num <- batch_num + 1
  }

  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  ALL BATCHES COMPLETE\n")
  cat("=", rep("=", 70), "\n", sep = "")
}

#' Run models sequentially
run_sequential_models <- function(configs, main_path, cores_per_model, ndraws, dry_run = FALSE) {

  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  SEQUENTIAL EXECUTION MODE\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat(sprintf("  Cores per model:       %d\n", cores_per_model))
  cat(sprintf("  Models to run:         %d\n", length(configs)))
  cat(sprintf("  MCMC draws per window: %d\n", ndraws))
  cat("=", rep("=", 70), "\n", sep = "")

  results <- list()
  total_start <- Sys.time()

  for (i in seq_along(configs)) {
    cfg <- configs[[i]]
    cat(sprintf("\n  [%d/%d] ", i, length(configs)))
    result <- run_single_model(cfg, main_path, cores_per_model, ndraws, dry_run)
    results[[cfg$name]] <- result
  }

  total_end <- Sys.time()
  total_elapsed <- difftime(total_end, total_start, units = "hours")

  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  EXECUTION SUMMARY\n")
  cat("=", rep("=", 70), "\n", sep = "")

  if (!dry_run) {
    for (name in names(results)) {
      r <- results[[name]]
      status <- if (r$success) "SUCCESS" else "FAILED"
      time_str <- if (!is.na(r$time)) sprintf("%.1f min", r$time) else "N/A"
      cat(sprintf("  %-20s %s (%s)\n", name, status, time_str))
    }
    cat(sprintf("\n  Total time: %.2f hours\n", as.numeric(total_elapsed)))
  }

  cat("=", rep("=", 70), "\n", sep = "")

  return(invisible(results))
}

###############################################################################
## SECTION 4: MAIN EXECUTION
###############################################################################

main <- function() {

  # Parse command-line arguments
  args <- parse_args()

  # Handle --list option
  if (args$list_only) {
    print_model_list()
    return(invisible(NULL))
  }

  # Validate model selection
  valid_ids <- sapply(MODEL_CONFIGS, function(x) x$id)
  invalid_ids <- setdiff(args$models, valid_ids)
  if (length(invalid_ids) > 0) {
    stop(sprintf("Invalid model IDs: %s. Valid IDs are 1-2.",
                 paste(invalid_ids, collapse = ", ")))
  }

  # Filter to selected models
  selected_configs <- MODEL_CONFIGS[args$models]

  # Print header
  cat("\n")
  cat("#", rep("#", 70), "\n", sep = "")
  cat("##  CONDITIONAL (TIME-VARYING) MODEL ESTIMATION\n")
  cat("#", rep("#", 70), "\n", sep = "")
  cat(sprintf("##  Started: %s\n", Sys.time()))
  cat(sprintf("##  Models:  %s\n", paste(args$models, collapse = ", ")))
  cat(sprintf("##  Mode:    %s\n", if (args$parallel) "PARALLEL" else "SEQUENTIAL"))
  cat(sprintf("##  MCMC:    %d draws per window\n", args$ndraws))
  if (args$dry_run) cat("##  [DRY RUN MODE]\n")
  cat("#", rep("#", 70), "\n", sep = "")

  # Run models
  if (args$parallel) {
    run_parallel_models(
      configs = selected_configs,
      main_path = main_path,
      total_cores = args$cores,
      cores_per_model = args$cores_per_model,
      ndraws = args$ndraws,
      dry_run = args$dry_run
    )
  } else {
    run_sequential_models(
      configs = selected_configs,
      main_path = main_path,
      cores_per_model = args$cores_per_model,
      ndraws = args$ndraws,
      dry_run = args$dry_run
    )
  }

  cat(sprintf("\n##  Finished: %s\n", Sys.time()))
  cat("#", rep("#", 70), "\n", sep = "")
}

# Run main function
main()
