###############################################################################
## _run_paper_results.R - Generate Tables and Figures for Academic Paper
## ---------------------------------------------------------------------------
##
## This script loads pre-computed MCMC results and generates all tables and
## figures for the paper. It is designed to be extensible - add new tables
## and figures in the designated sections below.
##
## WORKFLOW:
##   1. Configure paths and model settings in Section 1
##   2. The script constructs the .Rdata filename and loads it
##   3. Tables and figures are generated in Sections 3+
##   4. Outputs are saved to the specified output folder
##
## NAMING CONVENTION for .Rdata files:
##   {return_type}_{model_type}_alpha.w={alpha.w}_beta.w={beta.w}_kappa={kappa}_{tag}.Rdata
##   Example: excess_bond_stock_with_sp_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata
##
###############################################################################

gc()

###############################################################################
## SECTION 1: USER CONFIGURATION
###############################################################################

#### 1.1 Paths ----------------------------------------------------------------
# Main path to results folder containing .Rdata files
results_path   <- "output/unconditional"

# Project root (for sourcing helper functions)
project_root   <- getwd()

# Output folder for generated tables and figures
paper_output   <- "output/paper"

# Code folder containing helper functions
code_folder    <- "code_base"

# Data folder (for intermediate results like variance decomposition)
data_folder    <- "data"

#### 1.2 Model Configuration --------------------------------------------------
# These parameters determine which .Rdata file to load
model_type     <- "bond_stock_with_sp"   # Options: "bond", "stock", "bond_stock_with_sp", "treasury"
return_type    <- "excess"               # Options: "excess", "duration"
tag            <- "baseline"             # Label used when running MCMC
alpha.w        <- 1                      # Beta prior hyperparameter
beta.w         <- 1                      # Beta prior hyperparameter
kappa          <- 0                      # Factor tilt (0 = no tilt)

#### 1.3 Output Options -------------------------------------------------------
save_tables    <- TRUE                   # Save tables to CSV/LaTeX?
save_figures   <- TRUE                   # Save figures to PDF/PNG?
figure_format  <- "pdf"                  # Options: "pdf", "png", "both"
table_format   <- "both"                 # Options: "csv", "latex", "both"
verbose        <- TRUE                   # Print progress messages?

###############################################################################
## SECTION 2: SETUP AND DATA LOADING
###############################################################################

#### 2.1 Create Output Directories --------------------------------------------
if (!dir.exists(paper_output)) {
  dir.create(paper_output, recursive = TRUE)
  if (verbose) message("Created output directory: ", paper_output)
}

tables_dir <- file.path(paper_output, "tables")
figures_dir <- file.path(paper_output, "figures")

if (save_tables && !dir.exists(tables_dir)) {
  dir.create(tables_dir, recursive = TRUE)
}

if (save_figures && !dir.exists(figures_dir)) {
  dir.create(figures_dir, recursive = TRUE)
}

#### 2.2 Source Helper Functions ----------------------------------------------
if (verbose) message("Sourcing helper functions...")

# Source all required helper files from code_base
# Add new helper sources here as needed
helper_files <- c(
  "pp_figure_table.R",
  "plot_nfac_sr.R",
  "pp_bar_plots.R",
  "sr_decomposition.R",
  "run_sr_decomposition_multi.R",
  "sr_tables.R",
  "validate_and_align_dates.R",
  "outsample_asset_pricing.R",
  "pricing_tables.R",
  "thousands_outsample_tests.R",
  "plot_thousands_oos_densities.R",
  "plot_mean_vs_cov.R",
  "fit_sdf_models.R",
  "trading_table.R",
  "expanding_runs_plots.R"
  # Add more helper files as needed
)

for (helper in helper_files) {
  helper_path <- file.path(code_folder, helper)
  if (file.exists(helper_path)) {
    source(helper_path)
    if (verbose) message("  Sourced: ", helper)
  } else {
    warning("Helper file not found: ", helper_path)
  }
}

#### 2.3 Construct Filename and Load Data -------------------------------------
# Build the .Rdata filename based on configuration
rdata_filename <- sprintf(
  "%s_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s.Rdata",
  return_type,
  model_type,
  alpha.w,
  beta.w,
  kappa,
  tag
)

# Full path to the .Rdata file
rdata_path <- file.path(results_path, model_type, rdata_filename)

if (verbose) {
  message("\n", strrep("=", 60))
  message("LOADING RESULTS")
  message(strrep("=", 60))
  message("Looking for: ", rdata_path)
}

# Check if file exists
if (!file.exists(rdata_path)) {
  stop(
    "Results file not found: ", rdata_path, "\n",
    "Please check:\n",
    "  1. results_path is correct\n",
    "  2. Model configuration matches the MCMC run\n",
    "  3. The MCMC estimation has been completed"
  )
}

# Save user configuration before loading (load() may overwrite these variables)
cfg_model_type  <- model_type
cfg_return_type <- return_type
cfg_tag         <- tag
cfg_alpha.w     <- alpha.w
cfg_beta.w      <- beta.w
cfg_kappa       <- kappa

