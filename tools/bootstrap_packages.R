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

get_required_packages <- function() {
  c(
    "BayesianFactorZoo",
    "Rcpp",
    "RcppArmadillo",
    "pkgbuild",
    "MASS",
    "MCMCpack",
    "matrixStats",
    "doParallel",
    "foreach",
    "doRNG",
    "processx",
    "ggplot2",
    "ggtext",
    "patchwork",
    "reshape2",
    "scales",
    "RColorBrewer",
    "Hmisc",
    "dplyr",
    "tidyr",
    "purrr",
    "tibble",
    "data.table",
    "lubridate",
    "xtable",
    "proxyC",
    "rugarch",
    "forecast"
  )
}

parse_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  opts <- list(
    check_only = FALSE,
    repos = "https://cloud.r-project.org"
  )

  for (arg in args) {
    if (identical(arg, "--check")) {
      opts$check_only <- TRUE
    } else if (grepl("^--repos=", arg)) {
      opts$repos <- sub("^--repos=", "", arg)
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript tools/bootstrap_packages.R [options]\n\n",
        "Options:\n",
        "  --check         Report missing packages and exit without installing\n",
        "  --repos=URL     Override the CRAN mirror used for installs\n",
        "  --help, -h      Show this help message\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts
}

installed_status <- function(packages) {
  vapply(packages, requireNamespace, logical(1), quietly = TRUE)
}

default_user_library <- function() {
  user_lib <- Sys.getenv("R_LIBS_USER", unset = NA_character_)
  if (is.na(user_lib) || !nzchar(user_lib)) {
    expand_user_lib <- tryCatch(
      getFromNamespace(".expand_R_libs_env_var", "base"),
      error = function(e) NULL
    )
    if (is.function(expand_user_lib)) {
      user_lib <- expand_user_lib("%U")
    } else {
      user_lib <- file.path(path.expand("~"), "R", "library")
    }
  }

  path.expand(user_lib)
}

resolve_repos <- function(user_repos) {
  if (!identical(user_repos, "https://cloud.r-project.org")) {
    return(user_repos)
  }
  if (Sys.info()[["sysname"]] == "Linux") {
    os_release <- tryCatch(readLines("/etc/os-release", warn = FALSE),
                           error = function(e) character(0))
    codename_line <- grep("^VERSION_CODENAME=", os_release, value = TRUE)
    if (length(codename_line) > 0) {
      codename <- trimws(gsub('["\']', "", sub("^VERSION_CODENAME=", "", codename_line[1])))
      if (!nzchar(codename)) return(user_repos)
      ppm_url <- paste0("https://packagemanager.posit.co/cran/__linux__/",
                        codename, "/latest")
      ppm_ok <- tryCatch({
        old_timeout <- getOption("timeout")
        on.exit(options(timeout = old_timeout), add = TRUE)
        options(timeout = 10)
        con <- url(paste0(ppm_url, "/src/contrib/PACKAGES"))
        on.exit(close(con), add = TRUE)
        open(con, open = "r")
        length(readLines(con, n = 1, warn = FALSE)) > 0
      }, error = function(e) FALSE,
         warning = function(w) FALSE)
      if (ppm_ok) {
        cat("Linux detected (", codename,
            "). Using Posit Package Manager binaries.\n", sep = "")
        return(ppm_url)
      }
      cat("Linux detected but PPM unreachable for '", codename,
          "'. Falling back to CRAN (source compilation).\n", sep = "")
    }
  }
  user_repos
}

preflight_checks <- function(check_only = FALSE) {
  # a) Create user library if it does not exist (critical on fresh clones)
  user_lib <- default_user_library()
  if (nzchar(user_lib) && !dir.exists(user_lib)) {
    if (check_only) {
      cat("NOTE: User R library does not exist: ", user_lib, "\n", sep = "")
    } else {
      cat("Creating user R library: ", user_lib, "\n", sep = "")
      ok <- dir.create(user_lib, recursive = TRUE, showWarnings = FALSE)
      if (ok && dir.exists(user_lib)) {
        .libPaths(c(user_lib, .libPaths()))
      } else {
        cat("WARNING: Failed to create user library: ", user_lib, "\n", sep = "")
      }
    }
  }
  if (nzchar(user_lib) && dir.exists(user_lib)) {
    .libPaths(unique(c(user_lib, .libPaths())))
  }

  # b) Verify at least one writable library directory exists
  lib_paths <- .libPaths()
  writable <- vapply(lib_paths, function(p) {
    dir.exists(p) && file.access(p, 2) == 0
  }, logical(1))
  if (!any(writable)) {
    cat("ERROR: No writable R library found.\n")
    cat("Checked: ", paste(lib_paths, collapse = ", "), "\n")
    cat("Create a user library with:\n")
    cat("  Rscript -e 'dir.create(\"", user_lib, "\", recursive=TRUE)'\n", sep = "")
    quit(save = "no", status = 1)
  }

  if (!check_only) {
    # c) Clean stale lock directories from interrupted installs
    lib_dir <- lib_paths[writable][1]
    locks <- list.files(lib_dir, pattern = "^00LOCK", full.names = TRUE)
    if (length(locks) > 0) {
      cat("WARNING: Stale lock directories from interrupted installs:\n")
      cat("  ", paste(basename(locks), collapse = ", "), "\n")
      cat("Removing stale locks...\n")
      unlink(locks, recursive = TRUE)
    }

    # d) Set MAKEFLAGS for parallel compilation if not already set
    if (is.na(Sys.getenv("MAKEFLAGS", unset = NA))) {
      ncores <- tryCatch(parallel::detectCores(logical = FALSE),
                         error = function(e) NA_integer_)
      if (!is.na(ncores) && ncores > 1L) {
        Sys.setenv(MAKEFLAGS = paste0("-j", ncores))
        cat("Set MAKEFLAGS=-j", ncores, " for parallel compilation.\n", sep = "")
      }
    }
  }
}

install_cran_packages <- function(packages, repos) {
  if (length(packages) == 0) {
    return(invisible(list(success = 0L, failed = character(0))))
  }

  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  options(repos = c(CRAN = repos))

  n <- length(packages)
  cat(sprintf("\nInstalling %d CRAN packages...\n\n", n))
  t0 <- proc.time()[["elapsed"]]
  success <- 0L
  failed <- character(0)

  for (i in seq_along(packages)) {
    pkg <- packages[i]
    cat(sprintf("[%d/%d] %s ... ", i, n, pkg))
    flush.console()

    if (requireNamespace(pkg, quietly = TRUE)) {
      cat("OK (already installed)\n")
      success <- success + 1L
      next
    }

    pkg_t0 <- proc.time()[["elapsed"]]
    tryCatch(
      withCallingHandlers(
        utils::install.packages(pkg, dependencies = NA, quiet = TRUE),
        warning = function(w) invokeRestart("muffleWarning")
      ),
      error = function(e) NULL
    )

    elapsed <- round(proc.time()[["elapsed"]] - pkg_t0, 1)
    if (requireNamespace(pkg, quietly = TRUE)) {
      cat(sprintf("OK (%ss)\n", elapsed))
      success <- success + 1L
    } else {
      cat(sprintf("FAILED (%ss)\n", elapsed))
      failed <- c(failed, pkg)
    }
  }

  total_elapsed <- round(proc.time()[["elapsed"]] - t0, 1)
  cat(sprintf("\nInstalled %d/%d packages in %ss\n", success, n, total_elapsed))
  if (length(failed) > 0) {
    cat("Failed: ", paste(failed, collapse = ", "), "\n")
  }

  invisible(list(success = success, failed = failed))
}

install_local_bayesian_factor_zoo <- function(repo_root, repos) {
  local_pkg <- file.path(repo_root, "BayesianFactorZoo")
  if (!dir.exists(local_pkg)) {
    stop("Local BayesianFactorZoo package directory not found: ", local_pkg,
         call. = FALSE)
  }

  # Resolve BayesianFactorZoo's CRAN dependencies before local install
  desc_path <- file.path(local_pkg, "DESCRIPTION")
  if (file.exists(desc_path)) {
    desc <- tryCatch(
      read.dcf(desc_path),
      error = function(e) {
        cat(
          "WARNING: Could not read BayesianFactorZoo DESCRIPTION: ",
          conditionMessage(e),
          "\n",
          sep = ""
        )
        matrix(nrow = 0, ncol = 0)
      }
    )
    if (nrow(desc) > 0 && "Imports" %in% colnames(desc)) {
      raw <- desc[1, "Imports"]
      # Handle multi-line DCF fields: split on commas and/or newlines
      imports <- trimws(unlist(strsplit(raw, "[,\n]+")))
      imports <- sub("\\s*\\(.*\\)", "", imports)  # strip version constraints
      imports <- imports[nzchar(imports)]
      base_pkgs <- c(rownames(installed.packages(priority = "base")),
                     rownames(installed.packages(priority = "recommended")))
      needed <- setdiff(imports, base_pkgs)
      missing <- needed[!vapply(needed, requireNamespace, logical(1),
                                quietly = TRUE)]
      if (length(missing) > 0) {
        cat("Installing BayesianFactorZoo dependencies: ",
            paste(missing, collapse = ", "), "\n", sep = "")
        install_cran_packages(missing, repos)
      }
      remaining_missing <- needed[!vapply(needed, requireNamespace, logical(1),
                                          quietly = TRUE)]
      if (length(remaining_missing) > 0) {
        stop(
          "Cannot install local BayesianFactorZoo because required imports are still missing: ",
          paste(remaining_missing, collapse = ", "),
          call. = FALSE
        )
      }
    }
  } else {
    cat("WARNING: BayesianFactorZoo DESCRIPTION not found; attempting direct local install.\n")
  }

  cat("Installing local package: BayesianFactorZoo\n")
  install_error <- NULL
  tryCatch(
    utils::install.packages(local_pkg, repos = NULL, type = "source", quiet = TRUE),
    error = function(e) {
      install_error <<- conditionMessage(e)
      NULL
    }
  )
  if (!requireNamespace("BayesianFactorZoo", quietly = TRUE)) {
    stop(
      "Local BayesianFactorZoo install failed",
      if (!is.null(install_error)) paste0(": ", install_error) else ".",
      call. = FALSE
    )
  }
}

print_summary <- function(packages, status) {
  summary_df <- data.frame(
    package = packages,
    installed = unname(status),
    stringsAsFactors = FALSE
  )
  print(summary_df, row.names = FALSE)
}

main <- function() {
  opts <- parse_args()
  repo_root <- get_repo_root()
  packages <- get_required_packages()

  repos <- resolve_repos(opts$repos)

  preflight_checks(check_only = opts$check_only)

  status_before <- installed_status(packages)
  missing_before <- packages[!status_before]

  cat("Repo root: ", repo_root, "\n", sep = "")
  cat("CRAN mirror: ", repos, "\n", sep = "")
  cat("R library: ", .libPaths()[1], "\n\n", sep = "")
  cat("Package status before bootstrap:\n")
  print_summary(packages, status_before)

  if (opts$check_only) {
    if (length(missing_before) > 0) {
      cat("\nMissing packages:\n")
      cat("  ", paste(missing_before, collapse = ", "), "\n", sep = "")
      quit(save = "no", status = 1)
    }

    cat("\nAll required packages are installed.\n")
    quit(save = "no", status = 0)
  }

  cran_missing <- setdiff(missing_before, "BayesianFactorZoo")
  if (length(cran_missing) > 0) {
    install_cran_packages(cran_missing, repos)
  }

  if ("BayesianFactorZoo" %in% missing_before) {
    install_local_bayesian_factor_zoo(repo_root, repos)
  }

  status_after <- installed_status(packages)
  missing_after <- packages[!status_after]

  cat("\nPackage status after bootstrap:\n")
  print_summary(packages, status_after)

  if (length(missing_after) > 0) {
    cat(
      "\nBootstrap incomplete. Missing packages remain:\n  ",
      paste(missing_after, collapse = ", "),
      "\n",
      sep = ""
    )
    if (Sys.info()[["sysname"]] == "Linux") {
      cat(
        "\nIf packages failed due to compilation errors, install system libraries:\n",
        "  sudo apt install build-essential gfortran libcurl4-openssl-dev \\\n",
        "    libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev \\\n",
        "    libfribidi-dev libfreetype-dev libpng-dev libtiff-dev libjpeg-dev\n",
        sep = ""
      )
    }
    quit(save = "no", status = 1)
  }

  cat("\nBootstrap complete. All ", length(packages),
      " required packages are installed.\n", sep = "")
}

if (sys.nframe() == 0) {
  main()
}
