# Create w_all.rds — DR-tilt kappa weights for the treasury weighted model
#
# From Section 2.3 / Eq. (6): kappa > 0 tilts toward DR factors,
# kappa < 0 tilts toward CF factors. The weight vector assigns
# +1 to DR factors and -1 to CF factors (binary classification).
# Nontradable factors get 0 (no tilt).

decomp <- readRDS("data/variance_decomp_results_vuol.rds")
dr_factors <- decomp$factor_lists$DR_factors
cf_factors <- decomp$factor_lists$CF_factors

# Load factor names from data files
f1_names <- colnames(read.csv("data/nontraded.csv", check.names = FALSE)[, -1, drop = FALSE])
f2_bond <- colnames(read.csv("data/traded_bond_excess.csv", check.names = FALSE)[, -1, drop = FALSE])

# Treasury model uses f1 (nontraded) + f2 (bond factors only)
all_factors <- c(f1_names, f2_bond)

# Build weight vector: +1 for DR, -1 for CF, 0 for nontraded/unclassified
w_all <- setNames(numeric(length(all_factors)), all_factors)
w_all[names(w_all) %in% dr_factors] <- 1
w_all[names(w_all) %in% cf_factors] <- -1

cat("Total factors:", length(w_all), "\n")
cat("DR factors (w=+1):", sum(w_all == 1), "\n")
cat("CF factors (w=-1):", sum(w_all == -1), "\n")
cat("Neutral (w=0):", sum(w_all == 0), "\n")
cat("\nWeights:\n")
print(w_all)

# Save
dir.create("ia/data", recursive = TRUE, showWarnings = FALSE)
saveRDS(w_all, "ia/data/w_all.rds")
cat("\nSaved: ia/data/w_all.rds\n")
