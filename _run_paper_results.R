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
  "sr_tables.R"
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

# Load the .Rdata file
load(rdata_path)

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


#### Table 2: [Description] ---------------------------------------------------
# TODO: Add Table 2 generation code

if (verbose) message("Table 2: [Not yet implemented]")


#### Table 3: [Description] ---------------------------------------------------
# TODO: Add Table 3 generation code

if (verbose) message("Table 3: [Not yet implemented]")


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

if (verbose) message("Figure 2 + Table A.2: Posterior Probabilities")

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
    model_type    = model_type,
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

if (verbose) message("Figure 3: Number of Factors & Sharpe Ratio Distributions")

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
    model_type    = model_type,
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

if (verbose) message("Figure 4: Posterior Probabilities & Market Prices of Risk")

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
    model_type    = model_type,
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
