###############################################################################
## audit_helpers.R - Post-Run Replication Manifest and Output Audit
## ---------------------------------------------------------------------------
##
## Reusable functions for generating a machine-readable replication manifest
## after a pipeline run. Inventories estimation artifacts, reconciles expected
## outputs against exhibits.csv, aggregates per-model timing from logs, and
## writes output/replication_manifest.json.
##
## Used by tools/audit_run.R (standalone) and called from the orchestrators
## _run_full_replication.R and ia/_run_ia_full.R at the end of each run.
###############################################################################

# --------------------------------------------------------------------------
# Environment snapshot
# --------------------------------------------------------------------------

audit_environment_info <- function() {
  pkgs <- c(
    "lubridate", "dplyr", "tidyr", "purrr", "tibble", "data.table", "rlang",
    "ggplot2", "RColorBrewer", "scales", "patchwork",
    "parallel", "doParallel", "foreach", "doRNG",
    "MASS", "Matrix", "matrixStats", "Hmisc", "proxyC",
    "BayesianFactorZoo", "xtable", "Rcpp", "RcppArmadillo"
  )

  versions <- vapply(pkgs, function(p) {
    if (requireNamespace(p, quietly = TRUE)) as.character(packageVersion(p)) else NA_character_
  }, character(1))

  list(
    R_version   = R.version.string,
    platform    = R.version$platform,
    os          = paste(Sys.info()["sysname"], Sys.info()["release"]),
    machine     = Sys.info()["machine"],
    packages    = as.list(versions)
  )
}

# --------------------------------------------------------------------------
# Inventory estimation artifacts from .Rdata files
# --------------------------------------------------------------------------

inventory_estimation_artifacts <- function(repo_root, pipelines = c("main", "ia")) {
  artifacts <- list()

  search_dirs <- character(0)
  if ("main" %in% pipelines) {
    search_dirs <- c(
      search_dirs,
      file.path(repo_root, "output", "unconditional"),
      file.path(repo_root, "output", "time_varying")
    )
  }
  if ("ia" %in% pipelines) {
    search_dirs <- c(search_dirs, file.path(repo_root, "ia", "output", "unconditional"))
  }

  for (dir in search_dirs) {
    if (!dir.exists(dir)) next
    rdata_files <- list.files(dir, pattern = "\\.Rdata$", recursive = TRUE, full.names = TRUE)
    rds_files   <- list.files(dir, pattern = "\\.rds$", recursive = TRUE, full.names = TRUE)

    for (f in c(rdata_files, rds_files)) {
      info <- file.info(f)
      entry <- list(
        path      = normalizePath(f, winslash = "/", mustWork = FALSE),
        rel_path  = sub(paste0("^", normalizePath(repo_root, winslash = "/"), "/"), "", normalizePath(f, winslash = "/")),
        size_mb   = round(info$size / 1e6, 2),
        mtime     = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
        ndraws    = NA_integer_,
        engine    = NA_character_,
        model_type = NA_character_
      )

      # Try to extract metadata from .Rdata files
      if (grepl("\\.Rdata$", f, ignore.case = TRUE)) {
        tryCatch({
          env <- new.env(parent = emptyenv())
          load(f, envir = env)
          if (exists("metadata", envir = env)) {
            md <- get("metadata", envir = env)
            if (!is.null(md$ndraws))       entry$ndraws     <- as.integer(md$ndraws)
            if (!is.null(md$engine_label))  entry$engine     <- md$engine_label
            if (!is.null(md$engine_used))   entry$engine     <- entry$engine %||% md$engine_used
            if (!is.null(md$model_type))    entry$model_type <- md$model_type
          }
        }, error = function(e) NULL)
      }

      artifacts <- c(artifacts, list(entry))
    }
  }

  artifacts
}

# --------------------------------------------------------------------------
# Reconcile outputs against exhibits.csv
# --------------------------------------------------------------------------

