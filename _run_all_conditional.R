#!/usr/bin/env Rscript
###############################################################################
## _run_all_conditional.R - Run Conditional (Time-Varying) Models
## ---------------------------------------------------------------------------
##
## Paper role: Conditional estimation orchestrator for the investing exercise.
## Paper refs: Sec. 3.4; Table 6 Panel B; Figure 7; Appendix D benchmark
##   comparisons; docs/paper/co-pricing-factor-zoo.ai-optimized.md
## Outputs: output/time_varying/bond_stock_with_sp/...ALL_RESULTS.rds and
##   output/time_varying/logs/
##
## USAGE:
##   Rscript _run_all_conditional.R [options]
##
## OPTIONS:
##   --ndraws=N                 Number of MCMC draws (default: 50000)
##   --direction=both|forward|backward
##                              Run both directions in supervised parallel
##                              mode (default), or a single direction directly
##   --num-cores=N              Cores per direction (default: 4)
##   --self-pricing-engine=NAME fast or reference (default: fast)
##   --parallel-type=TYPE       auto, PSOCK, FORK, sequential
##   --cluster-timeout=SECONDS  Cluster creation timeout (default: 30)
##   --help, -h                 Show this help message
##
## SMOKE TEST:
##   Rscript _run_all_conditional.R --direction=both --ndraws=500
##
###############################################################################

