#!/usr/bin/env Rscript
###############################################################################
## _run_ia_results.R - Generate Internet Appendix Tables and Figures
## ---------------------------------------------------------------------------
##
## This script generates all tables and figures for the Internet Appendix.
## It requires the MCMC estimation to have been run first via:
##   Rscript ia/_run_ia_estimation.R
##
## OUTPUTS:
##   Tables:
##     - Posterior probabilities & risk prices for ALL 5 IA models
##     - Table IA.6: In-sample pricing (no intercept models)
##     - Table IA.7: Out-of-sample pricing (no intercept models)
##     - Duration pricing table (4 panels: IS/OS for bond_stock_with_sp and bond)
##     - Treasury posterior probabilities table
##     - Treasury SR decomposition table (nontradable vs tradable factors)
##     - Sparse model posterior probabilities table (imposing sparsity)
##     - Sparse model asset pricing table (IS/OS, 2 panels)
##
##   Figures:
##     - Figure 2 equivalent for joint_no_intercept
##     - Cumulative SR figure (from main paper's excess model)
##     - Treasury posterior probabilities figure (like Figure 2)
##     - Treasury nfac/SR distribution figure (like Figure 3)
##     - Treasury bar plots figure (like Figure 4)
##     - Treasury DR-tilt bar plots figure (weighted kappa model)
##     - Sparse model posterior probabilities figure
##
## USAGE:
##   From R:
##     source("ia/_run_ia_results.R")
##
##   From terminal:
##     Rscript ia/_run_ia_results.R
##
###############################################################################

gc()

# Close any stray graphics devices
if (length(dev.list()) > 0) graphics.off()

###############################################################################
## SECTION 1: CONFIGURATION
###############################################################################

# Ensure we're in project root
if (basename(getwd()) == "ia") {
  setwd("..")
}
main_path <- getwd()

# Verify location
if (!file.exists("code_base/run_bayesian_mcmc.R")) {
  stop("Please run this script from the project root directory")
}

# Paths
ia_output      <- "ia/output"
results_path   <- file.path(ia_output, "unconditional")
paper_output   <- file.path(ia_output, "paper")
tables_dir     <- file.path(paper_output, "tables")
figures_dir    <- file.path(paper_output, "figures")
code_folder    <- "code_base"
data_folder    <- "data"

# Create directories
for (d in c(tables_dir, figures_dir)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

# Settings
verbose        <- TRUE
return_type    <- "excess"

# Prior parameters (for prob_thresh calculation)
alpha.w        <- 1
beta.w         <- 1

###############################################################################
## SECTION 2: MODEL CONFIGURATIONS
###############################################################################

# Define model configurations in the correct order for the IA document
# Order:
#   1. Bond with intercept
#   2. Stock with intercept
#   3. Joint (bond_stock_with_sp) no intercept
#   4. Bond no intercept
#   5. Stock no intercept

IA_MODELS <- list(

  list(
    id          = 1,
    name        = "bond_intercept",
    model_type  = "bond",
    intercept   = TRUE,
    tag         = "ia_intercept",
    table_num   = "IA.1",
    caption     = "Posterior factor probabilities and risk prices for the corporate bond factor zoo -- with intercept"
  ),

  list(
    id          = 2,
    name        = "stock_intercept",
    model_type  = "stock",
    intercept   = TRUE,
    tag         = "ia_intercept",
    table_num   = "IA.2",
    caption     = "Posterior factor probabilities and risk prices for the stock factor zoo -- with intercept"
  ),

  list(
    id          = 3,
    name        = "joint_no_intercept",
    model_type  = "bond_stock_with_sp",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    table_num   = "IA.3",
    caption     = "Posterior factor probabilities and risk prices for the co-pricing factor zoo -- no intercept"
  ),

  list(
    id          = 4,
    name        = "bond_no_intercept",
    model_type  = "bond",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    table_num   = "IA.4",
    caption     = "Posterior factor probabilities and risk prices for the corporate bond factor zoo -- no intercept"
  ),

  list(
    id          = 5,
    name        = "stock_no_intercept",
    model_type  = "stock",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    table_num   = "IA.5",
    caption     = "Posterior factor probabilities and risk prices for the stock factor zoo -- no intercept"
  )
)

###############################################################################
## SECTION 3: SOURCE HELPER FUNCTIONS
###############################################################################

if (verbose) message("\nLoading helper functions...")

source(file.path(code_folder, "pp_figure_table.R"))
source(file.path(code_folder, "pricing_tables.R"))  # provides build_pricing_panel_rows()
source(file.path(code_folder, "validate_and_align_dates.R"))  # required by os_asset_pricing()
source(file.path(code_folder, "insample_asset_pricing.R"))
source(file.path(code_folder, "outsample_asset_pricing.R"))  # provides os_asset_pricing()
source(file.path(code_folder, "plot_cumulative_sr.R"))
source(file.path(code_folder, "plot_nfac_sr.R"))  # provides plot_nfac_sr() for Figure 3 equivalent
source(file.path(code_folder, "pp_bar_plots.R"))  # provides pp_bar_plots() for Figure 4 equivalent
source(file.path(code_folder, "sr_decomposition.R"))  # provides sr_decomposition() for SR tables
source(file.path(code_folder, "sr_tables.R"))  # provides generate_table_treasury_sr()

# Load additional helpers as needed
if (file.exists(file.path(code_folder, "oos_pricing_helpers.R"))) {
  source(file.path(code_folder, "oos_pricing_helpers.R"))
}

###############################################################################
## SECTION 4: HELPER FUNCTIONS
###############################################################################

#' Construct .Rdata filename for a model
#' Note: run_bayesian_mcmc adds "no_intercept_" prefix to tag when intercept=FALSE
get_rdata_path <- function(model, results_path, return_type = "excess") {
  # When intercept=FALSE, the actual filename has "no_intercept_" prefix before the tag
  if (model$intercept) {
    filename <- sprintf("%s_%s_alpha.w=1_beta.w=1_kappa=0_%s.Rdata",
                        return_type, model$model_type, model$tag)
  } else {
    filename <- sprintf("%s_%s_alpha.w=1_beta.w=1_kappa=0_no_intercept_%s.Rdata",
                        return_type, model$model_type, model$tag)
  }
  file.path(results_path, model$model_type, filename)
}

#' Load model results into an environment
load_model_results <- function(model, results_path, return_type = "excess") {
  rdata_path <- get_rdata_path(model, results_path, return_type)

  if (!file.exists(rdata_path)) {
    warning("Results file not found: ", rdata_path)
    return(NULL)
  }

  env <- new.env()
  load(rdata_path, envir = env)
  return(env)
}

#' Generate posterior probability table for a model
generate_ia_prob_table <- function(model, results_path, output_path, verbose = TRUE) {

  if (verbose) {
    message("\n", strrep("-", 60))
    message("Generating probability table for: ", model$name)
    message("  model_type = '", model$model_type, "'")
    message("  intercept  = ", model$intercept)
    message("  caption    = '", model$caption, "'")
    message(strrep("-", 60))
  }

  # Load results
  env <- load_model_results(model, results_path)
  if (is.null(env)) {
    warning("Skipping ", model$name, ": results not found")
    return(NULL)
  }

  # Extract required objects
  results <- get("results", envir = env)
  f1 <- get("f1", envir = env)
  f2 <- if (exists("f2", envir = env)) get("f2", envir = env) else NULL
  intercept <- get("intercept", envir = env)

  # Make f1, f2, intercept available for pp_figure_table
  assign("f1", f1, envir = .GlobalEnv)
  assign("f2", f2, envir = .GlobalEnv)
  assign("intercept", intercept, envir = .GlobalEnv)

  # Generate table name from model table_num (e.g., "IA.1" -> "table_ia_1")
  table_name <- tolower(gsub("\\.", "_", paste0("table_", model$table_num)))
  table_label <- paste0("tab:", tolower(gsub("\\.", "-", model$table_num)))

  # Generate the table (uses pp_figure_table.R logic)
  tryCatch({
    result <- pp_figure_table(
      results       = results,
      return_type   = return_type,
      model_type    = model$model_type,
      tag           = model$tag,
      alpha.w       = alpha.w,
      beta.w        = beta.w,
      main_path     = paper_output,
      output_folder = "figures",
      table_folder  = "tables",
      # Custom caption and label for IA
      table_caption = model$caption,
      table_label   = table_label,
      table_name    = table_name,
      verbose       = verbose
    )

    if (verbose) {
      message("  Figure saved: ", result$fig_file)
      message("  Table saved:  ", result$tex_file)
    }

    return(result)
  }, error = function(e) {
    warning("Error generating table for ", model$name, ": ", e$message)
    return(NULL)
  })
}

###############################################################################
## SECTION 5: MAIN EXECUTION
###############################################################################

if (verbose) {

  message("\n")
  message(strrep("=", 60))
  message("INTERNET APPENDIX RESULTS GENERATION")
  message(strrep("=", 60))
  message("\nOutput directories:")
  message("  Tables:  ", tables_dir)
  message("  Figures: ", figures_dir)
}

###############################################################################
## SECTION 5.1: POSTERIOR PROBABILITY TABLES (ALL MODELS)
###############################################################################

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 1: Posterior Probability Tables (All Models)")
  message(strrep("=", 60))
}

prob_table_results <- list()

for (model in IA_MODELS) {
  result <- generate_ia_prob_table(model, results_path, paper_output, verbose)
  if (!is.null(result)) {
    prob_table_results[[model$name]] <- result
  }
}