reconcile_exhibits <- function(repo_root, pipelines = c("main", "ia"), min_mtime = NULL) {
  manifest_path <- file.path(repo_root, "docs", "manifests", "exhibits.csv")
  if (!file.exists(manifest_path)) {
    return(list(ok = FALSE, issues = "exhibits.csv not found", exhibits = list()))
  }

  manifest <- read.csv(manifest_path, stringsAsFactors = FALSE)

  # Filter by pipeline
  categories <- character(0)
  if ("main" %in% pipelines) {
    categories <- c(categories, "main-table", "main-figure", "appendix-table", "appendix-figure")
  }
  if ("ia" %in% pipelines) {
    categories <- c(categories, "ia-table", "ia-figure")
  }

  relevant <- manifest[manifest$category %in% categories & manifest$coverage_status %in% c("implemented", "implemented-subset"), ]

  issues   <- character(0)
  exhibits <- list()

  for (idx in seq_len(nrow(relevant))) {
    row <- relevant[idx, ]
    pattern <- file.path(repo_root, row$output_path)
    found   <- Sys.glob(pattern)

    status <- if (length(found) > 0) "present" else "missing"

    # Check staleness
    stale_files <- character(0)
    if (length(found) > 0 && !is.null(min_mtime)) {
      infos <- file.info(found)
      stale_files <- rownames(infos)[!is.na(infos$mtime) & infos$mtime < min_mtime]
      if (length(stale_files) > 0) status <- "stale"
    }

    if (status != "present") {
      issues <- c(issues, paste0(row$exhibit_id, ": ", status, " (", row$output_path, ")"))
    }

    exhibits <- c(exhibits, list(list(
      exhibit_id = row$exhibit_id,
      category   = row$category,
      pattern    = row$output_path,
      status     = status,
      n_files    = length(found),
      files      = if (length(found) > 0) basename(found) else character(0)
    )))
  }

  list(
    ok       = length(issues) == 0,
    total    = nrow(relevant),
    present  = sum(vapply(exhibits, function(e) e$status == "present", logical(1))),
    missing  = sum(vapply(exhibits, function(e) e$status == "missing", logical(1))),
    stale    = sum(vapply(exhibits, function(e) e$status == "stale", logical(1))),
    issues   = issues,
    exhibits = exhibits
  )
}

# --------------------------------------------------------------------------
# Parse per-model timing from log files
# --------------------------------------------------------------------------

parse_model_timings <- function(repo_root, run_timestamp = NULL) {
  log_dirs <- c(
    file.path(repo_root, "output", "logs"),
    file.path(repo_root, "output", "time_varying", "logs"),
    file.path(repo_root, "ia", "output", "logs")
  )

  all_logs <- character(0)
  for (d in log_dirs) {
    if (dir.exists(d)) {
      logs <- list.files(d, pattern = "^log_", full.names = TRUE)
      all_logs <- c(all_logs, logs)
    }
  }

  # Filter by run timestamp if provided
  if (!is.null(run_timestamp)) {
    all_logs <- all_logs[grepl(run_timestamp, basename(all_logs), fixed = TRUE)]
  }

  timings <- list()
  for (logf in all_logs) {
    lines <- tryCatch(readLines(logf, warn = FALSE), error = function(e) character(0))
    if (length(lines) == 0) next

    started  <- grep("^Started:", lines, value = TRUE)
    finished <- grep("^Finished:", lines, value = TRUE)
    model    <- grep("^Model:", lines, value = TRUE)
    complete <- grep("^MODEL COMPLETE:", lines, value = TRUE)

    entry <- list(
      log_file  = basename(logf),
      rel_path  = sub(paste0("^", normalizePath(repo_root, winslash = "/"), "/"), "", normalizePath(logf, winslash = "/")),
      model     = if (length(model) > 0) trimws(sub("^Model:\\s*", "", model[1])) else NA_character_,
      started   = if (length(started) > 0) trimws(sub("^Started:\\s*", "", started[1])) else NA_character_,
      finished  = if (length(finished) > 0) trimws(sub("^Finished:\\s*", "", finished[1])) else NA_character_,
      status    = if (length(complete) > 0) "complete" else "incomplete"
    )

    # Compute elapsed minutes
    if (!is.na(entry$started) && !is.na(entry$finished)) {
      t1 <- tryCatch(as.POSIXct(entry$started), error = function(e) NA)
      t2 <- tryCatch(as.POSIXct(entry$finished), error = function(e) NA)
      if (!is.na(t1) && !is.na(t2)) {
        entry$elapsed_min <- round(as.numeric(difftime(t2, t1, units = "mins")), 1)
      }
    }

    timings <- c(timings, list(entry))
  }

  timings
}

