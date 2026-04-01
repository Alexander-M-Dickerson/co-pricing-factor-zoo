#!/usr/bin/env Rscript
###############################################################################
## _run_conditional_direction.R
##
## Run one conditional time-varying direction end-to-end.
##
## Paper role: Single-direction conditional estimation entrypoint used by the
##   supervised conditional orchestrator.
## Paper refs: Sec. 3.4; Figure 7; Table 6 Panel B;
##   docs/paper/co-pricing-factor-zoo.ai-optimized.md
## Outputs: output/time_varying/bond_stock_with_sp/...ALL_RESULTS.rds and
##   output/time_varying/logs/conditional_status_*.rds
###############################################################################

DEFAULT_NDRAWS <- 50000L
DEFAULT_NUM_CORES <- 4L
DEFAULT_CLUSTER_TIMEOUT <- 30L

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    direction = "forward",
    ndraws = DEFAULT_NDRAWS,
    run_timestamp = format(Sys.time(), "%Y%m%d_%H%M%S"),
    num_cores = DEFAULT_NUM_CORES,
    self_pricing_engine = "fast",
    parallel_type = "auto",
    cluster_timeout = DEFAULT_CLUSTER_TIMEOUT,
    status_path = NULL
  )

  for (arg in args) {
    if (grepl("^--direction=", arg)) {
      opts$direction <- sub("^--direction=", "", arg)
    } else if (grepl("^--ndraws=", arg)) {
      opts$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (grepl("^--run-timestamp=", arg)) {
      opts$run_timestamp <- sub("^--run-timestamp=", "", arg)
    } else if (grepl("^--num-cores=", arg)) {
      opts$num_cores <- as.integer(sub("^--num-cores=", "", arg))
    } else if (grepl("^--self-pricing-engine=", arg)) {
      opts$self_pricing_engine <- sub("^--self-pricing-engine=", "", arg)
    } else if (grepl("^--parallel-type=", arg)) {
      opts$parallel_type <- sub("^--parallel-type=", "", arg)
    } else if (grepl("^--cluster-timeout=", arg)) {
      opts$cluster_timeout <- as.integer(sub("^--cluster-timeout=", "", arg))
    } else if (grepl("^--status-path=", arg)) {
      opts$status_path <- sub("^--status-path=", "", arg)
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript _run_conditional_direction.R [options]\n\n",
        "Options:\n",
        "  --direction=forward|backward   Direction to estimate (default: forward)\n",
        "  --ndraws=N                     Number of MCMC draws (default: 50000)\n",
        "  --run-timestamp=STAMP          Shared timestamp for paired runs\n",
        "  --num-cores=N                  Cores for this direction (default: 4)\n",
        "  --self-pricing-engine=NAME     fast or reference (default: fast)\n",
        "  --parallel-type=TYPE           auto, PSOCK, FORK, sequential\n",
        "  --cluster-timeout=SECONDS      Cluster creation timeout (default: 30)\n",
        "  --status-path=PATH             Optional explicit status artifact path\n",
        "  --help, -h                     Show this help message\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts$direction <- match.arg(tolower(opts$direction), c("forward", "backward"))
  opts$self_pricing_engine <- match.arg(opts$self_pricing_engine, c("fast", "reference"))
  opts$parallel_type <- match.arg(opts$parallel_type, c("auto", "PSOCK", "FORK", "sequential"))

  opts
}

run_conditional_direction <- function(direction = "forward",
                                      ndraws = DEFAULT_NDRAWS,
                                      run_timestamp = format(Sys.time(), "%Y%m%d_%H%M%S"),
                                      num_cores = DEFAULT_NUM_CORES,
                                      self_pricing_engine = "fast",
                                      parallel_type = "auto",
                                      cluster_timeout = DEFAULT_CLUSTER_TIMEOUT,
                                      status_path = NULL) {
  main_path <- getwd()
  code_folder <- "code_base"
  output_folder <- "output"

  source(file.path(code_folder, "conditional_run_helpers.R"))
  source(file.path(code_folder, "logging_helpers.R"))
  source(file.path(code_folder, "validate_and_align_dates.R"))
  source(file.path(code_folder, "data_loading_helpers.R"))
  source(file.path(code_folder, "run_bayesian_mcmc.R"))
  source(file.path(code_folder, "run_bayesian_mcmc_time_varying.R"))
  source(file.path(code_folder, "run_time_varying_estimation.R"))

  tag <- conditional_direction_tag(direction)
  reverse_time <- conditional_direction_reverse_time(direction)
  logs_dir <- conditional_logs_dir(main_path = main_path, output_folder = output_folder)
  status_path <- conditional_value_or(
    status_path,
    conditional_status_path(logs_dir, direction = direction, run_timestamp = run_timestamp)
  )
  status_path <- normalizePath(status_path, winslash = "/", mustWork = FALSE)
  expected_results_path <- conditional_results_rds_path(
    main_path = main_path,
    output_folder = output_folder,
    model_type = "bond_stock_with_sp",
    return_type = "excess",
    alpha.w = 1,
    beta.w = 1,
    tag = tag,
    holding_period = 12,
    f1_flag = TRUE,
    reverse_time = reverse_time
  )

  started_at <- Sys.time()
  status <- list(
    status = "running",
    direction = direction,
    tag = tag,
    ndraws = ndraws,
    started_at = started_at,
    finished_at = NULL,
    expected_output_path = normalizePath(expected_results_path, winslash = "/", mustWork = FALSE),
    output_exists = file.exists(expected_results_path),
    output_mtime = if (file.exists(expected_results_path)) file.info(expected_results_path)$mtime else NULL,
    n_windows_total = NULL,
    n_windows_success = NULL,
    n_windows_failed = NULL,
    self_pricing_engine = self_pricing_engine,
    parallel_type = parallel_type,
    cluster_timeout = cluster_timeout,
    error = NULL
  )
  write_conditional_run_status(status_path, status)

  update_status <- function(...) {
    fields <- list(...)
    status <<- utils::modifyList(status, fields)
    write_conditional_run_status(status_path, status)
    invisible(status)
  }

  on.exit({
    if (!identical(status$status, "complete") && !identical(status$status, "failed")) {
      update_status(
        status = "failed",
        finished_at = Sys.time(),
        error = conditional_value_or(status$error, "Conditional direction exited without marking completion."),
        output_exists = file.exists(expected_results_path),
        output_mtime = if (file.exists(expected_results_path)) file.info(expected_results_path)$mtime else NULL
      )
    }
  }, add = TRUE)

  cat("\n========================================\n")
  cat("RUNNING CONDITIONAL DIRECTION\n")
  cat("========================================\n")
  cat("Direction:            ", direction, "\n", sep = "")
  cat("Tag:                  ", tag, "\n", sep = "")
  cat("Draws:                ", ndraws, "\n", sep = "")
  cat("Parallel type:        ", parallel_type, "\n", sep = "")
  cat("Self-pricing engine:  ", self_pricing_engine, "\n", sep = "")
  cat("Status artifact:      ", status_path, "\n", sep = "")
  cat("Expected output:      ", expected_results_path, "\n", sep = "")
  cat("========================================\n\n")

  result <- tryCatch({
    run_time_varying_estimation(
      main_path          = main_path,
      data_folder        = "data",
      output_folder      = output_folder,
      code_folder        = code_folder,
      model_type         = "bond_stock_with_sp",
      return_type        = "excess",
      f1                 = "nontraded.csv",
      f2                 = c("traded_bond_excess.csv", "traded_equity.csv"),
      R                  = c("bond_insample_test_assets_50_excess.csv",
                             "equity_anomalies_composite_33.csv"),
      fac_freq           = "frequentist_factors.csv",
      n_bond_factors     = NULL,
      date_start         = "1986-01-31",
      date_end           = "2022-12-31",
      initial_window     = 222,
      holding_period     = 12,
      window_type        = "expanding",
      reverse_time       = reverse_time,
      frequentist_models = list(
        CAPM  = "MKTS",
        CAPMB = "MKTB",
        FF5   = c("MKTS", "SMB", "HML", "DEF", "TERM"),
        HKM   = c("MKTS", "CPTLT")
      ),
      ndraws             = ndraws,
      drop_draws_pct     = 0,
      SRscale            = c(0.20, 0.40, 0.60, 0.80),
      alpha.w            = 1,
      beta.w             = 1,
      kappa              = 0,
      kappa_fac          = NULL,
      tag                = tag,
      num_cores          = num_cores,
      seed               = 234,
      intercept          = TRUE,
      save_flag          = FALSE,
      save_csv_flag      = FALSE,
      fac_to_drop        = NULL,
      weighting          = "GLS",
      verbose            = TRUE,
      self_pricing_engine = self_pricing_engine,
      parallel_type      = parallel_type,
      cluster_timeout    = cluster_timeout,
      require_all_windows = TRUE
    )
  }, error = function(e) {
    update_status(
      status = "failed",
      finished_at = Sys.time(),
      error = conditionMessage(e),
      output_exists = file.exists(expected_results_path),
      output_mtime = if (file.exists(expected_results_path)) file.info(expected_results_path)$mtime else NULL
    )
    stop(e)
  })

  validation <- validate_conditional_results_artifact(
    results_file = expected_results_path,
    expected_ndraws = ndraws,
    min_mtime = started_at,
    require_complete = TRUE
  )
  if (!isTRUE(validation$ok)) {
    validation_failed <- if (is.null(validation$metadata)) NULL else validation$metadata$n_windows_failed
    update_status(
      status = "failed",
      finished_at = Sys.time(),
      error = paste(validation$issues, collapse = " | "),
      output_exists = file.exists(expected_results_path),
      output_mtime = if (file.exists(expected_results_path)) file.info(expected_results_path)$mtime else NULL,
      n_windows_total = validation$n_windows_total,
      n_windows_success = validation$n_windows_success,
      n_windows_failed = conditional_value_or(validation_failed, NULL)
    )
    stop(
      "Conditional output validation failed for ",
      direction,
      ":\n",
      format_conditional_validation_issues(validation),
      call. = FALSE
    )
  }

  update_status(
    status = "complete",
    finished_at = Sys.time(),
    output_exists = TRUE,
    output_mtime = validation$results_mtime,
    n_windows_total = validation$n_windows_total,
    n_windows_success = validation$n_windows_success,
    n_windows_failed = if (is.null(validation$metadata)) 0L else conditional_value_or(validation$metadata$n_windows_failed, 0L),
    error = NULL
  )

  cat("Conditional direction complete: ", direction, "\n", sep = "")
  invisible(list(
    direction = direction,
    tag = tag,
    status_path = status_path,
    results_path = expected_results_path,
    validation = validation,
    result = result
  ))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- parse_args(args)
  run_conditional_direction(
    direction = opts$direction,
    ndraws = opts$ndraws,
    run_timestamp = opts$run_timestamp,
    num_cores = opts$num_cores,
    self_pricing_engine = opts$self_pricing_engine,
    parallel_type = opts$parallel_type,
    cluster_timeout = opts$cluster_timeout,
    status_path = opts$status_path
  )
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
