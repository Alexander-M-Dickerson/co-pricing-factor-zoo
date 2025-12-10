#!/usr/bin/env Rscript
###############################################################################
## _run_ia_full.R - Complete Internet Appendix Replication
## ---------------------------------------------------------------------------
##
## This script runs the complete IA pipeline:
##   1. Estimate all 5 models (parallel by default)
##   2. Generate tables and figures
##   3. Compile LaTeX document
##
## USAGE:
##   Rscript ia/_run_ia_full.R [options]
##
## OPTIONS:
##   --ndraws=N     Number of MCMC draws (default: 50000, use 5000 for quick test)
##   --sequential   Run models sequentially instead of parallel
##   --skip-estim   Skip estimation (use existing .Rdata files)
##   --help         Show this help message
##
###############################################################################

# Ensure we're in project root
if (basename(getwd()) == "ia") {
  setwd("..")
}
main_path <- getwd()

# Parse arguments
args <- commandArgs(trailingOnly = TRUE)
skip_estimation <- "--skip-estim" %in% args
ndraws_arg <- args[grepl("^--ndraws=", args)]
sequential <- "--sequential" %in% args

if ("--help" %in% args || "-h" %in% args) {
  cat("\n")
  cat("Usage: Rscript ia/_run_ia_full.R [options]\n\n")
  cat("Options:\n")
  cat("  --ndraws=N     MCMC draws (default: 50000, use 5000 for testing)\n")
  cat("  --sequential   Run models sequentially\n")
  cat("  --skip-estim   Skip estimation, use existing results\n")
  cat("  --help         Show this message\n\n")
  quit(save = "no", status = 0)
}

cat("\n")
cat("========================================\n")
cat("INTERNET APPENDIX FULL REPLICATION\n")
cat("========================================\n\n")

start_time <- Sys.time()

###############################################################################
## STEP 1: ESTIMATION
###############################################################################

if (!skip_estimation) {
  cat("STEP 1: Model Estimation\n")
  cat("------------------------\n")

  estim_args <- character()
  if (length(ndraws_arg) > 0) {
    estim_args <- c(estim_args, ndraws_arg)
  }
  if (sequential) {
    estim_args <- c(estim_args, "--sequential")
  }

  # Build command
  estim_script <- file.path(main_path, "ia", "_run_ia_estimation.R")
  estim_cmd <- paste("Rscript", shQuote(estim_script), paste(estim_args, collapse = " "))

  cat("Running:", estim_cmd, "\n\n")

  # Run estimation
  system(estim_cmd)

  if (!sequential) {
    # If parallel, wait for all models to complete
    cat("\nWaiting for parallel models to complete...\n")
    cat("(Check ia/output/logs/ for progress)\n\n")

    # Simple wait - check for .Rdata files
    expected_files <- c(
      "ia/output/unconditional/bond/excess_bond_alpha.w=1_beta.w=1_kappa=0_ia_intercept.Rdata",
      "ia/output/unconditional/stock/excess_stock_alpha.w=1_beta.w=1_kappa=0_ia_intercept.Rdata",
      "ia/output/unconditional/bond/excess_bond_alpha.w=1_beta.w=1_kappa=0_ia_no_intercept.Rdata",
      "ia/output/unconditional/stock/excess_stock_alpha.w=1_beta.w=1_kappa=0_ia_no_intercept.Rdata",
      "ia/output/unconditional/bond_stock_with_sp/excess_bond_stock_with_sp_alpha.w=1_beta.w=1_kappa=0_ia_no_intercept.Rdata"
    )

    max_wait <- 7200  # 2 hours max
    wait_interval <- 30  # Check every 30 seconds
    waited <- 0

    while (waited < max_wait) {
      all_done <- all(file.exists(expected_files))
      if (all_done) {
        cat("All models completed!\n\n")
        break
      }

      completed <- sum(file.exists(expected_files))
      cat(sprintf("\r  Progress: %d/%d models complete. Waiting... (%d sec)",
                  completed, length(expected_files), waited))

      Sys.sleep(wait_interval)
      waited <- waited + wait_interval
    }

    if (waited >= max_wait) {
      warning("Timeout waiting for models. Check logs for errors.")
    }
  }

} else {
  cat("STEP 1: Skipped (--skip-estim)\n\n")
}

###############################################################################
## STEP 2: GENERATE RESULTS
###############################################################################

cat("STEP 2: Generate Tables and Figures\n")
cat("------------------------------------\n")

results_script <- file.path(main_path, "ia", "_run_ia_results.R")
source(results_script)

###############################################################################
## STEP 3: COMPILE LATEX
###############################################################################

cat("\n")
cat("STEP 3: Compile LaTeX Document\n")
cat("-------------------------------\n")

latex_script <- file.path(main_path, "ia", "_create_ia_latex.R")
source(latex_script)

###############################################################################
## SUMMARY
###############################################################################

end_time <- Sys.time()
elapsed <- difftime(end_time, start_time, units = "mins")

cat("\n")
cat("========================================\n")
cat("INTERNET APPENDIX REPLICATION COMPLETE\n")
cat("========================================\n")
cat("\n")
cat(sprintf("Total time: %.1f minutes\n", as.numeric(elapsed)))
cat("\n")
cat("Outputs:\n")
cat("  Tables:  ia/output/paper/tables/\n")
cat("  Figures: ia/output/paper/figures/\n")
cat("  LaTeX:   ia/output/paper/latex/\n")
cat("\n")
