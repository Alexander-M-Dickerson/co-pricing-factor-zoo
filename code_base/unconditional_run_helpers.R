###############################################################################
## unconditional_run_helpers.R
## ---------------------------------------------------------------------------
##
## Paper role:
##   Validation helpers for the saved unconditional workspaces that feed the
##   main-text tables and figures.
##
## Paper refs:
##   - Sec. 3
##   - Tables 1-6
##   - Figures 2-5 and 9
##   - Appendix A/B output paths
###############################################################################

unconditional_value_or <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    y
  } else {
    x
  }
}

coerce_unconditional_time <- function(value) {
  if (is.null(value) || length(value) == 0 || all(is.na(value))) {
    return(NULL)
  }

  if (inherits(value, "POSIXt")) {
    return(as.POSIXct(value, tz = "UTC"))
  }

  if (is.numeric(value)) {
    return(as.POSIXct(value, origin = "1970-01-01", tz = "UTC"))
  }

  parsed <- as.POSIXct(value, tz = "UTC")
  if (is.na(parsed)) {
    return(NULL)
  }

  parsed
}

unconditional_model_specs <- function() {
  # Paper: these seven saved workspaces are the baseline unconditional inputs
  # required by the public paper-output path, including the stock- and
  # bond-Treasury component runs used by Figure 9 and the IA Treasury outputs.
  list(
    list(model_type = "stock", return_type = "excess", alpha.w = 1, beta.w = 1, kappa = 0, tag = "baseline"),
    list(model_type = "bond", return_type = "excess", alpha.w = 1, beta.w = 1, kappa = 0, tag = "baseline"),
    list(model_type = "bond", return_type = "duration", alpha.w = 1, beta.w = 1, kappa = 0, tag = "baseline"),
    list(model_type = "bond_stock_with_sp", return_type = "excess", alpha.w = 1, beta.w = 1, kappa = 0, tag = "baseline"),
    list(model_type = "bond_stock_with_sp", return_type = "duration", alpha.w = 1, beta.w = 1, kappa = 0, tag = "baseline"),
    list(model_type = "treasury", return_type = "excess", alpha.w = 1, beta.w = 1, kappa = 0, tag = "stock_treasury"),
    list(model_type = "treasury", return_type = "excess", alpha.w = 1, beta.w = 1, kappa = 0, tag = "bond_treasury")
  )
}

unconditional_results_filename <- function(return_type,
                                           model_type,
                                           alpha.w = 1,
                                           beta.w = 1,
                                           kappa = 0,
                                           tag = "baseline",
                                           intercept = TRUE) {
  kappa_str <- if (all(kappa == 0)) {
    "0"
  } else {
    paste(format(kappa, digits = 3, trim = TRUE), collapse = "_")
  }

  kappa_label <- if (nchar(kappa_str) > 10) "weighted" else kappa_str
  parts <- c(
    return_type,
    model_type,
    sprintf("alpha.w=%g", trunc(alpha.w)),
    sprintf("beta.w=%g", trunc(beta.w)),
    sprintf("kappa=%s", kappa_label)
  )

  if (!isTRUE(intercept)) {
    parts <- c(parts, "no_intercept")
  }

  if (nzchar(tag)) {
    parts <- c(parts, tag)
  }

  paste0(paste(parts, collapse = "_"), ".Rdata")
}

unconditional_results_rdata_path <- function(main_path = getwd(),
                                             output_folder = "output",
                                             model_type,
                                             return_type,
                                             alpha.w = 1,
                                             beta.w = 1,
                                             kappa = 0,
                                             tag = "baseline",
                                             intercept = TRUE) {
  base_output <- if (dir.exists(output_folder)) {
    output_folder
  } else {
    file.path(main_path, output_folder)
  }

  file.path(
    base_output,
    "unconditional",
    model_type,
    unconditional_results_filename(
      return_type = return_type,
      model_type = model_type,
      alpha.w = alpha.w,
      beta.w = beta.w,
      kappa = kappa,
      tag = tag,
      intercept = intercept
    )
  )
}

read_unconditional_workspace_metadata <- function(results_file) {
  if (is.null(results_file) || !nzchar(results_file) || !file.exists(results_file)) {
    return(NULL)
  }

  load_env <- new.env(parent = emptyenv())
  load(results_file, envir = load_env)

  if (exists("metadata", envir = load_env, inherits = FALSE)) {
    get("metadata", envir = load_env, inherits = FALSE)
  } else {
    NULL
  }
}