###############################################################################
## SECTION 5.2: PRICING TABLES (No Intercept Models)
###############################################################################
# Generate IS and OS pricing tables for models estimated WITHOUT intercept
# Uses: joint_no_intercept, bond_no_intercept, stock_no_intercept
# Output: table_ia_6_is_pricing.tex, table_ia_7_os_pricing.tex

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 2: Pricing Tables (No Intercept Models)")
  message(strrep("=", 60))
}

# Models to use for pricing tables (no_intercept only)
pricing_models <- list(
  joint = IA_MODELS[[3]],  # joint_no_intercept (bond_stock_with_sp)
  bond  = IA_MODELS[[4]],  # bond_no_intercept
  stock = IA_MODELS[[5]]   # stock_no_intercept
)

# Model columns in order (matching table header) - defined here so available for both IS and OS
model_cols <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                "CAPM", "CAPMB", "FF5", "HKM",
                "Top-80%-All", "KNS", "RP-PCA")

# Collect IS pricing results from each model
is_pricing_results <- list()
os_pricing_results <- list()

for (model_key in names(pricing_models)) {
  model <- pricing_models[[model_key]]

  if (verbose) {
    message("\n  Loading ", model$name, " for pricing...")
  }

  # Load model into a local environment first
  model_env <- load_model_results(model, results_path)

  if (is.null(model_env)) {
    warning("  Model not found: ", model$name, ". Skipping.")
    next
  }

  # Check if IS_AP exists
  if (!exists("IS_AP", envir = model_env)) {
    warning("  IS_AP not found in ", model$name, ". Skipping.")
    next
  }

  IS_AP_local <- get("IS_AP", envir = model_env)

  # Extract IS pricing
  if (!is.null(IS_AP_local$is_pricing_result)) {
    is_pricing_results[[model_key]] <- IS_AP_local$is_pricing_result
    if (verbose) message("    IS pricing: ", ncol(is_pricing_results[[model_key]]) - 1, " models")
  }

  # For OS pricing, we need to load into global and run os_asset_pricing
  # For now, check if kns_out exists (pre-computed OOS)
  if (exists("kns_out", envir = model_env)) {
    os_pricing_results[[model_key]] <- get("kns_out", envir = model_env)
    if (verbose) message("    OS pricing available")
  }
}

# ---- Generate Table IA.6: In-Sample Pricing ----
if (length(is_pricing_results) > 0) {
  if (verbose) message("\nGenerating Table IA.6: In-Sample Pricing (No Intercept)...")

  latex_lines <- c(
    "\\begin{table}[tbh!]",
    "\\begin{center}",
    "\\caption{In-sample cross-sectional asset pricing performance (no intercept)}\\label{tab:ia-is-pricing}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccc|ccccccc}\\toprule",
    " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
    " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
  )

  # Panel A: Co-pricing (joint)
  if (!is.null(is_pricing_results$joint)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel A:} Co-pricing bonds and stocks} \\\\ \\midrule")
    latex_lines <- c(latex_lines, build_pricing_panel_rows(is_pricing_results$joint, model_cols))
    latex_lines <- c(latex_lines, " \\midrule")
  }

  # Panel B: Bond
  if (!is.null(is_pricing_results$bond)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel B}: Pricing bonds} \\\\ \\midrule")
    latex_lines <- c(latex_lines, build_pricing_panel_rows(is_pricing_results$bond, model_cols))
    latex_lines <- c(latex_lines, " \\midrule")
  }

  # Panel C: Stock
  if (!is.null(is_pricing_results$stock)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel C}: Pricing stocks} \\\\ \\midrule")
    latex_lines <- c(latex_lines, build_pricing_panel_rows(is_pricing_results$stock, model_cols))
  }

  latex_lines <- c(latex_lines,
                   " \\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   "\t{\\footnotesize",
                   "The table presents the cross-sectional in-sample asset pricing performance of different models estimated \\textbf{without an intercept}, pricing bonds and stocks jointly (Panel A), bonds only (Panel B) and stocks only (Panel C), respectively.",
                   "For the BMA-SDF, we provide results for prior Sharpe ratio values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the test assets. TOP includes the top five factors with an average posterior probability greater than 50\\%.",
                   "CAPM is the standard single-factor model using MKTS, and CAPMB is the bond version using MKTB. FF5 is the five-factor model of \\cite{FamaFrench_1993}, HKM is the two-factor model of \\citet{HeKellyManela_2017}. KNS stands for the SDF estimation of \\citet{KozakNagelSantosh_2020} and RPPCA is the risk premia PCA of \\cite{LettauPelger_2020}.",
                   "Bond returns are computed in excess of the one-month risk-free rate of return.",
                   "All data are standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                   "}",
                   "\\end{spacing}",
                   "\\vspace{-4mm}",
                   "\\end{table}")

  is_tex_path <- file.path(tables_dir, "table_ia_6_is_pricing.tex")
  writeLines(latex_lines, is_tex_path)
  if (verbose) message("  Saved: ", is_tex_path)
}

# ---- Generate Table IA.7: Out-of-Sample Pricing ----
# Runs os_asset_pricing for each no-intercept model (joint, bond, stock)
# and generates a 3-panel table like Table 3 in the main paper

if (verbose) message("\nGenerating Table IA.7: Out-of-Sample Pricing (No Intercept)...")

# Collect OOS results for all 3 models
os_pricing_collected <- list()

# Load OOS test asset files once
bond_oos_file <- file.path(data_folder, "bond_oosample_all_excess.csv")
stock_oos_file <- file.path(data_folder, "equity_os_77.csv")

if (!file.exists(bond_oos_file)) {
  warning("  Bond OOS file not found: ", bond_oos_file)
}
if (!file.exists(stock_oos_file)) {
  warning("  Stock OOS file not found: ", stock_oos_file)
}

# Read OOS assets if available
Rb_oos <- if (file.exists(bond_oos_file)) read.csv(bond_oos_file, check.names = FALSE) else NULL
Rs_oos <- if (file.exists(stock_oos_file)) {
  tmp <- read.csv(stock_oos_file, check.names = FALSE)
  # Remove date column for combining (but keep for stock-only)
  tmp
} else NULL

# Process each model type
model_type_map <- list(
  joint = list(
    model = pricing_models$joint,
    panel = "bond_stock_with_sp",
    get_R_oos = function() {
      if (!is.null(Rb_oos) && !is.null(Rs_oos)) {
        cbind(Rb_oos, Rs_oos[, -1, drop = FALSE])  # Combine, removing Rs date
      } else NULL
    }
  ),
  bond = list(
    model = pricing_models$bond,
    panel = "bond",
    get_R_oos = function() Rb_oos
  ),
  stock = list(
    model = pricing_models$stock,
    panel = "stock",
    get_R_oos = function() Rs_oos
  )
)

for (model_key in names(model_type_map)) {
  model_info <- model_type_map[[model_key]]
  model <- model_info$model
  panel_name <- model_info$panel

  if (verbose) message("  Processing ", model_key, " model for OOS pricing...")

  rdata_path <- get_rdata_path(model, results_path)
  if (verbose) message("    Looking for: ", rdata_path)

  if (!file.exists(rdata_path)) {
    warning("    .Rdata not found: ", rdata_path)
    os_pricing_collected[[panel_name]] <- NULL
    next
  }

  # Load into a fresh environment to avoid conflicts
  load_env <- new.env()
  load_success <- tryCatch({
    load(rdata_path, envir = load_env)
    if (verbose) message("    Loaded successfully")
    TRUE
  }, error = function(e) {
    warning("    Failed to load .Rdata: ", e$message)
    FALSE
  })

  if (!load_success) {
    os_pricing_collected[[panel_name]] <- NULL
    next
  }

  # Check required objects
  required_objs <- c("IS_AP", "results", "f1", "kns_out", "rp_out", "frequentist_models")
  missing_objs <- required_objs[!sapply(required_objs, exists, envir = load_env)]

  if (length(missing_objs) > 0) {
    warning("    Missing objects in ", model_key, ": ", paste(missing_objs, collapse = ", "))
    os_pricing_collected[[panel_name]] <- NULL
    next
  }

  # Get OOS test assets for this model type
  R_oos_data <- model_info$get_R_oos()

  if (is.null(R_oos_data)) {
    warning("    OOS test assets not available for ", model_key)
    os_pricing_collected[[panel_name]] <- NULL
    next
  }

  if (verbose) message("    OOS assets: ", ncol(R_oos_data) - 1, " portfolios")

  tryCatch({
    # Extract objects from load environment
    IS_AP_local <- get("IS_AP", envir = load_env)
    frequentist_models_local <- get("frequentist_models", envir = load_env)
    kns_out_local <- get("kns_out", envir = load_env)
    rp_out_local <- get("rp_out", envir = load_env)
    pca_out_local <- if (exists("pca_out", envir = load_env)) get("pca_out", envir = load_env) else NULL

    # Get f1, f2, fac_freq - prefer data_list if available and complete
    if (exists("data_list", envir = load_env)) {
      data_list_local <- get("data_list", envir = load_env)
      # Check that data_list has the required fields
      if (!is.null(data_list_local$f1) && !is.null(data_list_local$fac_freq)) {
        f1_local <- data_list_local$f1
        f2_local <- data_list_local$f2  # Can be NULL for bond-only models
        fac_freq_local <- data_list_local$fac_freq
        if (verbose) message("    Using data from data_list (f1, f2, fac_freq)")
      } else {
        # data_list exists but incomplete - fallback to direct objects
        if (verbose) message("    data_list incomplete, using direct objects")
        f1_local <- get("f1", envir = load_env)
        f2_local <- if (exists("f2", envir = load_env)) get("f2", envir = load_env) else NULL
        fac_freq_local <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
      }
    } else {
      f1_local <- get("f1", envir = load_env)
      f2_local <- if (exists("f2", envir = load_env)) get("f2", envir = load_env) else NULL
      # Fallback: load fac_freq from CSV
      fac_freq_local <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
      if (verbose) message("    Using f1/f2 from load_env, fac_freq from CSV")
    }

    if (verbose) {
      message("    f1: ", nrow(f1_local), " x ", ncol(f1_local))
      message("    f2: ", if(is.null(f2_local)) "NULL" else paste(nrow(f2_local), "x", ncol(f2_local)))
      message("    fac_freq: ", nrow(fac_freq_local), " x ", ncol(fac_freq_local))
    }

    # Run OOS pricing
    if (verbose) message("    Running os_asset_pricing()...")
    os_result <- os_asset_pricing(
      R_oss              = R_oos_data,
      IS_AP              = IS_AP_local,
      f1                 = f1_local,
      f2                 = f2_local,
      fac_freq           = fac_freq_local,
      frequentist_models = frequentist_models_local,
      kns_out            = kns_out_local,
      rp_out             = rp_out_local,
      pca_out            = pca_out_local,
      intercept          = FALSE,  # No intercept for IA
      verbose            = verbose  # Pass through verbose flag
    )

    # os_asset_pricing returns a data frame directly
    if (!is.null(os_result) && is.data.frame(os_result) && nrow(os_result) > 0) {
      os_pricing_collected[[panel_name]] <- os_result
      if (verbose) message("    SUCCESS: ", ncol(os_result) - 1, " models evaluated")
    } else {
      warning("    os_asset_pricing returned invalid result for ", model_key)
      os_pricing_collected[[panel_name]] <- NULL
    }

  }, error = function(e) {
    warning("    ERROR in ", model_key, " OOS pricing: ", e$message)
    os_pricing_collected[[panel_name]] <<- NULL
  })

  # Clean up
  rm(load_env)
  gc(verbose = FALSE)
}

