cat("=== Test: no inv_sympd warnings ===\n")
source("code_base/continuous_ss_sdf_v2_fast.R")
load_continuous_ss_sdf_v2_fast_cpp(force_rebuild = FALSE)

source("code_base/validate_and_align_dates.R")
source("code_base/data_loading_helpers.R")

f1 <- as.matrix(read.csv("data/nontraded.csv", check.names = FALSE)[, -1, drop = FALSE])
f2_b <- as.matrix(read.csv("data/traded_bond_excess.csv", check.names = FALSE)[, -1, drop = FALSE])
f2_e <- as.matrix(read.csv("data/traded_equity.csv", check.names = FALSE)[, -1, drop = FALSE])
f2 <- cbind(f2_b, f2_e)
R <- as.matrix(read.csv("data/bond_insample_test_assets_50_excess.csv", check.names = FALSE)[, -1, drop = FALSE])

n <- min(nrow(f1), nrow(f2), nrow(R))
f1 <- f1[1:n, ]; f2 <- f2[1:n, ]; R <- R[1:n, ]

psi <- BayesianFactorZoo::psi_to_priorSR(cbind(R, f2), cbind(f1, f2), priorSR = 0.40 * 0.15)

cat(sprintf("Dims: T=%d, k1=%d, k2=%d, N=%d\n", n, ncol(f1), ncol(f2), ncol(R)))

# Capture warnings
set.seed(42)
result <- withCallingHandlers(
  continuous_ss_sdf_v2_fast(f1, f2, R, sim_length = 2000, psi0 = psi,
                             type = "GLS", intercept = TRUE, backend = "cpp"),
  warning = function(w) {
    cat("WARNING:", conditionMessage(w), "\n")
    invokeRestart("muffleWarning")
  }
)

cat(sprintf("Backend: %s\n", attr(result, "backend_used")))
cat("=== Done (check for WARNING lines above) ===\n")
