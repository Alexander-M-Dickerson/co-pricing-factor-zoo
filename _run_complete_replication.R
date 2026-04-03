#!/usr/bin/env Rscript
###############################################################################
## _run_complete_replication.R - Complete Main + IA Replication
## ---------------------------------------------------------------------------
##
## Runs both the main paper and Internet Appendix pipelines end-to-end, then
## generates a combined replication manifest.
##
## Main paper:              6 steps, ~65 min at 50k draws
## Internet Appendix:       4 steps, ~16 min at 50k draws
## Representative total:    ~81 min on a 24-core desktop
##
## USAGE:
##   Rscript _run_complete_replication.R [options]
##
## OPTIONS:
##   --ndraws=N        Number of MCMC draws (default: 50000; paper setting)
##   --quick           Shortcut for --ndraws=5000
##   --skip-main       Skip the main paper pipeline
##   --skip-ia         Skip the Internet Appendix pipeline
##   --skip-pdf        Skip PDF compilation in both pipelines
##   --fail-fast       Stop immediately if the main pipeline fails
##   --help            Show this help message
##
###############################################################################

args <- commandArgs(trailingOnly = TRUE)

ndraws    <- 50000
quick     <- FALSE
skip_main <- FALSE
skip_ia   <- FALSE
skip_pdf  <- FALSE
fail_fast <- FALSE
show_help <- FALSE

for (arg in args) {
  if (grepl("^--ndraws=", arg)) {
    ndraws <- as.integer(sub("^--ndraws=", "", arg))
  } else if (identical(arg, "--quick")) {
    quick <- TRUE
    ndraws <- 5000
  } else if (identical(arg, "--skip-main")) {
    skip_main <- TRUE
  } else if (identical(arg, "--skip-ia")) {
    skip_ia <- TRUE
  } else if (identical(arg, "--skip-pdf")) {
    skip_pdf <- TRUE
  } else if (identical(arg, "--fail-fast")) {
    fail_fast <- TRUE
  } else if (arg %in% c("--help", "-h")) {
    show_help <- TRUE
  }
}