# --------------------------------------------------------------------------
# Check PDF existence
# --------------------------------------------------------------------------

check_pdfs <- function(repo_root, pipelines = c("main", "ia")) {
  pdfs <- list()

  if ("main" %in% pipelines) {
    path <- file.path(repo_root, "output", "paper", "latex", "djm_main.pdf")
    info <- if (file.exists(path)) file.info(path) else NULL
    pdfs$main <- list(
      path    = "output/paper/latex/djm_main.pdf",
      exists  = file.exists(path),
      size_mb = if (!is.null(info)) round(info$size / 1e6, 2) else NA_real_,
      mtime   = if (!is.null(info)) format(info$mtime, "%Y-%m-%d %H:%M:%S") else NA_character_
    )
  }

  if ("ia" %in% pipelines) {
    path <- file.path(repo_root, "ia", "output", "paper", "latex", "ia_main.pdf")
    info <- if (file.exists(path)) file.info(path) else NULL
    pdfs$ia <- list(
      path    = "ia/output/paper/latex/ia_main.pdf",
      exists  = file.exists(path),
      size_mb = if (!is.null(info)) round(info$size / 1e6, 2) else NA_real_,
      mtime   = if (!is.null(info)) format(info$mtime, "%Y-%m-%d %H:%M:%S") else NA_character_
    )
  }

  pdfs
}

# --------------------------------------------------------------------------
# Generate the full manifest
# --------------------------------------------------------------------------

generate_replication_manifest <- function(
  repo_root      = getwd(),
  pipeline       = "main",
  ndraws         = NULL,
  step_times     = NULL,
  run_timestamp  = NULL,
  pipeline_start = NULL,
  pipeline_end   = NULL,
  min_mtime      = NULL,
  output_dir     = NULL
) {
  pipelines <- if (pipeline == "both") c("main", "ia") else pipeline

  manifest <- list(
    manifest_version = 1L,
    generated_at     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    pipeline         = pipeline,
    ndraws           = ndraws,
    run_timestamp    = run_timestamp
  )

  # Timing
  if (!is.null(pipeline_start) && !is.null(pipeline_end)) {
    manifest$total_elapsed_min <- round(as.numeric(difftime(pipeline_end, pipeline_start, units = "mins")), 1)
  }
  if (!is.null(step_times)) {
    manifest$step_timings <- as.list(step_times)
  }

  # Environment
  manifest$environment <- audit_environment_info()

  # Estimation artifacts
  manifest$estimation_artifacts <- inventory_estimation_artifacts(repo_root, pipelines)

  # Exhibit reconciliation
  manifest$exhibit_reconciliation <- reconcile_exhibits(repo_root, pipelines, min_mtime)

  # Per-model timing
  manifest$model_timings <- parse_model_timings(repo_root, run_timestamp)

  # PDFs
  manifest$pdfs <- check_pdfs(repo_root, pipelines)

  # Overall status
  exhibits_ok <- isTRUE(manifest$exhibit_reconciliation$ok)
  pdfs_ok     <- all(vapply(manifest$pdfs, function(p) isTRUE(p$exists), logical(1)))
  manifest$overall_status <- if (exhibits_ok && pdfs_ok) "complete" else "partial"

  if (!exhibits_ok) {
    manifest$issues <- manifest$exhibit_reconciliation$issues
  }

  # Write manifest
  if (is.null(output_dir)) {
    output_dir <- file.path(repo_root, "output")
  }
  if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

  manifest_filename <- if (!is.null(run_timestamp)) {
    sprintf("replication_manifest_%s_%s.json", pipeline, run_timestamp)
  } else {
    sprintf("replication_manifest_%s.json", pipeline)
  }
  manifest_path <- file.path(output_dir, manifest_filename)

  # Write JSON (no external dependency)
  json <- to_json(manifest)
  writeLines(json, manifest_path)

  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("REPLICATION MANIFEST\n")
  cat(strrep("=", 70), "\n")
  cat(sprintf("  Pipeline:    %s\n", pipeline))
  cat(sprintf("  Draws:       %s\n", if (!is.null(ndraws)) format(ndraws, big.mark = ",") else "unknown"))
  cat(sprintf("  Status:      %s\n", toupper(manifest$overall_status)))

  recon <- manifest$exhibit_reconciliation
  cat(sprintf("  Exhibits:    %d/%d present", recon$present, recon$total))
  if (recon$missing > 0) cat(sprintf(", %d missing", recon$missing))
  if (recon$stale > 0)   cat(sprintf(", %d stale", recon$stale))
  cat("\n")

  cat(sprintf("  Artifacts:   %d estimation files\n", length(manifest$estimation_artifacts)))
  cat(sprintf("  Model logs:  %d parsed\n", length(manifest$model_timings)))

  for (pname in names(manifest$pdfs)) {
    pdf <- manifest$pdfs[[pname]]
    cat(sprintf("  PDF (%s):  %s\n", pname, if (pdf$exists) "OK" else "MISSING"))
  }

  cat(sprintf("  Manifest:    %s\n", manifest_path))
  cat(strrep("=", 70), "\n\n")

  invisible(manifest)
}

