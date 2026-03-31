`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) {
    y
  } else {
    x
  }
}

get_testing_repo_root <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)

  if (length(file_arg) == 0) {
    return(normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE))
  }

  script_dir <- dirname(sub("^--file=", "", file_arg[1]))
  normalizePath(file.path(script_dir, ".."), winslash = "/", mustWork = TRUE)
}

build_report_dir <- function(prefix, report_dir = NULL) {
  target_dir <- report_dir %||% file.path(
    tempdir(),
    sprintf("%s_%s", prefix, format(Sys.time(), "%Y%m%d_%H%M%S"))
  )
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  normalizePath(target_dir, winslash = "/", mustWork = TRUE)
}

write_csv_report <- function(data, filepath) {
  utils::write.csv(data, filepath, row.names = FALSE)
}

load_validation_sources <- function(repo_root) {
  source(file.path(repo_root, "code_base", "validate_and_align_dates.R"))
  source(file.path(repo_root, "code_base", "data_loading_helpers.R"))
  source(file.path(repo_root, "code_base", "continuous_ss_sdf_v2_fast.R"))
}

load_matrix_file <- function(repo_root, filename) {
  as.matrix(utils::read.csv(
    file.path(repo_root, "data", filename),
    check.names = FALSE
  )[, -1, drop = FALSE])
}

load_date_column <- function(repo_root, filename) {
  raw <- utils::read.csv(file.path(repo_root, "data", filename), check.names = FALSE)
  as.character(raw[[1]])
}

default_frequentist_models <- function() {
  list(
    CAPM = "MKTS",
    CAPMB = "MKTB",
    FF5 = c("MKTS", "HML", "SMB", "DEF", "TERM"),
    HKM = c("MKTS", "CPTLT")
  )
}

load_kernel_validation_inputs <- function(repo_root) {
  f1 <- load_matrix_file(repo_root, "nontraded.csv")
  f2 <- cbind(
    load_matrix_file(repo_root, "traded_bond_excess.csv"),
    load_matrix_file(repo_root, "traded_equity.csv")
  )
  R <- cbind(
    load_matrix_file(repo_root, "bond_insample_test_assets_50_excess.csv"),
    load_matrix_file(repo_root, "equity_anomalies_composite_33.csv")
  )
  dates <- load_date_column(repo_root, "nontraded.csv")
  Rc <- cbind(R, f2)
  sr_scale <- c(0.20, 0.40, 0.60, 0.80)
  prior_sr <- sr_scale * sqrt(SharpeRatio(Rc))
  psi_grid <- BayesianFactorZoo::psi_to_priorSR(
    R = Rc,
    f = cbind(f1, f2),
    psi0 = NULL,
    priorSR = prior_sr,
    aw = 1,
    bw = 1
  )

  list(
    f1 = f1,
    f2 = f2,
    R = R,
    dates = dates,
    factor_names = colnames(cbind(f1, f2)),
    lambda_names = c("(Intercept)", colnames(cbind(f1, f2))),
    bma_names = dates,
    psi_grid = psi_grid,
    prior_labels = sprintf("SRscale_%0.2f", sr_scale)
  )
}

default_runner_validation_args <- function(repo_root, ndraws, seed) {
  list(
    main_path = repo_root,
    data_folder = "data",
    output_folder = tempdir(),
    code_folder = file.path(repo_root, "code_base"),
    model_type = "bond_stock_with_sp",
    return_type = "excess",
    f1 = "nontraded.csv",
    f2 = c("traded_bond_excess.csv", "traded_equity.csv"),
    R = c("bond_insample_test_assets_50_excess.csv", "equity_anomalies_composite_33.csv"),
    fac_freq = "frequentist_factors.csv",
    frequentist_models = default_frequentist_models(),
    ndraws = ndraws,
    SRscale = c(0.20, 0.40, 0.60, 0.80),
    alpha.w = 1,
    beta.w = 1,
    kappa = 0,
    kappa_fac = NULL,
    tag = "validation_runner",
    num_cores = 1,
    seed = seed,
    intercept = TRUE,
    save_flag = FALSE,
    verbose = FALSE,
    fac_to_drop = NULL,
    weighting = "GLS",
    parallel_type = "sequential"
  )
}

run_seeded_kernel_engine <- function(engine_fn, inputs, ndraws, seed_base) {
  result <- NULL
  timing <- system.time({
    result <- Map(
      function(current_psi, idx) {
        set.seed(seed_base + idx)
        engine_fn(
          f1 = inputs$f1,
          f2 = inputs$f2,
          R = inputs$R,
          sim_length = ndraws,
          psi0 = current_psi,
          r = 0.001,
          aw = 1,
          bw = 1,
          type = "GLS",
          intercept = TRUE
        )
      },
      inputs$psi_grid,
      seq_along(inputs$psi_grid)
    )
  })

  list(
    result = result,
    elapsed = unname(timing[["elapsed"]]),
    seeds = seed_base + seq_along(inputs$psi_grid)
  )
}

safe_abs_gap <- function(reference, candidate) {
  if (is.na(reference) && is.na(candidate)) {
    0
  } else if (is.na(reference) || is.na(candidate)) {
    Inf
  } else {
    abs(reference - candidate)
  }
}

value_equal_at_digits <- function(reference, candidate, digits) {
  if (is.na(reference) && is.na(candidate)) {
    TRUE
  } else {
    identical(round(reference, digits), round(candidate, digits))
  }
}

build_value_comparison_details <- function(component, prior_label, parameter_names, reference_values, candidate_values) {
  if (length(reference_values) != length(candidate_values)) {
    stop("Length mismatch in component '", component, "' for prior ", prior_label)
  }
  if (length(reference_values) != length(parameter_names)) {
    stop("Parameter name mismatch in component '", component, "' for prior ", prior_label)
  }

  abs_gap <- abs(reference_values - candidate_values)
  data.frame(
    component = component,
    prior_label = prior_label,
    parameter = parameter_names,
    reference = as.numeric(reference_values),
    candidate = as.numeric(candidate_values),
    abs_gap = as.numeric(abs_gap),
    equal_3dp = mapply(value_equal_at_digits, reference_values, candidate_values, MoreArgs = list(digits = 3)),
    equal_4dp = mapply(value_equal_at_digits, reference_values, candidate_values, MoreArgs = list(digits = 4)),
    stringsAsFactors = FALSE
  )
}

build_component_details <- function(component, prior_labels, parameter_names, reference_list, candidate_list) {
  detail_rows <- Map(
    function(prior_label, reference_values, candidate_values) {
      build_value_comparison_details(
        component = component,
        prior_label = prior_label,
        parameter_names = parameter_names,
        reference_values = reference_values,
        candidate_values = candidate_values
      )
    },
    prior_labels,
    reference_list,
    candidate_list
  )

  do.call(rbind, detail_rows)
}

summarise_component_details <- function(detail_df) {
  grouped <- split(detail_df, detail_df$prior_label)
  summary_rows <- lapply(grouped, function(df) {
    data.frame(
      component = df$component[1],
      prior_label = df$prior_label[1],
      n_values = nrow(df),
      max_abs_gap = max(df$abs_gap),
      mean_abs_gap = mean(df$abs_gap),
      equal_3dp = all(df$equal_3dp),
      equal_4dp = all(df$equal_4dp),
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, summary_rows)
}

kernel_result_details <- function(reference_results, candidate_results, inputs) {
  gamma_reference <- lapply(reference_results, function(x) colMeans(x$gamma_path))
  gamma_candidate <- lapply(candidate_results, function(x) colMeans(x$gamma_path))
  lambda_reference <- lapply(reference_results, function(x) colMeans(x$lambda_path))
  lambda_candidate <- lapply(candidate_results, function(x) colMeans(x$lambda_path))
  bma_reference <- lapply(reference_results, function(x) as.numeric(x$bma_sdf))
  bma_candidate <- lapply(candidate_results, function(x) as.numeric(x$bma_sdf))

  gamma_details <- build_component_details(
    component = "gamma_mean",
    prior_labels = inputs$prior_labels,
    parameter_names = inputs$factor_names,
    reference_list = gamma_reference,
    candidate_list = gamma_candidate
  )
  lambda_details <- build_component_details(
    component = "lambda_mean",
    prior_labels = inputs$prior_labels,
    parameter_names = inputs$lambda_names,
    reference_list = lambda_reference,
    candidate_list = lambda_candidate
  )
  bma_details <- build_component_details(
    component = "bma_sdf",
    prior_labels = inputs$prior_labels,
    parameter_names = inputs$bma_names,
    reference_list = bma_reference,
    candidate_list = bma_candidate
  )

  list(
    gamma = gamma_details,
    lambda = lambda_details,
    bma_sdf = bma_details,
    gamma_summary = summarise_component_details(gamma_details),
    lambda_summary = summarise_component_details(lambda_details),
    bma_sdf_summary = summarise_component_details(bma_details)
  )
}

sanitize_path_component <- function(x) {
  gsub("[^A-Za-z0-9_.-]", "_", x)
}

collect_object_signature <- function(x, path = "root") {
  class_name <- paste(class(x), collapse = "|")
  dims <- if (is.null(dim(x))) "" else paste(dim(x), collapse = "x")
  base_row <- data.frame(
    path = path,
    class = class_name,
    length = length(x),
    dims = dims,
    is_numeric = FALSE,
    mean = NA_real_,
    sd = NA_real_,
    max_abs = NA_real_,
    stringsAsFactors = FALSE
  )

  if (is.data.frame(x)) {
    child_rows <- lapply(seq_along(x), function(idx) {
      child_name <- sanitize_path_component(names(x)[idx] %||% paste0("col_", idx))
      collect_object_signature(x[[idx]], path = paste0(path, "$", child_name))
    })
    return(do.call(rbind, c(list(base_row), child_rows)))
  }

  if (is.list(x) && !is.object(x)) {
    child_rows <- lapply(seq_along(x), function(idx) {
      child_name <- sanitize_path_component(names(x)[idx] %||% paste0("item_", idx))
      collect_object_signature(x[[idx]], path = paste0(path, "$", child_name))
    })
    return(do.call(rbind, c(list(base_row), child_rows)))
  }

  if (inherits(x, "Date")) {
    return(base_row)
  }

  if (is.numeric(x) || is.integer(x)) {
    numeric_values <- as.numeric(x)
    base_row$is_numeric <- TRUE
    base_row$mean <- mean(numeric_values)
    base_row$sd <- if (length(numeric_values) > 1) stats::sd(numeric_values) else 0
    base_row$max_abs <- max(abs(numeric_values))
  }

  base_row
}

compare_object_signatures <- function(reference_signature, candidate_signature) {
  merged <- merge(
    reference_signature,
    candidate_signature,
    by = "path",
    all = TRUE,
    suffixes = c("_reference", "_candidate")
  )

  merged$missing_reference <- is.na(merged$class_reference)
  merged$missing_candidate <- is.na(merged$class_candidate)
  merged$class_match <- merged$class_reference == merged$class_candidate
  merged$length_match <- merged$length_reference == merged$length_candidate
  merged$dims_match <- merged$dims_reference == merged$dims_candidate

  numeric_rows <- merged[
    !merged$missing_reference &
      !merged$missing_candidate &
      merged$is_numeric_reference &
      merged$is_numeric_candidate,
    ,
    drop = FALSE
  ]

  if (nrow(numeric_rows) > 0) {
    numeric_rows$mean_abs_gap <- mapply(safe_abs_gap, numeric_rows$mean_reference, numeric_rows$mean_candidate)
    numeric_rows$sd_abs_gap <- mapply(safe_abs_gap, numeric_rows$sd_reference, numeric_rows$sd_candidate)
    numeric_rows$max_abs_gap <- mapply(safe_abs_gap, numeric_rows$max_abs_reference, numeric_rows$max_abs_candidate)
    numeric_rows$mean_equal_3dp <- mapply(value_equal_at_digits, numeric_rows$mean_reference, numeric_rows$mean_candidate, MoreArgs = list(digits = 3))
    numeric_rows$mean_equal_4dp <- mapply(value_equal_at_digits, numeric_rows$mean_reference, numeric_rows$mean_candidate, MoreArgs = list(digits = 4))
    numeric_rows$sd_equal_3dp <- mapply(value_equal_at_digits, numeric_rows$sd_reference, numeric_rows$sd_candidate, MoreArgs = list(digits = 3))
    numeric_rows$sd_equal_4dp <- mapply(value_equal_at_digits, numeric_rows$sd_reference, numeric_rows$sd_candidate, MoreArgs = list(digits = 4))
    numeric_rows$max_abs_equal_3dp <- mapply(value_equal_at_digits, numeric_rows$max_abs_reference, numeric_rows$max_abs_candidate, MoreArgs = list(digits = 3))
    numeric_rows$max_abs_equal_4dp <- mapply(value_equal_at_digits, numeric_rows$max_abs_reference, numeric_rows$max_abs_candidate, MoreArgs = list(digits = 4))
  }

  list(structure = merged, numeric = numeric_rows)
}

summarise_signature_comparison <- function(signature_comparison) {
  numeric_rows <- signature_comparison$numeric
  structure_rows <- signature_comparison$structure

  data.frame(
    missing_paths = sum(structure_rows$missing_reference | structure_rows$missing_candidate),
    class_mismatches = sum(!(structure_rows$class_match %in% TRUE), na.rm = TRUE),
    length_mismatches = sum(!(structure_rows$length_match %in% TRUE), na.rm = TRUE),
    dims_mismatches = sum(!(structure_rows$dims_match %in% TRUE), na.rm = TRUE),
    max_mean_abs_gap = if (nrow(numeric_rows) > 0) max(numeric_rows$mean_abs_gap) else 0,
    max_sd_abs_gap = if (nrow(numeric_rows) > 0) max(numeric_rows$sd_abs_gap) else 0,
    max_max_abs_gap = if (nrow(numeric_rows) > 0) max(numeric_rows$max_abs_gap) else 0,
    mean_equal_3dp = if (nrow(numeric_rows) > 0) all(numeric_rows$mean_equal_3dp) else TRUE,
    mean_equal_4dp = if (nrow(numeric_rows) > 0) all(numeric_rows$mean_equal_4dp) else TRUE,
    sd_equal_3dp = if (nrow(numeric_rows) > 0) all(numeric_rows$sd_equal_3dp) else TRUE,
    sd_equal_4dp = if (nrow(numeric_rows) > 0) all(numeric_rows$sd_equal_4dp) else TRUE,
    max_abs_equal_3dp = if (nrow(numeric_rows) > 0) all(numeric_rows$max_abs_equal_3dp) else TRUE,
    max_abs_equal_4dp = if (nrow(numeric_rows) > 0) all(numeric_rows$max_abs_equal_4dp) else TRUE,
    stringsAsFactors = FALSE
  )
}

write_session_info_report <- function(filepath) {
  lines <- capture.output(utils::sessionInfo())
  writeLines(lines, filepath)
}

write_kernel_validation_report <- function(report_dir, details, reference_elapsed, candidate_elapsed, seeds) {
  write_csv_report(details$gamma, file.path(report_dir, "gamma_mean_details.csv"))
  write_csv_report(details$lambda, file.path(report_dir, "lambda_mean_details.csv"))
  write_csv_report(details$bma_sdf, file.path(report_dir, "bma_sdf_details.csv"))
  write_csv_report(details$gamma_summary, file.path(report_dir, "gamma_mean_summary.csv"))
  write_csv_report(details$lambda_summary, file.path(report_dir, "lambda_mean_summary.csv"))
  write_csv_report(details$bma_sdf_summary, file.path(report_dir, "bma_sdf_summary.csv"))

  metadata <- data.frame(
    reference_elapsed = reference_elapsed,
    candidate_elapsed = candidate_elapsed,
    speedup = reference_elapsed / candidate_elapsed,
    seeds = paste(seeds, collapse = ","),
    stringsAsFactors = FALSE
  )
  write_csv_report(metadata, file.path(report_dir, "run_metadata.csv"))
  write_session_info_report(file.path(report_dir, "session_info.txt"))
}

write_runner_validation_report <- function(report_dir,
                                           result_details,
                                           signature_comparison,
                                           signature_summary,
                                           reference_elapsed,
                                           candidate_elapsed) {
  write_csv_report(result_details$gamma, file.path(report_dir, "runner_gamma_mean_details.csv"))
  write_csv_report(result_details$lambda, file.path(report_dir, "runner_lambda_mean_details.csv"))
  write_csv_report(result_details$bma_sdf, file.path(report_dir, "runner_bma_sdf_details.csv"))
  write_csv_report(result_details$gamma_summary, file.path(report_dir, "runner_gamma_mean_summary.csv"))
  write_csv_report(result_details$lambda_summary, file.path(report_dir, "runner_lambda_mean_summary.csv"))
  write_csv_report(result_details$bma_sdf_summary, file.path(report_dir, "runner_bma_sdf_summary.csv"))
  write_csv_report(signature_comparison$structure, file.path(report_dir, "is_ap_structure_comparison.csv"))
  write_csv_report(signature_comparison$numeric, file.path(report_dir, "is_ap_numeric_signature_comparison.csv"))
  write_csv_report(signature_summary, file.path(report_dir, "is_ap_numeric_signature_summary.csv"))

  metadata <- data.frame(
    reference_elapsed = reference_elapsed,
    candidate_elapsed = candidate_elapsed,
    speedup = reference_elapsed / candidate_elapsed,
    stringsAsFactors = FALSE
  )
  write_csv_report(metadata, file.path(report_dir, "run_metadata.csv"))
  write_session_info_report(file.path(report_dir, "session_info.txt"))
}

collect_toolchain_status <- function() {
  has_pkgbuild <- requireNamespace("pkgbuild", quietly = TRUE)
  has_rcpp <- requireNamespace("Rcpp", quietly = TRUE)
  has_rcpp_armadillo <- requireNamespace("RcppArmadillo", quietly = TRUE)
  old_path <- Sys.getenv("PATH")

  if (.Platform$OS.type == "windows") {
    rtools_root <- "C:/rtools45"
    candidate_paths <- c(
      file.path(rtools_root, "usr", "bin"),
      file.path(rtools_root, "x86_64-w64-mingw32.static.posix", "bin")
    )
    existing_candidate_paths <- candidate_paths[dir.exists(candidate_paths)]
    if (length(existing_candidate_paths) > 0) {
      Sys.setenv(PATH = paste(c(existing_candidate_paths, old_path), collapse = .Platform$path.sep))
    }
  }

  on.exit(Sys.setenv(PATH = old_path), add = TRUE)

  make_path <- Sys.which("make")
  gcc_path <- Sys.which("gcc")
  gpp_path <- Sys.which("g++")

  pkgbuild_status <- if (has_pkgbuild) {
    tryCatch(
      suppressWarnings(pkgbuild::has_build_tools(debug = FALSE)),
      error = function(e) FALSE
    )
  } else {
    NA
  }

  compile_probe <- FALSE
  compile_message <- "Skipped compile probe."
  if (has_rcpp && nzchar(make_path)) {
    probe <- tryCatch({
      # Use a base-backed environment so the probe tests compilation, not missing
      # core language bindings.
      env <- new.env(parent = baseenv())
      Rcpp::cppFunction(
        code = "int add_ints(int x, int y) { return x + y; }",
        env = env
      )
      identical(env$add_ints(2L, 3L), 5L)
    }, error = function(e) {
      compile_message <<- conditionMessage(e)
      FALSE
    })
    compile_probe <- isTRUE(probe)
    if (compile_probe) {
      compile_message <- "Compile probe succeeded."
    }
  } else if (!has_rcpp) {
    compile_message <- "Rcpp is not installed."
  } else if (!nzchar(make_path)) {
    compile_message <- "No 'make' executable found on PATH."
  }

  data.frame(
    os = Sys.info()[["sysname"]],
    r_version = R.version.string,
    make_path = unname(make_path),
    gcc_path = unname(gcc_path),
    gpp_path = unname(gpp_path),
    has_pkgbuild = has_pkgbuild,
    has_build_tools = pkgbuild_status,
    has_rcpp = has_rcpp,
    has_rcpp_armadillo = has_rcpp_armadillo,
    compile_probe = compile_probe,
    compile_message = compile_message,
    stringsAsFactors = FALSE
  )
}

print_component_summary <- function(summary_df) {
  for (idx in seq_len(nrow(summary_df))) {
    row <- summary_df[idx, , drop = FALSE]
    cat(sprintf(
      "%s [%s] max_abs_gap=%.6f mean_abs_gap=%.6f equal_3dp=%s equal_4dp=%s\n",
      row$component,
      row$prior_label,
      row$max_abs_gap,
      row$mean_abs_gap,
      row$equal_3dp,
      row$equal_4dp
    ))
  }
}