# ---- Build the 3-panel OOS pricing table ----
if (verbose) message("\n  Building Table IA.7 with ", sum(!sapply(os_pricing_collected, is.null)), " panels...")

# Check if we have any results
if (all(sapply(os_pricing_collected, is.null))) {
  warning("  No OOS pricing results available! Skipping Table IA.7.")
} else {

  os_latex_lines <- c(
    "\\begin{table}[tbh!]",
    "\\begin{center}",
    "\\caption{Out-of-sample cross-sectional asset pricing performance (no intercept)}\\label{tab:ia-os-pricing}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccc|ccccccc}\\toprule",
    " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
    " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
  )

  # Panel A: Co-pricing (bond_stock_with_sp)
  if (!is.null(os_pricing_collected$bond_stock_with_sp)) {
    os_latex_lines <- c(os_latex_lines,
                        "\\multicolumn{12}{c}{\\textbf{Panel A}: Co-pricing bonds and stocks} \\\\ \\midrule",
                        build_pricing_panel_rows(os_pricing_collected$bond_stock_with_sp, model_cols),
                        " \\midrule")
    if (verbose) message("    Added Panel A: Co-pricing")
  }

  # Panel B: Bond
  if (!is.null(os_pricing_collected$bond)) {
    os_latex_lines <- c(os_latex_lines,
                        "\\multicolumn{12}{c}{\\textbf{Panel B}: Pricing bonds} \\\\ \\midrule",
                        build_pricing_panel_rows(os_pricing_collected$bond, model_cols),
                        " \\midrule")
    if (verbose) message("    Added Panel B: Bonds")
  }

  # Panel C: Stock
  if (!is.null(os_pricing_collected$stock)) {
    os_latex_lines <- c(os_latex_lines,
                        "\\multicolumn{12}{c}{\\textbf{Panel C}: Pricing stocks} \\\\ \\midrule",
                        build_pricing_panel_rows(os_pricing_collected$stock, model_cols))
    if (verbose) message("    Added Panel C: Stocks")
  }

  os_latex_lines <- c(os_latex_lines,
                      " \\bottomrule",
                      "\\end{tabular}",
                      "}",
                      "\\end{center}",
                      "\\begin{spacing}{1}",
                      "    {\\footnotesize",
                      "The table presents the cross-sectional out-of-sample asset pricing performance of models estimated \\textbf{without an intercept}, pricing bonds and stocks jointly (Panel A), bonds only (Panel B) and stocks only (Panel C).",
                      "For the BMA-SDF, we provide results for prior Sharpe ratio values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the in-sample test assets.",
                      "Models are first estimated using the in-sample test assets and then used to price (with no additional parameter estimation) the out-of-sample test assets.",
                      "All data are standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                      "}",
                      "\\end{spacing}",
                      "\\vspace{-4mm}",
                      "\\end{table}")

  os_tex_path <- file.path(tables_dir, "table_ia_7_os_pricing.tex")
  writeLines(os_latex_lines, os_tex_path)
  if (verbose) message("  Saved: ", os_tex_path)
}

###############################################################################
## SECTION 5.3: FIGURE 2 EQUIVALENT (joint_no_intercept only)
###############################################################################

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 3: Posterior Probability Figure (Joint Model)")
  message(strrep("=", 60))
}

# The Figure 2 equivalent was already generated in Section 5.1
# when we processed the joint_no_intercept model

if (!is.null(prob_table_results[["joint_no_intercept"]])) {
  if (verbose) {
    message("\nFigure 2 equivalent already generated:")
    message("  ", prob_table_results[["joint_no_intercept"]]$fig_file)
  }
} else {
  warning("Figure 2 equivalent not generated - joint model results missing")
}

###############################################################################
## SECTION 5.4: CUMULATIVE SR FIGURE (uses main paper's duration model)
###############################################################################

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 4: Cumulative Co-Pricing SDF-Implied Sharpe Ratio")
  message(strrep("=", 60))
}

# This figure uses the MAIN paper's excess_bond_stock_with_sp model
# (not IA-specific), but outputs to the IA figures directory
main_results_path <- "output/unconditional"
excess_rdata_file <- file.path(
  main_results_path, "bond_stock_with_sp",
  "excess_bond_stock_with_sp_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata"
)

fig13_output_path <- file.path(figures_dir, "fig13_cum_sr_80pct.pdf")

if (file.exists(fig13_output_path)) {
  if (verbose) message("  Skipping Figure 13: file already exists")
} else if (!file.exists(excess_rdata_file)) {
  warning("Excess .Rdata not found. Skipping Figure 13.\n  ", excess_rdata_file)
} else {
  if (verbose) message("  Computing cumulative Sharpe ratios...")

  # Compute cumulative Sharpe ratios
  sharpe_tbl <- cumulative_sharpe_ratio(
    main_path     = main_path,
    output_folder = "output",
    model_type    = "bond_stock_with_sp",
    return_type   = "excess",
    kappa         = 0,
    alpha.w       = 1,
    beta.w        = 1,
    tag           = "baseline",
    prior_labels  = c("20%", "40%", "60%", "80%"),
    verbose       = verbose
  )

  # Generate the figure
  fig13_result <- plot_cumulative_sr(
    sharpe_tbl          = sharpe_tbl,
    sr_shrinkage        = "80%",
    use_ratio           = FALSE,
    main_path           = paper_output,
    output_folder       = "figures",
    fig_name            = "fig13_cum_sr_80pct.pdf",
    width               = 12,
    height              = 7,
    units               = "in",
    y_axis_text_size    = 12,
    x_axis_text_size    = 9,
    y_label_text_size   = 16,
    legend_text_size    = 12,
    verbose             = verbose
  )

  if (verbose) {
    message("  Generated: fig13_cum_sr_80pct.pdf")
  }
}


###############################################################################
## SECTION 5.5: DURATION-ADJUSTED BOND RETURNS PRICING TABLE
###############################################################################
# Generate 4-panel pricing table for duration-adjusted bond returns
# Uses MAIN paper's duration models (intercept=TRUE) from output/unconditional/
# Panel A: In-sample co-pricing stocks and bonds (bond_stock_with_sp, duration)
# Panel B: In-sample pricing bonds (bond, duration)
# Panel C: Out-of-sample co-pricing stocks and bonds
# Panel D: Out-of-sample pricing bonds

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 5: Duration-Adjusted Bond Returns Pricing Table")
  message(strrep("=", 60))
}

# Duration models use MAIN output folder, not IA output folder
main_results_path <- "output/unconditional"

# Helper to construct duration .Rdata path
get_duration_rdata_path <- function(model_type) {
  filename <- sprintf("duration_%s_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata", model_type)
  file.path(main_results_path, model_type, filename)
}

# Helper to load duration model
load_duration_model <- function(model_type, verbose = TRUE) {
  rdata_path <- get_duration_rdata_path(model_type)
  if (!file.exists(rdata_path)) {
    if (verbose) warning("Duration model not found: ", rdata_path)
    return(NULL)
  }
  if (verbose) message("  Loading: ", rdata_path)
  env <- new.env()
  load(rdata_path, envir = env)
  return(env)
}

# Collect IS and OS results for duration models
dur_is_results <- list()
dur_os_results <- list()

# ---- Panel A: bond_stock_with_sp IS (duration) ----
if (verbose) message("\n--- Processing: bond_stock_with_sp (duration) ---")

bswsp_dur_env <- load_duration_model("bond_stock_with_sp", verbose)

