args <- commandArgs(trailingOnly = TRUE)
ndraws <- if (length(args) >= 1) as.integer(args[1]) else 50L
report_dir_arg <- if (length(args) >= 2) args[2] else NULL
runner_seed <- 234L

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
source(file.path(repo_root, "code_base", "run_bayesian_mcmc.R"))

report_dir <- build_report_dir("validate_unconditional_runner_fast", report_dir_arg)
inputs <- load_kernel_validation_inputs(repo_root)

run_runner_engine <- function(engine) {
  args <- default_runner_validation_args(repo_root, ndraws = ndraws, seed = runner_seed)
  args$self_pricing_engine <- engine

  result <- NULL
  timing <- system.time({
    result <- do.call(run_bayesian_mcmc, args)
  })

  list(
    result = result,
    elapsed = unname(timing[["elapsed"]])
  )
}

reference_self_check_one <- run_runner_engine("reference")
reference_self_check_two <- run_runner_engine("reference")
fast_run <- run_runner_engine("fast")
fast_self_check <- run_runner_engine("fast")

reference_signature_one <- collect_object_signature(reference_self_check_one$result$IS_AP, path = "IS_AP")
reference_signature_two <- collect_object_signature(reference_self_check_two$result$IS_AP, path = "IS_AP")
fast_signature_one <- collect_object_signature(fast_run$result$IS_AP, path = "IS_AP")
fast_signature_two <- collect_object_signature(fast_self_check$result$IS_AP, path = "IS_AP")

reference_self_details <- kernel_result_details(
  reference_results = reference_self_check_one$result$results,
  candidate_results = reference_self_check_two$result$results,
  inputs = inputs
)
fast_self_details <- kernel_result_details(
  reference_results = fast_run$result$results,
  candidate_results = fast_self_check$result$results,
  inputs = inputs
)

reference_signature_self <- compare_object_signatures(reference_signature_one, reference_signature_two)
fast_signature_self <- compare_object_signatures(fast_signature_one, fast_signature_two)
reference_signature_self_summary <- summarise_signature_comparison(reference_signature_self)
fast_signature_self_summary <- summarise_signature_comparison(fast_signature_self)

reference_self_check_pass <- all(reference_self_details$gamma_summary$equal_4dp) &&
  all(reference_self_details$lambda_summary$equal_4dp) &&
  all(reference_self_details$bma_sdf_summary$equal_4dp) &&
  reference_signature_self_summary$missing_paths == 0 &&
  reference_signature_self_summary$class_mismatches == 0 &&
  reference_signature_self_summary$length_mismatches == 0 &&
  reference_signature_self_summary$dims_mismatches == 0 &&
  reference_signature_self_summary$mean_equal_4dp &&
  reference_signature_self_summary$sd_equal_4dp &&
  reference_signature_self_summary$max_abs_equal_4dp

fast_self_check_pass <- all(fast_self_details$gamma_summary$equal_4dp) &&
  all(fast_self_details$lambda_summary$equal_4dp) &&
  all(fast_self_details$bma_sdf_summary$equal_4dp) &&
  fast_signature_self_summary$missing_paths == 0 &&
  fast_signature_self_summary$class_mismatches == 0 &&
  fast_signature_self_summary$length_mismatches == 0 &&
  fast_signature_self_summary$dims_mismatches == 0 &&
  fast_signature_self_summary$mean_equal_4dp &&
  fast_signature_self_summary$sd_equal_4dp &&
  fast_signature_self_summary$max_abs_equal_4dp

if (!reference_self_check_pass) {
  stop("Reference runner self-check failed: repeated runs with the same seed did not reproduce the same 4-decimal summaries.", call. = FALSE)
}

if (!fast_self_check_pass) {
  stop("Fast runner self-check failed: repeated runs with the same seed did not reproduce the same 4-decimal summaries.", call. = FALSE)
}

result_details <- kernel_result_details(
  reference_results = reference_self_check_one$result$results,
  candidate_results = fast_run$result$results,
  inputs = inputs
)

