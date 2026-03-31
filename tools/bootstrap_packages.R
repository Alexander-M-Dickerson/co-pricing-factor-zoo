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
    "ggplot2",
    "ggtext",
    "patchwork",
    "scales",
    "RColorBrewer",
    "Hmisc",
    "dplyr",
    "tidyr",
    "purrr",
    "tibble",
    "data.table",
    "rlang",
    "lubridate",
    "xtable",
    "proxyC",
    "PerformanceAnalytics",
    "rugarch",
    "rmgarch",
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

install_cran_packages <- function(packages, repos) {
  if (length(packages) == 0) {
    return(invisible(NULL))
  }

  old_repos <- getOption("repos")
  on.exit(options(repos = old_repos), add = TRUE)
  options(repos = c(CRAN = repos))

  cat("Installing CRAN packages:\n")
  cat("  ", paste(packages, collapse = ", "), "\n", sep = "")
  utils::install.packages(packages, dependencies = TRUE)
}

install_local_bayesian_factor_zoo <- function(repo_root) {
  local_pkg <- file.path(repo_root, "BayesianFactorZoo")
  if (!dir.exists(local_pkg)) {
    stop("Local BayesianFactorZoo package directory not found: ", local_pkg, call. = FALSE)
  }

  cat("Installing local package: BayesianFactorZoo\n")
  utils::install.packages(local_pkg, repos = NULL, type = "source")
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
  status_before <- installed_status(packages)
  missing_before <- packages[!status_before]

  cat("Repo root: ", repo_root, "\n", sep = "")
  cat("CRAN mirror: ", opts$repos, "\n\n", sep = "")
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
    install_cran_packages(cran_missing, opts$repos)
  }

  if ("BayesianFactorZoo" %in% missing_before) {
    install_local_bayesian_factor_zoo(repo_root)
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
    quit(save = "no", status = 1)
  }

  cat("\nBootstrap complete. The repo package set is installed.\n")
}

if (sys.nframe() == 0) {
  main()
}
