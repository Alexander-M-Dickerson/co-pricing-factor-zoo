#!/usr/bin/env Rscript
###############################################################################
## audit_run.R - Post-Run Replication Audit
## ---------------------------------------------------------------------------
##
## Standalone tool that audits a completed replication run. Inventories
## estimation artifacts, reconciles expected outputs against exhibits.csv,
## aggregates per-model timing from logs, and writes a machine-readable
## replication manifest to output/replication_manifest_<pipeline>_<timestamp>.json.
##
## Also called automatically at the end of _run_full_replication.R and
## ia/_run_ia_full.R.
##
## USAGE:
##   Rscript tools/audit_run.R [options]
##
## OPTIONS:
##   --pipeline=PIPELINE   Pipeline to audit: main, ia, or both (default: both)
##   --ndraws=N            Expected draw count (for reporting only)
##   --run-timestamp=TS    Filter logs to a specific run timestamp (YYYYMMDD_HHMMSS)
##   --list-runs           List all recorded runs and exit
##   --latest              Show the latest run only (with --list-runs)
##   --help                Show this help message
##
###############################################################################

args <- commandArgs(trailingOnly = TRUE)

pipeline      <- "both"
ndraws        <- NULL
run_timestamp <- NULL
list_runs     <- FALSE
latest        <- FALSE
show_help     <- FALSE

for (arg in args) {
  if (grepl("^--pipeline=", arg)) {
    pipeline <- sub("^--pipeline=", "", arg)
  } else if (grepl("^--ndraws=", arg)) {
    ndraws <- as.integer(sub("^--ndraws=", "", arg))
  } else if (grepl("^--run-timestamp=", arg)) {
    run_timestamp <- sub("^--run-timestamp=", "", arg)
  } else if (identical(arg, "--list-runs")) {
    list_runs <- TRUE
  } else if (identical(arg, "--latest")) {
    latest <- TRUE
  } else if (arg %in% c("--help", "-h")) {
    show_help <- TRUE
  }
}

if (show_help) {
  cat("
audit_run.R - Post-Run Replication Audit

USAGE:
  Rscript tools/audit_run.R [options]

OPTIONS:
  --pipeline=PIPELINE   Pipeline to audit: main, ia, or both (default: both)
  --ndraws=N            Expected draw count (for reporting only)
  --run-timestamp=TS    Filter logs to a specific run timestamp
  --list-runs           List all recorded runs and exit
  --latest              Show the latest run only (with --list-runs)
  --help                Show this help message

EXAMPLES:
  Rscript tools/audit_run.R                          # Audit both pipelines
  Rscript tools/audit_run.R --pipeline=main          # Audit main paper only
  Rscript tools/audit_run.R --list-runs              # List all runs
  Rscript tools/audit_run.R --list-runs --latest     # Show latest run

")
  quit(save = "no", status = 0)
}

# Resolve repo root
if (basename(getwd()) == "tools") setwd("..")
repo_root <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

source(file.path(repo_root, "code_base", "audit_helpers.R"))

if (list_runs) {
  list_replication_runs(repo_root, latest_only = latest)
  quit(save = "no", status = 0)
}

manifest <- generate_replication_manifest(
  repo_root     = repo_root,
  pipeline      = pipeline,
  ndraws        = ndraws,
  run_timestamp = run_timestamp
)

status <- if (identical(manifest$overall_status, "complete")) 0L else 1L
quit(save = "no", status = status)
