###############################################################################
## _run_paper_conditional_results.R
##
## Generate Figure 7 and Table 6 Panel B from conditional model results.
## This is a slimmed-down version of _run_eval_conditional_perf.R that only
## produces the paper outputs: fig7_oos_cumret.pdf and table_6_panel_b_trading.tex
###############################################################################

cat("\n")
cat("========================================\n")
cat("PAPER RESULTS: CONDITIONAL MODEL\n")
cat("========================================\n\n")

gc()

###############################################################################
## 1. CONFIGURATION
###############################################################################

#### 1.1 Results Location -----------------------------------------------------
# Root path where time-varying results are saved
output_root    <- "C:/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo/output/time_varying" 

#### 1.2 Path Override --------------------------------------------------------
# When TRUE, use the paths below instead of those stored in the metadata.
# This is useful when running on a different machine than where estimation ran.
path_override  <- TRUE

# These paths are ONLY used when path_override = TRUE
override_main_path     <- "C:/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo"
override_data_folder   <- "C:/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo/data"
override_code_folder   <- "C:/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo/code_base"
override_output_folder <- "C:/Users/ASUS/Documents/GitHub/co-pricing-factor-zoo/output"

#### 1.3 Model Specification --------------------------------------------------
# These parameters identify which results file to load
return_type    <- "excess"              # "excess" or "duration"
model_type     <- "bond_stock_with_sp"  # "bond", "stock", "bond_stock_with_sp"
tag            <- "ExpandingForward"    # Tag used during estimation
holding_period <- 12                    # Holding period in months
f1_flag        <- TRUE                  # TRUE if f1 was used, FALSE otherwise
alpha.w        <- 1                     # Alpha hyperparameter
beta.w         <- 1                     # Beta hyperparameter

#### 1.4 Performance Evaluation Options ---------------------------------------
# Volatility scaling: scale all portfolios to match this model's volatility
# Set to NULL for no scaling
vol_scale      <- "MKTS"                # "MKTS", "EqualWeight", or NULL

#### 1.5 Figure 7 Options -----------------------------------------------------
# Portfolios to include in cumulative return plot
factor_vec     <- c("BMA-80%", "KNS", "RP-PCA", "EqualWeight", "MKTB", "MKTS")

# Colors for each portfolio (must match factor_vec order)
color_vec      <- c("red", "#66C2A5", "black", "lightblue", "royalblue4", "purple")

# Line types for each portfolio (must match factor_vec order)
line_types_vec <- c("solid", "solid", "solid", "dashed", "dashed", "dashed")

# Legend position (x, y) where 0,0 is bottom-left and 1,1 is top-right
legend_position <- c(0.02, 0.98)

# Y-axis dollar spacing for cumulative return plot
dollar_step    <- 50

# Figure output settings
fig_width      <- 12
fig_height     <- 7

###############################################################################
## 2. BUILD RESULTS FILE PATH
###############################################################################

# Construct filename
results_filename <- sprintf(
  "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s_holding_period=%d_f1=%s_ALL_RESULTS.rds",
  return_type,
  model_type,
  trunc(alpha.w),
  trunc(beta.w),
  tag,
  holding_period,
  toupper(as.character(f1_flag))
)

# Full path: output_root / model_type / filename
results_file <- file.path(output_root, model_type, results_filename)

cat("Looking for results file:\n")
cat("  ", results_file, "\n\n")

###############################################################################
## 3. LOAD COMBINED RESULTS
###############################################################################

cat("Loading combined results...\n")

if (!file.exists(results_file)) {
  stop("Combined results file not found: ", results_file, "\n",
       "Please check your configuration parameters.")
}

combined_results <- readRDS(results_file)

cat("Combined results loaded successfully.\n\n")

###############################################################################
## 4. EXTRACT CONFIGURATION FROM METADATA
###############################################################################

cat("Extracting configuration from metadata...\n")

metadata <- combined_results$metadata

# Extract paths: use override if enabled, otherwise use metadata
if (path_override) {
  cat("  [PATH OVERRIDE ENABLED]\n")
  # Modify metadata$paths directly so downstream code sees overridden values
  metadata$paths$main_path     <- override_main_path
  metadata$paths$data_folder   <- override_data_folder
  metadata$paths$code_folder   <- override_code_folder
  metadata$paths$output_folder <- override_output_folder
}

# Now extract from (possibly modified) metadata
main_path     <- metadata$paths$main_path
data_folder   <- metadata$paths$data_folder
code_folder   <- metadata$paths$code_folder
output_folder <- metadata$paths$output_folder

# Extract data file names from metadata (these are filenames, not paths)
f2       <- metadata$data_files$f2
R        <- metadata$data_files$R
fac_freq <- metadata$data_files$fac_freq

cat("  Main path:    ", main_path, "\n")
cat("  Data folder:  ", data_folder, "\n")
cat("  Code folder:  ", code_folder, "\n")
cat("  Output folder:", output_folder, "\n")
cat("  Window type:  ", metadata$window_type, "\n")
cat("  Holding period: ", metadata$holding_period, " months\n")
cat("  Date range:   ", metadata$date_start, " to ", metadata$date_end, "\n")
cat("  Number of windows: ", metadata$n_windows_success, "\n\n")

###############################################################################
## 5. LOAD DEPENDENCIES
###############################################################################

cat("Loading dependencies...\n")

library(dplyr)
library(lubridate)
library(tidyr)

# Source helper functions
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))

# Source the paper-specific evaluation function
source(file.path(code_folder, "evaluate_performance_paper.R"))

# Source plotting library (for plot_cumret)
source(file.path(code_folder, "plot_portfolio_analytics.R"))

cat("Dependencies loaded.\n\n")

###############################################################################
## 6. RUN EVALUATE PERFORMANCE (PAPER VERSION)
###############################################################################

cat("Running evaluate_performance_paper()...\n\n")

t_start <- Sys.time()

results <- evaluate_performance_paper(
  combined_results = combined_results,
  main_path        = main_path,
  data_folder      = data_folder,
  f2               = f2,
  R                = R,
  fac_freq         = fac_freq,
  vol_scale        = vol_scale,
  factor_vec       = factor_vec,
  color_vec        = color_vec,
  line_types_vec   = line_types_vec,
  legend_position  = legend_position,
  dollar_step      = dollar_step,
  fig_width        = fig_width,
  fig_height       = fig_height,
  verbose          = TRUE
)

t_end <- Sys.time()

cat("\n")
cat("========================================\n")
cat("SUCCESS!\n")
cat("========================================\n\n")
cat("Computation time: ", round(difftime(t_end, t_start, units = "secs"), 2), " seconds\n\n")

###############################################################################
## 7. SUMMARY
###############################################################################

cat("========================================\n")
cat("OUTPUT FILES GENERATED\n")
cat("========================================\n\n")

figures_dir <- file.path(output_folder, "time_varying", model_type, "figures")
tables_dir  <- file.path(output_folder, "time_varying", model_type, "tables")

cat("Figure 7 saved to:\n")
cat("  ", file.path(figures_dir, "fig7_oos_cumret.pdf"), "\n\n")

cat("Table 6 Panel B saved to:\n")
cat("  ", file.path(tables_dir, "table_6_panel_b_trading.tex"), "\n\n")

cat("========================================\n")
cat("PAPER RESULTS COMPLETE\n")
cat("========================================\n\n")