# Load the .Rdata file
load(rdata_path)

# Restore user configuration (in case load() overwrote them)
model_type  <- cfg_model_type
return_type <- cfg_return_type
tag         <- cfg_tag
alpha.w     <- cfg_alpha.w
beta.w      <- cfg_beta.w
kappa       <- cfg_kappa

# CRITICAL: Verify configuration was restored correctly
if (verbose) {
  message("\n*** CONFIGURATION VERIFICATION ***")
  message("  model_type  = '", model_type, "'")
  message("  return_type = '", return_type, "'")
  message("  tag         = '", tag, "'")
  message("**********************************\n")
}

# ENFORCE: Figures 2-4 require bond_stock_with_sp model
if (model_type != "bond_stock_with_sp") {
  warning("WARNING: model_type is '", model_type, "' but expected 'bond_stock_with_sp' for main paper figures!")
}

if (verbose) {
  message("Successfully loaded: ", rdata_filename)
  message("Objects loaded: ", paste(ls(), collapse = ", "))
  message(strrep("=", 60), "\n")
}

#### 2.4 Validate Required Objects --------------------------------------------
# List of objects expected from the .Rdata file
# Add to this list as you discover what's needed
required_objects <- c(
  "results",      # MCMC results list (for pp_figure_table)
  "f1",           # Non-traded factors matrix
  "f2",           # Traded factors matrix (may be NULL for treasury)
  "intercept"     # Whether intercept was included
  # "IS_AP",      # In-sample asset pricing results
  # "metadata"    # Run metadata
)

missing_objects <- required_objects[!required_objects %in% ls()]
if (length(missing_objects) > 0) {
  warning(
    "Some expected objects are missing from the loaded data:\n  ",
    paste(missing_objects, collapse = ", "),
    "\nSome tables/figures may fail to generate."
  )
}

# Print summary of loaded data
if (verbose) {
  message("\nData summary:")
  if (exists("f1")) message("  f1: ", nrow(f1), " obs x ", ncol(f1), " factors")
  if (exists("f2") && !is.null(f2)) message("  f2: ", nrow(f2), " obs x ", ncol(f2), " factors")
  if (exists("results")) message("  results: ", length(results), " prior specifications")
}


###############################################################################
## SECTION 2.5: INTERMEDIATE DATA GENERATION
###############################################################################
# Generate intermediate results needed for multiple tables.
# These are computed once and saved to data/ for reuse.

if (verbose) {

  message("\n", strrep("=", 60))
  message("GENERATING INTERMEDIATE DATA")
  message(strrep("=", 60), "\n")
}

#### SR Decomposition (for Tables 1, 4, 5) ------------------------------------
# Runs sr_decomposition() across all model types and saves combined results.
# Required for: Table 1 (Top 5 factors), Table 4 (SR by factor type),
#               Table 5 (DR vs CF decomposition)

# Check if cached results exist
sr_decomp_file <- file.path(data_folder, "sr_decomposition_results.rds")
regenerate_sr_decomp <- FALSE  # Set to TRUE to force re-estimation

if (file.exists(sr_decomp_file) && !regenerate_sr_decomp) {
  if (verbose) message("SR Decomposition: Loading cached results from ", sr_decomp_file)
  res_tbl_top <- readRDS(sr_decomp_file)
} else {
  if (verbose) message("SR Decomposition: Computing for all model types...")
  # Run SR decomposition across all model types
  res_tbl_top <- run_sr_decomposition_multi(
    results_path  = results_path,
    data_path     = data_folder,
    model_types   = c("bond_stock_with_sp", "stock", "bond"),
    return_type   = return_type,
    alpha.w       = alpha.w,
    beta.w        = beta.w,
    kappa         = kappa,
    tag           = tag,
    top_factors   = 5,
    prior_labels  = c("20%", "40%", "60%", "80%"),
    save_output   = TRUE,
    output_path   = data_folder,
    output_name   = "sr_decomposition_results.rds",
    verbose       = verbose
  )
}

if (verbose && !is.null(res_tbl_top)) {
  message("  SR decomposition results available for: ",
          paste(names(res_tbl_top)[!sapply(res_tbl_top, is.null)], collapse = ", "))
}


#### Pricing Results (for Tables 2, 3) ----------------------------------------
# Collects IS and OS pricing results across all model types.
# Required for: Table 2 (IS pricing), Table 3 (OS pricing)

if (verbose) message("Pricing Results: Collecting for all model types...")

# Check if we should regenerate or use cached results
pricing_file <- file.path(data_folder, "pricing_results.rds")
regenerate_pricing <- FALSE  # Set to TRUE to force re-computation (required after OOS fix)