if (show_help) {
  cat("
_run_complete_replication.R - Complete Main + IA Replication

USAGE:
  Rscript _run_complete_replication.R [options]

OPTIONS:
  --ndraws=N        Number of MCMC draws (default: 50000; paper setting)
  --quick           Reduced-draw smoke mode (--ndraws=5000)
  --skip-main       Skip the main paper pipeline
  --skip-ia         Skip the Internet Appendix pipeline
  --skip-pdf        Skip PDF compilation in both pipelines
  --fail-fast       Stop immediately if the main pipeline fails (default: continue to IA)
  --help            Show this help message

EXAMPLES:
  Rscript _run_complete_replication.R                    # Full replication (~81 min)
  Rscript _run_complete_replication.R --quick            # Reduced-draw smoke (~15 min)
  Rscript _run_complete_replication.R --skip-main        # IA only

")
  quit(status = 0)
}

source(file.path("code_base", "audit_helpers.R"))

repo_rscript <- if (.Platform$OS.type == "windows") {
  file.path(R.home("bin"), "Rscript.exe")
} else {
  file.path(R.home("bin"), "Rscript")
}

cat("\n")
cat(strrep("#", 70), "\n")
cat("#", strrep(" ", 66), "#\n")
cat("#   COMPLETE REPLICATION: MAIN PAPER + INTERNET APPENDIX", strrep(" ", 12), "#\n")
cat("#", strrep(" ", 66), "#\n")
cat(strrep("#", 70), "\n\n")

cat("Configuration:\n")
cat(sprintf("  MCMC draws:  %d\n", ndraws))
cat(sprintf("  Main paper:  %s\n", if (skip_main) "SKIP" else "YES"))
cat(sprintf("  IA:          %s\n", if (skip_ia) "SKIP" else "YES"))
cat(sprintf("  PDF:         %s\n", if (skip_pdf) "SKIP" else "YES"))
cat("\n")

overall_start <- Sys.time()
main_time <- NA_real_
ia_time   <- NA_real_
main_ok   <- TRUE
ia_ok     <- TRUE

# ---- Main paper pipeline ----

if (!skip_main) {
  cat(strrep("=", 70), "\n")
  cat("MAIN PAPER PIPELINE\n")
  cat(strrep("=", 70), "\n\n")

  main_start <- Sys.time()
  main_args <- c("_run_full_replication.R", sprintf("--ndraws=%d", ndraws))
  if (skip_pdf) main_args <- c(main_args, "--skip-pdf")

  rc <- system2(repo_rscript, args = main_args)

  main_end  <- Sys.time()
  main_time <- round(as.numeric(difftime(main_end, main_start, units = "mins")), 1)

  if (rc != 0) {
    main_ok <- FALSE
    cat(sprintf("\nMain paper pipeline FAILED (exit %d) after %.1f minutes.\n\n", rc, main_time))
    if (fail_fast) {
      cat("--fail-fast: aborting.\n")
      quit(status = 1)
    }
    cat("Continuing to IA pipeline...\n\n")
  } else {
    cat(sprintf("\nMain paper pipeline completed in %.1f minutes.\n\n", main_time))
  }
} else {
  cat("Skipping main paper pipeline (--skip-main)\n\n")
}

# ---- IA pipeline ----

if (!skip_ia) {
  cat(strrep("=", 70), "\n")
  cat("INTERNET APPENDIX PIPELINE\n")
  cat(strrep("=", 70), "\n\n")

  ia_start <- Sys.time()
  ia_args <- c("ia/_run_ia_full.R", sprintf("--ndraws=%d", ndraws))
  if (skip_pdf) ia_args <- c(ia_args, "--skip-pdf")

  rc <- system2(repo_rscript, args = ia_args)

  ia_end  <- Sys.time()
  ia_time <- round(as.numeric(difftime(ia_end, ia_start, units = "mins")), 1)

  if (rc != 0) {
    ia_ok <- FALSE
    cat(sprintf("\nIA pipeline FAILED (exit %d) after %.1f minutes.\n\n", rc, ia_time))
  } else {
    cat(sprintf("\nIA pipeline completed in %.1f minutes.\n\n", ia_time))
  }
} else {
  cat("Skipping IA pipeline (--skip-ia)\n\n")
}

# ---- Combined summary ----

overall_end <- Sys.time()
total_elapsed <- round(as.numeric(difftime(overall_end, overall_start, units = "mins")), 1)

cat(strrep("#", 70), "\n")
cat("#", strrep(" ", 66), "#\n")
if (main_ok && ia_ok) {
  cat("#   COMPLETE REPLICATION FINISHED", strrep(" ", 35), "#\n")
} else {
  cat("#   COMPLETE REPLICATION FINISHED (WITH ISSUES)", strrep(" ", 20), "#\n")
}
cat("#", strrep(" ", 66), "#\n")
cat(strrep("#", 70), "\n\n")

cat(sprintf("Total runtime: %.1f minutes\n\n", total_elapsed))
if (!is.na(main_time)) cat(sprintf("  Main paper:  %.1f min  %s\n", main_time, if (main_ok) "OK" else "FAILED"))
if (!is.na(ia_time))   cat(sprintf("  IA:          %.1f min  %s\n", ia_time, if (ia_ok) "OK" else "FAILED"))
cat("\n")

# ---- Combined manifest ----

generate_replication_manifest(
  repo_root      = getwd(),
  pipeline       = "both",
  ndraws         = ndraws,
  run_timestamp  = format(overall_start, "%Y%m%d_%H%M%S"),
  pipeline_start = overall_start,
  pipeline_end   = overall_end,
  min_mtime      = overall_start
)

if (!main_ok || !ia_ok) quit(status = 1)
