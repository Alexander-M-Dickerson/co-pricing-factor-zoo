#!/usr/bin/env Rscript
###############################################################################
## _run_ia_model.R
##
## Run one Internet Appendix model end to end.
##
## Paper role: Single-model IA estimation entrypoint used by the supervised IA
##   orchestrator.
## Paper refs: IA.6, IA.7, IA.9, IA.10; Eq. (6), Eq. (10);
##   docs/paper/co-pricing-factor-zoo.ai-optimized.md
## Outputs: ia/output/unconditional/...Rdata and ia/output/logs/ia_status_*.rds
###############################################################################

DEFAULT_NDRAWS <- 50000L
DEFAULT_NUM_CORES <- 4L

parse_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- list(
    model_id = NULL,
    ndraws = DEFAULT_NDRAWS,
    num_cores = DEFAULT_NUM_CORES,
    run_timestamp = format(Sys.time(), "%Y%m%d_%H%M%S"),
    self_pricing_engine = "fast",
    status_path = NULL
  )

  for (arg in args) {
    if (grepl("^--model-id=", arg)) {
      opts$model_id <- as.integer(sub("^--model-id=", "", arg))
    } else if (grepl("^--ndraws=", arg)) {
      opts$ndraws <- as.integer(sub("^--ndraws=", "", arg))
    } else if (grepl("^--num-cores=", arg)) {
      opts$num_cores <- as.integer(sub("^--num-cores=", "", arg))
    } else if (grepl("^--run-timestamp=", arg)) {
      opts$run_timestamp <- sub("^--run-timestamp=", "", arg)
    } else if (grepl("^--self-pricing-engine=", arg)) {
      opts$self_pricing_engine <- sub("^--self-pricing-engine=", "", arg)
    } else if (grepl("^--status-path=", arg)) {
      opts$status_path <- sub("^--status-path=", "", arg)
    } else if (identical(arg, "--help") || identical(arg, "-h")) {
      cat(
        "Usage: Rscript ia/_run_ia_model.R [options]\n\n",
        "Options:\n",
        "  --model-id=N                 IA model id to estimate (required)\n",
        "  --ndraws=N                   Number of MCMC draws (default: 50000)\n",
        "  --num-cores=N                Cores for this model (default: 4)\n",
        "  --run-timestamp=STAMP        Shared timestamp for the parent IA run\n",
        "  --self-pricing-engine=NAME   fast or reference (default: fast)\n",
        "  --status-path=PATH           Optional explicit status artifact path\n",
        "  --help, -h                   Show this help message\n",
        sep = ""
      )
      quit(save = "no", status = 0)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  if (is.null(opts$model_id) || is.na(opts$model_id)) {
    stop("`--model-id=` is required.", call. = FALSE)
  }

  opts$self_pricing_engine <- match.arg(opts$self_pricing_engine, c("fast", "reference"))
  opts
}

ensure_repo_root <- function() {
  if (basename(getwd()) == "ia") {
    setwd("..")
  }

  if (!file.exists("code_base/run_bayesian_mcmc.R")) {
    stop("Please run this script from the project root directory (co-pricing-factor-zoo/).", call. = FALSE)
  }

  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

read_kappa_inputs <- function(model) {
  if (is.null(model$kappa_file) || !nzchar(model$kappa_file)) {
    return(list(kappa = ia_value_or(model$kappa, 0), kappa_fac = NULL))
  }

  if (!file.exists(model$kappa_file)) {
    stop(
      "Kappa weights file not found: ", model$kappa_file,
      "\nThis file is now required clone data for the IA weighted treasury branch.",
      call. = FALSE
    )
  }

  w_all <- readRDS(model$kappa_file)
  if (!is.numeric(w_all) || is.null(names(w_all))) {
    stop("`", model$kappa_file, "` must contain a named numeric vector.", call. = FALSE)
  }

  list(kappa = w_all, kappa_fac = names(w_all))
}

validate_model_inputs <- function(model, data_folder = "data") {
  required_paths <- c(
    file.path(data_folder, model$f1),
    file.path(data_folder, model$f2),
    file.path(data_folder, model$R),
    file.path(data_folder, "frequentist_factors.csv")
  )

  missing <- required_paths[!file.exists(required_paths)]
  if (length(missing) > 0) {
    stop("Required IA input files are missing: ", paste(missing, collapse = ", "), call. = FALSE)
  }

  invisible(required_paths)
}

run_ia_model <- function(model_id,
                         ndraws = DEFAULT_NDRAWS,
                         num_cores = DEFAULT_NUM_CORES,
                         run_timestamp = format(Sys.time(), "%Y%m%d_%H%M%S"),
                         self_pricing_engine = "fast",
                         status_path = NULL) {
  main_path <- ensure_repo_root()
  code_folder <- "code_base"
  output_folder <- file.path("ia", "output")

  source(file.path(code_folder, "ia_run_helpers.R"))
  source(file.path(code_folder, "logging_helpers.R"))
  source(file.path(code_folder, "validate_and_align_dates.R"))
  source(file.path(code_folder, "data_loading_helpers.R"))
  source(file.path(code_folder, "run_bayesian_mcmc.R"))

  model <- ia_model_by_id(model_id)
  logs_dir <- ia_logs_dir(main_path = main_path, output_folder = output_folder)
  status_path <- ia_value_or(
    status_path,
    ia_status_path(logs_dir, model_id = model$id, model_name = model$name, run_timestamp = run_timestamp)
  )
  status_path <- normalizePath(status_path, winslash = "/", mustWork = FALSE)

  expected_output_path <- ia_results_path(model, main_path = main_path, output_folder = output_folder)
  expected_engine <- ia_expected_engine(model, self_pricing_engine = self_pricing_engine)
  started_at <- Sys.time()

  status <- list(
    status = "running",
    model_id = model$id,
    model_name = model$name,
    ndraws = ndraws,
    started_at = started_at,
    finished_at = NULL,
    expected_output_path = normalizePath(expected_output_path, winslash = "/", mustWork = FALSE),
    output_exists = file.exists(expected_output_path),
    output_mtime = if (file.exists(expected_output_path)) file.info(expected_output_path)$mtime else NULL,
    engine_expected = expected_engine$function_name,
    engine_expected_label = expected_engine$engine_label,
    engine_used = NULL,
    engine_label = NULL,
    num_cores = num_cores,
    error = NULL
  )
  write_ia_status(status_path, status)

  update_status <- function(...) {
    status <<- utils::modifyList(status, list(...))
    write_ia_status(status_path, status)
    invisible(status)
  }

  on.exit({
    if (!identical(status$status, "complete") && !identical(status$status, "failed")) {
      update_status(
        status = "failed",
        finished_at = Sys.time(),
        output_exists = file.exists(expected_output_path),
        output_mtime = if (file.exists(expected_output_path)) file.info(expected_output_path)$mtime else NULL,
        error = ia_value_or(status$error, "IA model exited without marking completion.")
      )
    }
  }, add = TRUE)

  cat("\n========================================\n")
  cat("RUNNING IA MODEL\n")
  cat("========================================\n")
  cat("Model:                ", model$name, " (", model$id, ")\n", sep = "")
  cat("Description:          ", model$description, "\n", sep = "")
  cat("Expected engine:      ", expected_engine$function_name, " [", expected_engine$engine_label, "]\n", sep = "")
  cat("Expected output:      ", expected_output_path, "\n", sep = "")
  cat("Status artifact:      ", status_path, "\n", sep = "")
  cat("Draws:                ", ndraws, "\n", sep = "")
  cat("Cores:                ", num_cores, "\n", sep = "")
  cat("========================================\n\n")

  validate_model_inputs(model)
  kappa_inputs <- read_kappa_inputs(model)

  result <- tryCatch({
    run_bayesian_mcmc(
      main_path = main_path,
      data_folder = "data",
      output_folder = output_folder,
      code_folder = code_folder,
      model_type = model$model_type,
      return_type = model$return_type,
      f1 = model$f1,
      f2 = model$f2,
      R = model$R,
      fac_freq = "frequentist_factors.csv",
      n_bond_factors = NULL,
      date_start = NULL,
      date_end = NULL,
      frequentist_models = model$frequentist_models,
      ndraws = ndraws,
      SRscale = c(0.20, 0.40, 0.60, 0.80),
      alpha.w = model$alpha_w,
      beta.w = model$beta_w,
      kappa = kappa_inputs$kappa,
      kappa_fac = kappa_inputs$kappa_fac,
      drop_draws_pct = 0,
      tag = model$tag,
      num_cores = num_cores,
      seed = 234,
      intercept = model$intercept,
      save_flag = TRUE,
      verbose = TRUE,
      fac_to_drop = NULL,
      weighting = "GLS",
      self_pricing_engine = self_pricing_engine
    )
  }, error = function(e) {
    update_status(
      status = "failed",
      finished_at = Sys.time(),
      output_exists = file.exists(expected_output_path),
      output_mtime = if (file.exists(expected_output_path)) file.info(expected_output_path)$mtime else NULL,
      error = conditionMessage(e)
    )
    stop(e)
  })

  validation <- validate_ia_results_artifact(
    results_file = result$saved_path,
    expected_ndraws = ndraws,
    min_mtime = started_at,
    expected_engine = expected_engine
  )

  if (!isTRUE(validation$ok)) {
    update_status(
      status = "failed",
      finished_at = Sys.time(),
      output_exists = file.exists(result$saved_path),
      output_mtime = if (file.exists(result$saved_path)) file.info(result$saved_path)$mtime else NULL,
      engine_used = validation$engine_used,
      engine_label = validation$engine_label,
      error = paste(validation$issues, collapse = " | ")
    )
    stop(
      "IA output validation failed for ", model$name, ":\n",
      format_ia_validation_issues(validation),
      call. = FALSE
    )
  }

  update_status(
    status = "complete",
    finished_at = Sys.time(),
    output_exists = TRUE,
    output_mtime = validation$results_mtime,
    engine_used = validation$engine_used,
    engine_label = validation$engine_label,
    error = NULL
  )

  cat("IA model complete: ", model$name, "\n", sep = "")
  invisible(list(
    model = model,
    status_path = status_path,
    results_path = result$saved_path,
    validation = validation
  ))
}

main <- function(args = commandArgs(trailingOnly = TRUE)) {
  opts <- parse_args(args)
  run_ia_model(
    model_id = opts$model_id,
    ndraws = opts$ndraws,
    num_cores = opts$num_cores,
    run_timestamp = opts$run_timestamp,
    self_pricing_engine = opts$self_pricing_engine,
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
