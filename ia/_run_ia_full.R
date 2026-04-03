#!/usr/bin/env Rscript
###############################################################################
## _run_ia_full.R - Complete Internet Appendix Replication
## ---------------------------------------------------------------------------
##
## This script runs the complete implemented IA pipeline:
##   1. Estimate the 9 IA-related models       ~12 min
##   2. Generate the implemented IA tables/figs ~4 min
##   3. Assemble the IA LaTeX tree              <1 min
##   4. Compile PDF (pdflatex + bibtex)         <1 min
##
## Representative total: ~16 min at 50,000 draws on a 24-core desktop.
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
    skip_pdf = FALSE,
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
    } else if (identical(arg, "--skip-pdf")) {
      opts$skip_pdf <- TRUE
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
        "  --skip-pdf                  Skip PDF compilation (step 4)\n",
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
source(file.path(main_path, "code_base", "audit_helpers.R"))

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

if (!opts$skip_pdf) {
  cat("STEP 4: Compile IA PDF\n")
  cat("----------------------\n")

  latex_dir <- file.path(main_path, "ia", "output", "paper", "latex")
  pdflatex <- Sys.which("pdflatex")
  bibtex <- Sys.which("bibtex")

  if (!nzchar(pdflatex)) {
    cat("WARNING: pdflatex not found on PATH. Skipping PDF compilation.\n")
    cat("Install a TeX distribution (MiKTeX, TeX Live) to enable this step.\n\n")
  } else {
    old_wd <- getwd()
    setwd(latex_dir)
    on.exit(setwd(old_wd), add = TRUE)

    # pdflatex pass 1
    rc <- system2(pdflatex, args = c("-interaction=nonstopmode", "ia_main.tex"))
    if (rc != 0) stop("pdflatex pass 1 failed (exit ", rc, ")", call. = FALSE)

    # bibtex
    if (nzchar(bibtex)) {
      rc <- system2(bibtex, args = "ia_main")
      if (rc != 0) cat("WARNING: bibtex returned exit code ", rc, " (non-fatal)\n")
    } else {
      cat("WARNING: bibtex not found, skipping bibliography pass.\n")
    }

    # pdflatex passes 2-3
    for (pass in 2:3) {
      rc <- system2(pdflatex, args = c("-interaction=nonstopmode", "ia_main.tex"))
      if (rc != 0) stop("pdflatex pass ", pass, " failed (exit ", rc, ")", call. = FALSE)
    }

    setwd(old_wd)
    cat("  PDF: ", file.path(latex_dir, "ia_main.pdf"), "\n\n", sep = "")
  }
} else {
  cat("STEP 4: Skipped (--skip-pdf)\n\n")
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
if (!opts$skip_pdf && nzchar(Sys.which("pdflatex"))) {
  cat("  PDF:        ia/output/paper/latex/ia_main.pdf\n")
}
cat("\n")

# Generate replication manifest
ia_end <- Sys.time()
generate_replication_manifest(
  repo_root      = main_path,
  pipeline       = "ia",
  ndraws         = opts$ndraws,
  run_timestamp  = format(started_at, "%Y%m%d_%H%M%S"),
  pipeline_start = started_at,
  pipeline_end   = ia_end,
  min_mtime      = if (!opts$skip_estim) started_at else NULL
)
