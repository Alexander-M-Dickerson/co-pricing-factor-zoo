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
##   final LaTeX assembly via _create_djm_tabs_figs.R,
##   compiled PDF at output/paper/latex/djm_main.pdf
##
## It sequentially executes all 6 steps:
##   1. Unconditional models (7 models)          ~8 min
##   2. Conditional models (2 directions)         ~46 min
##   3. Generate tables & figures (unconditional) ~10 min
##   4. Generate tables & figures (conditional)   <1 min
##   5. Assemble LaTeX source tree                <1 min
##   6. Compile PDF (pdflatex + bibtex)           <1 min
##
## Representative total: ~65 min at 50,000 draws on a 24-core desktop.
##
## Coverage note: this repo replicates all main-text tables/figures, all main
## Appendix tables/figures, and a subset of Internet Appendix results.
##
## USAGE:
##   Rscript _run_full_replication.R [options]
##
## OPTIONS:
##   --ndraws=N        Number of MCMC draws (default: 50000; this is the paper setting)
##   --quick           Shortcut for --ndraws=5000 (reduced-draw smoke mode)
##   --sequential      Run models sequentially instead of parallel (default: parallel)
##   --skip-estimation Skip steps 1-2, only regenerate tables/figures and LaTeX sources
##   --skip-pdf        Skip PDF compilation (step 6)
##   --help            Show this help message
##
## EXAMPLES:
##   Rscript _run_full_replication.R                    # Exact paper replication (50,000 draws)
##   Rscript _run_full_replication.R --quick            # Reduced-draw smoke validation (~30 min)
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
skip_pdf <- FALSE
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
  } else if (arg == "--skip-pdf") {
    skip_pdf <- TRUE
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
  --ndraws=N        Number of MCMC draws (default: 50000; paper setting)
  --quick           Reduced-draw smoke mode (--ndraws=5000)
  --sequential      Run models sequentially (default: parallel)
  --skip-estimation Skip estimation, only regenerate tables/figures and LaTeX sources
  --skip-pdf        Skip PDF compilation (step 6)
  --help            Show this help message

EXAMPLES:
  Rscript _run_full_replication.R                    # Exact paper replication (50,000 draws)
  Rscript _run_full_replication.R --quick            # Reduced-draw smoke validation
  Rscript _run_full_replication.R --skip-estimation  # Regenerate outputs and LaTeX sources only

")
  quit(status = 0)
}

source(file.path("code_base", "conditional_run_helpers.R"))
source(file.path("code_base", "unconditional_run_helpers.R"))
source(file.path("code_base", "audit_helpers.R"))

###############################################################################
## HELPER FUNCTION
###############################################################################

repo_rscript <- if (.Platform$OS.type == "windows") {
  file.path(R.home("bin"), "Rscript.exe")
} else {
  file.path(R.home("bin"), "Rscript")
}

run_step <- function(step_num, total_steps, description, script, args = character()) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("STEP %d/%d: %s\n", step_num, total_steps, description))
  cat(strrep("=", 70), "\n\n")

  start_time <- Sys.time()

  # Run command and capture exit status
  exit_status <- system2(repo_rscript, args = c(script, args))

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

  list(
    elapsed = elapsed,
    started_at = start_time,
    completed_at = end_time
  )
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
cat(sprintf("  Skip PDF:      %s\n", ifelse(skip_pdf, "YES", "NO")))
cat("\n")

pipeline_start <- Sys.time()
run_timestamp <- format(pipeline_start, "%Y%m%d_%H%M%S")
step_times <- numeric()

# Build parallel flag
parallel_flag <- ifelse(parallel_mode, "", "--sequential")

# Count steps: estimation (2) + outputs (2) + assembly (1) + pdf (1)
pdf_step <- if (!skip_pdf) 1L else 0L

if (!skip_estimation) {
  total_steps <- 5 + pdf_step

  # Step 1: Unconditional models
  step1_args <- c(sprintf("--ndraws=%d", ndraws))
  if (nzchar(parallel_flag)) {
    step1_args <- c(step1_args, parallel_flag)
  }
  step1_info <- run_step(1, total_steps, "Running unconditional models (7 models)", "_run_all_unconditional.R", step1_args)
  step_times[1] <- step1_info$elapsed

  unconditional_validation <- validate_expected_unconditional_workspaces(
    main_path = getwd(),
    output_folder = "output",
    expected_ndraws = ndraws,
    min_mtime = step1_info$started_at
  )
  if (!isTRUE(unconditional_validation$ok)) {
    stop(
      "Step 1 completed but one or more unconditional result workspaces are stale, missing, or mismatched.\n",
      format_unconditional_validation_issues(unconditional_validation),
      call. = FALSE
    )
  }

  # Step 2: Conditional models
  step2_info <- run_step(
    2,
    total_steps,
    "Running conditional models (2 models)",
    "_run_all_conditional.R",
    c(sprintf("--ndraws=%d", ndraws), "--direction=both")
  )
  step_times[2] <- step2_info$elapsed

  conditional_paths <- list(
    forward = conditional_results_rds_path(
      main_path = getwd(),
      output_folder = "output",
      model_type = "bond_stock_with_sp",
      return_type = "excess",
      alpha.w = 1,
      beta.w = 1,
      tag = "ExpandingForward",
      holding_period = 12,
      f1_flag = TRUE,
      reverse_time = FALSE
    ),
    backward = conditional_results_rds_path(
      main_path = getwd(),
      output_folder = "output",
      model_type = "bond_stock_with_sp",
      return_type = "excess",
      alpha.w = 1,
      beta.w = 1,
      tag = "ExpandingBackward",
      holding_period = 12,
      f1_flag = TRUE,
      reverse_time = TRUE
    )
  )

  for (direction_name in names(conditional_paths)) {
    validation <- validate_conditional_results_artifact(
      results_file = conditional_paths[[direction_name]],
      expected_ndraws = ndraws,
      min_mtime = step2_info$started_at,
      require_complete = TRUE
    )
    if (!isTRUE(validation$ok)) {
      stop(
        "Step 2 completed but the conditional ",
        direction_name,
        " artifact is stale or incomplete.\n",
        format_conditional_validation_issues(validation),
        call. = FALSE
      )
    }
  }

  step_offset <- 2
} else {
  total_steps <- 3 + pdf_step
  step_offset <- 0
  cat("Skipping estimation steps (--skip-estimation)\n")
}