validate_unconditional_results_artifact <- function(results_file,
                                                    expected_ndraws = NULL,
                                                    min_mtime = NULL) {
  issues <- character(0)
  normalized_results_file <- normalizePath(results_file, winslash = "/", mustWork = FALSE)
  results_exists <- file.exists(normalized_results_file)
  file_mtime <- if (results_exists) file.info(normalized_results_file)$mtime else as.POSIXct(NA)
  file_mtime <- coerce_unconditional_time(file_mtime)
  min_mtime <- coerce_unconditional_time(min_mtime)

  if (!results_exists) {
    issues <- c(issues, paste("Expected unconditional results file not found:", normalized_results_file))
  }

  metadata <- NULL
  if (results_exists) {
    metadata <- tryCatch(
      read_unconditional_workspace_metadata(normalized_results_file),
      error = function(e) {
        issues <<- c(issues, paste("Could not read unconditional metadata:", conditionMessage(e)))
        NULL
      }
    )
  }

  ndraws <- unconditional_value_or(unconditional_value_or(metadata$ndraws, NULL), NULL)

  if (!is.null(expected_ndraws)) {
    if (is.null(ndraws)) {
      issues <- c(issues, "Unconditional results metadata does not expose ndraws.")
    } else if (as.integer(ndraws) != as.integer(expected_ndraws)) {
      issues <- c(
        issues,
        sprintf("Results were generated with ndraws=%s, expected %s.", ndraws, expected_ndraws)
      )
    }
  }

  if (!is.null(min_mtime) && !is.null(file_mtime) && !is.na(file_mtime) && file_mtime < min_mtime) {
    issues <- c(
      issues,
      sprintf(
        "Results file is stale: mtime=%s is older than required start time %s.",
        format(file_mtime, tz = "UTC", usetz = TRUE),
        format(min_mtime, tz = "UTC", usetz = TRUE)
      )
    )
  }

  list(
    ok = length(issues) == 0,
    issues = unique(issues),
    metadata = metadata,
    ndraws = ndraws,
    results_file = normalized_results_file,
    results_mtime = file_mtime
  )
}

validate_expected_unconditional_workspaces <- function(main_path = getwd(),
                                                       output_folder = "output",
                                                       expected_ndraws = NULL,
                                                       min_mtime = NULL) {
  specs <- unconditional_model_specs()
  validations <- lapply(specs, function(spec) {
    results_file <- unconditional_results_rdata_path(
      main_path = main_path,
      output_folder = output_folder,
      model_type = spec$model_type,
      return_type = spec$return_type,
      alpha.w = spec$alpha.w,
      beta.w = spec$beta.w,
      kappa = spec$kappa,
      tag = spec$tag
    )

    validation <- validate_unconditional_results_artifact(
      results_file = results_file,
      expected_ndraws = expected_ndraws,
      min_mtime = min_mtime
    )
    validation$spec <- spec
    validation
  })

  issues <- unique(unlist(lapply(validations, `[[`, "issues")))

  list(
    ok = length(issues) == 0,
    issues = issues,
    validations = validations
  )
}

format_unconditional_validation_issues <- function(validation) {
  if (isTRUE(validation$ok)) {
    return("")
  }

  paste0("- ", paste(validation$issues, collapse = "\n- "))
}

validate_replication_files <- function(paths, min_mtime = NULL, labels = NULL) {
  min_mtime <- coerce_unconditional_time(min_mtime)
  if (is.null(labels)) {
    labels <- basename(paths)
  }

  issues <- character(0)
  normalized_paths <- normalizePath(paths, winslash = "/", mustWork = FALSE)
  mtimes <- vector("list", length(paths))

  for (i in seq_along(normalized_paths)) {
    path <- normalized_paths[[i]]
    label <- labels[[i]]

    if (!file.exists(path)) {
      issues <- c(issues, paste(label, "not found:", path))
      mtimes[[i]] <- as.POSIXct(NA)
      next
    }

    file_mtime <- coerce_unconditional_time(file.info(path)$mtime)
    mtimes[[i]] <- file_mtime

    if (!is.null(min_mtime) && !is.null(file_mtime) && !is.na(file_mtime) && file_mtime < min_mtime) {
      issues <- c(
        issues,
        sprintf(
          "%s is stale: mtime=%s is older than required start time %s.",
          label,
          format(file_mtime, tz = "UTC", usetz = TRUE),
          format(min_mtime, tz = "UTC", usetz = TRUE)
        )
      )
    }
  }

  list(
    ok = length(issues) == 0,
    issues = unique(issues),
    paths = normalized_paths,
    mtimes = mtimes
  )
}

format_replication_file_issues <- function(validation) {
  if (isTRUE(validation$ok)) {
    return("")
  }

  paste0("- ", paste(validation$issues, collapse = "\n- "))
}