# --------------------------------------------------------------------------
# Minimal JSON writer (no external dependency)
# --------------------------------------------------------------------------

to_json <- function(x, indent = 0) {
  pad  <- strrep("  ", indent)
  pad1 <- strrep("  ", indent + 1)

  if (is.null(x) || (is.atomic(x) && length(x) == 1 && is.na(x))) {
    return("null")
  }

  if (is.logical(x) && length(x) == 1) {
    return(if (x) "true" else "false")
  }

  if (is.numeric(x) && length(x) == 1) {
    return(format(x, scientific = FALSE))
  }

  if (is.character(x) && length(x) == 1) {
    escaped <- gsub("\\\\", "\\\\\\\\", x)
    escaped <- gsub('"', '\\\\"', escaped)
    escaped <- gsub("\n", "\\\\n", escaped)
    escaped <- gsub("\t", "\\\\t", escaped)
    return(paste0('"', escaped, '"'))
  }

  # Vector of length > 1

  if (is.atomic(x) && length(x) > 1) {
    elements <- vapply(x, function(el) to_json(el, indent + 1), character(1))
    return(paste0("[\n", pad1, paste(elements, collapse = paste0(",\n", pad1)), "\n", pad, "]"))
  }

  # Atomic vector of length 0
  if (is.atomic(x) && length(x) == 0) {
    return("[]")
  }

  # Named list -> object
  if (is.list(x) && !is.null(names(x))) {
    if (length(x) == 0) return("{}")
    entries <- vapply(names(x), function(k) {
      paste0(pad1, to_json(k), ": ", to_json(x[[k]], indent + 1))
    }, character(1))
    return(paste0("{\n", paste(entries, collapse = ",\n"), "\n", pad, "}"))
  }

  # Unnamed list -> array
  if (is.list(x)) {
    if (length(x) == 0) return("[]")
    elements <- vapply(seq_along(x), function(i) {
      paste0(pad1, to_json(x[[i]], indent + 1))
    }, character(1))
    return(paste0("[\n", paste(elements, collapse = ",\n"), "\n", pad, "]"))
  }

  # Fallback
  to_json(as.character(x), indent)
}

