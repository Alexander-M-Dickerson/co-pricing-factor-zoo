#!/usr/bin/env Rscript
###############################################################################
## _run_full_replication.R - Complete Paper Replication Pipeline
## ---------------------------------------------------------------------------
##
## This script runs the entire replication pipeline for:
##   "The Co-Pricing Factor Zoo" (Dickerson, Julliard, Mueller, JFE 2025)
##
## Paper role: Top-level orchestrator for the main-text replication pipeline.
## Paper refs: Sec. 3; Tables 1-6; Figures 2-7; Appendix A tables/figures;
##   docs/paper/co-pricing-factor-zoo.ai-optimized.md
## Outputs: output/unconditional/, output/time_varying/, output/paper/,
##   final LaTeX assembly via _create_djm_tabs_figs.R
##
## It sequentially executes all 5 steps:
##   1. Unconditional models (7 models, ~1-2 hours)
##   2. Conditional models (2 models, ~30-40 min)
##   3. Generate tables & figures (unconditional)
##   4. Generate tables & figures (conditional)
##   5. Compile LaTeX document
##
## Coverage note: this repo replicates all main-text tables/figures, all main
## Appendix tables/figures, and a subset of Internet Appendix results.
##
## USAGE:
##   Rscript _run_full_replication.R [options]
##
## OPTIONS:
##   --ndraws=N        Number of MCMC draws (default: 50000, use 5000 for quick test)
##   --quick           Shortcut for --ndraws=5000 (quick test mode)
##   --sequential      Run models sequentially instead of parallel (default: parallel)
##   --skip-estimation Skip steps 1-2, only regenerate tables/figures
##   --help            Show this help message
##
## EXAMPLES:
##   Rscript _run_full_replication.R                    # Full replication
##   Rscript _run_full_replication.R --quick            # Quick test (~30 min)
##   Rscript _run_full_replication.R --skip-estimation  # Regenerate outputs only
##
###############################################################################

###############################################################################
## PARSE COMMAND LINE ARGUMENTS
###############################################################################

args <- commandArgs(trailingOnly = TRUE)

# Defaults
ndraws <- 50000
parallel_mode <- TRUE
skip_estimation <- FALSE
show_help <- FALSE

# Parse arguments
for (arg in args) {
  if (grepl("^--ndraws=", arg)) {
    ndraws <- as.integer(sub("^--ndraws=", "", arg))
  } else if (arg == "--quick") {
    ndraws <- 5000
  } else if (arg == "--sequential") {
    parallel_mode <- FALSE
  } else if (arg == "--skip-estimation") {
    skip_estimation <- TRUE
  } else if (arg == "--help" || arg == "-h") {
    show_help <- TRUE
  }
}

# Show help
if (show_help) {
  cat("
_run_full_replication.R - Complete Paper Replication Pipeline

USAGE:
  Rscript _run_full_replication.R [options]

OPTIONS:
  --ndraws=N        Number of MCMC draws (default: 50000)
  --quick           Quick test mode (--ndraws=5000)
  --sequential      Run models sequentially (default: parallel)
  --skip-estimation Skip estimation, only regenerate tables/figures
  --help            Show this help message

EXAMPLES:
  Rscript _run_full_replication.R                    # Full replication
  Rscript _run_full_replication.R --quick            # Quick test
  Rscript _run_full_replication.R --skip-estimation  # Regenerate outputs only

")
  quit(status = 0)
}

###############################################################################
## HELPER FUNCTION
###############################################################################

run_step <- function(step_num, total_steps, description, command) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("STEP %d/%d: %s\n", step_num, total_steps, description))
  cat(strrep("=", 70), "\n\n")

  start_time <- Sys.time()

  # Run command and capture exit status
  exit_status <- system(command)

  end_time <- Sys.time()
  elapsed <- round(difftime(end_time, start_time, units = "mins"), 1)

  if (exit_status != 0) {
    cat("\n")
    cat(strrep("!", 70), "\n")
    cat(sprintf("ERROR: Step %d failed with exit code %d\n", step_num, exit_status))
    cat("Aborting replication pipeline.\n")
    cat(strrep("!", 70), "\n")
    quit(status = 1)
  }

  cat(sprintf("\nStep %d completed in %.1f minutes.\n", step_num, elapsed))

  return(elapsed)
}