if (!is.null(bswsp_dur_env)) {
  if (exists("IS_AP", envir = bswsp_dur_env)) {
    IS_AP_bswsp_dur <- get("IS_AP", envir = bswsp_dur_env)
    if (!is.null(IS_AP_bswsp_dur$is_pricing_result)) {
      dur_is_results$bond_stock_with_sp <- IS_AP_bswsp_dur$is_pricing_result
      if (verbose) message("  IS pricing: ", ncol(dur_is_results$bond_stock_with_sp) - 1, " models")
    }
  } else {
    warning("  IS_AP not found in bond_stock_with_sp duration model")
  }
} else {
  warning("  bond_stock_with_sp duration model not found")
}

# ---- Panel B: bond IS (duration) ----
if (verbose) message("\n--- Processing: bond (duration) ---")

bond_dur_env <- load_duration_model("bond", verbose)

if (!is.null(bond_dur_env)) {
  if (exists("IS_AP", envir = bond_dur_env)) {
    IS_AP_bond_dur <- get("IS_AP", envir = bond_dur_env)
    if (!is.null(IS_AP_bond_dur$is_pricing_result)) {
      dur_is_results$bond <- IS_AP_bond_dur$is_pricing_result
      if (verbose) message("  IS pricing: ", ncol(dur_is_results$bond) - 1, " models")
    }
  } else {
    warning("  IS_AP not found in bond duration model")
  }
} else {
  warning("  bond duration model not found")
}

# ---- OOS Pricing for Duration Models ----
if (verbose) message("\n--- Generating OOS pricing for duration models ---")

# OOS test asset files for duration-adjusted returns
bond_dur_oos_file <- file.path(data_folder, "bond_insample_test_assets_50_duration_tmt.csv")
stock_oos_file_dur <- file.path(data_folder, "equity_os_77.csv")

# Check file existence
if (!file.exists(bond_dur_oos_file)) {
  warning("Bond duration OOS file not found: ", bond_dur_oos_file)
}
if (!file.exists(stock_oos_file_dur)) {
  warning("Stock OOS file not found: ", stock_oos_file_dur)
}

# Read OOS test assets
Rb_dur_oos <- if (file.exists(bond_dur_oos_file)) {
  read.csv(bond_dur_oos_file, check.names = FALSE)
} else NULL

Rs_dur_oos <- if (file.exists(stock_oos_file_dur)) {
  read.csv(stock_oos_file_dur, check.names = FALSE)
} else NULL

# ---- Panel C: bond_stock_with_sp OS (duration) ----
if (verbose) message("\n--- Panel C: bond_stock_with_sp OOS (duration) ---")

if (!is.null(bswsp_dur_env) && !is.null(Rb_dur_oos) && !is.null(Rs_dur_oos)) {

  # Check required objects exist before proceeding
  required_objs_dur <- c("IS_AP", "f1", "kns_out", "rp_out", "frequentist_models", "intercept")
  missing_objs_dur <- required_objs_dur[!sapply(required_objs_dur, exists, envir = bswsp_dur_env)]

  if (length(missing_objs_dur) > 0) {
    warning("  Missing objects in bond_stock_with_sp duration: ", paste(missing_objs_dur, collapse = ", "))
    if (verbose) message("  Skipping Panel C due to missing objects")
  } else {

    tryCatch({
      # Combine bond and stock OOS assets (remove date from Rs to avoid duplicate)
      R_oos_combined_dur <- cbind(Rb_dur_oos, Rs_dur_oos[, -1, drop = FALSE])
      if (verbose) message("  Combined OOS assets: ", ncol(R_oos_combined_dur) - 1, " portfolios")

      # Extract required objects from environment
      IS_AP_local <- get("IS_AP", envir = bswsp_dur_env)
      frequentist_models_local <- get("frequentist_models", envir = bswsp_dur_env)
      kns_out_local <- get("kns_out", envir = bswsp_dur_env)
      rp_out_local <- get("rp_out", envir = bswsp_dur_env)
      pca_out_local <- if (exists("pca_out", envir = bswsp_dur_env)) get("pca_out", envir = bswsp_dur_env) else NULL
      intercept_local <- get("intercept", envir = bswsp_dur_env)

      # Get f1, f2, fac_freq from data_list if available
      if (exists("data_list", envir = bswsp_dur_env)) {
        data_list_local <- get("data_list", envir = bswsp_dur_env)
        f1_local <- data_list_local$f1
        f2_local <- data_list_local$f2
        fac_freq_local <- data_list_local$fac_freq
        if (verbose) message("  Using data from data_list (f1, f2, fac_freq)")
      } else {
        f1_local <- get("f1", envir = bswsp_dur_env)
        f2_local <- if (exists("f2", envir = bswsp_dur_env)) get("f2", envir = bswsp_dur_env) else NULL
        fac_freq_local <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
        if (verbose) message("  Using f1/f2 from env, fac_freq from CSV")
      }

      if (verbose) {
        message("  f1: ", nrow(f1_local), " x ", ncol(f1_local))
        message("  f2: ", if(is.null(f2_local)) "NULL" else paste(nrow(f2_local), "x", ncol(f2_local)))
        message("  fac_freq: ", nrow(fac_freq_local), " x ", ncol(fac_freq_local))
      }

      # Run OOS pricing
      if (verbose) message("  Running os_asset_pricing()...")
      os_result_bswsp_dur <- os_asset_pricing(
        R_oss              = R_oos_combined_dur,
        IS_AP              = IS_AP_local,
        f1                 = f1_local,
        f2                 = f2_local,
        fac_freq           = fac_freq_local,
        frequentist_models = frequentist_models_local,
        kns_out            = kns_out_local,
        rp_out             = rp_out_local,
        pca_out            = pca_out_local,
        intercept          = intercept_local,
        verbose            = verbose
      )

      if (!is.null(os_result_bswsp_dur) && is.data.frame(os_result_bswsp_dur)) {
        dur_os_results$bond_stock_with_sp <- os_result_bswsp_dur
        if (verbose) message("  SUCCESS: ", ncol(os_result_bswsp_dur) - 1, " models evaluated")
      } else {
        warning("  os_asset_pricing returned NULL or invalid result")
      }

    }, error = function(e) {
      warning("  ERROR in bond_stock_with_sp duration OOS pricing: ", e$message)
      if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
    })
  }
} else {
  if (verbose) {
    message("  Skipping Panel C: missing requirements")
    message("    bswsp_dur_env: ", if(is.null(bswsp_dur_env)) "NULL" else "OK")
    message("    Rb_dur_oos: ", if(is.null(Rb_dur_oos)) "NULL" else "OK")
    message("    Rs_dur_oos: ", if(is.null(Rs_dur_oos)) "NULL" else "OK")
  }
}

# ---- Panel D: bond OS (duration) ----
if (verbose) message("\n--- Panel D: bond OOS (duration) ---")

if (!is.null(bond_dur_env) && !is.null(Rb_dur_oos)) {

  # Check required objects exist before proceeding
  required_objs_bond <- c("IS_AP", "f1", "kns_out", "rp_out", "frequentist_models", "intercept")
  missing_objs_bond <- required_objs_bond[!sapply(required_objs_bond, exists, envir = bond_dur_env)]

  if (length(missing_objs_bond) > 0) {
    warning("  Missing objects in bond duration: ", paste(missing_objs_bond, collapse = ", "))
    if (verbose) message("  Skipping Panel D due to missing objects")
  } else {

    tryCatch({
      if (verbose) message("  Bond OOS assets: ", ncol(Rb_dur_oos) - 1, " portfolios")

      # Extract required objects from environment
      IS_AP_local <- get("IS_AP", envir = bond_dur_env)
      frequentist_models_local <- get("frequentist_models", envir = bond_dur_env)
      kns_out_local <- get("kns_out", envir = bond_dur_env)
      rp_out_local <- get("rp_out", envir = bond_dur_env)
      pca_out_local <- if (exists("pca_out", envir = bond_dur_env)) get("pca_out", envir = bond_dur_env) else NULL
      intercept_local <- get("intercept", envir = bond_dur_env)

      # Get f1, f2, fac_freq from data_list if available
      if (exists("data_list", envir = bond_dur_env)) {
        data_list_local <- get("data_list", envir = bond_dur_env)
        f1_local <- data_list_local$f1
        f2_local <- data_list_local$f2
        fac_freq_local <- data_list_local$fac_freq
        if (verbose) message("  Using data from data_list (f1, f2, fac_freq)")
      } else {
        f1_local <- get("f1", envir = bond_dur_env)
        f2_local <- if (exists("f2", envir = bond_dur_env)) get("f2", envir = bond_dur_env) else NULL
        fac_freq_local <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
        if (verbose) message("  Using f1/f2 from env, fac_freq from CSV")
      }

      if (verbose) {
        message("  f1: ", nrow(f1_local), " x ", ncol(f1_local))
        message("  f2: ", if(is.null(f2_local)) "NULL" else paste(nrow(f2_local), "x", ncol(f2_local)))
        message("  fac_freq: ", nrow(fac_freq_local), " x ", ncol(fac_freq_local))
      }

      # Run OOS pricing
      if (verbose) message("  Running os_asset_pricing()...")
      os_result_bond_dur <- os_asset_pricing(
        R_oss              = Rb_dur_oos,
        IS_AP              = IS_AP_local,
        f1                 = f1_local,
        f2                 = f2_local,
        fac_freq           = fac_freq_local,
        frequentist_models = frequentist_models_local,
        kns_out            = kns_out_local,
        rp_out             = rp_out_local,
        pca_out            = pca_out_local,
        intercept          = intercept_local,
        verbose            = verbose
      )

      if (!is.null(os_result_bond_dur) && is.data.frame(os_result_bond_dur)) {
        dur_os_results$bond <- os_result_bond_dur
        if (verbose) message("  SUCCESS: ", ncol(os_result_bond_dur) - 1, " models evaluated")
      } else {
        warning("  os_asset_pricing returned NULL or invalid result")
      }

    }, error = function(e) {
      warning("  ERROR in bond duration OOS pricing: ", e$message)
      if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
    })
  }
} else {
  if (verbose) {
    message("  Skipping Panel D: missing requirements")
    message("    bond_dur_env: ", if(is.null(bond_dur_env)) "NULL" else "OK")
    message("    Rb_dur_oos: ", if(is.null(Rb_dur_oos)) "NULL" else "OK")
  }
}

