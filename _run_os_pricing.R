# Load workspace
load("output/unconditional/bond_stock_with_sp/excess_bond_stock_with_sp_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata")
source("code_base/outsample_asset_pricing.R")
source("code_base/validate_and_align_dates.R")

# Prepare OOS data (with date column!)
Rb <- read.csv("data/bond_oosample_all_excess.csv", check.names = FALSE)
Rs <- read.csv("data/equity_os_77.csv", check.names = FALSE)[-1]
R_oos_data <- cbind(Rb,Rs)


# Run OOS pricing
oos_metrics <- os_asset_pricing(
  R_oss = R_oos_data,
  IS_AP = IS_AP,
  f1 = data_list$f1,
  f2 = data_list$f2,
  fac_freq = data_list$fac_freq,
  frequentist_models = frequentist_models,
  kns_out = kns_out,
  rp_out = rp_out,
  pca_out = pca_out,
  intercept = intercept,
  date_start = "1986-01-31",
  verbose = TRUE
)

print( oos_metrics )