if (file.exists(pricing_file) && !regenerate_pricing) {
  if (verbose) message("  Loading cached pricing results from ", pricing_file)
  pricing_results <- readRDS(pricing_file)
} else {
  if (verbose) message("  Computing pricing results (this may take a moment)...")
  # Run pricing collection across all model types
  pricing_results <- run_pricing_multi(
    results_path  = results_path,
    data_path     = data_folder,
    model_types   = c("bond_stock_with_sp", "stock", "bond"),
    return_type   = return_type,
    alpha.w       = alpha.w,
    beta.w        = beta.w,
    kappa         = kappa,
    tag           = tag,
    run_oos       = TRUE,
    save_output   = TRUE,
    output_path   = data_folder,
    output_name   = "pricing_results.rds",
    verbose       = verbose
  )
}

if (verbose && !is.null(pricing_results)) {
  message("  IS pricing available for: ",
          paste(names(pricing_results$is_results)[!sapply(pricing_results$is_results, is.null)], collapse = ", "))
  message("  OS pricing available for: ",
          paste(names(pricing_results$os_results)[!sapply(pricing_results$os_results, is.null)], collapse = ", "))
}


#### Thousands OOS Tests (for Figure 5) ----------------------------------------
# Runs OOS pricing across thousands of test asset subset combinations.
# Required for: Figure 5 (OOS pricing robustness across asset subsets)

if (verbose) message("\nThousands OOS Tests: Running subset combinations...")

# Check if cached results exist
thousands_oos_file <- file.path(data_folder, "thousands_oos_results.rds")
regenerate_thousands_oos <- FALSE  # Set to TRUE to force re-computation

if (file.exists(thousands_oos_file) && !regenerate_thousands_oos) {
  if (verbose) message("  Loading cached results from ", thousands_oos_file)
  thousands_oos_results <- readRDS(thousands_oos_file)
} else {
  if (verbose) message("  Computing thousands OOS tests (this may take several minutes)...")
  # Run thousands of OOS tests across all model types
  thousands_oos_results <- run_thousands_oos_tests(
    results_path   = results_path,
    data_path      = data_folder,
    model_types    = c("bond_stock_with_sp", "stock", "bond"),
    return_type    = return_type,
    alpha.w        = alpha.w,
    beta.w         = beta.w,
    kappa          = kappa,
    tag            = tag,
    intercept      = TRUE,
    bond_oos_file  = "bond_oosample_all_excess.csv",
    stock_oos_file = "equity_os_77.csv",
    n_cores        = max(1, parallel::detectCores() - 1),
    save_output    = TRUE,
    output_path    = data_folder,
    output_name    = "thousands_oos_results.rds",
    verbose        = verbose
  )
}

if (verbose && !is.null(thousands_oos_results)) {
  message("  Thousands OOS results available for: ",
          paste(names(thousands_oos_results)[!sapply(thousands_oos_results, is.null)], collapse = ", "))
}


#### Thousands OOS Tests - Duration Mode (for Figure 5) ------------------------
# Same as above but with duration-adjusted returns for bond models.
# bond_stock_with_sp and bond use duration .Rdata files
# stock uses excess .Rdata file (unchanged)
# Bond OOS file: bond_oosample_all_duration_tmt.csv

if (verbose) message("\nThousands OOS Tests (Duration): Running subset combinations...")

# Check if cached results exist
thousands_oos_dur_file <- file.path(data_folder, "thousands_oos_results_duration.rds")
regenerate_thousands_oos_dur <- FALSE  # Set to TRUE to force re-computation

if (file.exists(thousands_oos_dur_file) && !regenerate_thousands_oos_dur) {
  if (verbose) message("  Loading cached results from ", thousands_oos_dur_file)
  thousands_oos_results_duration <- readRDS(thousands_oos_dur_file)
} else {
  if (verbose) message("  Computing thousands OOS tests - duration mode (this may take several minutes)...")
  # Run thousands of OOS tests with duration-adjusted returns
  thousands_oos_results_duration <- run_thousands_oos_tests(
    results_path   = results_path,
    data_path      = data_folder,
    model_types    = c("bond_stock_with_sp", "stock", "bond"),
    return_type    = return_type,
    alpha.w        = alpha.w,
    beta.w         = beta.w,
    kappa          = kappa,
    tag            = tag,
    intercept      = TRUE,
    bond_oos_file  = "bond_oosample_all_excess.csv",
    stock_oos_file = "equity_os_77.csv",
    duration_mode  = TRUE,
    bond_oos_file_duration = "bond_oosample_all_duration_tmt.csv",
    n_cores        = max(1, parallel::detectCores() - 1),
    save_output    = TRUE,
    output_path    = data_folder,
    output_name    = "thousands_oos_results_duration.rds",
    verbose        = verbose
  )
}

if (verbose && !is.null(thousands_oos_results_duration)) {
  message("  Thousands OOS (duration) results available for: ",
          paste(names(thousands_oos_results_duration)[!sapply(thousands_oos_results_duration, is.null)], collapse = ", "))
}


###############################################################################
## SECTION 3: TABLES
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("GENERATING TABLES")
  message(strrep("=", 60), "\n")
}