# ---- Build Duration Pricing Table ----
if (verbose) message("\n--- Building Duration Pricing Table ---")

# Check if we have any results
has_dur_results <- !is.null(dur_is_results$bond_stock_with_sp) ||
                   !is.null(dur_is_results$bond) ||
                   !is.null(dur_os_results$bond_stock_with_sp) ||
                   !is.null(dur_os_results$bond)

if (!has_dur_results) {
  warning("  No duration pricing results available! Skipping duration table.")
} else {
  dur_latex_lines <- c(
    "\\begin{table}[tbp] ",
    "\\begin{center}",
    "\\caption{Cross-sectional asset pricing performance:  Duration-adjusted bond returns}\\label{tab:is_pricing_duration_baseline}",
    "\\resizebox{16.5cm}{!}{%",
    "\\begin{tabular}{lcccc|ccccccc}\\toprule",
    " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
    " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
  )

  # Panel A: In-sample co-pricing
  if (!is.null(dur_is_results$bond_stock_with_sp)) {
    dur_latex_lines <- c(dur_latex_lines,
                         "\\multicolumn{12}{c}{\\textbf{Panel A}: In-sample co-pricing stocks and bonds} \\\\ \\midrule",
                         build_pricing_panel_rows(dur_is_results$bond_stock_with_sp, model_cols),
                         "\\midrule")
    if (verbose) message("  Added Panel A: In-sample co-pricing")
  }

  # Panel B: In-sample pricing bonds
  if (!is.null(dur_is_results$bond)) {
    dur_latex_lines <- c(dur_latex_lines,
                         "\\multicolumn{12}{c}{\\textbf{Panel B}: In-sample pricing bonds} \\\\ \\midrule",
                         build_pricing_panel_rows(dur_is_results$bond, model_cols),
                         "\\midrule")
    if (verbose) message("  Added Panel B: In-sample pricing bonds")
  }

  # Panel C: Out-of-sample co-pricing
  if (!is.null(dur_os_results$bond_stock_with_sp)) {
    dur_latex_lines <- c(dur_latex_lines,
                         "\\multicolumn{12}{c}{\\textbf{Panel C}: Out-of-sample co-pricing stocks and bonds} \\\\ \\midrule",
                         build_pricing_panel_rows(dur_os_results$bond_stock_with_sp, model_cols),
                         "\\midrule")
    if (verbose) message("  Added Panel C: Out-of-sample co-pricing")
  }

  # Panel D: Out-of-sample pricing bonds
  if (!is.null(dur_os_results$bond)) {
    dur_latex_lines <- c(dur_latex_lines,
                         "\\multicolumn{12}{c}{\\textbf{Panel D}: Out-of-sample pricing bonds} \\\\ \\midrule",
                         build_pricing_panel_rows(dur_os_results$bond, model_cols))
    if (verbose) message("  Added Panel D: Out-of-sample pricing bonds")
  }

  # Close table
  dur_latex_lines <- c(dur_latex_lines,
                       "\\bottomrule",
                       "\\end{tabular}}",
                       "\\end{center}",
                       "\\begin{spacing}{0.80}",
                       "{\\footnotesize ",
                       "The table presents the cross-sectional in and out-of-sample asset pricing performance of different models pricing (duration-adjusted) bonds and stocks jointly (Panels A and C), and (duration-adjusted) bonds only (Panels B and D), respectively. ",
                       "For the BMA-SDF, we provide results for prior Sharpe ratio  values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the test assets. ",
                       "TOP includes the top five factors with an average posterior probability greater than 50\\%. ",
                       "CAPM is the standard single-factor model using MKTS, and CAPMB is the bond version using MKTB. ",
                       "FF5 is the five-factor model of \\cite{FamaFrench_1993}, HKM is the two-factor model of \\citet{HeKellyManela_2017}. ",
                       "KNS stands for the SDF estimation of \\citet{KozakNagelSantosh_2020} and RPPCA is the  risk premia PCA of \\cite{LettauPelger_2020}. ",
                       "Estimation details for the benchmark models are given in Appendix \\ref{sec:benchmark_models}.",
                       "Bond returns are computed in excess of a duration matched portfolio of U.S. Treasury bonds.",
                       "In Panels A and B the models are estimated with the respective factor zoos and test assets.  The resulting SDF is then used to price (with no additional parameter estimation) the two sets of the OS assets in Panels C and D.    ",
                       "IS test assets are the 83 bond and stock portfolios and the 40 tradable bond and stock factors (Panel A), and the 50 bond portfolios and  16 tradable bond factors (Panel B), respectively. ",
                       "OS test assets are the combined 154 bond and stock portfolios (Panel C), as well as the 77 bond portfolios only (Panel D). ",
                       "All are described in Section \\ref{sec:data}. ",
                       "All data is standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                       "}",
                       "",
                       "",
                       "\\end{spacing}",
                       "\\end{table} ")

  # Write output
  dur_tex_path <- file.path(tables_dir, "table_duration_pricing.tex")
  writeLines(dur_latex_lines, dur_tex_path)
  if (verbose) message("  Saved: ", dur_tex_path)
}

# Clean up duration environments
if (exists("bswsp_dur_env") && !is.null(bswsp_dur_env)) rm(bswsp_dur_env)
if (exists("bond_dur_env") && !is.null(bond_dur_env)) rm(bond_dur_env)
gc(verbose = FALSE)


###############################################################################
## SECTION 5.6: TREASURY MODEL FIGURES AND TABLE
###############################################################################
# Generate Figures and Tables for Treasury component:
# - Posterior probability figure (like Figure 2)
# - Posterior probability table (like Table A.2)
# - Number of factors & SR distribution figure (like Figure 3)
# - Bar plots of posterior probabilities & risk prices (like Figure 4)
# - SR decomposition table (like Table 4, nontradable vs tradable)
# Uses treasury model from ia/output/unconditional/treasury/

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 6: Treasury Model Figures and Table")
  message(strrep("=", 60))
}

# Treasury model path
treasury_rdata_path <- file.path(
  "ia/output/unconditional/treasury",
  "excess_treasury_alpha.w=1_beta.w=1_kappa=0_bond_treasury.Rdata"
)

# Track if we assigned global variables (for cleanup)
treasury_globals_assigned <- FALSE

# Helper function to clean up treasury global variables
cleanup_treasury_globals <- function() {
  globals_to_clean <- c("f1", "f2", "intercept", "nontraded_names", "bond_names", "stock_names")
  for (g in globals_to_clean) {
    if (exists(g, envir = .GlobalEnv)) {
      rm(list = g, envir = .GlobalEnv)
      if (verbose) message("  Cleaned up global: ", g)
    }
  }
}

