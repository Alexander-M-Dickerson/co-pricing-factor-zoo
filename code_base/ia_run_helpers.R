###############################################################################
## ia_run_helpers.R
## ---------------------------------------------------------------------------
##
## Paper role:
##   Shared registry and validation helpers for the implemented Internet
##   Appendix estimation subset.
##
## Paper refs:
##   - IA.6 and IA.7: intercept/no-intercept robustness
##   - IA.9: Treasury-component and DR-tilt robustness
##   - IA.10: sparse and IS/OS-switch robustness
##   - Eq. (6): heterogeneous kappa tilt for weighted Treasury runs
##   - Eq. (10): Treasury-component decomposition
###############################################################################

ia_value_or <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    y
  } else {
    x
  }
}

ia_default_frequentist_models <- function() {
  list(
    CAPM = "MKTS",
    CAPMB = "MKTB",
    FF5 = c("MKTS", "HML", "SMB", "DEF", "TERM"),
    HKM = c("MKTS", "CPTLT")
  )
}

ia_treasury_frequentist_models <- function() {
  list(
    CAPM = c("MKTB"),
    CAPMB = c("MKTB", "MKTBD"),
    HKM = c("MKTB", "DEF", "TERM"),
    FF5 = c("MKTB", "SZE", "HMLB", "CRF", "DRF")
  )
}

