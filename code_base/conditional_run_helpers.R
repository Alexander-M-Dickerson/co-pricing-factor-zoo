conditional_value_or <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    y
  } else {
    x
  }
}

conditional_direction_tag <- function(direction) {
  direction <- tolower(direction)
  if (identical(direction, "forward")) {
    return("ExpandingForward")
  }
  if (identical(direction, "backward")) {
    return("ExpandingBackward")
  }
  stop("`direction` must be 'forward' or 'backward'.", call. = FALSE)
}

conditional_direction_reverse_time <- function(direction) {
  direction <- tolower(direction)
  if (identical(direction, "forward")) {
    return(FALSE)
  }
  if (identical(direction, "backward")) {
    return(TRUE)
  }
  stop("`direction` must be 'forward' or 'backward'.", call. = FALSE)
}

conditional_logs_dir <- function(main_path = getwd(), output_folder = "output") {
  base_output <- if (dir.exists(output_folder)) {
    output_folder
  } else {
    file.path(main_path, output_folder)
  }
  logs_dir <- file.path(base_output, "time_varying", "logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)
  normalizePath(logs_dir, winslash = "/", mustWork = FALSE)
}

conditional_status_path <- function(logs_dir, direction, run_timestamp) {
  tag <- conditional_direction_tag(direction)
  file.path(logs_dir, sprintf("conditional_status_%s_%s.rds", tag, run_timestamp))
}

conditional_results_base_pattern <- function(return_type = "excess",
                                             model_type = "bond_stock_with_sp",
                                             alpha.w = 1,
                                             beta.w = 1,
                                             tag,
                                             holding_period = 12,
                                             f1_flag = TRUE,
                                             reverse_time = FALSE) {
  f1_token <- toupper(as.character(isTRUE(f1_flag) || identical(f1_flag, "TRUE")))
  direction_suffix <- if (isTRUE(reverse_time)) "_backward" else ""
  sprintf(
    "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s_holding_period=%d_f1=%s%s",
    return_type,
    model_type,
    trunc(alpha.w),
    trunc(beta.w),
    tag,
    holding_period,
    f1_token,
    direction_suffix
  )
}

conditional_results_rds_path <- function(main_path = getwd(),
                                         output_folder = "output",
                                         model_type = "bond_stock_with_sp",
                                         return_type = "excess",
                                         alpha.w = 1,
                                         beta.w = 1,
                                         tag,
                                         holding_period = 12,
                                         f1_flag = TRUE,
                                         reverse_time = FALSE) {
  base_output <- if (dir.exists(output_folder)) {
    output_folder
  } else {
    file.path(main_path, output_folder)
  }
  file.path(
    base_output,
    "time_varying",
    model_type,
    paste0(
      conditional_results_base_pattern(
        return_type = return_type,
        model_type = model_type,
        alpha.w = alpha.w,
        beta.w = beta.w,
        tag = tag,
        holding_period = holding_period,
        f1_flag = f1_flag,
        reverse_time = reverse_time
      ),
      "_ALL_RESULTS.rds"
    )
  )
}

write_conditional_run_status <- function(status_path, status) {
  dir.create(dirname(status_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(status, file = status_path, compress = TRUE)
  invisible(status_path)
}

read_conditional_run_status <- function(status_path) {
  if (is.null(status_path) || !nzchar(status_path) || !file.exists(status_path)) {
    return(NULL)
  }

  readRDS(status_path)
}

coerce_conditional_time <- function(value) {
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

validate_conditional_results_artifact <- function(results_file,
                                                  status_path = NULL,
                                                  expected_ndraws = NULL,
                                                  expected_windows = NULL,
                                                  min_mtime = NULL,
                                                  require_complete = TRUE) {
  issues <- character(0)
  status <- read_conditional_run_status(status_path)

  normalized_results_file <- normalizePath(results_file, winslash = "/", mustWork = FALSE)
  results_exists <- file.exists(normalized_results_file)
  file_mtime <- if (results_exists) file.info(normalized_results_file)$mtime else as.POSIXct(NA)
  file_mtime <- coerce_conditional_time(file_mtime)
  min_mtime <- coerce_conditional_time(min_mtime)

  if (!results_exists) {
    issues <- c(issues, paste("Expected results file not found:", normalized_results_file))
  }

  if (!is.null(status)) {
    expected_path <- conditional_value_or(status$expected_output_path, "")
    if (nzchar(expected_path)) {
      normalized_expected_path <- normalizePath(expected_path, winslash = "/", mustWork = FALSE)
      if (!identical(normalized_expected_path, normalized_results_file)) {
        issues <- c(
          issues,
          paste("Status file points to a different results file:", normalized_expected_path)
        )
      }
    }

    if (!identical(status$status, "complete")) {
      issues <- c(issues, paste("Run status is not complete:", conditional_value_or(status$status, "missing")))
    }

    if (!isTRUE(conditional_value_or(status$output_exists, FALSE))) {
      issues <- c(issues, "Status file reports that the expected output file was not written.")
    }

    status_output_mtime <- coerce_conditional_time(status$output_mtime)
    if (is.null(file_mtime) || is.na(file_mtime)) {
      file_mtime <- status_output_mtime
    }
  }

  metadata <- NULL
  if (results_exists) {
    metadata <- tryCatch({
      readRDS(normalized_results_file)$metadata
    }, error = function(e) {
      issues <<- c(issues, paste("Could not read conditional results metadata:", conditionMessage(e)))
      NULL
    })
  }

  ndraws <- conditional_value_or(conditional_value_or(status$ndraws, NULL), conditional_value_or(metadata$ndraws, NULL))
  n_windows_total <- conditional_value_or(
    conditional_value_or(status$n_windows_total, NULL),
    conditional_value_or(metadata$n_windows_total, NULL)
  )
  n_windows_success <- conditional_value_or(
    conditional_value_or(status$n_windows_success, NULL),
    conditional_value_or(metadata$n_windows_success, NULL)
  )
  n_windows_failed <- conditional_value_or(
    conditional_value_or(status$n_windows_failed, NULL),
    conditional_value_or(metadata$n_windows_failed, NULL)
  )

  if (!is.null(expected_ndraws) && !is.null(ndraws) && as.integer(ndraws) != as.integer(expected_ndraws)) {
    issues <- c(
      issues,
      sprintf("Results were generated with ndraws=%s, expected %s.", ndraws, expected_ndraws)
    )
  }

  if (!is.null(expected_windows) && !is.null(n_windows_total) && as.integer(n_windows_total) != as.integer(expected_windows)) {
    issues <- c(
      issues,
      sprintf("Results reported %s windows, expected %s.", n_windows_total, expected_windows)
    )
  }

  if (isTRUE(require_complete) &&
      !is.null(n_windows_total) &&
      !is.null(n_windows_success) &&
      as.integer(n_windows_success) != as.integer(n_windows_total)) {
    issues <- c(
      issues,
      sprintf(
        "Results are partial: n_windows_success=%s, n_windows_total=%s, n_windows_failed=%s.",
        n_windows_success,
        n_windows_total,
        conditional_value_or(n_windows_failed, NA_integer_)
      )
    )
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
    status = status,
    metadata = metadata,
    ndraws = ndraws,
    n_windows_total = n_windows_total,
    n_windows_success = n_windows_success,
    results_file = normalized_results_file,
    results_mtime = file_mtime
  )
}

format_conditional_validation_issues <- function(validation) {
  if (isTRUE(validation$ok)) {
    return("")
  }

  paste0("- ", paste(validation$issues, collapse = "\n- "))
}
