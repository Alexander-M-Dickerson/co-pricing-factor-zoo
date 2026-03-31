#!/usr/bin/env Rscript

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x)) {
    y
  } else {
    x
  }
}

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
    force_rebuild = FALSE
  )

  for (arg in args) {
    if (identical(arg, "--check-only")) {
      opts$check_only <- TRUE
    } else if (identical(arg, "--force-rebuild")) {
      opts$force_rebuild <- TRUE
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript tools/doctor.R [options]\n\n",
        "Options:\n",
        "  --check-only     Run a non-destructive readiness check\n",
        "  --force-rebuild  Rebuild both fast C++ backends before reporting\n",
        "  --help, -h       Show this help message\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts
}

read_data_manifest <- function(repo_root) {
  manifest_path <- file.path(repo_root, "docs", "manifests", "data-files.csv")
  utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
}

check_packages <- function(packages) {
  data.frame(
    package = packages,
    installed = vapply(packages, requireNamespace, logical(1), quietly = TRUE),
    stringsAsFactors = FALSE
  )
}

check_data_files <- function(repo_root, manifest) {
  resolved_paths <- file.path(repo_root, manifest$path)
  data.frame(
    path = manifest$path,
    required_for = manifest$required_for,
    required = manifest$required,
    exists = file.exists(resolved_paths),
    stringsAsFactors = FALSE
  )
}

check_toolchain <- function(repo_root) {
  source(file.path(repo_root, "testing", "validation_helpers.R"))
  collect_toolchain_status()
}

check_backends <- function(repo_root, force_rebuild) {
  source(file.path(repo_root, "code_base", "continuous_ss_sdf_fast.R"))
  source(file.path(repo_root, "code_base", "continuous_ss_sdf_v2_fast.R"))

  fast_loaded <- tryCatch(
    load_continuous_ss_sdf_fast_cpp(force_rebuild = force_rebuild),
    error = function(e) {
      continuous_ss_sdf_fast_cpp_state$last_error <- conditionMessage(e)
      FALSE
    }
  )
  fast_status <- continuous_ss_sdf_fast_backend_status()

  v2_loaded <- tryCatch(
    load_continuous_ss_sdf_v2_fast_cpp(force_rebuild = force_rebuild),
    error = function(e) {
      continuous_ss_sdf_v2_fast_cpp_state$last_error <- conditionMessage(e)
      FALSE
    }
  )
  v2_status <- continuous_ss_sdf_v2_fast_backend_status()

  data.frame(
    backend = c("continuous_ss_sdf_fast", "continuous_ss_sdf_v2_fast"),
    loaded = c(isTRUE(fast_loaded), isTRUE(v2_loaded)),
    last_error = c(
      fast_status$last_error %||% "",
      v2_status$last_error %||% ""
    ),
    stringsAsFactors = FALSE
  )
}

print_section <- function(title) {
  cat("\n", title, "\n", strrep("=", nchar(title)), "\n", sep = "")
}

main <- function() {
  opts <- parse_args()
  repo_root <- get_repo_root()
  source(file.path(repo_root, "tools", "bootstrap_packages.R"))

  packages <- get_required_packages()
  package_status <- check_packages(packages)
  data_manifest <- read_data_manifest(repo_root)
  data_status <- check_data_files(repo_root, data_manifest)
  toolchain_status <- suppressWarnings(check_toolchain(repo_root))
  backend_status <- check_backends(repo_root, force_rebuild = opts$force_rebuild)

  rscript_name <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  rscript_path <- file.path(R.home("bin"), rscript_name)
  pdflatex_path <- Sys.which("pdflatex")

  required_data_missing <- subset(data_status, required == "yes" & !exists)
  optional_data_missing <- subset(data_status, required != "yes" & !exists)
  missing_packages <- subset(package_status, !installed)

  main_ready <- nrow(missing_packages) == 0 &&
    nrow(required_data_missing) == 0 &&
    all(backend_status$loaded)
  latex_ready <- main_ready && nzchar(pdflatex_path)
  treasury_weighted_ready <- main_ready && !any(data_status$path == "ia/data/w_all.rds" & !data_status$exists)

  cat("Repo doctor for The Co-Pricing Factor Zoo\n")
  cat("Repo root: ", repo_root, "\n", sep = "")
  cat("Mode: ", if (opts$check_only) "check-only" else "standard", "\n", sep = "")
  cat("Rscript: ", normalizePath(rscript_path, winslash = "/", mustWork = FALSE), "\n", sep = "")

  print_section("Toolchain")
  print(toolchain_status, row.names = FALSE)
  if (!isTRUE(toolchain_status$compile_probe)) {
    cat(
      "\nToolchain note: compile probes can fail inside restricted or sandboxed terminals even when Rtools paths are visible.\n",
      sep = ""
    )
  }

  print_section("Packages")
  print(package_status, row.names = FALSE)
  if (nrow(missing_packages) > 0) {
    cat("\nMissing packages:\n")
    cat("  ", paste(missing_packages$package, collapse = ", "), "\n", sep = "")
    cat("Run `Rscript tools/bootstrap_packages.R` or the PowerShell wrapper to install them.\n")
  }

  print_section("Data Files")
  print(data_status, row.names = FALSE)
  if (nrow(required_data_missing) > 0) {
    cat("\nMissing required data files:\n")
    cat("  ", paste(required_data_missing$path, collapse = ", "), "\n", sep = "")
  }
  if (nrow(optional_data_missing) > 0) {
    cat("\nMissing optional IA-only data files:\n")
    cat("  ", paste(optional_data_missing$path, collapse = ", "), "\n", sep = "")
  }

  print_section("Fast Backends")
  print(backend_status, row.names = FALSE)
  if (!all(backend_status$loaded)) {
    cat(
      "\nBackend note: if compilation fails in a managed or sandboxed terminal, retry the doctor in a normal PowerShell or shell before changing repo code.\n",
      sep = ""
    )
  }

  print_section("LaTeX")
  cat("pdflatex: ", if (nzchar(pdflatex_path)) pdflatex_path else "not found", "\n", sep = "")

  print_section("Readiness Summary")
  summary_df <- data.frame(
    target = c(
      "Main paper estimation and outputs",
      "Final LaTeX assembly",
      "Treasury-weighted IA branch"
    ),
    ready = c(main_ready, latex_ready, treasury_weighted_ready),
    stringsAsFactors = FALSE
  )
  print(summary_df, row.names = FALSE)

  if (!main_ready) {
    cat(
      "\nNext action: fix the first missing package, required data file, or backend error above, then rerun the doctor.\n",
      sep = ""
    )
    quit(save = "no", status = 1)
  }

  cat("\nThe repo is ready for the main paper pipeline.\n")
  if (!latex_ready) {
    cat("LaTeX is optional until you need final PDF assembly.\n")
  }
  if (!treasury_weighted_ready) {
    cat("Weighted-treasury IA outputs remain blocked until ia/data/w_all.rds is present.\n")
  }
}

if (sys.nframe() == 0) {
  main()
}