if (!file.exists(treasury_rdata_path)) {
  warning("Treasury model not found: ", treasury_rdata_path)
  if (verbose) message("  Skipping Treasury figures and table.")
} else {
  if (verbose) message("  Loading: ", treasury_rdata_path)

  # Load treasury model into environment
  treasury_env <- new.env()
  load_success <- tryCatch({
    load(treasury_rdata_path, envir = treasury_env)
    TRUE
  }, error = function(e) {
    warning("  Failed to load treasury .Rdata: ", e$message)
    FALSE
  })

  if (!load_success) {
    if (verbose) message("  Skipping Treasury due to load failure")
  } else {
    # List what was loaded
    loaded_objects <- ls(envir = treasury_env)
    if (verbose) message("  Loaded objects: ", paste(loaded_objects, collapse = ", "))

    # Check required objects
    treasury_required <- c("results", "f1", "intercept")
    treasury_missing <- treasury_required[!sapply(treasury_required, exists, envir = treasury_env)]

    if (length(treasury_missing) > 0) {
      warning("  Missing objects in treasury model: ", paste(treasury_missing, collapse = ", "))
      if (verbose) message("  Skipping Treasury due to missing objects")
    } else {

      # Extract objects from environment
      f1_treasury <- get("f1", envir = treasury_env)
      f2_treasury <- if (exists("f2", envir = treasury_env)) get("f2", envir = treasury_env) else NULL
      intercept_treasury <- get("intercept", envir = treasury_env)
      results_treasury <- get("results", envir = treasury_env)

      # Extract factor name vectors (used by pp_bar_plots)
      # Use what's in the .Rdata file, or derive from f1/f2 columns as fallback
      nontraded_names_treasury <- if (exists("nontraded_names", envir = treasury_env)) {
        get("nontraded_names", envir = treasury_env)
      } else {
        colnames(f1_treasury)  # fallback: all f1 columns are non-traded
      }
      bond_names_treasury <- if (exists("bond_names", envir = treasury_env)) {
        get("bond_names", envir = treasury_env)
      } else {
        character(0)  # fallback: no bond factors
      }
      stock_names_treasury <- if (exists("stock_names", envir = treasury_env)) {
        get("stock_names", envir = treasury_env)
      } else {
        character(0)  # fallback: no stock factors
      }

      # Log dimensions
      if (verbose) {
        message("  f1 dimensions: ", nrow(f1_treasury), " x ", ncol(f1_treasury))
        message("  f2 dimensions: ", if(is.null(f2_treasury)) "NULL" else paste(nrow(f2_treasury), "x", ncol(f2_treasury)))
        message("  intercept: ", intercept_treasury)
        message("  results: ", length(results_treasury), " prior levels")
        message("  gamma_path dimensions: ", nrow(results_treasury[[1]]$gamma_path), " x ", ncol(results_treasury[[1]]$gamma_path))
        message("  nontraded_names: ", length(nontraded_names_treasury), " factors")
        message("  bond_names: ", length(bond_names_treasury), " factors")
        message("  stock_names: ", length(stock_names_treasury), " factors")
      }

      # Temporarily assign to global for pp_figure_table and pp_bar_plots (they use get with inherits=TRUE)
      # Use on.exit to ensure cleanup even if errors occur
      assign("f1", f1_treasury, envir = .GlobalEnv)
      assign("f2", f2_treasury, envir = .GlobalEnv)
      assign("intercept", intercept_treasury, envir = .GlobalEnv)
      assign("nontraded_names", nontraded_names_treasury, envir = .GlobalEnv)
      assign("bond_names", bond_names_treasury, envir = .GlobalEnv)
      assign("stock_names", stock_names_treasury, envir = .GlobalEnv)
      treasury_globals_assigned <- TRUE

      # Ensure cleanup happens on exit from this block
      on.exit(cleanup_treasury_globals(), add = TRUE)

      # ---- Figure + Table: Posterior Probabilities (Treasury) ----
      if (verbose) message("\n--- Treasury: Posterior Probabilities Figure + Table ---")

      tryCatch({
        if (verbose) message("  Calling pp_figure_table()...")
        treasury_pp_result <- pp_figure_table(
          results       = results_treasury,
          return_type   = "excess",
          model_type    = "treasury",
          tag           = "bond_treasury",
          alpha.w       = alpha.w,
          beta.w        = beta.w,
          main_path     = paper_output,
          output_folder = "figures",
          table_folder  = "tables",
          # Custom caption for Treasury
          table_caption = "Posterior factor probabilities and risk prices: Treasury component",
          table_label   = "tab:treasury-posterior-probs",
          table_name    = "table_treasury_posterior_probs",
          verbose       = verbose
        )

        if (!is.null(treasury_pp_result)) {
          if (verbose) {
            message("  SUCCESS: Posterior probability figure + table generated")
            message("  Figure saved: ", treasury_pp_result$fig_file)
            message("  Table saved:  ", treasury_pp_result$tex_file)
          }
        } else {
          warning("  pp_figure_table returned NULL")
        }
      }, error = function(e) {
        warning("  ERROR in Treasury posterior probability figure/table: ", e$message)
        if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
      })

      # ---- Figure: Number of Factors & Sharpe Ratio (Treasury) ----
      if (verbose) message("\n--- Treasury: Number of Factors & Sharpe Ratio Figure ---")

      # Check if sdf_path exists
      if (is.null(results_treasury[[1]]$sdf_path)) {
        warning("  results$sdf_path not found. Skipping Treasury nfac/SR figure.")
        if (verbose) message("  (SDF tracking may not have been enabled during MCMC)")
      } else {
        if (verbose) message("  sdf_path found, proceeding with nfac/SR figure...")

        tryCatch({
          if (verbose) message("  Calling plot_nfac_sr()...")
          treasury_nfac_result <- plot_nfac_sr(
            results       = results_treasury,
            return_type   = "excess",
            model_type    = "treasury",
            tag           = "bond_treasury",
            prior_labels  = c("20%", "40%", "60%", "80%"),
            prior_choice  = "80%",
            main_path     = paper_output,
            output_folder = "figures",
            verbose       = verbose
          )

          if (!is.null(treasury_nfac_result)) {
            if (verbose) {
              message("  SUCCESS: nfac/SR figure generated")
              message("  Figure saved: ", treasury_nfac_result$fig_file)
              message("  Prior used: ", treasury_nfac_result$prior_used)
              message("  N factors [2.5%, 50%, 97.5%]: ",
                      paste(round(treasury_nfac_result$n_factors_summary, 1), collapse = ", "))
              message("  SR [5%, 95%]: ",
                      paste(round(treasury_nfac_result$sr_summary, 3), collapse = ", "))
            }
          } else {
            warning("  plot_nfac_sr returned NULL")
          }
        }, error = function(e) {
          warning("  ERROR in Treasury nfac/SR figure: ", e$message)
          if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
        })
      }

      # ---- Figure: Posterior Probabilities Bar Plots (Treasury) ----
      # Equivalent to Figure 4 in the main paper
      if (verbose) message("\n--- Treasury: Posterior Probabilities Bar Plots (Figure 4 equivalent) ---")

      tryCatch({
        if (verbose) {
          message("  Calling pp_bar_plots()...")
          message("  Using global vars: f1, f2, nontraded_names, bond_names, stock_names")
        }

        treasury_bar_result <- pp_bar_plots(
          results       = results_treasury,
          return_type   = "excess",
          model_type    = "treasury",
          tag           = "bond_treasury",
          prior_labels  = c("20%", "40%", "60%", "80%"),
          prior_choice  = "80%",
          # Custom panel titles for Treasury
          panelA_title  = "(A)  Posterior probabilities",
          panelB_title  = "(B)  Posterior market prices of risk",
          main_path     = paper_output,
          output_folder = "figures",
          verbose       = verbose
        )

        if (!is.null(treasury_bar_result)) {
          if (verbose) {
            message("  SUCCESS: Bar plots figure generated")
            message("  Figure saved: ", treasury_bar_result$fig_file)
            message("  Prior used: ", treasury_bar_result$prior_used)
            message("  N factors: ", treasury_bar_result$n_factors)
            message("  Factor types: ", paste(names(treasury_bar_result$factor_types),
                                               treasury_bar_result$factor_types,
                                               sep = "=", collapse = ", "))
          }
        } else {
          warning("  pp_bar_plots returned NULL")
        }
      }, error = function(e) {
        warning("  ERROR in Treasury bar plots figure: ", e$message)
        if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
      })

      # ---- Table: SR Decomposition (Treasury) ----
      # Equivalent to Table 4 in the main paper but for treasury component only
      if (verbose) message("\n--- Treasury: SR Decomposition Table ---")

      tryCatch({
        if (verbose) {
          message("  Calling sr_decomposition()...")
          message("  Using global vars: f1, f2, intercept, nontraded_names, bond_names, stock_names")
        }

        # Run SR decomposition for treasury model
        # Note: requires f1, f2, intercept, nontraded_names, bond_names, stock_names in global env
        treasury_sr_decomp <- sr_decomposition(
          results      = results_treasury,
          prior_labels = c("20%", "40%", "60%", "80%"),
          dr_cf_decomp = NULL,  # No DR/CF decomposition for treasury
          top_factors  = 5
        )

        if (verbose) {
          message("  SR decomposition complete: ", nrow(treasury_sr_decomp), " rows")
          message("  Factor types found: ",
                  paste(unique(treasury_sr_decomp$factor_type), collapse = ", "))
        }

        # Generate the LaTeX table
        if (verbose) message("  Calling generate_table_treasury_sr()...")

        treasury_sr_table_result <- generate_table_treasury_sr(
          sr_decomp_data = treasury_sr_decomp,
          output_path    = tables_dir,
          table_name     = "table_treasury_sr_decomp.tex",
          n_nontraded    = length(nontraded_names_treasury),
          n_traded       = length(bond_names_treasury) + length(stock_names_treasury),
          verbose        = verbose
        )

        if (!is.null(treasury_sr_table_result)) {
          if (verbose) {
            message("  SUCCESS: SR decomposition table generated")
            message("  Table saved to: ", tables_dir, "/table_treasury_sr_decomp.tex")
          }
        } else {
          warning("  generate_table_treasury_sr returned NULL")
        }
      }, error = function(e) {
        warning("  ERROR in Treasury SR decomposition table: ", e$message)
        if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
      })

      # Note: cleanup_treasury_globals() will be called automatically via on.exit()
    }

    # Clean up treasury environment
    rm(treasury_env)
  }

  gc(verbose = FALSE)
}

# Final check: ensure globals are cleaned up (belt and suspenders)
if (treasury_globals_assigned) {
  cleanup_treasury_globals()
}


###############################################################################
## SECTION 5.7: TREASURY WEIGHTED MODEL (DR-TILT) FIGURE
###############################################################################
# Generate Figure 4 equivalent for the treasury model with DR-tilt kappa weights.
# This requires the weighted estimation to have been run via:
#   Rscript ia/_run_treasury_weighted.R
#
# Output: figure_4_posterior_bars_excess_treasury_bond_treasury_dr_tilt.pdf

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 7: Treasury Weighted (DR-Tilt) Figure")
  message(strrep("=", 60))
}

# Path to weighted treasury model
treasury_weighted_rdata_path <- file.path(
  "ia/output/unconditional/treasury",
  "excess_treasury_alpha.w=1_beta.w=1_kappa=weighted_bond_treasury.Rdata"
)

# Track globals for cleanup
treasury_wt_globals_assigned <- FALSE

# Helper function to clean up weighted treasury global variables
cleanup_treasury_wt_globals <- function() {
  globals_to_clean <- c("f1", "f2", "intercept", "nontraded_names", "bond_names", "stock_names")
  for (g in globals_to_clean) {
    if (exists(g, envir = .GlobalEnv)) {
      rm(list = g, envir = .GlobalEnv)
      if (verbose) message("  Cleaned up global: ", g)
    }
  }
}

