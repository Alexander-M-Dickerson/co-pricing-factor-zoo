#!/usr/bin/env Rscript
###############################################################################
## _run_ia_estimation.R - Internet Appendix Model Estimation
## ---------------------------------------------------------------------------
##
## Paper role: IA estimation orchestrator for robustness and extension models.
## Paper refs: IA.6, IA.7, IA.9, IA.10; Eq. (6), Eq. (10); Tables IA.XVI-XXIX;
##   Figures IA.22-39; docs/paper/co-pricing-factor-zoo.ai-optimized.md
## Outputs: ia/output/unconditional/{model_type}/...Rdata and ia/output/logs/
##
## USAGE:
##   Rscript ia/_run_ia_estimation.R [options]
##
## OPTIONS:
##   --models=1,2,3              Run specific models (comma-separated, default: all)
##   --ndraws=N                  Number of MCMC draws (default: 50000; paper setting)
##   --parallel                  Run models in supervised parallel batches (default)
##   --sequential                Run models sequentially in-process
##   --cores=N                   Total available cores (default: auto-detect)
##   --cores-per-model=N         Cores per model (default: 4)
##   --self-pricing-engine=NAME  fast or reference (default: fast)
##   --dry-run                   Show what would be run without executing
##   --list                      List all available models and exit
##   --help, -h                  Show this help message
##
## OUTPUT:
##   ia/output/unconditional/{model_type}/...Rdata
##   ia/output/logs/log_ia_model_* and ia_status_model_*.rds
##
## Coverage note: this script estimates 9 IA-related models, but the repo only
## generates a subset of IA tables/figures downstream. Use ia/_run_ia_results.R
## as the source of truth for the currently implemented IA output subset.
###############################################################################

gc()

if (basename(getwd()) == "ia") {
  setwd("..")
}

main_path <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
if (!file.exists("code_base/run_bayesian_mcmc.R")) {
  stop("Please run this script from the project root directory (co-pricing-factor-zoo/).", call. = FALSE)
}

source(file.path("code_base", "ia_run_helpers.R"))