#### Tables 1, 4, 5: SR Decomposition Tables ----------------------------------
# Generated using sr_tables.R functions:
#   - Table 1: Top 5 factor contributions to SDF
#   - Table 4: BMA-SDF dimensionality & SR by factor type
#   - Table 5: Discount rate vs cash-flow news
# Source: res_tbl_top from SR decomposition (Section 2.5)

if (!exists("res_tbl_top") || is.null(res_tbl_top)) {
  warning("res_tbl_top not available. Skipping Tables 1, 4, 5.")
} else {
  if (verbose) message("Tables 1, 4, 5: SR Decomposition Tables")

  # Generate all SR tables at once using the master function
  sr_table_results <- generate_sr_tables(
    res_tbl_top  = res_tbl_top,
    output_path  = tables_dir,
    tables       = c(1, 4, 5),
    verbose      = verbose
  )

  if (verbose) {
    message("  Generated: table_1_top5_factors.tex")
    message("  Generated: table_4_sr_by_factor_type.tex")
    message("  Generated: table_5_dr_vs_cf.tex")
  }
}


#### Tables 2, 3: IS and OS Pricing Tables ------------------------------------
# Generated using pricing_tables.R functions:
#   - Table 2: In-sample cross-sectional asset pricing performance
#   - Table 3: Out-of-sample cross-sectional asset pricing performance
# Source: pricing_results from pricing collection (Section 2.5)

if (!exists("pricing_results") || is.null(pricing_results)) {
  warning("pricing_results not available. Skipping Tables 2, 3.")
} else {
  if (verbose) message("Tables 2, 3: IS and OS Pricing Tables")

  # Generate both pricing tables at once
  pricing_table_results <- generate_pricing_tables(
    pricing_results = pricing_results,
    output_path     = tables_dir,
    tables          = c(2, 3),
    verbose         = verbose
  )

  if (verbose) {
    message("  Generated: table_2_is_pricing.tex")
    message("  Generated: table_3_os_pricing.tex")
  }
}


#### Table 6 Panel A: Trading Performance --------------------------------------
# Generated using trading_table.R:
#   - Table 6 Panel A: In-sample trading performance of SDF mimicking portfolios
# Computes: Mean, SR, IR, Skewness, Kurtosis
# All factors scaled to CAPM monthly volatility
# Source: IS_AP$sdf_mim from loaded .Rdata

if (verbose) message("Table 6 Panel A: Trading Performance")

if (!exists("IS_AP") || is.null(IS_AP$sdf_mim)) {
  warning("IS_AP$sdf_mim not available. Skipping Table 6 Panel A.")
} else {
  # Generate Table 6 Panel A
  table_6a_result <- generate_table_6_panel_a(
    IS_AP       = IS_AP,
    output_path = tables_dir,
    verbose     = verbose
  )

  if (verbose) {
    message("  Generated: table_6_panel_a_trading.csv")
    message("  Generated: table_6_panel_a_trading.tex")
  }
}


###############################################################################
## SECTION 4: FIGURES
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("GENERATING FIGURES")
  message(strrep("=", 60), "\n")
}

#### Figure 1: [Description] --------------------------------------------------
# TODO: Add Figure 1 generation code
# Source: code_base/[figure_script].R or inline

if (verbose) message("Figure 1: [Not yet implemented]")


#### Figure 2 + Table A.2: Posterior Probabilities ----------------------------
# Generates: Figure 2 (posterior probability plot) and Table A.2 (LaTeX table)
# Source: code_base/pp_figure_table.R

# ENFORCE: Use bond_stock_with_sp for Figure 2
fig2_model_type <- "bond_stock_with_sp"
if (verbose) {
  message("Figure 2 + Table A.2: Posterior Probabilities")
  message("  [ENFORCED] Using model_type = '", fig2_model_type, "'")
}

# Check that required objects exist from loaded .Rdata
if (!exists("results")) {
  warning("Object 'results' not found. Skipping Figure 2 / Table A.2.")
} else {
  # Call pp_figure_table() with metadata parameters
  # Note: f1, f2, intercept must exist in the environment (loaded from .Rdata)
  fig2_result <- pp_figure_table(
    results       = results,
    # Metadata for filenames
    return_type   = return_type,
    model_type    = fig2_model_type,  # ENFORCED: always bond_stock_with_sp
    tag           = tag,
    # Prior parameters (for prob_thresh calculation)
    alpha.w       = alpha.w,
    beta.w        = beta.w,
    # Output paths
    main_path     = paper_output,
    output_folder = "figures",
    table_folder  = "tables",
    # Display options
    verbose       = verbose
  )

  if (verbose) {
    message("  Figure saved: ", fig2_result$fig_file)
    message("  Table saved:  ", fig2_result$tex_file)
  }
}


#### Figure 3: Number of Factors & Sharpe Ratio Distributions -----------------
# Generates: Figure 3 (two-panel: posterior n_factors + SR distribution)
# Source: code_base/plot_nfac_sr.R

# ENFORCE: Use bond_stock_with_sp for Figure 3
fig3_model_type <- "bond_stock_with_sp"
if (verbose) {
  message("Figure 3: Number of Factors & Sharpe Ratio Distributions")
  message("  [ENFORCED] Using model_type = '", fig3_model_type, "'")
}

