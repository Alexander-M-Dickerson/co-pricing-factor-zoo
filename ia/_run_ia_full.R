#!/usr/bin/env Rscript
###############################################################################
## _run_ia_full.R - Complete Internet Appendix Replication
## ---------------------------------------------------------------------------
##
## This script runs the complete implemented IA pipeline:
##   1. Estimate the 9 IA-related models defined in ia/_run_ia_estimation.R
##   2. Generate the implemented IA tables and figures
##   3. Assemble the IA LaTeX tree
##
## PDF compilation is a separate public step via tools/build_ia_paper.*.
## The no-flag path is the exact IA replication setting and defaults to 50,000
## draws.
###############################################################################

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    ndraws = 50000L,
    sequential = FALSE,
    skip_estim = FALSE,
    skip_results = FALSE,
    skip_assembly = FALSE,
    cores = NULL,
    cores_per_model = 4L,
    self_pricing_engine = "fast"
  )

  for (arg in args) {
    if (grepl("^--ndraws=", arg)) {
      opts$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (identical(arg, "--sequential")) {
      opts$sequential <- TRUE
    } else if (identical(arg, "--skip-estim")) {
      opts$skip_estim <- TRUE
    } else if (identical(arg, "--skip-results")) {
      opts$skip_results <- TRUE
    } else if (identical(arg, "--skip-assembly")) {
      opts$skip_assembly <- TRUE
    } else if (grepl("^--cores=", arg)) {
      opts$cores <- as.integer(sub("^--cores=", "", arg))
    } else if (grepl("^--cores-per-model=", arg)) {
      opts$cores_per_model <- as.integer(sub("^--cores-per-model=", "", arg))
    } else if (grepl("^--self-pricing-engine=", arg)) {
      opts$self_pricing_engine <- sub("^--self-pricing-engine=", "", arg)
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript ia/_run_ia_full.R [options]\n\n",
        "Options:\n",
        "  --ndraws=N                  Number of MCMC draws (default: 50000; paper setting)\n",
        "  --sequential                Run IA estimation sequentially instead of supervised parallel\n",
        "  --skip-estim                Skip IA estimation and use existing IA results\n",
        "  --skip-results              Skip IA tables/figures generation\n",
        "  --skip-assembly             Skip IA LaTeX assembly\n",
        "  --cores=N                   Total available cores for IA estimation\n",
        "  --cores-per-model=N         Cores per IA model (default: 4)\n",
        "  --self-pricing-engine=NAME  fast or reference (default: fast)\n",
        "  --help, -h                  Show this help message\n\n",
        "The no-flag path uses 50,000 draws for exact IA replication.\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts$self_pricing_engine <- match.arg(opts$self_pricing_engine, c("fast", "reference"))
  opts
}

resolve_rscript <- function() {
  if (.Platform$OS.type == "windows") {
    file.path(R.home("bin"), "Rscript.exe")
  } else {
    file.path(R.home("bin"), "Rscript")
  }
}

run_step <- function(rscript, script, args = character()) {
  status <- system2(rscript, args = c(script, args))
  if (!identical(status, 0L)) {
    stop("Step failed: ", script, call. = FALSE)
  }
}

if (basename(getwd()) == "ia") {
  setwd("..")
}
main_path <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
opts <- parse_args()
rscript <- resolve_rscript()

cat("\n========================================\n")
cat("INTERNET APPENDIX FULL REPLICATION\n")
cat("========================================\n\n")

cat("Repo root: ", main_path, "\n", sep = "")
cat("Rscript:   ", normalizePath(rscript, winslash = "/", mustWork = FALSE), "\n", sep = "")
cat("Draws:     ", opts$ndraws, "\n\n", sep = "")

started_at <- Sys.time()

if (!opts$skip_estim) {
  cat("STEP 1: IA Estimation\n")
  cat("---------------------\n")
  estim_args <- c(
    "ia/_run_ia_estimation.R",
    paste0("--ndraws=", opts$ndraws),
    paste0("--cores-per-model=", opts$cores_per_model),
    paste0("--self-pricing-engine=", opts$self_pricing_engine)
  )
  if (!is.null(opts$cores) && !is.na(opts$cores)) {
    estim_args <- c(estim_args, paste0("--cores=", opts$cores))
  }
  if (isTRUE(opts$sequential)) {
    estim_args <- c(estim_args, "--sequential")
  }
  run_step(rscript, estim_args[[1]], estim_args[-1])
  cat("\n")
} else {
  cat("STEP 1: Skipped (--skip-estim)\n\n")
}

if (!opts$skip_results) {
  cat("STEP 2: IA Tables And Figures\n")
  cat("-----------------------------\n")
  results_args <- c(
    "ia/_run_ia_results.R",
    paste0("--expected-ndraws=", opts$ndraws),
    paste0("--self-pricing-engine=", opts$self_pricing_engine)
  )
  if (!opts$skip_estim) {
    results_args <- c(results_args, paste0("--min-results-mtime=", as.numeric(started_at)))
  }
  run_step(rscript, results_args[[1]], results_args[-1])
  cat("\n")
} else {
  cat("STEP 2: Skipped (--skip-results)\n\n")
}

if (!opts$skip_assembly) {
  cat("STEP 3: IA LaTeX Assembly\n")
  cat("-------------------------\n")
  run_step(rscript, "ia/_create_ia_latex.R")
  cat("\n")
} else {
  cat("STEP 3: Skipped (--skip-assembly)\n\n")
}

elapsed <- difftime(Sys.time(), started_at, units = "mins")
cat("========================================\n")
cat("INTERNET APPENDIX PIPELINE COMPLETE\n")
cat("========================================\n")
cat(sprintf("Total time: %.1f minutes\n", as.numeric(elapsed)))
cat("\nOutputs:\n")
cat("  Estimation: ia/output/unconditional/\n")
cat("  Tables:     ia/output/paper/tables/\n")
cat("  Figures:    ia/output/paper/figures/\n")
cat("  LaTeX:      ia/output/paper/latex/\n")
cat("\nNext step for PDF compilation:\n")
cat("  tools/build_ia_paper.*\n")
