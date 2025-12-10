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
##     - Posterior probabilities & risk prices for ALL 5 models
##     - Table 2 equivalent (IS pricing) for joint_no_intercept
##     - Table 3 equivalent (OS pricing) for joint_no_intercept
##
##   Figures:
##     - Figure 2 equivalent for joint_no_intercept
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
source(file.path(code_folder, "insample_asset_pricing.R"))
source(file.path(code_folder, "outsample_asset_pricing.R"))  # provides os_asset_pricing()
source(file.path(code_folder, "plot_cumulative_sr.R"))

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

  # Model columns in order (matching table header)
  model_cols <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                  "CAPM", "CAPMB", "FF5", "HKM",
                  "Top-80%-All", "KNS", "RP-PCA")

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
# This requires running os_asset_pricing for each model
# For now, we check if the results already exist in the .Rdata files

if (verbose) message("\nGenerating Table IA.7: Out-of-Sample Pricing (No Intercept)...")

# We need to properly run OOS pricing by loading each model and running os_asset_pricing
# This is more complex - let's load the joint model into global and run pricing

joint_model <- pricing_models$joint
joint_rdata_path <- get_rdata_path(joint_model, results_path)

if (file.exists(joint_rdata_path)) {

  # Clear and load into global environment
  load(joint_rdata_path, envir = .GlobalEnv)

  # Source the OOS pricing function if not already available
  if (!exists("os_asset_pricing")) {
    source(file.path(code_folder, "outsample_asset_pricing.R"))
  }

  # Check if we can run OOS pricing
  if (exists("IS_AP") && exists("results") && exists("f1")) {

    tryCatch({
      # Load OOS test assets
      bond_oos_file <- file.path(data_folder, "bond_oosample_all_excess.csv")
      stock_oos_file <- file.path(data_folder, "equity_os_77.csv")

      if (file.exists(bond_oos_file) && file.exists(stock_oos_file)) {
        Rb_oos <- read.csv(bond_oos_file, check.names = FALSE)
        Rs_oos <- read.csv(stock_oos_file, check.names = FALSE)[, -1, drop = FALSE]
        R_oos <- cbind(Rb_oos, Rs_oos)

        # Run OOS pricing
        os_result <- os_asset_pricing(
          IS_AP      = IS_AP,
          R_oos_data = R_oos,
          f1         = f1,
          f2         = if (exists("f2")) f2 else NULL,
          intercept  = FALSE,  # No intercept for IA
          weighting  = "GLS",
          verbose    = verbose
        )

        if (!is.null(os_result) && !is.null(os_result$os_pricing_result)) {
          # Build OOS pricing table
          os_pricing <- os_result$os_pricing_result

          os_latex_lines <- c(
            "\\begin{table}[tbh!]",
            "\\begin{center}",
            "\\caption{Out-of-sample cross-sectional asset pricing performance (no intercept)}\\label{tab:ia-os-pricing}\\vspace{-2mm}",
            "\\scalebox{.8}{",
            "\\begin{tabular}{lcccc|ccccccc}\\toprule",
            " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
            " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule",
            "\\multicolumn{12}{c}{\\textbf{Panel A:} Co-pricing bonds and stocks out-of-sample} \\\\ \\midrule"
          )

          os_latex_lines <- c(os_latex_lines, build_pricing_panel_rows(os_pricing, model_cols))

          os_latex_lines <- c(os_latex_lines,
                              " \\bottomrule",
                              "\\end{tabular}",
                              "}",
                              "\\end{center}",
                              "\\begin{spacing}{1}",
                              "\t{\\footnotesize",
                              "The table presents the cross-sectional out-of-sample asset pricing performance of models estimated \\textbf{without an intercept}.",
                              "Models are first estimated using the in-sample test assets and then used to price (with no additional parameter estimation) the out-of-sample test assets.",
                              "For the BMA-SDF, we provide results for prior Sharpe ratio values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the in-sample test assets.",
                              "All data are standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                              "}",
                              "\\end{spacing}",
                              "\\vspace{-4mm}",
                              "\\end{table}")

          os_tex_path <- file.path(tables_dir, "table_ia_7_os_pricing.tex")
          writeLines(os_latex_lines, os_tex_path)
          if (verbose) message("  Saved: ", os_tex_path)
        }
      } else {
        warning("  OOS test asset files not found. Skipping Table IA.7.")
      }
    }, error = function(e) {
      warning("  Error generating OOS pricing table: ", e$message)
    })
  } else {
    warning("  Required objects not found for OOS pricing. Skipping Table IA.7.")
  }
} else {
  warning("  Joint model .Rdata not found. Skipping Table IA.7.")
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