ia_model_configs <- function() {
  list(
    # Paper: Models 1-5 are the baseline IA robustness block that toggles
    # intercept inclusion and compares bond, stock, and joint co-pricing runs.
    list(
      id = 1L,
      name = "bond_intercept",
      description = "Bond factors WITH intercept (excess returns)",
      model_type = "bond",
      return_type = "excess",
      intercept = TRUE,
      tag = "ia_intercept",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv"),
      R = c("bond_insample_test_assets_50_excess.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    ),
    list(
      id = 2L,
      name = "stock_intercept",
      description = "Stock factors WITH intercept (excess returns)",
      model_type = "stock",
      return_type = "excess",
      intercept = TRUE,
      tag = "ia_intercept",
      f1 = "nontraded.csv",
      f2 = c("traded_equity.csv"),
      R = c("equity_anomalies_composite_33.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    ),
    list(
      id = 3L,
      name = "bond_no_intercept",
      description = "Bond factors WITHOUT intercept (excess returns)",
      model_type = "bond",
      return_type = "excess",
      intercept = FALSE,
      tag = "ia_no_intercept",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv"),
      R = c("bond_insample_test_assets_50_excess.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    ),
    list(
      id = 4L,
      name = "stock_no_intercept",
      description = "Stock factors WITHOUT intercept (excess returns)",
      model_type = "stock",
      return_type = "excess",
      intercept = FALSE,
      tag = "ia_no_intercept",
      f1 = "nontraded.csv",
      f2 = c("traded_equity.csv"),
      R = c("equity_anomalies_composite_33.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    ),
    list(
      id = 5L,
      name = "joint_no_intercept",
      description = "Joint bond+stock WITHOUT intercept (excess returns)",
      model_type = "bond_stock_with_sp",
      return_type = "excess",
      intercept = FALSE,
      tag = "ia_no_intercept",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv", "traded_equity.csv"),
      R = c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    ),
    # Paper: Treasury base is the Eq. (10) component exercise with Treasury-
    # matched bond returns, reported separately from the main co-pricing model.
    list(
      id = 6L,
      name = "treasury_base",
      description = "Treasury bond component (excess returns)",
      model_type = "treasury",
      return_type = "excess",
      intercept = TRUE,
      tag = "bond_treasury",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv"),
      R = c("bond_insample_test_assets_50_duration_tmt_tbond.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_treasury_frequentist_models()
    ),
    # Paper: Treasury weighted is the DR-tilt robustness that applies Eq. (6)
    # style prior tilts using the CF/DR-informed weights stored in w_all.rds.
    list(
      id = 7L,
      name = "treasury_weighted",
      description = "Treasury bond component with DR-tilt kappa (excess returns)",
      model_type = "treasury",
      return_type = "excess",
      intercept = TRUE,
      tag = "bond_treasury",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv"),
      R = c("bond_insample_test_assets_50_duration_tmt_tbond.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = NULL,
      kappa_file = "ia/data/w_all.rds",
      frequentist_models = ia_treasury_frequentist_models()
    ),
    # Paper: Sparse joint uses the Beta prior calibrated so the expected model
    # size is close to the canonical five-factor benchmark.
    list(
      id = 8L,
      name = "sparse_joint",
      description = "Joint bond+stock with sparsity prior (excess returns)",
      model_type = "bond_stock_with_sp",
      return_type = "excess",
      intercept = TRUE,
      tag = "ia_sparse",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv", "traded_equity.csv"),
      R = c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv"),
      alpha_w = 3.537037,
      beta_w = 34.662963,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    ),
    # Paper: IS/OS switch re-estimates the joint model on the original OOS test
    # assets to test whether the main findings depend on the canonical IS split.
    list(
      id = 9L,
      name = "isos_switch",
      description = "Joint bond+stock IS/OS switch (excess returns)",
      model_type = "bond_stock_with_sp",
      return_type = "excess",
      intercept = TRUE,
      tag = "isos_switch",
      f1 = "nontraded.csv",
      f2 = c("traded_bond_excess.csv", "traded_equity.csv"),
      R = c("bond_oosample_all_excess.csv", "equity_os_77.csv"),
      alpha_w = 1,
      beta_w = 1,
      kappa = 0,
      kappa_file = NULL,
      frequentist_models = ia_default_frequentist_models()
    )
  )
}

ia_model_ids <- function() {
  vapply(ia_model_configs(), `[[`, integer(1), "id")
}

ia_model_by_id <- function(model_id) {
  model_id <- as.integer(model_id)
  matches <- Filter(function(cfg) identical(cfg$id, model_id), ia_model_configs())
  if (length(matches) != 1) {
    stop("Unknown IA model id: ", model_id, call. = FALSE)
  }
  matches[[1]]
}

ia_logs_dir <- function(main_path = getwd(), output_folder = file.path("ia", "output")) {
  base_output <- if (dir.exists(output_folder)) {
    output_folder
  } else {
    file.path(main_path, output_folder)
  }
  logs_dir <- file.path(base_output, "logs")
  dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)
  normalizePath(logs_dir, winslash = "/", mustWork = FALSE)
}

ia_status_path <- function(logs_dir, model_id, model_name, run_timestamp) {
  file.path(logs_dir, sprintf("ia_status_model_%d_%s_%s.rds", model_id, model_name, run_timestamp))
}

ia_log_path <- function(logs_dir, model_id, model_name, run_timestamp) {
  file.path(logs_dir, sprintf("log_ia_model_%d_%s_%s.txt", model_id, model_name, run_timestamp))
}

ia_kappa_label <- function(model) {
  if (!is.null(model$kappa_file) && nzchar(model$kappa_file)) {
    return("weighted")
  }

  kappa <- ia_value_or(model$kappa, 0)
  if (all(kappa == 0)) {
    return("0")
  }

  kappa_str <- paste(format(kappa, digits = 3, trim = TRUE), collapse = "_")
  if (nchar(kappa_str) > 10) {
    "weighted"
  } else {
    kappa_str
  }
}

ia_results_filename <- function(model) {
  parts <- c(
    model$return_type,
    model$model_type,
    sprintf("alpha.w=%g", trunc(model$alpha_w)),
    sprintf("beta.w=%g", trunc(model$beta_w)),
    sprintf("kappa=%s", ia_kappa_label(model))
  )

  if (!isTRUE(model$intercept)) {
    parts <- c(parts, "no_intercept")
  }

  if (nzchar(model$tag)) {
    parts <- c(parts, model$tag)
  }

  paste0(paste(parts, collapse = "_"), ".Rdata")
}

ia_results_path <- function(model,
                            main_path = getwd(),
                            output_folder = file.path("ia", "output")) {
  base_output <- if (dir.exists(output_folder)) {
    output_folder
  } else {
    file.path(main_path, output_folder)
  }

  file.path(
    base_output,
    "unconditional",
    model$model_type,
    ia_results_filename(model)
  )
}

ia_expected_engine <- function(model, self_pricing_engine = "fast") {
  self_pricing_engine <- match.arg(self_pricing_engine, c("fast", "reference"))
  # Paper: Treasury-component runs are estimated through the no-self-pricing
  # branch because the Treasury factors are folded into the non-traded block for
  # the BMA-SDF step. Fast self-pricing applies only to the tradable-factor
  # v2 sampler used by the bond, stock, and joint co-pricing IA models.
  has_tradable_factors <- !identical(model$model_type, "treasury") &&
    !is.null(model$f2) &&
    length(model$f2) > 0
  has_nonzero_kappa <- !is.null(model$kappa_file) || (!is.null(model$kappa) && any(model$kappa != 0))

  if (has_tradable_factors && has_nonzero_kappa) {
    return(list(
      function_name = "continuous_ss_sdf_multi_asset",
      engine_label = "weighted_multi_asset",
      requires_fast_backend = FALSE
    ))
  }

  if (has_tradable_factors && identical(self_pricing_engine, "fast")) {
    return(list(
      function_name = "continuous_ss_sdf_v2_fast",
      engine_label = "fast_self_pricing",
      requires_fast_backend = TRUE
    ))
  }

  if (has_tradable_factors) {
    return(list(
      function_name = "BayesianFactorZoo::continuous_ss_sdf_v2",
      engine_label = "reference_self_pricing",
      requires_fast_backend = FALSE
    ))
  }

  if (has_nonzero_kappa) {
    return(list(
      function_name = "continuous_ss_sdf_multi_asset_no_sp",
      engine_label = "weighted_no_self_pricing",
      requires_fast_backend = FALSE
    ))
  }

  list(
    function_name = "BayesianFactorZoo::continuous_ss_sdf",
    engine_label = "reference_no_self_pricing",
    requires_fast_backend = FALSE
  )
}

write_ia_status <- function(status_path, status) {
  dir.create(dirname(status_path), recursive = TRUE, showWarnings = FALSE)
  saveRDS(status, file = status_path, compress = TRUE)
  invisible(status_path)
}

read_ia_status <- function(status_path) {
  if (is.null(status_path) || !nzchar(status_path) || !file.exists(status_path)) {
    return(NULL)
  }

  readRDS(status_path)
}

coerce_ia_time <- function(value) {
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

read_ia_workspace_metadata <- function(results_file) {
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

validate_ia_results_artifact <- function(results_file,
                                         status_path = NULL,
                                         expected_ndraws = NULL,
                                         min_mtime = NULL,
                                         expected_engine = NULL) {
  issues <- character(0)
  status <- read_ia_status(status_path)
  normalized_results_file <- normalizePath(results_file, winslash = "/", mustWork = FALSE)
  results_exists <- file.exists(normalized_results_file)
  file_mtime <- if (results_exists) file.info(normalized_results_file)$mtime else as.POSIXct(NA)
  file_mtime <- coerce_ia_time(file_mtime)
  min_mtime <- coerce_ia_time(min_mtime)

  if (!results_exists) {
    issues <- c(issues, paste("Expected IA results file not found:", normalized_results_file))
  }

  if (!is.null(status)) {
    expected_path <- ia_value_or(status$expected_output_path, "")
    if (nzchar(expected_path)) {
      normalized_expected <- normalizePath(expected_path, winslash = "/", mustWork = FALSE)
      if (!identical(normalized_expected, normalized_results_file)) {
        issues <- c(issues, paste("Status file points to a different IA results file:", normalized_expected))
      }
    }

    if (!identical(status$status, "complete")) {
      issues <- c(issues, paste("IA model status is not complete:", ia_value_or(status$status, "missing")))
    }

    if (!isTRUE(ia_value_or(status$output_exists, FALSE))) {
      issues <- c(issues, "Status file reports that the IA output file was not written.")
    }

    status_output_mtime <- coerce_ia_time(status$output_mtime)
    if (is.null(file_mtime) || is.na(file_mtime)) {
      file_mtime <- status_output_mtime
    }
  }

  metadata <- NULL
  if (results_exists) {
    metadata <- tryCatch(
      read_ia_workspace_metadata(normalized_results_file),
      error = function(e) {
        issues <<- c(issues, paste("Could not read IA results metadata:", conditionMessage(e)))
        NULL
      }
    )
  }

  ndraws <- ia_value_or(ia_value_or(status$ndraws, NULL), ia_value_or(metadata$ndraws, NULL))
  if (!is.null(expected_ndraws)) {
    if (is.null(ndraws)) {
      issues <- c(issues, "IA results metadata does not expose ndraws.")
    } else if (as.integer(ndraws) != as.integer(expected_ndraws)) {
      issues <- c(
        issues,
        sprintf("IA results were generated with ndraws=%s, expected %s.", ndraws, expected_ndraws)
      )
    }
  }

  engine_used <- ia_value_or(
    ia_value_or(status$engine_used, NULL),
    ia_value_or(metadata$engine_used, ia_value_or(metadata$sampler_dispatch$function_name, NULL))
  )
  engine_label <- ia_value_or(
    ia_value_or(status$engine_label, NULL),
    ia_value_or(metadata$engine_label, ia_value_or(metadata$sampler_dispatch$engine_label, NULL))
  )

  if (!is.null(expected_engine)) {
    if (!identical(engine_used, expected_engine$function_name)) {
      issues <- c(
        issues,
        sprintf(
          "IA results used engine '%s', expected '%s'.",
          ia_value_or(engine_used, "missing"),
          expected_engine$function_name
        )
      )
    }

    if (!identical(engine_label, expected_engine$engine_label)) {
      issues <- c(
        issues,
        sprintf(
          "IA results reported engine label '%s', expected '%s'.",
          ia_value_or(engine_label, "missing"),
          expected_engine$engine_label
        )
      )
    }
  }

  if (!is.null(min_mtime) && !is.null(file_mtime) && !is.na(file_mtime) && file_mtime < min_mtime) {
    issues <- c(
      issues,
      sprintf(
        "IA results file is stale: mtime=%s is older than required start time %s.",
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
    engine_used = engine_used,
    engine_label = engine_label,
    results_file = normalized_results_file,
    results_mtime = file_mtime
  )
}

validate_expected_ia_workspaces <- function(main_path = getwd(),
                                            output_folder = file.path("ia", "output"),
                                            expected_ndraws = NULL,
                                            min_mtime = NULL,
                                            model_ids = ia_model_ids(),
                                            self_pricing_engine = "fast") {
  validations <- lapply(model_ids, function(model_id) {
    model <- ia_model_by_id(model_id)
    results_file <- ia_results_path(
      model = model,
      main_path = main_path,
      output_folder = output_folder
    )
    validation <- validate_ia_results_artifact(
      results_file = results_file,
      expected_ndraws = expected_ndraws,
      min_mtime = min_mtime,
      expected_engine = ia_expected_engine(model, self_pricing_engine = self_pricing_engine)
    )
    validation$model <- model
    validation
  })

  issues <- unique(unlist(lapply(validations, `[[`, "issues")))
  list(
    ok = length(issues) == 0,
    issues = issues,
    validations = validations
  )
}

format_ia_validation_issues <- function(validation) {
  if (isTRUE(validation$ok)) {
    return("")
  }

  paste0("- ", paste(validation$issues, collapse = "\n- "))
}

implemented_ia_manifest_outputs <- function(repo_root = getwd()) {
  manifest_path <- file.path(repo_root, "docs", "manifests", "exhibits.csv")
  manifest <- utils::read.csv(manifest_path, stringsAsFactors = FALSE, check.names = FALSE)
  subset(
    manifest,
    category %in% c("ia-table", "ia-figure") &
      coverage_status == "implemented-subset",
    select = c("exhibit_id", "output_path")
  )
}

validate_ia_manifest_outputs <- function(repo_root = getwd(), min_mtime = NULL) {
  manifest_outputs <- implemented_ia_manifest_outputs(repo_root)
  issues <- character(0)
  matches <- vector("list", nrow(manifest_outputs))
  min_mtime <- coerce_ia_time(min_mtime)

  for (idx in seq_len(nrow(manifest_outputs))) {
    pattern <- file.path(repo_root, manifest_outputs$output_path[[idx]])
    found <- Sys.glob(pattern)
    matches[[idx]] <- found
    if (length(found) == 0) {
      issues <- c(
        issues,
        paste("Missing IA output for", manifest_outputs$exhibit_id[[idx]], "at pattern", manifest_outputs$output_path[[idx]])
      )
    } else if (!is.null(min_mtime)) {
      file_infos <- file.info(found)
      stale <- rownames(file_infos)[!is.na(file_infos$mtime) & coerce_ia_time(file_infos$mtime) < min_mtime]
      if (length(stale) > 0) {
        issues <- c(
          issues,
          paste("Stale IA output(s) for", manifest_outputs$exhibit_id[[idx]], ":", paste(basename(stale), collapse = ", "))
        )
      }
    }
  }

  list(
    ok = length(issues) == 0,
    issues = unique(issues),
    matches = matches,
    manifest_outputs = manifest_outputs
  )
}

format_ia_output_issues <- function(validation) {
  if (isTRUE(validation$ok)) {
    return("")
  }

  paste0("- ", paste(validation$issues, collapse = "\n- "))
}