# --------------------------------------------------------------------------
# List runs from manifests or logs
# --------------------------------------------------------------------------

list_replication_runs <- function(repo_root = getwd(), latest_only = FALSE) {
  output_dir <- file.path(repo_root, "output")

  # Check for manifest files first
  manifests <- list.files(output_dir, pattern = "^replication_manifest_.*\\.json$", full.names = TRUE)

  if (length(manifests) > 0) {
    runs <- list()
    for (mf in sort(manifests, decreasing = TRUE)) {
      tryCatch({
        content <- paste(readLines(mf, warn = FALSE), collapse = "\n")
        # Extract key fields with regex (avoid jsonlite dependency)
        ts   <- regmatches(content, regexpr('"generated_at":\\s*"[^"]*"', content))
        ts   <- sub('.*"generated_at":\\s*"', "", sub('"$', "", ts))
        pipe <- regmatches(content, regexpr('"pipeline":\\s*"[^"]*"', content))
        pipe <- sub('.*"pipeline":\\s*"', "", sub('"$', "", pipe))
        st   <- regmatches(content, regexpr('"overall_status":\\s*"[^"]*"', content))
        st   <- sub('.*"overall_status":\\s*"', "", sub('"$', "", st))

        runs <- c(runs, list(list(
          manifest = basename(mf),
          timestamp = if (length(ts) > 0) ts else NA_character_,
          pipeline  = if (length(pipe) > 0) pipe else NA_character_,
          status    = if (length(st) > 0) st else NA_character_
        )))
      }, error = function(e) NULL)
    }

    if (latest_only && length(runs) > 0) runs <- runs[1]

    cat("\nReplication Runs\n")
    cat(strrep("-", 70), "\n")
    cat(sprintf("%-22s %-10s %-10s %s\n", "Timestamp", "Pipeline", "Status", "Manifest"))
    cat(strrep("-", 70), "\n")
    for (r in runs) {
      cat(sprintf("%-22s %-10s %-10s %s\n",
        r$timestamp %||% "?", r$pipeline %||% "?", r$status %||% "?", r$manifest))
    }
    cat("\n")
    return(invisible(runs))
  }

  # Fallback: group logs by timestamp
  log_dir <- file.path(repo_root, "output", "logs")
  if (!dir.exists(log_dir)) {
    cat("No manifest files or logs found.\n")
    return(invisible(list()))
  }

  logs <- list.files(log_dir, pattern = "^log_", full.names = FALSE)
  # Extract YYYYMMDD_HHMMSS from filenames
  timestamps <- unique(regmatches(logs, regexpr("[0-9]{8}_[0-9]{6}", logs)))
  timestamps <- sort(timestamps, decreasing = TRUE)

  if (latest_only && length(timestamps) > 0) timestamps <- timestamps[1]

  cat("\nReplication Runs (from logs)\n")
  cat(strrep("-", 70), "\n")
  cat(sprintf("%-18s %-8s %s\n", "Timestamp", "N Logs", "Log Files"))
  cat(strrep("-", 70), "\n")
  for (ts in timestamps) {
    matching <- logs[grepl(ts, logs, fixed = TRUE)]
    cat(sprintf("%-18s %-8d %s\n", ts, length(matching), paste(matching[1:min(3, length(matching))], collapse = ", ")))
    if (length(matching) > 3) cat(sprintf("%-18s %-8s ... and %d more\n", "", "", length(matching) - 3))
  }
  cat("\n")

  if (latest_only && length(timestamps) > 0) {
    cat("Log files for latest run:\n")
    matching <- logs[grepl(timestamps[1], logs, fixed = TRUE)]
    for (lf in matching) cat(sprintf("  %s\n", file.path(log_dir, lf)))
    cat("\n")
  }

  invisible(timestamps)
}

# Null-coalescing operator (if not already defined)
if (!exists("%||%", mode = "function")) {
  `%||%` <- function(a, b) if (is.null(a) || (is.atomic(a) && length(a) == 1 && is.na(a))) b else a
}