# Check that required objects exist from loaded .Rdata
if (!exists("results")) {
  warning("Object 'results' not found. Skipping Figure 3.")
} else if (is.null(results[[1]]$sdf_path)) {
  warning("results$sdf_path not found. Skipping Figure 3 (requires SDF tracking).")
} else {
  # Call plot_nfac_sr() with metadata parameters
  fig3_result <- plot_nfac_sr(
    results       = results,
    # Metadata for filenames
    return_type   = return_type,
    model_type    = fig3_model_type,  # ENFORCED: always bond_stock_with_sp
    tag           = tag,
    # Prior selection (use highest shrinkage by default)
    prior_labels  = c("20%", "40%", "60%", "80%"),
    prior_choice  = "80%",
    # Output paths
    main_path     = paper_output,
    output_folder = "figures",
    # Display options
    verbose       = verbose
  )

  if (verbose) {
    message("  Figure saved: ", fig3_result$fig_file)
    message("  Prior used: ", fig3_result$prior_used)
    message("  N factors [2.5%, 50%, 97.5%]: ",
            paste(round(fig3_result$n_factors_summary, 1), collapse = ", "))
    message("  SR [5%, 95%]: ",
            paste(round(fig3_result$sr_summary, 3), collapse = ", "))
  }
}


#### Figure 4: Posterior Probabilities & Market Prices of Risk ----------------
# Generates: Figure 4 (two-panel: posterior probabilities + risk prices)
# Panel A: Posterior inclusion probabilities for each factor
# Panel B: Posterior mean market prices of risk (annualized)
# Source: code_base/pp_bar_plots.R

# ENFORCE: Use bond_stock_with_sp for Figure 4
fig4_model_type <- "bond_stock_with_sp"
if (verbose) {
  message("Figure 4: Posterior Probabilities & Market Prices of Risk")
  message("  [ENFORCED] Using model_type = '", fig4_model_type, "'")
}

# Check that required objects exist from loaded .Rdata
if (!exists("results")) {
  warning("Object 'results' not found. Skipping Figure 4.")
} else {
  # Call pp_bar_plots() with metadata parameters
  # Note: f1, f2, nontraded_names, bond_names, stock_names must exist
  fig4_result <- pp_bar_plots(
    results       = results,
    # Metadata for filenames
    return_type   = return_type,
    model_type    = fig4_model_type,  # ENFORCED: always bond_stock_with_sp
    tag           = tag,
    # Prior selection (use highest shrinkage by default)
    prior_labels  = c("20%", "40%", "60%", "80%"),
    prior_choice  = "80%",
    # Output paths
    main_path     = paper_output,
    output_folder = "figures",
    # Display options
    verbose       = verbose
  )

  if (verbose) {
    message("  Figure saved: ", fig4_result$fig_file)
    message("  Prior used: ", fig4_result$prior_used)
    message("  Factor types: ", paste(names(fig4_result$factor_types),
                                       fig4_result$factor_types,
                                       sep = "=", collapse = ", "))
  }
}


#### Figure 5: Thousands OOS Pricing Tests (Excess Returns) -------------------
# Generates: Figure 5 (4 density plots for OOS pricing metrics)
#   fig5_1_gls.pdf  - R2GLS densities
#   fig5_2_ols.pdf  - R2OLS densities
#   fig5_3_rmse.pdf - RMSEdm densities
#   fig5_4_mape.pdf - MAPEdm densities
# Shows distribution of metrics across thousands of test asset subsets.
# Source: thousands_oos_results from Section 2.5

if (verbose) message("Figure 5: Thousands OOS Pricing Tests (Excess Returns)")

if (!exists("thousands_oos_results") || is.null(thousands_oos_results)) {
  warning("thousands_oos_results not available. Skipping Figure 5.")
} else {
  # Generate Figure 5 density plots
  fig5_result <- plot_thousands_oos_densities(
    thousands_oos_results = thousands_oos_results,
    model_col     = "BMA-80%",
    os_estim      = "co_pricing",
    output_path   = figures_dir,
    figure_prefix = "fig5",
    verbose       = verbose
  )

  if (verbose) {
    message("  Generated 4 density plots for Figure 5")
  }
}


#### Figure 8: Thousands OOS Pricing Tests (Duration-Adjusted) -----------------
# Generates: Figure 8 (4 density plots for OOS pricing metrics, duration-adjusted)
#   fig8_1_gls.pdf  - R2GLS densities
#   fig8_2_ols.pdf  - R2OLS densities
#   fig8_3_rmse.pdf - RMSEdm densities
#   fig8_4_mape.pdf - MAPEdm densities
# Same as Figure 5 but using duration-adjusted results.
# Source: thousands_oos_results_duration from Section 2.5

if (verbose) message("Figure 8: Thousands OOS Pricing Tests (Duration-Adjusted)")