# Step 3: Generate tables & figures (unconditional)
step3_args <- c(
  "--strict-freshness",
  sprintf("--expected-ndraws=%d", ndraws)
)
if (!skip_estimation) {
  step3_args <- c(
    step3_args,
    sprintf("--min-results-mtime=%s", as.numeric(step1_info$started_at))
  )
}
step_times[step_offset + 1] <- run_step(
  step_offset + 1, total_steps,
  "Generating tables and figures (unconditional)",
  "_run_paper_results.R",
  step3_args
)$elapsed

# Step 4: Generate tables & figures (conditional)
conditional_args <- c(sprintf("--expected-ndraws=%d", ndraws))
if (!skip_estimation) {
  conditional_args <- c(
    conditional_args,
    sprintf("--min-results-mtime=%s", as.numeric(step2_info$started_at))
  )
}
step_times[step_offset + 2] <- run_step(
  step_offset + 2, total_steps,
  "Generating tables and figures (conditional)",
  "_run_paper_conditional_results.R",
  conditional_args
)$elapsed

# Step 5: Assemble LaTeX source tree
step_times[step_offset + 3] <- run_step(
  step_offset + 3, total_steps,
  "Assembling LaTeX source tree",
  "_create_djm_tabs_figs.R"
)$elapsed

# Step 6: Compile PDF
if (!skip_pdf) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("STEP %d/%d: %s\n", step_offset + 4, total_steps, "Compiling PDF (pdflatex + bibtex)"))
  cat(strrep("=", 70), "\n\n")

  pdf_start <- Sys.time()
  latex_dir <- file.path(getwd(), "output", "paper", "latex")

  pdflatex <- Sys.which("pdflatex")
  bibtex <- Sys.which("bibtex")

  if (!nzchar(pdflatex)) {
    cat("WARNING: pdflatex not found on PATH. Skipping PDF compilation.\n")
    cat("Install a TeX distribution (MiKTeX, TeX Live) to enable this step.\n")
    step_times[step_offset + 4] <- 0
  } else {
    old_wd <- getwd()
    setwd(latex_dir)
    on.exit(setwd(old_wd), add = TRUE)

    # pdflatex pass 1
    rc <- system2(pdflatex, args = c("-interaction=nonstopmode", "djm_main.tex"))
    if (rc != 0) stop("pdflatex pass 1 failed (exit ", rc, ")", call. = FALSE)

    # bibtex
    if (nzchar(bibtex)) {
      rc <- system2(bibtex, args = "djm_main")
      if (rc != 0) cat("WARNING: bibtex returned exit code ", rc, " (non-fatal)\n")
    } else {
      cat("WARNING: bibtex not found, skipping bibliography pass.\n")
    }

    # pdflatex passes 2-3
    for (pass in 2:3) {
      rc <- system2(pdflatex, args = c("-interaction=nonstopmode", "djm_main.tex"))
      if (rc != 0) stop("pdflatex pass ", pass, " failed (exit ", rc, ")", call. = FALSE)
    }

    setwd(old_wd)

    pdf_end <- Sys.time()
    pdf_elapsed <- round(difftime(pdf_end, pdf_start, units = "mins"), 1)
    step_times[step_offset + 4] <- pdf_elapsed
    cat(sprintf("\nStep %d completed in %.1f minutes.\n", step_offset + 4, pdf_elapsed))
    cat(sprintf("  PDF: %s\n", file.path(latex_dir, "djm_main.pdf")))
  }
}

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
if (!skip_pdf && nzchar(Sys.which("pdflatex"))) {
  cat("  PDF:      output/paper/latex/djm_main.pdf\n")
}
cat("  Logs:     output/logs/\n")
cat("\n")

# Generate replication manifest
generate_replication_manifest(
  repo_root      = getwd(),
  pipeline       = "main",
  ndraws         = ndraws,
  step_times     = step_times,
  run_timestamp  = run_timestamp,
  pipeline_start = pipeline_start,
  pipeline_end   = pipeline_end,
  min_mtime      = if (!skip_estimation) pipeline_start else NULL
)
