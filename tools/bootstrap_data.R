#!/usr/bin/env Rscript

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }

  normalizePath(dirname(sub("^--file=", "", file_arg[1])), winslash = "/", mustWork = TRUE)
}

get_repo_root <- function() {
  normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
}

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  opts <- list(
    check_only = FALSE,
    force = FALSE,
    source_id = NULL
  )

  for (arg in args) {
    if (identical(arg, "--check")) {
      opts$check_only <- TRUE
    } else if (identical(arg, "--force")) {
      opts$force <- TRUE
    } else if (grepl("^--source=", arg)) {
      opts$source_id <- sub("^--source=", "", arg)
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript tools/bootstrap_data.R [options]\n\n",
        "Options:\n",
        "  --check           Report missing bundle-managed files without downloading\n",
        "  --force           Download and extract even if all bundle-managed files exist\n",
        "  --source=ID       Override the canonical source_id from docs/manifests/data-sources.csv\n",
        "  --help, -h        Show this help message\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts
}

read_manifest <- function(repo_root, filename) {
  utils::read.csv(
    file.path(repo_root, "docs", "manifests", filename),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
}

select_source <- function(source_manifest, source_id = NULL) {
  if (!is.null(source_id) && nzchar(source_id)) {
    selected <- source_manifest[source_manifest$source_id == source_id, , drop = FALSE]
  } else {
    selected <- subset(source_manifest, canonical == "yes")
  }

  if (nrow(selected) != 1) {
    stop("Could not resolve exactly one data source row.", call. = FALSE)
  }

  selected[1, , drop = FALSE]
}

status_table <- function(repo_root, data_manifest, source_id) {
  covered <- subset(data_manifest, bootstrap_source_id == source_id)
  if (nrow(covered) == 0) {
    stop("No data-files.csv rows are assigned to bootstrap source '", source_id, "'.", call. = FALSE)
  }

  covered$exists <- file.exists(file.path(repo_root, covered$path))
  covered
}

print_status <- function(status_df) {
  summary_df <- data.frame(
    path = status_df$path,
    required = status_df$required,
    exists = status_df$exists,
    stringsAsFactors = FALSE
  )
  print(summary_df, row.names = FALSE)
}

download_bundle <- function(url, archive_type) {
  suffix <- if (nzchar(archive_type)) paste0(".", archive_type) else ""
  bundle_path <- tempfile(pattern = "djm-data-", fileext = suffix)
  utils::download.file(url, destfile = bundle_path, mode = "wb", quiet = FALSE)
  bundle_path
}

extract_bundle <- function(bundle_path, archive_type, target_dir) {
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)

  if (identical(tolower(archive_type), "zip")) {
    utils::unzip(bundle_path, exdir = target_dir, overwrite = TRUE)
    return(invisible(TRUE))
  }

  stop("Unsupported archive_type: ", archive_type, call. = FALSE)
}

main <- function() {
  opts <- parse_args()
  repo_root <- get_repo_root()
  data_manifest <- read_manifest(repo_root, "data-files.csv")
  source_manifest <- read_manifest(repo_root, "data-sources.csv")
  source_row <- select_source(source_manifest, opts$source_id)

  source_id <- source_row$source_id[[1]]
  bundle_url <- source_row$bundle_url[[1]]
  archive_type <- source_row$archive_type[[1]]
  extract_to <- source_row$extract_to[[1]]
  target_dir <- file.path(repo_root, extract_to)

  bundle_status <- status_table(repo_root, data_manifest, source_id)
  covered_required <- subset(bundle_status, required == "yes")
  uncovered_required <- subset(data_manifest, required == "yes" & bootstrap_source_id != source_id)
  uncovered_required$exists <- file.exists(file.path(repo_root, uncovered_required$path))
  uncovered_required_missing <- subset(uncovered_required, !exists)

  cat("Repo root: ", repo_root, "\n", sep = "")
  cat("Source:    ", source_id, "\n", sep = "")
  cat("Bundle:    ", bundle_url, "\n", sep = "")
  cat("Target:    ", target_dir, "\n\n", sep = "")

  if (nrow(uncovered_required_missing) > 0) {
    stop(
      "Required repo files are missing outside the canonical data bundle. Restore these tracked files from the clone: ",
      paste(uncovered_required_missing$path, collapse = ", "),
      call. = FALSE
    )
  }

  cat("Bundle-managed file status:\n")
  print_status(bundle_status)

  missing_required <- subset(covered_required, !exists)
  if (opts$check_only) {
    if (nrow(missing_required) > 0) {
      cat(
        "\nMissing required bundle-managed files:\n  ",
        paste(missing_required$path, collapse = ", "),
        "\n",
        sep = ""
      )
      cat("Run `Rscript tools/bootstrap_data.R` or the platform wrapper to download and extract the canonical bundle.\n")
      quit(save = "no", status = 1)
    }

    cat("\nAll required bundle-managed files are present.\n")
    quit(save = "no", status = 0)
  }

  if (nrow(missing_required) == 0 && !opts$force) {
    cat("\nAll bundle-managed files are already present. Use --force to re-download and overwrite them.\n")
    quit(save = "no", status = 0)
  }

  cat("\nDownloading canonical data bundle...\n")
  bundle_path <- download_bundle(bundle_url, archive_type)
  on.exit(unlink(bundle_path), add = TRUE)

  cat("Extracting into ", target_dir, " ...\n", sep = "")
  extract_bundle(bundle_path, archive_type, target_dir)

  final_status <- status_table(repo_root, data_manifest, source_id)
  final_missing_required <- subset(final_status, required == "yes" & !exists)

  cat("\nBundle-managed file status after extraction:\n")
  print_status(final_status)

  if (nrow(final_missing_required) > 0) {
    cat(
      "\nBootstrap incomplete. Missing required files remain:\n  ",
      paste(final_missing_required$path, collapse = ", "),
      "\n",
      sep = ""
    )
    quit(save = "no", status = 1)
  }

  tracked_required <- subset(data_manifest, required == "yes" & !nzchar(bootstrap_source_id))
  if (nrow(tracked_required) > 0) {
    cat(
      "\nRequired repo-tracked files outside the canonical bundle should already be present in the clone:\n  ",
      paste(tracked_required$path, collapse = ", "),
      "\n",
      sep = ""
    )
  }

  cat("\nData bootstrap complete. The canonical bundle is in place.\n")
}

if (sys.nframe() == 0) {
  main()
}