if (!exists("thousands_oos_results_duration") || is.null(thousands_oos_results_duration)) {
  warning("thousands_oos_results_duration not available. Skipping Figure 8.")
} else {
  # Generate Figure 8 density plots
  fig8_result <- plot_thousands_oos_densities(
    thousands_oos_results = thousands_oos_results_duration,
    model_col     = "BMA-80%",
    os_estim      = "co_pricing",
    output_path   = figures_dir,
    figure_prefix = "fig8",
    force_left_annotations = TRUE,  # All annotations top-left for duration figures
    verbose       = verbose
  )

  if (verbose) {
    message("  Generated 4 density plots for Figure 8")
  }
}


#### Figure 9: Mean vs Covariance Diagnostic Plots (Treasury Model) -----------
# Generates: Figure 9 (4 scatter plots of E[R] vs -cov(M,R))
#   fig9_1_bond_is.pdf   - Bond treasury in-sample
#   fig9_2_bond_os.pdf   - Bond treasury out-of-sample
#   fig9_3_stock_is.pdf  - Stock treasury in-sample
#   fig9_4_stock_os.pdf  - Stock treasury out-of-sample
# Plots expected returns against SDF covariance to visualize pricing fit.
# Under correct specification, points should lie on the 45-degree line.
# Source: Treasury .Rdata files (bond_treasury and stock_treasury tags)

if (verbose) message("Figure 9: Mean vs Covariance Diagnostic Plots (Treasury Model)")

# Figure 9.1 & 9.2: Bond Treasury (IS & OS)
fig9_1_path <- file.path(figures_dir, "fig9_1_bond_is.pdf")
fig9_2_path <- file.path(figures_dir, "fig9_2_bond_os.pdf")

if (file.exists(fig9_1_path) && file.exists(fig9_2_path)) {
  if (verbose) message("  Skipping Figure 9.1-9.2: files already exist")
} else {
  bond_treasury_file <- file.path(
    results_path, "treasury",
    "excess_treasury_alpha.w=1_beta.w=1_kappa=0_bond_treasury.Rdata"
  )

  if (!file.exists(bond_treasury_file)) {
    warning("Bond treasury .Rdata not found. Skipping Figure 9.1-9.2.\n  ", bond_treasury_file)
  } else {
    fig9_bond <- plot_mean_vs_cov(
      results_path  = results_path,
      return_type   = "excess",
      model_type    = "treasury",
      alpha.w       = 1,
      beta.w        = 1,
      kappa         = 0,
      tag           = "bond_treasury",
      intercept     = TRUE,
      data_folder   = data_folder,
      os_pricing    = "treasury_oosample_all_excess.csv",
      sr_scale      = "80%",
      output_path   = figures_dir,
      figure_prefix = "fig9",
      suffix_is     = "1_bond_is",
      suffix_os     = "2_bond_os",
      constrained   = TRUE,
      verbose       = verbose
    )
    if (verbose) {
      message("  Generated: fig9_1_bond_is.pdf, fig9_2_bond_os.pdf")
    }
  }
}

# Figure 9.3 & 9.4: Stock Treasury (IS & OS)
fig9_3_path <- file.path(figures_dir, "fig9_3_stock_is.pdf")
fig9_4_path <- file.path(figures_dir, "fig9_4_stock_os.pdf")

if (file.exists(fig9_3_path) && file.exists(fig9_4_path)) {
  if (verbose) message("  Skipping Figure 9.3-9.4: files already exist")
} else {
  stock_treasury_file <- file.path(
    results_path, "treasury",
    "excess_treasury_alpha.w=1_beta.w=1_kappa=0_stock_treasury.Rdata"
  )

  if (!file.exists(stock_treasury_file)) {
    warning("Stock treasury .Rdata not found. Skipping Figure 9.3-9.4.\n  ", stock_treasury_file)
  } else {
    fig9_stock <- plot_mean_vs_cov(
      results_path  = results_path,
      return_type   = "excess",
      model_type    = "treasury",
      alpha.w       = 1,
      beta.w        = 1,
      kappa         = 0,
      tag           = "stock_treasury",
      intercept     = TRUE,
      data_folder   = data_folder,
      os_pricing    = "treasury_oosample_all_excess.csv",
      sr_scale      = "80%",
      output_path   = figures_dir,
      figure_prefix = "fig9",
      suffix_is     = "3_stock_is",
      suffix_os     = "4_stock_os",
      constrained   = TRUE,
      verbose       = verbose
    )
    if (verbose) {
      message("  Generated: fig9_3_stock_is.pdf, fig9_4_stock_os.pdf")
    }
  }
}


#### Figure 6 Panel A: Top Factors Over Time (Expanding Window) ---------------
# Generates: fig6a_top5_prob_psi80.pdf - Heatmap of top 5 factors by posterior
#            probability across forward-expanding estimation windows.
# Source: expanding_runs_plots.R
# Input: Time-varying estimation .rds file from run_time_varying_estimation()

if (verbose) message("Figure 6 Panel A: Top Factors Over Time (Expanding Window)")