###############################################################################
## MAIN PIPELINE
###############################################################################

cat("\n")
cat(strrep("#", 70), "\n")
cat("#", strrep(" ", 66), "#\n")
cat("#   THE CO-PRICING FACTOR ZOO - FULL REPLICATION PIPELINE", strrep(" ", 11), "#\n")
cat("#   Dickerson, Julliard, Mueller (JFE 2025)", strrep(" ", 25), "#\n")
cat("#", strrep(" ", 66), "#\n")
cat(strrep("#", 70), "\n\n")

cat("Configuration:\n")
cat(sprintf("  MCMC draws:    %d\n", ndraws))
cat(sprintf("  Parallel mode: %s\n", ifelse(parallel_mode, "YES", "NO")))
cat(sprintf("  Skip estimation: %s\n", ifelse(skip_estimation, "YES", "NO")))
cat("\n")

pipeline_start <- Sys.time()
step_times <- numeric()

# Build parallel flag
parallel_flag <- ifelse(parallel_mode, "", "--sequential")

if (!skip_estimation) {
  total_steps <- 5

  # Step 1: Unconditional models
  cmd1 <- sprintf("Rscript _run_all_unconditional.R --ndraws=%d %s", ndraws, parallel_flag)
  step_times[1] <- run_step(1, total_steps, "Running unconditional models (7 models)", cmd1)

  # Step 2: Conditional models
  cmd2 <- sprintf("Rscript _run_all_conditional.R --ndraws=%d", ndraws)
  step_times[2] <- run_step(2, total_steps, "Running conditional models (2 models)", cmd2)

  step_offset <- 2
} else {
  total_steps <- 3
  step_offset <- 0
  cat("Skipping estimation steps (--skip-estimation)\n")
}

# Step 3: Generate tables & figures (unconditional)
step_times[step_offset + 1] <- run_step(
  step_offset + 1, total_steps,
  "Generating tables and figures (unconditional)",
  "Rscript _run_paper_results.R"
)

# Step 4: Generate tables & figures (conditional)
step_times[step_offset + 2] <- run_step(
  step_offset + 2, total_steps,
  "Generating tables and figures (conditional)",
  "Rscript _run_paper_conditional_results.R"
)

# Step 5: Compile LaTeX document
step_times[step_offset + 3] <- run_step(
  step_offset + 3, total_steps,
  "Compiling LaTeX document",
  "Rscript _create_djm_tabs_figs.R"
)

###############################################################################
## SUMMARY
###############################################################################

pipeline_end <- Sys.time()
total_elapsed <- round(difftime(pipeline_end, pipeline_start, units = "mins"), 1)

cat("\n")
cat(strrep("#", 70), "\n")
cat("#", strrep(" ", 66), "#\n")
cat("#   REPLICATION COMPLETE!", strrep(" ", 43), "#\n")
cat("#", strrep(" ", 66), "#\n")
cat(strrep("#", 70), "\n\n")

cat(sprintf("Total runtime: %.1f minutes\n\n", total_elapsed))

cat("Output locations:\n")
cat("  Tables:   output/paper/tables/\n")
cat("  Figures:  output/paper/figures/\n")
cat("  LaTeX:    output/paper/latex/\n")
cat("  Logs:     output/logs/\n")
cat("\n")

cat("To compile the PDF:\n")
cat("  cd output/paper/latex\n")
cat("  pdflatex djm_main.tex\n")
cat("  bibtex djm_main\n")
cat("  pdflatex djm_main.tex\n")
cat("  pdflatex djm_main.tex\n")
cat("\n")