if (!file.exists(treasury_weighted_rdata_path)) {
  warning("Treasury weighted model not found: ", treasury_weighted_rdata_path)
  if (verbose) {
    message("  Skipping Treasury DR-Tilt figure.")
    message("  To generate, run: Rscript ia/_run_ia_estimation.R --models=7")
  }
} else {
  if (verbose) message("  Loading: ", treasury_weighted_rdata_path)

  # Load weighted treasury model into environment
  treasury_wt_env <- new.env()
  load_success <- tryCatch({
    load(treasury_weighted_rdata_path, envir = treasury_wt_env)
    TRUE
  }, error = function(e) {
    warning("  Failed to load treasury weighted .Rdata: ", e$message)
    FALSE
  })

  if (!load_success) {
    if (verbose) message("  Skipping Treasury DR-Tilt due to load failure")
  } else {
    # List what was loaded
    loaded_objects <- ls(envir = treasury_wt_env)
    if (verbose) message("  Loaded objects: ", paste(loaded_objects, collapse = ", "))

    # Check required objects
    treasury_wt_required <- c("results", "f1", "intercept")
    treasury_wt_missing <- treasury_wt_required[!sapply(treasury_wt_required, exists, envir = treasury_wt_env)]

    if (length(treasury_wt_missing) > 0) {
      warning("  Missing objects: ", paste(treasury_wt_missing, collapse = ", "))
      if (verbose) message("  Skipping Treasury DR-Tilt due to missing objects")
    } else {

      # Extract objects from environment
      f1_treasury_wt <- get("f1", envir = treasury_wt_env)
      f2_treasury_wt <- if (exists("f2", envir = treasury_wt_env)) get("f2", envir = treasury_wt_env) else NULL
      intercept_treasury_wt <- get("intercept", envir = treasury_wt_env)
      results_treasury_wt <- get("results", envir = treasury_wt_env)

      # Extract factor name vectors (with fallbacks)
      nontraded_names_treasury_wt <- if (exists("nontraded_names", envir = treasury_wt_env)) {
        get("nontraded_names", envir = treasury_wt_env)
      } else {
        colnames(f1_treasury_wt)
      }
      bond_names_treasury_wt <- if (exists("bond_names", envir = treasury_wt_env)) {
        get("bond_names", envir = treasury_wt_env)
      } else {
        character(0)
      }
      stock_names_treasury_wt <- if (exists("stock_names", envir = treasury_wt_env)) {
        get("stock_names", envir = treasury_wt_env)
      } else {
        character(0)
      }

      # Log dimensions
      if (verbose) {
        message("  f1 dimensions: ", nrow(f1_treasury_wt), " x ", ncol(f1_treasury_wt))
        message("  f2 dimensions: ", if(is.null(f2_treasury_wt)) "NULL" else paste(nrow(f2_treasury_wt), "x", ncol(f2_treasury_wt)))
        message("  intercept: ", intercept_treasury_wt)
        message("  results: ", length(results_treasury_wt), " prior levels")
        message("  nontraded_names: ", length(nontraded_names_treasury_wt), " factors")
        message("  bond_names: ", length(bond_names_treasury_wt), " factors")
        message("  stock_names: ", length(stock_names_treasury_wt), " factors")
      }

      # Assign to global environment for pp_bar_plots
      assign("f1", f1_treasury_wt, envir = .GlobalEnv)
      assign("f2", f2_treasury_wt, envir = .GlobalEnv)
      assign("intercept", intercept_treasury_wt, envir = .GlobalEnv)
      assign("nontraded_names", nontraded_names_treasury_wt, envir = .GlobalEnv)
      assign("bond_names", bond_names_treasury_wt, envir = .GlobalEnv)
      assign("stock_names", stock_names_treasury_wt, envir = .GlobalEnv)
      treasury_wt_globals_assigned <- TRUE

      # Ensure cleanup on exit
      on.exit(cleanup_treasury_wt_globals(), add = TRUE)

      # ---- Figure: Posterior Probabilities Bar Plots (Treasury DR-Tilt) ----
      if (verbose) message("\n--- Treasury DR-Tilt: Posterior Probabilities Bar Plots ---")

      tryCatch({
        if (verbose) {
          message("  Calling pp_bar_plots()...")
        }

        treasury_wt_bar_result <- pp_bar_plots(
          results       = results_treasury_wt,
          return_type   = "excess",
          model_type    = "treasury",
          tag           = "bond_treasury_dr_tilt",  # Different tag for weighted version
          prior_labels  = c("20%", "40%", "60%", "80%"),
          prior_choice  = "80%",
          panelA_title  = "(A)  Posterior probabilities",
          panelB_title  = "(B)  Posterior market prices of risk",
          main_path     = paper_output,
          output_folder = "figures",
          verbose       = verbose
        )

        if (!is.null(treasury_wt_bar_result)) {
          if (verbose) {
            message("  SUCCESS: Bar plots figure generated")
            message("  Figure saved: ", treasury_wt_bar_result$fig_file)
            message("  Prior used: ", treasury_wt_bar_result$prior_used)
            message("  N factors: ", treasury_wt_bar_result$n_factors)
            message("  Factor types: ", paste(names(treasury_wt_bar_result$factor_types),
                                               treasury_wt_bar_result$factor_types,
                                               sep = "=", collapse = ", "))
          }
        } else {
          warning("  pp_bar_plots returned NULL")
        }
      }, error = function(e) {
        warning("  ERROR in Treasury DR-Tilt bar plots figure: ", e$message)
        if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
      })
    }

    # Clean up environment
    rm(treasury_wt_env)
  }

  gc(verbose = FALSE)
}

# Final cleanup for weighted treasury globals
if (treasury_wt_globals_assigned) {
  cleanup_treasury_wt_globals()
}


###############################################################################
## SECTION 5.8: SPARSE JOINT MODEL (SPARSITY-INDUCING PRIOR)
###############################################################################
# Generate tables for the sparse joint model (bond_stock_with_sp with sparsity prior):
# - Table: Posterior factor probabilities and risk prices -- imposing sparsity
# - Table: Asset pricing performance with two panels:
#   - Panel A: In-sample co-pricing bonds and stocks
#   - Panel B: Out-of-sample co-pricing bonds and stocks (Rs and Rb)
#
# Uses estimation with beta_params_auto_sd(5, 54) -> alpha.w ≈ 3.54, beta.w ≈ 34.66
# Expected output file: excess_bond_stock_with_sp_alpha.w=3_beta.w=34_kappa=0_baseline.Rdata

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 8: Sparse Joint Model (Sparsity-Inducing Prior)")
  message(strrep("=", 60))
}

# Sparse model parameters (from beta_params_auto_sd(5, 54))
sparse_alpha_w <- 3  # trunc(3.537037)
sparse_beta_w <- 34  # trunc(34.662963)

# Construct path to sparse model .Rdata
sparse_rdata_path <- file.path(
  results_path, "bond_stock_with_sp",
  sprintf("excess_bond_stock_with_sp_alpha.w=%d_beta.w=%d_kappa=0_baseline.Rdata",
          sparse_alpha_w, sparse_beta_w)
)

# Track globals for cleanup
sparse_globals_assigned <- FALSE

# Helper function to clean up sparse model global variables
cleanup_sparse_globals <- function() {
  globals_to_clean <- c("f1", "f2", "intercept", "nontraded_names", "bond_names", "stock_names")
  for (g in globals_to_clean) {
    if (exists(g, envir = .GlobalEnv)) {
      rm(list = g, envir = .GlobalEnv)
      if (verbose) message("  Cleaned up global: ", g)
    }
  }
}

