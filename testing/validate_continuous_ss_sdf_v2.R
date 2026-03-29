args <- commandArgs(trailingOnly = TRUE)
ndraws <- if (length(args) >= 1) as.integer(args[1]) else 50L
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

report_dir <- build_report_dir("validate_continuous_ss_sdf_v2", report_dir_arg)
inputs <- load_kernel_validation_inputs(repo_root)

reference_self_check_one <- run_seeded_kernel_engine(
  BayesianFactorZoo::continuous_ss_sdf_v2,
  inputs,
  ndraws = ndraws,
  seed_base = seed_base
)
reference_self_check_two <- run_seeded_kernel_engine(
  BayesianFactorZoo::continuous_ss_sdf_v2,
  inputs,
  ndraws = ndraws,
  seed_base = seed_base
)
fast_run <- run_seeded_kernel_engine(
  continuous_ss_sdf_v2_fast,
  inputs,
  ndraws = ndraws,
  seed_base = seed_base
)
fast_self_check <- run_seeded_kernel_engine(
  continuous_ss_sdf_v2_fast,
  inputs,
  ndraws = ndraws,
  seed_base = seed_base
)

reference_identical <- identical(reference_self_check_one$result, reference_self_check_two$result)
fast_identical <- identical(fast_run$result, fast_self_check$result)

if (!reference_identical) {
  stop("Reference self-check failed: identical seeds did not reproduce identical kernel outputs.", call. = FALSE)
}

if (!fast_identical) {
  stop("Fast self-check failed: identical seeds did not reproduce identical kernel outputs.", call. = FALSE)
}

details <- kernel_result_details(
  reference_results = reference_self_check_one$result,
  candidate_results = fast_run$result,
  inputs = inputs
)

write_kernel_validation_report(
  report_dir = report_dir,
  details = details,
  reference_elapsed = reference_self_check_one$elapsed,
  candidate_elapsed = fast_run$elapsed,
  seeds = reference_self_check_one$seeds
)

validation_status <- data.frame(
  reference_self_check_identical = reference_identical,
  fast_self_check_identical = fast_identical,
  gamma_pass_3dp = all(details$gamma_summary$equal_3dp),
  lambda_pass_3dp = all(details$lambda_summary$equal_3dp),
  bma_sdf_pass_3dp = all(details$bma_sdf_summary$equal_3dp),
  gamma_pass_4dp = all(details$gamma_summary$equal_4dp),
  lambda_pass_4dp = all(details$lambda_summary$equal_4dp),
  bma_sdf_pass_4dp = all(details$bma_sdf_summary$equal_4dp),
  stringsAsFactors = FALSE
)
write_csv_report(validation_status, file.path(report_dir, "validation_status.csv"))

cat(sprintf("Kernel validation report: %s\n", report_dir))
cat(sprintf("Draws: %d\n", ndraws))
cat(sprintf("Seeds: %s\n", paste(reference_self_check_one$seeds, collapse = ",")))
cat(sprintf("Reference self-check identical: %s\n", reference_identical))
cat(sprintf("Fast self-check identical: %s\n", fast_identical))
cat(sprintf(
  "Reference elapsed: %.3fs | Fast elapsed: %.3fs | Speedup: %.2fx\n",
  reference_self_check_one$elapsed,
  fast_run$elapsed,
  reference_self_check_one$elapsed / fast_run$elapsed
))
print_component_summary(details$gamma_summary)
print_component_summary(details$lambda_summary)
print_component_summary(details$bma_sdf_summary)

if (!validation_status$gamma_pass_3dp) {
  stop("Kernel validation failed: gamma posterior means do not match at 3 decimals.", call. = FALSE)
}

if (!validation_status$lambda_pass_3dp) {
  stop("Kernel validation failed: lambda posterior means do not match at 3 decimals.", call. = FALSE)
}

if (!validation_status$bma_sdf_pass_3dp) {
  stop("Kernel validation failed: BMA-SDF does not match at 3 decimals.", call. = FALSE)
}

cat("PASS kernel validation at 3 decimals.\n")