# Path to expanding window results
expanding_rds_path <- file.path(
  "output/time_varying/bond_stock_with_sp",
  "SS_excess_bond_stock_with_sp_alpha.w=1_beta.w=1_SRscale=ExpandingForward_holding_period=12_f1=TRUE_ALL_RESULTS.rds"
)

fig6a_output_path <- file.path(figures_dir, "fig6a_top5_prob_psi80.pdf")

if (file.exists(fig6a_output_path)) {
  if (verbose) message("  Skipping Figure 6a: file already exists")
} else if (!file.exists(expanding_rds_path)) {
  warning("Expanding window .rds not found. Skipping Figure 6a.\n  ", expanding_rds_path)
} else {
  fig6a_result <- generate_figure_6a(
    rds_path    = expanding_rds_path,
    psi_level   = 0.8,
    top_n       = 5,
    output_path = figures_dir,
    verbose     = verbose
  )

  if (verbose) {
    message("  Generated: fig6a_top5_prob_psi80.pdf")
    message("  Estimation dates: ", length(fig6a_result$top_factors_prob))
  }
}


#### Figure IA.17a: Top Factors by Lambda Over Time (Expanding Window) ---------
# Generates: fig_ia_17a_top5_lambda_psi80.pdf - Heatmap of top 5 factors by
#            absolute market price of risk across forward-expanding estimation windows.
# Source: expanding_runs_plots.R
# Input: Time-varying estimation .rds file from run_time_varying_estimation()

if (verbose) message("Figure IA.17a: Top Factors by Lambda Over Time (Expanding Window)")

fig_ia17a_output_path <- file.path(figures_dir, "fig_ia_17a_top5_lambda_psi80.pdf")

if (file.exists(fig_ia17a_output_path)) {
  if (verbose) message("  Skipping Figure IA.17a: file already exists")
} else if (!file.exists(expanding_rds_path)) {
  warning("Expanding window .rds not found. Skipping Figure IA.17a.\n  ", expanding_rds_path)
} else {
  fig_ia17a_result <- generate_figure_ia17a(
    rds_path    = expanding_rds_path,
    psi_level   = 0.8,
    top_n       = 5,
    output_path = figures_dir,
    verbose     = verbose
  )

  if (verbose) {
    message("  Generated: fig_ia_17a_top5_lambda_psi80.pdf")
    message("  Estimation dates: ", length(fig_ia17a_result$top_factors_lambda))
  }
}


#### Figure 6 Panel B: Top Factors Over Time (Backward Expanding Window) -------
# Generates: fig6b_top5_prob_psi80.pdf - Heatmap of top 5 factors by posterior
#            probability across backward-expanding estimation windows (reversed x-axis).
# Source: expanding_runs_plots.R
# Input: Backward time-varying estimation .rds file

if (verbose) message("Figure 6 Panel B: Top Factors Over Time (Backward Expanding)")

# Path to backward expanding window results
backward_rds_path <- file.path(
  "output/time_varying/bond_stock_with_sp",
  "SS_excess_bond_stock_with_sp_alpha.w=1_beta.w=1_SRscale=ExpandingBackward_holding_period=12_f1=TRUE_backward_ALL_RESULTS.rds"
)

fig6b_output_path <- file.path(figures_dir, "fig6b_top5_prob_psi80.pdf")

if (file.exists(fig6b_output_path)) {
  if (verbose) message("  Skipping Figure 6b: file already exists")
} else if (!file.exists(backward_rds_path)) {
  warning("Backward expanding window .rds not found. Skipping Figure 6b.\n  ", backward_rds_path)
} else {
  fig6b_result <- generate_figure_6b(
    rds_path    = backward_rds_path,
    psi_level   = 0.8,
    top_n       = 5,
    output_path = figures_dir,
    verbose     = verbose
  )

  if (verbose) {
    message("  Generated: fig6b_top5_prob_psi80.pdf")
    message("  Estimation dates: ", length(fig6b_result$top_factors_prob))
  }
}


#### Figure IA.17b: Top Factors by Lambda (Backward Expanding Window) ----------
# Generates: fig_ia_17b_top5_lambda_psi80.pdf - Heatmap of top 5 factors by
#            absolute market price of risk across backward-expanding windows (reversed x-axis).
# Source: expanding_runs_plots.R
# Input: Backward time-varying estimation .rds file

if (verbose) message("Figure IA.17b: Top Factors by Lambda (Backward Expanding)")

fig_ia17b_output_path <- file.path(figures_dir, "fig_ia_17b_top5_lambda_psi80.pdf")

if (file.exists(fig_ia17b_output_path)) {
  if (verbose) message("  Skipping Figure IA.17b: file already exists")
} else if (!file.exists(backward_rds_path)) {
  warning("Backward expanding window .rds not found. Skipping Figure IA.17b.\n  ", backward_rds_path)
} else {
  fig_ia17b_result <- generate_figure_ia17b(
    rds_path    = backward_rds_path,
    psi_level   = 0.8,
    top_n       = 5,
    output_path = figures_dir,
    verbose     = verbose
  )

  if (verbose) {
    message("  Generated: fig_ia_17b_top5_lambda_psi80.pdf")
    message("  Estimation dates: ", length(fig_ia17b_result$top_factors_lambda))
  }
}


