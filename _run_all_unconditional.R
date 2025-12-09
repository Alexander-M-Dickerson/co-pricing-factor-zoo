#!/usr/bin/env Rscript
###############################################################################
## _run_all_unconditional.R - Run All Unconditional Models for Paper
## ---------------------------------------------------------------------------
## This script runs all 7 unconditional models required for the paper:
##
##   1. stock              - Stock factors only
##   2. bond_excess        - Bond factors with excess returns
##   3. bond_duration      - Bond factors with duration-adjusted returns
##   4. joint_excess       - Joint bond+stock with excess returns
##   5. joint_duration     - Joint bond+stock with duration-adjusted returns
##   6. treasury_stock     - Treasury test assets with stock factors
##   7. treasury_bond      - Treasury test assets with bond factors
##
## USAGE:
##   From R:
##     source("_run_all_unconditional.R")
##
##   From terminal:
##     Rscript _run_all_unconditional.R [options]
##
## OPTIONS:
##   --models=1,2,3      Run specific models (comma-separated, default: all)
##   --parallel          Run models in parallel (default: sequential)
##   --cores=N           Total available cores (default: auto-detect)
##   --cores-per-model=N Cores per model (default: 4)
##   --dry-run           Show what would be run without executing
##   --list              List all available models and exit
##
## EXAMPLES:
##   Rscript _run_all_unconditional.R --list
##   Rscript _run_all_unconditional.R --models=1,2 --parallel --cores=9
##   Rscript _run_all_unconditional.R --models=4,5 --sequential
##   Rscript _run_all_unconditional.R --parallel --cores=17
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
RUN_PARALLEL            <- FALSE
MODELS_TO_RUN           <- 1:7  # All models by default
DRY_RUN                 <- FALSE

###############################################################################
## SECTION 2: MODEL DEFINITIONS
###############################################################################

# Define all 7 models as a list of configurations
MODEL_CONFIGS <- list(

  # Model 1: Stock only
  list(
    id          = 1,
    name        = "stock",
    description = "Stock factors only (equity test assets)",
    model_type  = "stock",
    return_type = "excess",
    tag         = "baseline",
    f2          = 'c("traded_equity.csv")',
    R           = 'c("equity_anomalies_composite_33.csv")'
  ),


  # Model 2: Bond with excess returns
  list(
    id          = 2,
    name        = "bond_excess",
    description = "Bond factors with excess returns",
    model_type  = "bond",
    return_type = "excess",
    tag         = "baseline",
    f2          = 'c("traded_bond_excess.csv")',
    R           = 'c("bond_insample_test_assets_50_excess.csv")'
  ),

  # Model 3: Bond with duration-adjusted returns
  list(
    id          = 3,
    name        = "bond_duration",
    description = "Bond factors with duration-adjusted returns",
    model_type  = "bond",
    return_type = "duration",
    tag         = "baseline",
    f2          = 'c("traded_bond_duration_tmt.csv")',
    R           = 'c("bond_insample_test_assets_50_duration_tmt.csv")'
  ),

  # Model 4: Joint bond+stock with excess returns
  list(
    id          = 4,
    name        = "joint_excess",
    description = "Joint bond+stock factors with excess returns",
    model_type  = "bond_stock_with_sp",
    return_type = "excess",
    tag         = "baseline",
    f2          = 'c("traded_bond_excess.csv", "traded_equity.csv")',
    R           = 'c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv")'
  ),

  # Model 5: Joint bond+stock with duration-adjusted returns
  list(
    id          = 5,
    name        = "joint_duration",
    description = "Joint bond+stock factors with duration-adjusted returns",
    model_type  = "bond_stock_with_sp",
    return_type = "duration",
    tag         = "baseline",
    f2          = 'c("traded_bond_duration_tmt.csv", "traded_equity.csv")',
    R           = 'c("bond_insample_test_assets_50_duration_tmt.csv", "equity_anomalies_composite_33.csv")'
  ),

  # Model 6: Treasury with stock factors
  list(
    id          = 6,
    name        = "treasury_stock",
    description = "Treasury test assets with stock factors only",
    model_type  = "treasury",
    return_type = "excess",
    tag         = "stock_treasury",
    f2          = 'c("traded_equity.csv")',
    R           = 'c("bond_insample_test_assets_50_duration_tmt_tbond.csv")'
  ),

  # Model 7: Treasury with bond factors
  list(
    id          = 7,
    name        = "treasury_bond",
    description = "Treasury test assets with bond factors only",
    model_type  = "treasury",
    return_type = "excess",
    tag         = "bond_treasury",
    f2          = 'c("traded_bond_excess.csv")',
    R           = 'c("bond_insample_test_assets_50_duration_tmt_tbond.csv")'
  )
)

