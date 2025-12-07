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
 # "table_helpers.R",
 # "figure_helpers.R",
 # "latex_helpers.R"
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
  # "IS_AP",        # In-sample asset pricing results
 # "metadata"      # Run metadata
)

missing_objects <- required_objects[!required_objects %in% ls()]
if (length(missing_objects) > 0) {
  warning(
    "Some expected objects are missing from the loaded data:\n  ",
    paste(missing_objects, collapse = ", "),
    "\nSome tables/figures may fail to generate."
  )
}


###############################################################################
## SECTION 3: TABLES
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("GENERATING TABLES")
  message(strrep("=", 60), "\n")
}

#### Table 1: [Description] ---------------------------------------------------
# TODO: Add Table 1 generation code
# Source: code_base/[table_script].R or inline

if (verbose) message("Table 1: [Not yet implemented]")


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


#### Figure 2: [Description] --------------------------------------------------
# TODO: Add Figure 2 generation code

if (verbose) message("Figure 2: [Not yet implemented]")


#### Figure 3: [Description] --------------------------------------------------
# TODO: Add Figure 3 generation code

if (verbose) message("Figure 3: [Not yet implemented]")


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