#### Figures 10-12: SDF Time Series, Volatility, and Predictability -----------
# Generates:
#   Figure 10: SDF_Time_Series_BMA.pdf - BMA SDF time series with ARIMA mean
#   Figure 11: SDF_Volatility_BMA_CAPMB_FF5.pdf - Conditional volatility comparison
#   Figure 12 Panel A: Predictability1m_BMA.pdf - 1-month return predictability
#   Figure 12 Panel B: Predictability12m_BMA.pdf - 12-month return predictability
# Source: fit_sdf_models.R

if (verbose) message("Figures 10-12: SDF Time Series, Volatility, and Predictability")

# Check if all Figure 10-12 outputs already exist
fig10_path <- file.path(figures_dir, "fig10_sdf_time_series_bma.pdf")
fig11_path <- file.path(figures_dir, "fig11_sdf_volatility_bma_capmb_ff5.pdf")
fig12a_path <- file.path(figures_dir, "fig12a_predictability1m_bma.pdf")
fig12b_path <- file.path(figures_dir, "fig12b_predictability12m_bma.pdf")

if (file.exists(fig10_path) && file.exists(fig11_path) &&
    file.exists(fig12a_path) && file.exists(fig12b_path)) {
  if (verbose) message("  Skipping Figures 10-12: files already exist")
} else {
  # Check if required .Rdata file exists
  main_rdata_file <- file.path(
    results_path, model_type,
    sprintf("%s_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s.Rdata",
            return_type, model_type, alpha.w, beta.w, kappa, tag)
  )

  if (!file.exists(main_rdata_file)) {
    warning("Main .Rdata not found. Skipping Figures 10-12.\n  ", main_rdata_file)
  } else {
    fig10_12_result <- fit_sdf_models(
      results_path = results_path,
      return_type  = return_type,
      model_type   = model_type,
      alpha.w      = alpha.w,
      beta.w       = beta.w,
      kappa        = kappa,
      tag          = tag,
      shrinkage    = 4,  # 80% shrinkage
      output_path  = figures_dir,
      paper_only   = TRUE,
      verbose      = verbose
    )

    if (verbose) {
      message("  Generated: fig10_sdf_time_series_bma.pdf")
      message("  Generated: fig11_sdf_volatility_bma_capmb_ff5.pdf")
      message("  Generated: fig12a_predictability1m_bma.pdf")
      message("  Generated: fig12b_predictability12m_bma.pdf")
    }
  }
}


###############################################################################
## SECTION 5: SUMMARY AND CLEANUP
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("GENERATION COMPLETE")
  message(strrep("=", 60))
  message("Tables saved to:  ", tables_dir)
  message("Figures saved to: ", figures_dir)
  message(strrep("=", 60), "\n")
}

# Clean up large objects if needed
# gc()


###############################################################################
## APPENDIX: UTILITY FUNCTIONS (inline helpers)
###############################################################################

#' Save table to CSV and/or LaTeX
#'
#' @param df Data frame to save
#' @param name Base filename (without extension)
#' @param format One of "csv", "latex", or "both"
save_table <- function(df, name, format = table_format) {
  if (format %in% c("csv", "both")) {
    csv_path <- file.path(tables_dir, paste0(name, ".csv"))
    write.csv(df, csv_path, row.names = FALSE)
    if (verbose) message("  Saved: ", csv_path)
  }

  if (format %in% c("latex", "both")) {
    # Requires xtable package
    if (requireNamespace("xtable", quietly = TRUE)) {
      tex_path <- file.path(tables_dir, paste0(name, ".tex"))
      xtab <- xtable::xtable(df)
      print(xtab, file = tex_path, include.rownames = FALSE)
      if (verbose) message("  Saved: ", tex_path)
    } else {
      warning("Package 'xtable' not installed. Skipping LaTeX output.")
    }
  }
}


#' Save figure to PDF and/or PNG
#'
#' @param plot_fn Function that generates the plot (called inside device)
#' @param name Base filename (without extension)
#' @param width Width in inches
#' @param height Height in inches
#' @param format One of "pdf", "png", or "both"
save_figure <- function(plot_fn, name, width = 8, height = 6, format = figure_format) {
  if (format %in% c("pdf", "both")) {
    pdf_path <- file.path(figures_dir, paste0(name, ".pdf"))
    pdf(pdf_path, width = width, height = height)
    plot_fn()
    dev.off()
    if (verbose) message("  Saved: ", pdf_path)
  }

  if (format %in% c("png", "both")) {
    png_path <- file.path(figures_dir, paste0(name, ".png"))
    png(png_path, width = width * 100, height = height * 100, res = 100)
    plot_fn()
    dev.off()
    if (verbose) message("  Saved: ", png_path)
  }
}
