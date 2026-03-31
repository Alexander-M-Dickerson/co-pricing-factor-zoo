cat("=== Rebuilding both C++ kernels ===\n")

cat("1. Self-pricing (v2)...\n")
source("code_base/continuous_ss_sdf_v2_fast.R")
ok1 <- load_continuous_ss_sdf_v2_fast_cpp(force_rebuild = TRUE)
cat("   Compiled:", ok1, "\n")
if (!ok1) cat("   Error:", continuous_ss_sdf_v2_fast_cpp_error(), "\n")

cat("2. No-SP (treasury)...\n")
source("code_base/continuous_ss_sdf_fast.R")
ok2 <- load_continuous_ss_sdf_fast_cpp(force_rebuild = TRUE)
cat("   Compiled:", ok2, "\n")
if (!ok2) cat("   Error:", continuous_ss_sdf_fast_cpp_error(), "\n")

if (ok1 && ok2) {
  cat("\n=== Both kernels compiled OK ===\n")
} else {
  stop("Compilation failed", call. = FALSE)
}