###############################################################################
## SECTION 3: HELPER FUNCTIONS
###############################################################################

#' Print model list
print_model_list <- function() {
  cat("\n")
  cat("=" , rep("=", 70), "\n", sep = "")
  cat("  AVAILABLE UNCONDITIONAL MODELS\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("\n")

  for (cfg in MODEL_CONFIGS) {
    cat(sprintf("  [%d] %-20s - %s\n", cfg$id, cfg$name, cfg$description))
    cat(sprintf("      model_type: %-20s return_type: %s\n",
                cfg$model_type, cfg$return_type))
    cat(sprintf("      tag: %s\n", cfg$tag))
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
    } else if (grepl("^--cores=", arg)) {
      result$cores <- as.integer(sub("^--cores=", "", arg))
    } else if (grepl("^--cores-per-model=", arg)) {
      result$cores_per_model <- as.integer(sub("^--cores-per-model=", "", arg))
    } else if (arg == "--help" || arg == "-h") {
      cat("\nUsage: Rscript _run_all_unconditional.R [options]\n\n")
      cat("Options:\n")
      cat("  --models=1,2,3      Run specific models (comma-separated)\n")
      cat("  --parallel          Run models in parallel\n")
      cat("  --sequential        Run models sequentially (default)\n")
      cat("  --cores=N           Total available cores (default: auto-detect)\n")
      cat("  --cores-per-model=N Cores per model (default: 4)\n")
      cat("  --dry-run           Show what would be run without executing\n")
      cat("  --list              List all available models\n")
      cat("  --help, -h          Show this help message\n\n")
      quit(save = "no", status = 0)
    }
  }

  return(result)
}

#' Generate R script for a single model
generate_model_script <- function(cfg, main_path, cores_per_model) {

  script <- sprintf('
###############################################################################
## Auto-generated script for model: %s
###############################################################################

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

#### Frequentist Models
frequentist_models <- list(
  CAPM = "MKTS",
  CAPMB= "MKTB",
  FF5  = c("MKTS","HML","SMB","DEF","TERM"),
  HKM  = c("MKTS","CPTLT")
)

#### MCMC Parameters
ndraws         <- 50000
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
intercept      <- TRUE
save_flag      <- TRUE
verbose        <- TRUE
fac_to_drop    <- NULL
weighting      <- "GLS"

#### Source and run the estimation code
setwd(main_path)
source(file.path(code_folder, "run_unconditional_mcmc.R"))
',
    cfg$name,
    main_path,
    cfg$model_type,
    cfg$return_type,
    cfg$f2,
    cfg$R,
    cfg$tag,
    cores_per_model
  )

  return(script)
}

