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

read_data_source_manifest <- function(repo_root) {
  manifest_path <- file.path(repo_root, "docs", "manifests", "data-sources.csv")
  if (!file.exists(manifest_path)) {
    return(data.frame())
  }

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
    bootstrap_source_id = manifest$bootstrap_source_id,
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

check_execution_surface <- function(repo_root, rscript_path) {
  normalized_root <- normalizePath(repo_root, winslash = "/", mustWork = FALSE)
  managed_workspace <- grepl("/\\.codex/\\.sandbox/", normalized_root) ||
    grepl("CodexSandboxOffline", normalized_root, ignore.case = TRUE)

  processx_supported <- FALSE
  processx_detail <- "processx is not installed."
  if (requireNamespace("processx", quietly = TRUE)) {
    processx_probe <- tryCatch({
      if (file.exists(rscript_path)) {
        proc <- processx::process$new(
          command = rscript_path,
          args = "--version",
          stdout = "|",
          stderr = "|",
          cleanup_tree = TRUE
        )
      } else {
        proc <- processx::process$new(
          command = "/bin/sh",
          args = c("-lc", "exit 0"),
          stdout = "|",
          stderr = "|",
          cleanup_tree = TRUE
        )
      }
      proc$wait(timeout = 5000)
      stdout_text <- tryCatch(proc$read_all_output(), error = function(e) "")
      stderr_text <- tryCatch(proc$read_all_error(), error = function(e) "")
      probe_text <- paste(stdout_text, stderr_text)
      list(
        ok = identical(proc$get_exit_status(), 0L),
        detail = if (identical(proc$get_exit_status(), 0L)) {
          if (grepl("Rscript", probe_text, fixed = TRUE)) {
            "Child Rscript processes with piped stdio are supported."
          } else {
            "Child process exited cleanly, but the probe output was not observed."
          }
        } else {
          paste(
            "Child process exited with status",
            proc$get_exit_status(),
            if (nzchar(probe_text)) paste0("(", trimws(probe_text), ")") else ""
          )
        }
      )
    }, error = function(e) {
      list(ok = FALSE, detail = conditionMessage(e))
    })

    processx_supported <- isTRUE(processx_probe$ok)
    processx_detail <- processx_probe$detail
  }

  data.frame(
    check = c("managed_workspace", "child_process_supervision"),
    ready = c(!managed_workspace, processx_supported),
    detail = c(
      if (managed_workspace) {
        "Managed sandbox workspace detected. Heavy replication should run from a normal host shell."
      } else {
        "Repo is running from a normal host workspace."
      },
      processx_detail
    ),
    stringsAsFactors = FALSE
  )
}

check_macos_toolchain <- function() {
  sysname <- Sys.info()[["sysname"]] %||% ""
  if (!identical(sysname, "Darwin")) {
    return(data.frame())
  }

  xcode_select <- Sys.which("xcode-select")
  clang_path <- Sys.which("clang")
  gfortran_path <- Sys.which("gfortran")

  xcode_ready <- FALSE
  xcode_detail <- "xcode-select not found. Install Xcode Command Line Tools with `xcode-select --install`."
  if (nzchar(xcode_select)) {
    xcode_probe <- tryCatch({
      output <- system2(xcode_select, "-p", stdout = TRUE, stderr = TRUE)
      status <- attr(output, "status") %||% 0L
      list(
        ok = identical(as.integer(status), 0L),
        detail = if (identical(as.integer(status), 0L) && length(output) > 0) {
          paste("Xcode Command Line Tools root:", trimws(output[[1]]))
        } else if (length(output) > 0) {
          paste(trimws(output), collapse = " ")
        } else {
          "xcode-select did not report an active developer directory."
        }
      )
    }, error = function(e) {
      list(ok = FALSE, detail = conditionMessage(e))
    })

    xcode_ready <- isTRUE(xcode_probe$ok)
    xcode_detail <- xcode_probe$detail
  }

  data.frame(
    check = c("xcode_clt", "clang", "gfortran"),
    ready = c(
      xcode_ready,
      nzchar(clang_path),
      nzchar(gfortran_path)
    ),
    detail = c(
      xcode_detail,
      if (nzchar(clang_path)) {
        paste("clang found at", unname(clang_path))
      } else {
        "clang not found on PATH. Xcode Command Line Tools are required for Rcpp compilation."
      },
      if (nzchar(gfortran_path)) {
        paste("gfortran found at", unname(gfortran_path))
      } else {
        paste(
          "gfortran not found on PATH.",
          "Install the CRAN-recommended GNU Fortran that matches your CRAN R version:",
          "https://cran.r-project.org/bin/macosx/tools/",
          "and",
          "https://mac.r-project.org/tools/"
        )
      }
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
  data_source_manifest <- read_data_source_manifest(repo_root)
  data_status <- check_data_files(repo_root, data_manifest)
  toolchain_status <- suppressWarnings(check_toolchain(repo_root))
  backend_status <- check_backends(repo_root, force_rebuild = opts$force_rebuild)

  rscript_name <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  rscript_path <- file.path(R.home("bin"), rscript_name)
  execution_surface <- check_execution_surface(repo_root, rscript_path)
  macos_toolchain <- check_macos_toolchain()
  pdflatex_path <- Sys.which("pdflatex")

  required_data_missing <- subset(data_status, required == "yes" & !exists)
  bundle_managed_missing <- subset(required_data_missing, nzchar(bootstrap_source_id))
  bundle_unmanaged_missing <- subset(required_data_missing, !nzchar(bootstrap_source_id))
  missing_packages <- subset(package_status, !installed)
  macos_toolchain_ready <- nrow(macos_toolchain) == 0 || all(macos_toolchain$ready)

  main_ready <- nrow(missing_packages) == 0 &&
    nrow(required_data_missing) == 0 &&
    all(backend_status$loaded) &&
    macos_toolchain_ready
  current_shell_parallel_ready <- main_ready && all(execution_surface$ready)
  latex_ready <- main_ready && nzchar(pdflatex_path)
  ia_ready <- main_ready

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
  if (nrow(data_source_manifest) > 0) {
    canonical_source <- subset(data_source_manifest, canonical == "yes")
    if (nrow(canonical_source) == 1) {
      print_section("Data Bootstrap")
      cat("source_id: ", canonical_source$source_id[[1]], "\n", sep = "")
      cat("bundle_url: ", canonical_source$bundle_url[[1]], "\n", sep = "")
      cat("extract_to: ", canonical_source$extract_to[[1]], "\n", sep = "")
    }
  }
  if (nrow(required_data_missing) > 0) {
    cat("\nMissing required data files:\n")
    cat("  ", paste(required_data_missing$path, collapse = ", "), "\n", sep = "")
    if (nrow(bundle_managed_missing) > 0) {
      cat("Run `Rscript tools/bootstrap_data.R` or the platform wrapper to fetch the canonical public bundle.\n")
    }
    if (nrow(bundle_unmanaged_missing) > 0) {
      cat("Some required files are tracked with the repo and should already be present in the clone. Restore them from git before rerunning the doctor.\n")
    }
  }

  print_section("Fast Backends")
  print(backend_status, row.names = FALSE)
  if (!all(backend_status$loaded)) {
    cat(
      "\nBackend note: if compilation fails in a managed or sandboxed terminal, retry the doctor in a normal PowerShell or shell before changing repo code.\n",
      sep = ""
    )
  }

  print_section("Execution Surface")
  print(execution_surface, row.names = FALSE)
  if (!all(execution_surface$ready)) {
    cat(
      "\nExecution note: concurrent child supervision or backend rebuilds may be blocked in managed terminals. Use the host PowerShell wrappers for long replication runs.\n",
      sep = ""
    )
  }

  if (nrow(macos_toolchain) > 0) {
    print_section("macOS Toolchain")
    print(macos_toolchain, row.names = FALSE)
    cat(
      "\nmacOS note: use the official CRAN/mac.R toolchain pages and match GNU Fortran to the installed CRAN R version.\n",
      "Avoid mixing CRAN R binaries with Homebrew or MacPorts compilers unless you are rebuilding the full toolchain consistently.\n",
      sep = ""
    )
  }

  print_section("LaTeX")
  cat("pdflatex: ", if (nzchar(pdflatex_path)) pdflatex_path else "not found", "\n", sep = "")

  print_section("Readiness Summary")
  summary_targets <- c("Main paper estimation and outputs")
  summary_ready <- c(main_ready)
  if (nrow(macos_toolchain) > 0) {
    summary_targets <- c(summary_targets, "macOS build toolchain")
    summary_ready <- c(summary_ready, macos_toolchain_ready)
  }
  summary_targets <- c(
    summary_targets,
    "Parallel conditional execution in current shell",
    "Final LaTeX assembly",
    "Implemented IA estimation surface"
  )
  summary_ready <- c(summary_ready, current_shell_parallel_ready, latex_ready, ia_ready)
  summary_df <- data.frame(
    target = summary_targets,
    ready = summary_ready,
    stringsAsFactors = FALSE
  )
  print(summary_df, row.names = FALSE)

  if (!main_ready) {
    cat("\n")
    if (nrow(missing_packages) > 0) {
      cat("Next action: run `Rscript tools/bootstrap_packages.R` or the platform wrapper, then rerun the doctor.\n")
    } else if (nrow(bundle_managed_missing) > 0) {
      cat("Next action: run `Rscript tools/bootstrap_data.R` or the platform wrapper, then rerun the doctor.\n")
    } else if (nrow(required_data_missing) > 0) {
      cat("Next action: add the missing required data files listed above, then rerun the doctor.\n")
    } else {
      cat("Next action: fix the first backend or toolchain error above, then rerun the doctor.\n")
    }
    quit(save = "no", status = 1)
  }

  cat("\nThe repo is ready for the main paper pipeline.\n")
  if (!latex_ready) {
    cat("LaTeX is optional until you need final PDF assembly.\n")
  }
  cat("The repo is ready for the implemented IA estimation surface.\n")
}

if (sys.nframe() == 0) {
  main()
}