DEFAULT_NDRAWS <- 50000L
DEFAULT_DIRECTION <- "both"
DEFAULT_NUM_CORES <- 4L
DEFAULT_CLUSTER_TIMEOUT <- 30L
MAX_RUNTIME_MINS <- 180
POLL_SECONDS <- 15

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    ndraws = DEFAULT_NDRAWS,
    direction = DEFAULT_DIRECTION,
    num_cores = DEFAULT_NUM_CORES,
    self_pricing_engine = "fast",
    parallel_type = "auto",
    cluster_timeout = DEFAULT_CLUSTER_TIMEOUT
  )

  for (arg in args) {
    if (grepl("^--ndraws=", arg)) {
      opts$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (grepl("^--direction=", arg)) {
      opts$direction <- sub("^--direction=", "", arg)
    } else if (grepl("^--num-cores=", arg)) {
      opts$num_cores <- as.integer(sub("^--num-cores=", "", arg))
    } else if (grepl("^--self-pricing-engine=", arg)) {
      opts$self_pricing_engine <- sub("^--self-pricing-engine=", "", arg)
    } else if (grepl("^--parallel-type=", arg)) {
      opts$parallel_type <- sub("^--parallel-type=", "", arg)
    } else if (grepl("^--cluster-timeout=", arg)) {
      opts$cluster_timeout <- as.integer(sub("^--cluster-timeout=", "", arg))
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript _run_all_conditional.R [options]\n\n",
        "Options:\n",
        "  --ndraws=N                 Number of MCMC draws (default: 50000)\n",
        "  --direction=both|forward|backward\n",
        "                             Run both directions in supervised parallel mode,\n",
        "                             or a single direction directly in-process\n",
        "  --num-cores=N              Cores per direction (default: 4)\n",
        "  --self-pricing-engine=NAME fast or reference (default: fast)\n",
        "  --parallel-type=TYPE       auto, PSOCK, FORK, sequential\n",
        "  --cluster-timeout=SECONDS  Cluster creation timeout (default: 30)\n",
        "  --help, -h                 Show this help message\n\n",
        "Smoke test:\n",
        "  Rscript _run_all_conditional.R --direction=both --ndraws=500\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts$direction <- match.arg(tolower(opts$direction), c("both", "forward", "backward"))
  opts$self_pricing_engine <- match.arg(opts$self_pricing_engine, c("fast", "reference"))
  opts$parallel_type <- match.arg(opts$parallel_type, c("auto", "PSOCK", "FORK", "sequential"))
  opts
}

print_environment_info <- function() {
  cat("========================================\n")
  cat("ENVIRONMENT INFORMATION\n")
  cat("========================================\n")
  cat("R Version:\n")
  cat("  ", R.version.string, "\n", sep = "")
  cat("  Platform: ", R.version$platform, "\n", sep = "")
  cat("  OS:       ", Sys.info()[["sysname"]], " ", Sys.info()[["release"]], "\n", sep = "")
  cat("========================================\n\n")
}

child_rscript <- function() {
  if (.Platform$OS.type == "windows") {
    return(file.path(R.home("bin"), "Rscript.exe"))
  }
  file.path(R.home("bin"), "Rscript")
}

build_child_args <- function(direction, opts, run_timestamp, status_path) {
  c(
    "_run_conditional_direction.R",
    paste0("--direction=", direction),
    paste0("--ndraws=", opts$ndraws),
    paste0("--run-timestamp=", run_timestamp),
    paste0("--num-cores=", opts$num_cores),
    paste0("--self-pricing-engine=", opts$self_pricing_engine),
    paste0("--parallel-type=", opts$parallel_type),
    paste0("--cluster-timeout=", opts$cluster_timeout),
    paste0("--status-path=", status_path)
  )
}

launch_direction_process <- function(direction, opts, run_timestamp, logs_dir) {
  if (!requireNamespace("processx", quietly = TRUE)) {
    stop(
      "Package 'processx' is required for --direction=both.\n",
      "Install it with Rscript tools/bootstrap_packages.R or install.packages('processx').",
      call. = FALSE
    )
  }

  tag <- conditional_direction_tag(direction)
  status_path <- conditional_status_path(logs_dir, direction = direction, run_timestamp = run_timestamp)
  log_path <- file.path(logs_dir, sprintf("log_conditional_%s_%s.txt", tag, run_timestamp))
  args <- build_child_args(direction, opts, run_timestamp, status_path)

  proc <- processx::process$new(
    command = child_rscript(),
    args = args,
    wd = getwd(),
    stdout = log_path,
    stderr = log_path,
    cleanup_tree = TRUE
  )

  list(
    direction = direction,
    tag = tag,
    log_path = normalizePath(log_path, winslash = "/", mustWork = FALSE),
    status_path = normalizePath(status_path, winslash = "/", mustWork = FALSE),
    results_path = normalizePath(
      conditional_results_rds_path(
        main_path = getwd(),
        output_folder = "output",
        model_type = "bond_stock_with_sp",
        return_type = "excess",
        alpha.w = 1,
        beta.w = 1,
        tag = tag,
        holding_period = 12,
        f1_flag = TRUE,
        reverse_time = conditional_direction_reverse_time(direction)
      ),
      winslash = "/",
      mustWork = FALSE
    ),
    process = proc
  )
}

validate_child_result <- function(proc_info, ndraws, min_mtime) {
  exit_status <- proc_info$process$get_exit_status()
  status <- read_conditional_run_status(proc_info$status_path)

  if (is.null(exit_status) || exit_status != 0L) {
    status_error <- if (is.null(status)) NULL else status$error
    error_msg <- conditional_value_or(status_error, "Child process exited without a successful status artifact.")
    stop(
      sprintf(
        "Conditional %s run failed with exit status %s.\nStatus: %s\nLog: %s",
        proc_info$direction,
        conditional_value_or(exit_status, NA_integer_),
        error_msg,
        proc_info$log_path
      ),
      call. = FALSE
    )
  }

  validation <- validate_conditional_results_artifact(
    results_file = proc_info$results_path,
    status_path = proc_info$status_path,
    expected_ndraws = ndraws,
    min_mtime = min_mtime,
    require_complete = TRUE
  )

  if (!isTRUE(validation$ok)) {
    stop(
      sprintf(
        "Conditional %s outputs failed validation.\nStatus: %s\nLog: %s\n%s",
        proc_info$direction,
        proc_info$status_path,
        proc_info$log_path,
        format_conditional_validation_issues(validation)
      ),
      call. = FALSE
    )
  }

  validation
}

run_both_directions <- function(opts) {
  source(file.path("code_base", "conditional_run_helpers.R"))
  source("_run_conditional_direction.R")

  run_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  logs_dir <- conditional_logs_dir(main_path = getwd(), output_folder = "output")
  launched_at <- Sys.time()

  cat("Launching both conditional directions in supervised parallel mode...\n\n")
  proc_infos <- tryCatch({
    lapply(c("forward", "backward"), launch_direction_process,
           opts = opts, run_timestamp = run_timestamp, logs_dir = logs_dir)
  }, error = function(e) {
    cat("Parallel child supervision is unavailable in this terminal.\n")
    cat("Falling back to sequential forward/backward execution.\n")
    cat("Launch error: ", conditionMessage(e), "\n\n", sep = "")

    sequential_results <- lapply(c("forward", "backward"), function(direction) {
      run_conditional_direction(
        direction = direction,
        ndraws = opts$ndraws,
        run_timestamp = run_timestamp,
        num_cores = opts$num_cores,
        self_pricing_engine = opts$self_pricing_engine,
        parallel_type = opts$parallel_type,
        cluster_timeout = opts$cluster_timeout
      )
    })

    return(invisible(list(sequential_results = sequential_results)))
  })

  if (!is.null(proc_infos$sequential_results)) {
    return(invisible(proc_infos$sequential_results))
  }

  for (info in proc_infos) {
    cat("  ", info$tag, "\n", sep = "")
    cat("    Log:    ", info$log_path, "\n", sep = "")
    cat("    Status: ", info$status_path, "\n", sep = "")
  }
  cat("\nWaiting for completion...\n")

  repeat {
    Sys.sleep(POLL_SECONDS)
    elapsed_mins <- as.numeric(difftime(Sys.time(), launched_at, units = "mins"))

    status_lines <- vapply(proc_infos, function(info) {
      exit_status <- info$process$get_exit_status()
      if (info$process$is_alive()) {
        sprintf("%s=running", info$direction)
      } else {
        sprintf("%s=exit(%s)", info$direction, conditional_value_or(exit_status, NA_integer_))
      }
    }, character(1))

    cat(sprintf("\r  %s | elapsed %.1f min   ", paste(status_lines, collapse = " | "), elapsed_mins))

    if (all(!vapply(proc_infos, function(info) info$process$is_alive(), logical(1)))) {
      break
    }

    if (elapsed_mins > MAX_RUNTIME_MINS) {
      cat("\n")
      for (info in proc_infos) {
        if (info$process$is_alive()) {
          info$process$kill()
        }
      }
      stop(
        "Conditional runs exceeded the timeout of ",
        MAX_RUNTIME_MINS,
        " minutes and were terminated.",
        call. = FALSE
      )
    }
  }

  cat("\n")
  validations <- lapply(proc_infos, validate_child_result, ndraws = opts$ndraws, min_mtime = launched_at)

  cat("\nConditional supervised run complete.\n")
  for (idx in seq_along(proc_infos)) {
    info <- proc_infos[[idx]]
    validation <- validations[[idx]]
    cat("  ", info$tag, ": ", validation$results_file, "\n", sep = "")
  }

  invisible(list(processes = proc_infos, validations = validations))
}

run_single_direction <- function(opts) {
  source(file.path("code_base", "conditional_run_helpers.R"))
  source("_run_conditional_direction.R")

  result <- run_conditional_direction(
    direction = opts$direction,
    ndraws = opts$ndraws,
    num_cores = opts$num_cores,
    self_pricing_engine = opts$self_pricing_engine,
    parallel_type = opts$parallel_type,
    cluster_timeout = opts$cluster_timeout
  )

  cat("\nSingle-direction conditional run complete.\n")
  cat("  Results: ", result$results_path, "\n", sep = "")
  cat("  Status:  ", result$status_path, "\n", sep = "")
  invisible(result)
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- parse_args(args)

  cat("\n########################################################################\n")
  cat("##  CONDITIONAL (TIME-VARYING) MODEL ESTIMATION\n")
  cat("########################################################################\n")
  cat(sprintf("##  Started: %s\n", Sys.time()))
  cat("##  Direction: ", opts$direction, "\n", sep = "")
  cat("##  Draws:     ", opts$ndraws, "\n", sep = "")
  cat("##  Cores:     ", opts$num_cores, " per direction\n", sep = "")
  cat("########################################################################\n\n")

  print_environment_info()

  if (identical(opts$direction, "both")) {
    run_both_directions(opts)
  } else {
    run_single_direction(opts)
  }
}

if (sys.nframe() == 0) {
  tryCatch(
    main(),
    error = function(e) {
      message(conditionMessage(e))
      quit(save = "no", status = 1)
    }
  )
}
