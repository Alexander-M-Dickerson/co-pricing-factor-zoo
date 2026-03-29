args <- commandArgs(trailingOnly = TRUE)
ndraws <- if (length(args) >= 1) as.integer(args[1]) else 500L
report_dir_arg <- if (length(args) >= 2) args[2] else NULL
seed_base <- 1000L

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) == 0) {
    return(normalizePath(getwd(), winslash = "/", mustWork = TRUE))
  }

  normalizePath(dirname(sub("^--file=", "", file_arg[1])), winslash = "/", mustWork = TRUE)
}

repo_root <- normalizePath(file.path(get_script_dir(), ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "testing", "validation_helpers.R"))
repo_root <- get_testing_repo_root()
load_validation_sources(repo_root)

report_dir <- build_report_dir("benchmark_continuous_ss_sdf_v2", report_dir_arg)
inputs <- load_kernel_validation_inputs(repo_root)

cpp_available <- load_continuous_ss_sdf_v2_fast_cpp()
cpp_error <- continuous_ss_sdf_v2_fast_cpp_error()

engines <- list(
  reference = BayesianFactorZoo::continuous_ss_sdf_v2,
  fast_r = continuous_ss_sdf_v2_fast_r
)

if (cpp_available) {
  engines$fast_cpp <- function(...) {
    continuous_ss_sdf_v2_fast_cpp(..., force_rebuild = FALSE)
  }
}

benchmark_results <- list()
for (engine_name in names(engines)) {
  engine_run <- run_seeded_kernel_engine(
    engine_fn = engines[[engine_name]],
    inputs = inputs,
    ndraws = ndraws,
    seed_base = seed_base
  )

  backend_used <- attr(engine_run$result[[1]], "backend_used")
  if (is.null(backend_used)) {
    backend_used <- engine_name
  }

  details <- if (!identical(engine_name, "reference")) {
    kernel_result_details(
      reference_results = benchmark_results$reference$result,
      candidate_results = engine_run$result,
      inputs = inputs
    )
  } else {
    NULL
  }

  benchmark_results[[engine_name]] <- list(
    name = engine_name,
    elapsed = engine_run$elapsed,
    backend_used = backend_used,
    result = engine_run$result,
    details = details
  )
}

reference_elapsed <- benchmark_results$reference$elapsed

summary_rows <- lapply(benchmark_results, function(run) {
  max_gamma_gap <- if (is.null(run$details)) 0 else max(run$details$gamma_summary$max_abs_gap)
  max_lambda_gap <- if (is.null(run$details)) 0 else max(run$details$lambda_summary$max_abs_gap)
  max_bma_gap <- if (is.null(run$details)) 0 else max(run$details$bma_sdf_summary$max_abs_gap)

  data.frame(
    engine = run$name,
    backend_used = run$backend_used,
    elapsed = run$elapsed,
    speedup_vs_reference = reference_elapsed / run$elapsed,
    max_gamma_mean_abs_gap = max_gamma_gap,
    max_lambda_mean_abs_gap = max_lambda_gap,
    max_bma_sdf_abs_gap = max_bma_gap,
    stringsAsFactors = FALSE
  )
})

summary_df <- do.call(rbind, summary_rows)
write_csv_report(summary_df, file.path(report_dir, "benchmark_summary.csv"))
write_csv_report(
  data.frame(
    cpp_available = cpp_available,
    cpp_error = cpp_error %||% "",
    ndraws = ndraws,
    seeds = paste(seed_base + seq_along(inputs$psi_grid), collapse = ","),
    stringsAsFactors = FALSE
  ),
  file.path(report_dir, "benchmark_metadata.csv")
)
write_session_info_report(file.path(report_dir, "session_info.txt"))

for (run in benchmark_results[names(benchmark_results) != "reference"]) {
  write_csv_report(
    run$details$gamma_summary,
    file.path(report_dir, sprintf("%s_gamma_mean_summary.csv", run$name))
  )
  write_csv_report(
    run$details$lambda_summary,
    file.path(report_dir, sprintf("%s_lambda_mean_summary.csv", run$name))
  )
  write_csv_report(
    run$details$bma_sdf_summary,
    file.path(report_dir, sprintf("%s_bma_sdf_summary.csv", run$name))
  )
}

cat(sprintf("Benchmark report: %s\n", report_dir))
cat(sprintf("Draws: %d\n", ndraws))
cat(sprintf("C++ available: %s\n", cpp_available))
if (!cpp_available && nzchar(cpp_error %||% "")) {
  cat(sprintf("C++ error: %s\n", cpp_error))
}
print(summary_df, row.names = FALSE)