DEFAULT_CORES_PER_MODEL <- 4L
DEFAULT_TOTAL_CORES <- max(1L, parallel::detectCores() - 1L)
DEFAULT_NDRAWS <- 50000L
DEFAULT_RUN_PARALLEL <- TRUE
DEFAULT_MODELS <- ia_model_ids()
MAX_RUNTIME_MINS <- 240
POLL_SECONDS <- 15

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    models = DEFAULT_MODELS,
    ndraws = DEFAULT_NDRAWS,
    parallel = DEFAULT_RUN_PARALLEL,
    cores = DEFAULT_TOTAL_CORES,
    cores_per_model = DEFAULT_CORES_PER_MODEL,
    self_pricing_engine = "fast",
    dry_run = FALSE,
    list_only = FALSE
  )

  for (arg in args) {
    if (identical(arg, "--list")) {
      opts$list_only <- TRUE
    } else if (identical(arg, "--parallel")) {
      opts$parallel <- TRUE
    } else if (identical(arg, "--sequential")) {
      opts$parallel <- FALSE
    } else if (identical(arg, "--dry-run")) {
      opts$dry_run <- TRUE
    } else if (grepl("^--models=", arg)) {
      model_str <- sub("^--models=", "", arg)
      opts$models <- as.integer(strsplit(model_str, ",")[[1]])
    } else if (grepl("^--ndraws=", arg)) {
      opts$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (grepl("^--cores=", arg)) {
      opts$cores <- as.integer(sub("^--cores=", "", arg))
    } else if (grepl("^--cores-per-model=", arg)) {
      opts$cores_per_model <- as.integer(sub("^--cores-per-model=", "", arg))
    } else if (grepl("^--self-pricing-engine=", arg)) {
      opts$self_pricing_engine <- sub("^--self-pricing-engine=", "", arg)
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript ia/_run_ia_estimation.R [options]\n\n",
        "Options:\n",
        "  --models=1,2,3              Run specific models (comma-separated)\n",
        "  --ndraws=N                  Number of MCMC draws (default: 50000; paper setting)\n",
        "  --parallel                  Run models in supervised parallel batches (default)\n",
        "  --sequential                Run models sequentially\n",
        "  --cores=N                   Total available cores\n",
        "  --cores-per-model=N         Cores per model (default: 4)\n",
        "  --self-pricing-engine=NAME  fast or reference (default: fast)\n",
        "  --dry-run                   Show what would be run\n",
        "  --list                      List all available models\n",
        "  --help, -h                  Show this help message\n\n",
        "The no-flag path uses 50,000 draws for the IA estimation paper setting.\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  opts$self_pricing_engine <- match.arg(opts$self_pricing_engine, c("fast", "reference"))
  opts
}

print_model_list <- function() {
  cat("\n")
  cat("======================================================================\n")
  cat("  INTERNET APPENDIX MODELS\n")
  cat("======================================================================\n\n")

  for (cfg in ia_model_configs()) {
    cat(sprintf("  [%d] %-25s\n", cfg$id, cfg$name))
    cat(sprintf("      %s\n", cfg$description))
    cat(sprintf("      model_type: %-20s intercept: %s\n", cfg$model_type, if (cfg$intercept) "YES" else "NO"))
    cat(sprintf("      expected engine: %s\n\n", ia_expected_engine(cfg)$function_name))
  }
}

child_rscript <- function() {
  if (.Platform$OS.type == "windows") {
    return(file.path(R.home("bin"), "Rscript.exe"))
  }
  file.path(R.home("bin"), "Rscript")
}

build_child_args <- function(model, opts, run_timestamp, status_path) {
  c(
    "ia/_run_ia_model.R",
    paste0("--model-id=", model$id),
    paste0("--ndraws=", opts$ndraws),
    paste0("--num-cores=", opts$cores_per_model),
    paste0("--run-timestamp=", run_timestamp),
    paste0("--self-pricing-engine=", opts$self_pricing_engine),
    paste0("--status-path=", status_path)
  )
}

launch_model_process <- function(model, opts, run_timestamp, logs_dir) {
  status_path <- ia_status_path(logs_dir, model_id = model$id, model_name = model$name, run_timestamp = run_timestamp)
  log_path <- ia_log_path(logs_dir, model_id = model$id, model_name = model$name, run_timestamp = run_timestamp)
  args <- build_child_args(model, opts, run_timestamp, status_path)

  proc <- processx::process$new(
    command = child_rscript(),
    args = args,
    wd = getwd(),
    stdout = log_path,
    stderr = log_path,
    cleanup_tree = TRUE
  )

  list(
    model = model,
    log_path = normalizePath(log_path, winslash = "/", mustWork = FALSE),
    status_path = normalizePath(status_path, winslash = "/", mustWork = FALSE),
    results_path = normalizePath(ia_results_path(model, main_path = getwd(), output_folder = file.path("ia", "output")), winslash = "/", mustWork = FALSE),
    process = proc
  )
}

validate_child_model_result <- function(proc_info, opts, min_mtime) {
  exit_status <- proc_info$process$get_exit_status()
  status <- read_ia_status(proc_info$status_path)

  if (is.null(exit_status) || exit_status != 0L) {
    status_error <- if (is.null(status)) NULL else status$error
    stop(
      sprintf(
        "IA model %s failed with exit status %s.\nStatus: %s\nLog: %s",
        proc_info$model$name,
        ia_value_or(exit_status, NA_integer_),
        ia_value_or(status_error, "Child process exited without a successful status artifact."),
        proc_info$log_path
      ),
      call. = FALSE
    )
  }

  validation <- validate_ia_results_artifact(
    results_file = proc_info$results_path,
    status_path = proc_info$status_path,
    expected_ndraws = opts$ndraws,
    min_mtime = min_mtime,
    expected_engine = ia_expected_engine(proc_info$model, self_pricing_engine = opts$self_pricing_engine)
  )

  if (!isTRUE(validation$ok)) {
    stop(
      sprintf(
        "IA model %s outputs failed validation.\nStatus: %s\nLog: %s\n%s",
        proc_info$model$name,
        proc_info$status_path,
        proc_info$log_path,
        format_ia_validation_issues(validation)
      ),
      call. = FALSE
    )
  }

  validation
}

run_sequential_models <- function(models, opts, run_timestamp) {
  source(file.path("code_base", "ia_run_helpers.R"))
  source(file.path("ia", "_run_ia_model.R"))

  results <- lapply(models, function(model) {
    run_ia_model(
      model_id = model$id,
      ndraws = opts$ndraws,
      num_cores = opts$cores_per_model,
      run_timestamp = run_timestamp,
      self_pricing_engine = opts$self_pricing_engine
    )
  })

  invisible(results)
}

run_parallel_models <- function(models, opts, run_timestamp) {
  if (!requireNamespace("processx", quietly = TRUE)) {
    cat("Package 'processx' is not installed. Falling back to sequential IA execution.\n\n")
    return(run_sequential_models(models, opts, run_timestamp))
  }

  logs_dir <- ia_logs_dir(main_path = getwd(), output_folder = file.path("ia", "output"))
  available_cores <- max(1L, opts$cores - 1L)
  max_concurrent <- max(1L, floor(available_cores / max(1L, opts$cores_per_model)))

  cat("\n======================================================================\n")
  cat("  IA SUPERVISED PARALLEL EXECUTION\n")
  cat("======================================================================\n")
  cat("  Total cores available: ", opts$cores, "\n", sep = "")
  cat("  Cores per model:       ", opts$cores_per_model, "\n", sep = "")
  cat("  Max concurrent models: ", max_concurrent, "\n", sep = "")
  cat("  MCMC draws:            ", opts$ndraws, "\n", sep = "")
  cat("======================================================================\n")

  all_validations <- list()
  batch_num <- 1L

  for (i in seq(1L, length(models), by = max_concurrent)) {
    batch_models <- models[i:min(i + max_concurrent - 1L, length(models))]
    launched_at <- Sys.time()

    cat("\nLaunching IA batch ", batch_num, ": ", paste(vapply(batch_models, `[[`, character(1), "name"), collapse = ", "), "\n", sep = "")

    proc_infos <- tryCatch({
      lapply(batch_models, launch_model_process, opts = opts, run_timestamp = run_timestamp, logs_dir = logs_dir)
    }, error = function(e) {
      cat("Supervised child launch failed in this terminal.\n")
      cat("Falling back to sequential IA execution for the remaining models.\n")
      cat("Launch error: ", conditionMessage(e), "\n\n", sep = "")
      return(NULL)
    })

    if (is.null(proc_infos)) {
      remaining <- models[i:length(models)]
      sequential_results <- run_sequential_models(remaining, opts, run_timestamp)
      all_validations <- c(all_validations, lapply(sequential_results, `[[`, "validation"))
      break
    }

    repeat {
      Sys.sleep(POLL_SECONDS)
      elapsed_mins <- as.numeric(difftime(Sys.time(), launched_at, units = "mins"))
      status_lines <- vapply(proc_infos, function(info) {
        if (info$process$is_alive()) {
          sprintf("%s=running", info$model$name)
        } else {
          sprintf("%s=exit(%s)", info$model$name, ia_value_or(info$process$get_exit_status(), NA_integer_))
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
        stop("IA run exceeded the timeout of ", MAX_RUNTIME_MINS, " minutes and was terminated.", call. = FALSE)
      }
    }

    cat("\n")
    batch_validations <- lapply(proc_infos, validate_child_model_result, opts = opts, min_mtime = launched_at)
    names(batch_validations) <- vapply(proc_infos, function(info) info$model$name, character(1))
    all_validations <- c(all_validations, batch_validations)
    batch_num <- batch_num + 1L
  }

  invisible(all_validations)
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- parse_args(args)

  if (isTRUE(opts$list_only)) {
    print_model_list()
    quit(save = "no", status = 0)
  }

  models <- lapply(opts$models, ia_model_by_id)
  run_timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

  cat("\n======================================================================\n")
  cat("  INTERNET APPENDIX MODEL ESTIMATION\n")
  cat("======================================================================\n")
  cat("  Models:               ", paste(vapply(models, `[[`, integer(1), "id"), collapse = ", "), "\n", sep = "")
  cat("  Draws:                ", opts$ndraws, "\n", sep = "")
  cat("  Parallel:             ", if (opts$parallel) "YES" else "NO", "\n", sep = "")
  cat("  Self-pricing engine:  ", opts$self_pricing_engine, "\n", sep = "")
  cat("  Dry run:              ", if (opts$dry_run) "YES" else "NO", "\n", sep = "")
  cat("======================================================================\n\n")

  if (isTRUE(opts$dry_run)) {
    for (model in models) {
      expected_engine <- ia_expected_engine(model, self_pricing_engine = opts$self_pricing_engine)
      cat(sprintf(
        "[DRY RUN] Model %d (%s): output=%s | engine=%s\n",
        model$id,
        model$name,
        ia_results_path(model, main_path = main_path, output_folder = file.path("ia", "output")),
        expected_engine$function_name
      ))
    }
    quit(save = "no", status = 0)
  }

  validations <- if (isTRUE(opts$parallel) && length(models) > 1) {
    run_parallel_models(models, opts, run_timestamp)
  } else {
    lapply(run_sequential_models(models, opts, run_timestamp), `[[`, "validation")
  }

  cat("\n======================================================================\n")
  cat("  IA ESTIMATION SUMMARY\n")
  cat("======================================================================\n")
  for (validation in validations) {
    model_name <- if (!is.null(validation$status$model_name)) validation$status$model_name else basename(validation$results_file)
    cat(sprintf(
      "  %-25s OK  engine=%s  output=%s\n",
      model_name,
      ia_value_or(validation$engine_used, "missing"),
      validation$results_file
    ))
  }
  cat("======================================================================\n")
  cat("Done.\n")
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