#' Run a single model
run_single_model <- function(cfg, main_path, cores_per_model, dry_run = FALSE) {

  cat("\n")
  cat("-", rep("-", 70), "\n", sep = "")
  cat(sprintf("  MODEL %d: %s\n", cfg$id, cfg$name))
  cat(sprintf("  %s\n", cfg$description))
  cat("-", rep("-", 70), "\n", sep = "")

  if (dry_run) {
    cat("  [DRY RUN] Would execute with:\n")
    cat(sprintf("    model_type:  %s\n", cfg$model_type))
    cat(sprintf("    return_type: %s\n", cfg$return_type))
    cat(sprintf("    tag:         %s\n", cfg$tag))
    cat(sprintf("    f2:          %s\n", cfg$f2))
    cat(sprintf("    R:           %s\n", cfg$R))
    cat(sprintf("    cores:       %d\n", cores_per_model))
    return(list(success = TRUE, time = 0))
  }

  # Generate temporary script
  script_content <- generate_model_script(cfg, main_path, cores_per_model)
  temp_script <- tempfile(pattern = paste0("model_", cfg$id, "_"), fileext = ".R")
  writeLines(script_content, temp_script)

  cat(sprintf("  Starting at: %s\n", Sys.time()))
  cat(sprintf("  Temp script: %s\n", temp_script))

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
run_parallel_models <- function(configs, main_path, total_cores, cores_per_model, dry_run = FALSE) {

  # Calculate how many models can run simultaneously
  # Reserve 1 core, use remaining for models
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
  results <- list()
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
    processes <- list()
    temp_scripts <- character()
    log_files <- character()

    for (cfg in batch_configs) {
      # Generate script
      script_content <- generate_model_script(cfg, main_path, cores_per_model)
      temp_script <- file.path(main_path, sprintf(".temp_model_%d_%s.R", cfg$id, cfg$name))
      log_file <- file.path(main_path, "output", sprintf("log_model_%d_%s.txt", cfg$id, cfg$name))

      writeLines(script_content, temp_script)
      temp_scripts <- c(temp_scripts, temp_script)
      log_files <- c(log_files, log_file)

      # Launch R process in background
      cmd <- sprintf('Rscript "%s" > "%s" 2>&1 &', temp_script, log_file)

      cat(sprintf("  Launching model %d (%s)...\n", cfg$id, cfg$name))
      system(cmd, wait = FALSE)

      # Small delay to avoid race conditions
      Sys.sleep(1)
    }

    cat("\n  Waiting for batch to complete...\n")
    cat(sprintf("  Log files in: %s/output/\n", main_path))

    # Wait for all processes to complete by checking log files
    # This is a simple polling approach
    all_done <- FALSE
    start_time <- Sys.time()

    while (!all_done) {
      Sys.sleep(30)  # Check every 30 seconds

      # Check if all temp scripts have been removed or logs show completion
      # For simplicity, we'll wait for log files to contain "Completed" or error
      done_count <- 0
      for (j in seq_along(log_files)) {
        if (file.exists(log_files[j])) {
          log_content <- tryCatch(readLines(log_files[j]), error = function(e) "")
          log_text <- paste(log_content, collapse = "\n")
          if (grepl("Results saved|Error|error|ERROR", log_text, ignore.case = FALSE)) {
            done_count <- done_count + 1
          }
        }
      }

      elapsed <- difftime(Sys.time(), start_time, units = "mins")
      cat(sprintf("\r  Progress: %d/%d models complete (%.1f min elapsed)    ",
                  done_count, length(batch_configs), as.numeric(elapsed)))

      if (done_count >= length(batch_configs)) {
        all_done <- TRUE
      }

      # Timeout after 8 hours per batch
      if (as.numeric(elapsed) > 480) {
        cat("\n  WARNING: Batch timeout reached (8 hours)\n")
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
run_sequential_models <- function(configs, main_path, cores_per_model, dry_run = FALSE) {

  cat("\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat("  SEQUENTIAL EXECUTION MODE\n")
  cat("=", rep("=", 70), "\n", sep = "")
  cat(sprintf("  Cores per model: %d\n", cores_per_model))
  cat(sprintf("  Models to run:   %d\n", length(configs)))
  cat("=", rep("=", 70), "\n", sep = "")

  results <- list()
  total_start <- Sys.time()

  for (i in seq_along(configs)) {
    cfg <- configs[[i]]
    cat(sprintf("\n  [%d/%d] ", i, length(configs)))
    result <- run_single_model(cfg, main_path, cores_per_model, dry_run)
    results[[cfg$name]] <- result
  }

  total_end <- Sys.time()
  total_elapsed <- difftime(total_end, total_start, units = "mins")

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
    cat(sprintf("\n  Total time: %.1f minutes\n", as.numeric(total_elapsed)))
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
    stop(sprintf("Invalid model IDs: %s. Valid IDs are 1-7.",
                 paste(invalid_ids, collapse = ", ")))
  }

  # Filter to selected models
  selected_configs <- MODEL_CONFIGS[args$models]

  # Print header
  cat("\n")
  cat("#", rep("#", 70), "\n", sep = "")
  cat("##  UNCONDITIONAL MODEL ESTIMATION - PAPER PIPELINE\n")
  cat("#", rep("#", 70), "\n", sep = "")
  cat(sprintf("##  Started: %s\n", Sys.time()))
  cat(sprintf("##  Models:  %s\n", paste(args$models, collapse = ", ")))
  cat(sprintf("##  Mode:    %s\n", if (args$parallel) "PARALLEL" else "SEQUENTIAL"))
  if (args$dry_run) cat("##  [DRY RUN MODE]\n")
  cat("#", rep("#", 70), "\n", sep = "")

  # Run models
  if (args$parallel) {
    run_parallel_models(
      configs = selected_configs,
      main_path = main_path,
      total_cores = args$cores,
      cores_per_model = args$cores_per_model,
      dry_run = args$dry_run
    )
  } else {
    run_sequential_models(
      configs = selected_configs,
      main_path = main_path,
      cores_per_model = args$cores_per_model,
      dry_run = args$dry_run
    )
  }

  cat(sprintf("\n##  Finished: %s\n", Sys.time()))
  cat("#", rep("#", 70), "\n", sep = "")
}

# Run main function
main()