signature_comparison <- compare_object_signatures(reference_signature_one, fast_signature_one)
signature_summary <- summarise_signature_comparison(signature_comparison)

write_runner_validation_report(
  report_dir = report_dir,
  result_details = result_details,
  signature_comparison = signature_comparison,
  signature_summary = signature_summary,
  reference_elapsed = reference_self_check_one$elapsed,
  candidate_elapsed = fast_run$elapsed
)

validation_status <- data.frame(
  reference_self_check_pass_4dp = reference_self_check_pass,
  fast_self_check_pass_4dp = fast_self_check_pass,
  gamma_pass_3dp = all(result_details$gamma_summary$equal_3dp),
  lambda_pass_3dp = all(result_details$lambda_summary$equal_3dp),
  bma_sdf_pass_3dp = all(result_details$bma_sdf_summary$equal_3dp),
  gamma_pass_4dp = all(result_details$gamma_summary$equal_4dp),
  lambda_pass_4dp = all(result_details$lambda_summary$equal_4dp),
  bma_sdf_pass_4dp = all(result_details$bma_sdf_summary$equal_4dp),
  signature_pass_3dp = signature_summary$missing_paths == 0 &&
    signature_summary$class_mismatches == 0 &&
    signature_summary$length_mismatches == 0 &&
    signature_summary$dims_mismatches == 0 &&
    signature_summary$mean_equal_3dp &&
    signature_summary$sd_equal_3dp &&
    signature_summary$max_abs_equal_3dp,
  signature_pass_4dp = signature_summary$missing_paths == 0 &&
    signature_summary$class_mismatches == 0 &&
    signature_summary$length_mismatches == 0 &&
    signature_summary$dims_mismatches == 0 &&
    signature_summary$mean_equal_4dp &&
    signature_summary$sd_equal_4dp &&
    signature_summary$max_abs_equal_4dp,
  stringsAsFactors = FALSE
)
write_csv_report(validation_status, file.path(report_dir, "validation_status.csv"))

cat(sprintf("Runner validation report: %s\n", report_dir))
cat(sprintf("Draws: %d | Seed: %d\n", ndraws, runner_seed))
cat(sprintf("Reference self-check pass at 4dp: %s\n", reference_self_check_pass))
cat(sprintf("Fast self-check pass at 4dp: %s\n", fast_self_check_pass))
cat(sprintf(
  "Reference elapsed: %.3fs | Fast elapsed: %.3fs | Speedup: %.2fx\n",
  reference_self_check_one$elapsed,
  fast_run$elapsed,
  reference_self_check_one$elapsed / fast_run$elapsed
))
cat(sprintf(
  "IS_AP structure: missing=%d class_mismatch=%d length_mismatch=%d dims_mismatch=%d max_mean_gap=%.6f max_sd_gap=%.6f max_max_abs_gap=%.6f\n",
  signature_summary$missing_paths,
  signature_summary$class_mismatches,
  signature_summary$length_mismatches,
  signature_summary$dims_mismatches,
  signature_summary$max_mean_abs_gap,
  signature_summary$max_sd_abs_gap,
  signature_summary$max_max_abs_gap
))
print_component_summary(result_details$gamma_summary)
print_component_summary(result_details$lambda_summary)
print_component_summary(result_details$bma_sdf_summary)

if (!validation_status$gamma_pass_3dp) {
  stop("Runner validation failed: gamma posterior means do not match at 3 decimals.", call. = FALSE)
}

if (!validation_status$lambda_pass_3dp) {
  stop("Runner validation failed: lambda posterior means do not match at 3 decimals.", call. = FALSE)
}

if (!validation_status$bma_sdf_pass_3dp) {
  stop("Runner validation failed: BMA-SDF does not match at 3 decimals.", call. = FALSE)
}

if (!validation_status$signature_pass_3dp) {
  stop("Runner validation failed: IS_AP structure or numeric signature does not match at 3 decimals.", call. = FALSE)
}

cat("PASS runner validation at 3 decimals.\n")