if (!file.exists(sparse_rdata_path)) {
  warning("Sparse joint model not found: ", sparse_rdata_path)
  if (verbose) {
    message("  Skipping Sparse model tables.")
    message("  To generate, run: Rscript ia/_run_ia_estimation.R --models=8")
  }
} else {
  if (verbose) message("  Loading: ", sparse_rdata_path)

  # Load sparse model into environment
  sparse_env <- new.env()
  load_success <- tryCatch({
    load(sparse_rdata_path, envir = sparse_env)
    TRUE
  }, error = function(e) {
    warning("  Failed to load sparse .Rdata: ", e$message)
    FALSE
  })

  if (!load_success) {
    if (verbose) message("  Skipping Sparse model due to load failure")
  } else {
    # List what was loaded
    loaded_objects <- ls(envir = sparse_env)
    if (verbose) message("  Loaded objects: ", paste(head(loaded_objects, 20), collapse = ", "), if(length(loaded_objects) > 20) "..." else "")

    # Check required objects
    sparse_required <- c("results", "f1", "f2", "intercept", "IS_AP", "kns_out", "rp_out", "frequentist_models")
    sparse_missing <- sparse_required[!sapply(sparse_required, exists, envir = sparse_env)]

    if (length(sparse_missing) > 0) {
      warning("  Missing objects in sparse model: ", paste(sparse_missing, collapse = ", "))
      if (verbose) message("  Skipping Sparse model due to missing objects")
    } else {

      # Extract objects from environment
      f1_sparse <- get("f1", envir = sparse_env)
      f2_sparse <- get("f2", envir = sparse_env)
      intercept_sparse <- get("intercept", envir = sparse_env)
      results_sparse <- get("results", envir = sparse_env)
      IS_AP_sparse <- get("IS_AP", envir = sparse_env)
      kns_out_sparse <- get("kns_out", envir = sparse_env)
      rp_out_sparse <- get("rp_out", envir = sparse_env)
      pca_out_sparse <- if (exists("pca_out", envir = sparse_env)) get("pca_out", envir = sparse_env) else NULL
      frequentist_models_sparse <- get("frequentist_models", envir = sparse_env)

      # Extract factor name vectors
      nontraded_names_sparse <- if (exists("nontraded_names", envir = sparse_env)) {
        get("nontraded_names", envir = sparse_env)
      } else {
        colnames(f1_sparse)
      }
      bond_names_sparse <- if (exists("bond_names", envir = sparse_env)) {
        get("bond_names", envir = sparse_env)
      } else {
        character(0)
      }
      stock_names_sparse <- if (exists("stock_names", envir = sparse_env)) {
        get("stock_names", envir = sparse_env)
      } else {
        character(0)
      }

      # Log dimensions
      if (verbose) {
        message("  f1 dimensions: ", nrow(f1_sparse), " x ", ncol(f1_sparse))
        message("  f2 dimensions: ", nrow(f2_sparse), " x ", ncol(f2_sparse))
        message("  intercept: ", intercept_sparse)
        message("  results: ", length(results_sparse), " prior levels")
        message("  nontraded_names: ", length(nontraded_names_sparse), " factors")
        message("  bond_names: ", length(bond_names_sparse), " factors")
        message("  stock_names: ", length(stock_names_sparse), " factors")
      }

      # Assign to global environment for pp_figure_table
      assign("f1", f1_sparse, envir = .GlobalEnv)
      assign("f2", f2_sparse, envir = .GlobalEnv)
      assign("intercept", intercept_sparse, envir = .GlobalEnv)
      assign("nontraded_names", nontraded_names_sparse, envir = .GlobalEnv)
      assign("bond_names", bond_names_sparse, envir = .GlobalEnv)
      assign("stock_names", stock_names_sparse, envir = .GlobalEnv)
      sparse_globals_assigned <- TRUE

      # Ensure cleanup on exit
      on.exit(cleanup_sparse_globals(), add = TRUE)

      # ---- Table: Posterior Probabilities (Sparse) ----
      if (verbose) message("\n--- Sparse Model: Posterior Probabilities Table ---")

      tryCatch({
        if (verbose) message("  Calling pp_figure_table()...")
        sparse_pp_result <- pp_figure_table(
          results       = results_sparse,
          return_type   = "excess",
          model_type    = "bond_stock_with_sp",
          tag           = "baseline",
          alpha.w       = sparse_alpha_w,
          beta.w        = sparse_beta_w,
          main_path     = paper_output,
          output_folder = "figures",
          table_folder  = "tables",
          # Custom caption for Sparse model
          table_caption = "Posterior factor probabilities and risk prices -- imposing sparsity",
          table_label   = "tab:sparse-posterior-probs",
          table_name    = "table_sparse_posterior_probs",
          verbose       = verbose
        )

        if (!is.null(sparse_pp_result)) {
          if (verbose) {
            message("  SUCCESS: Posterior probability figure + table generated")
            message("  Figure saved: ", sparse_pp_result$fig_file)
            message("  Table saved:  ", sparse_pp_result$tex_file)
          }
        } else {
          warning("  pp_figure_table returned NULL")
        }
      }, error = function(e) {
        warning("  ERROR in Sparse posterior probability table: ", e$message)
        if (verbose) message("  Stack trace: ", paste(capture.output(traceback()), collapse = "\n"))
      })

      # ---- Table: Asset Pricing (Sparse) ----
      # Panel A: In-sample, Panel B: Out-of-sample
      if (verbose) message("\n--- Sparse Model: Asset Pricing Table ---")

      # Collect IS results
      sparse_is_result <- NULL
      sparse_os_result <- NULL

      # In-sample from IS_AP
      if (!is.null(IS_AP_sparse$is_pricing_result)) {
        sparse_is_result <- IS_AP_sparse$is_pricing_result
        if (verbose) message("  IS pricing: ", ncol(sparse_is_result) - 1, " models")
      }

      # Out-of-sample: combine Rb and Rs OOS assets
      if (verbose) message("\n  Computing out-of-sample pricing...")

      # Read OOS test assets
      bond_oos_file_sparse <- file.path(data_folder, "bond_oosample_all_excess.csv")
      stock_oos_file_sparse <- file.path(data_folder, "equity_os_77.csv")

      Rb_oos_sparse <- if (file.exists(bond_oos_file_sparse)) {
        read.csv(bond_oos_file_sparse, check.names = FALSE)
      } else NULL

      Rs_oos_sparse <- if (file.exists(stock_oos_file_sparse)) {
        read.csv(stock_oos_file_sparse, check.names = FALSE)
      } else NULL

      if (!is.null(Rb_oos_sparse) && !is.null(Rs_oos_sparse)) {
        # Combine bond and stock OOS assets
        R_oos_combined_sparse <- cbind(Rb_oos_sparse, Rs_oos_sparse[, -1, drop = FALSE])
        if (verbose) message("  Combined OOS assets: ", ncol(R_oos_combined_sparse) - 1, " portfolios")

        # Get fac_freq
        if (exists("data_list", envir = sparse_env)) {
          data_list_sparse <- get("data_list", envir = sparse_env)
          fac_freq_sparse <- data_list_sparse$fac_freq
        } else {
          fac_freq_sparse <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
        }

        # Run OOS pricing
        tryCatch({
          if (verbose) message("  Running os_asset_pricing()...")
          sparse_os_result <- os_asset_pricing(
            R_oss              = R_oos_combined_sparse,
            IS_AP              = IS_AP_sparse,
            f1                 = f1_sparse,
            f2                 = f2_sparse,
            fac_freq           = fac_freq_sparse,
            frequentist_models = frequentist_models_sparse,
            kns_out            = kns_out_sparse,
            rp_out             = rp_out_sparse,
            pca_out            = pca_out_sparse,
            intercept          = intercept_sparse,
            verbose            = verbose
          )

          if (!is.null(sparse_os_result) && is.data.frame(sparse_os_result)) {
            if (verbose) message("  SUCCESS: OOS pricing computed - ", ncol(sparse_os_result) - 1, " models")
          } else {
            warning("  os_asset_pricing returned NULL or invalid result")
            sparse_os_result <- NULL
          }
        }, error = function(e) {
          warning("  ERROR in Sparse OOS pricing: ", e$message)
          sparse_os_result <<- NULL
        })
      } else {
        warning("  OOS test assets not available for Sparse model")
      }

      # ---- Build the 2-panel pricing table ----
      if (!is.null(sparse_is_result) || !is.null(sparse_os_result)) {
        if (verbose) message("\n  Building Sparse Asset Pricing Table...")

        sparse_latex_lines <- c(
          "\\begin{table}[tbh!]",
          "\\begin{center}",
          "\\caption{Cross-sectional asset pricing performance -- imposing sparsity}\\label{tab:sparse-pricing}\\vspace{-2mm}",
          "\\scalebox{.8}{",
          "\\begin{tabular}{lcccc|ccccccc}\\toprule",
          " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
          " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
        )

        # Panel A: In-sample co-pricing
        if (!is.null(sparse_is_result)) {
          sparse_latex_lines <- c(sparse_latex_lines,
                                  "\\multicolumn{12}{c}{\\textbf{Panel A}: In-sample co-pricing bonds and stocks} \\\\ \\midrule",
                                  build_pricing_panel_rows(sparse_is_result, model_cols),
                                  "\\midrule")
          if (verbose) message("  Added Panel A: In-sample co-pricing")
        }

        # Panel B: Out-of-sample co-pricing
        if (!is.null(sparse_os_result)) {
          sparse_latex_lines <- c(sparse_latex_lines,
                                  "\\multicolumn{12}{c}{\\textbf{Panel B}: Out-of-sample co-pricing bonds and stocks} \\\\ \\midrule",
                                  build_pricing_panel_rows(sparse_os_result, model_cols))
          if (verbose) message("  Added Panel B: Out-of-sample co-pricing")
        }

        sparse_latex_lines <- c(sparse_latex_lines,
                                "\\bottomrule",
                                "\\end{tabular}",
                                "}",
                                "\\end{center}",
                                "\\begin{spacing}{1}",
                                "{\\footnotesize",
                                "The table presents the cross-sectional in-sample (Panel A) and out-of-sample (Panel B) asset pricing performance of the co-pricing model estimated with a sparsity-inducing prior.",
                                sprintf("The prior uses $\\\\alpha_w = %d$ and $\\\\beta_w = %d$, corresponding to an expected %d active factors out of %d total factors.",
                                        sparse_alpha_w, sparse_beta_w, 5, 54),
                                "For the BMA-SDF, we provide results for prior Sharpe ratio values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the test assets.",
                                "TOP includes the top five factors with an average posterior probability greater than 50\\%.",
                                "Out-of-sample test assets are the combined 154 bond and stock portfolios.",
                                "All data are standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                                "}",
                                "\\end{spacing}",
                                "\\vspace{-4mm}",
                                "\\end{table}")

        sparse_tex_path <- file.path(tables_dir, "table_sparse_pricing.tex")
        writeLines(sparse_latex_lines, sparse_tex_path)
        if (verbose) message("  Saved: ", sparse_tex_path)
      } else {
        warning("  No pricing results available for Sparse model. Skipping pricing table.")
      }
    }

    # Clean up environment
    rm(sparse_env)
  }

  gc(verbose = FALSE)
}

# Final cleanup for sparse model globals
if (sparse_globals_assigned) {
  cleanup_sparse_globals()
}


###############################################################################
## CLEANUP
###############################################################################

# Close any remaining graphics devices
if (length(dev.list()) > 0) graphics.off()

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("INTERNET APPENDIX RESULTS COMPLETE")
  message(strrep("=", 60))
  message("\nOutputs saved to:")
  message("  Tables:  ", tables_dir)
  message("  Figures: ", figures_dir)
  message("\nNext step: Run ia/_create_ia_latex.R to compile LaTeX document")
}
