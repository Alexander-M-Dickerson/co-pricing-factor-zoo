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

# Define model configurations matching _run_ia_estimation.R
IA_MODELS <- list(

  list(
    id          = 1,
    name        = "bond_intercept",
    model_type  = "bond",
    intercept   = TRUE,
    tag         = "ia_intercept",
    description = "Bond factors WITH intercept"
  ),

  list(
    id          = 2,
    name        = "stock_intercept",
    model_type  = "stock",
    intercept   = TRUE,
    tag         = "ia_intercept",
    description = "Stock factors WITH intercept"
  ),

  list(
    id          = 3,
    name        = "bond_no_intercept",
    model_type  = "bond",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    description = "Bond factors WITHOUT intercept"
  ),

  list(
    id          = 4,
    name        = "stock_no_intercept",
    model_type  = "stock",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    description = "Stock factors WITHOUT intercept"
  ),

  list(
    id          = 5,
    name        = "joint_no_intercept",
    model_type  = "bond_stock_with_sp",
    intercept   = FALSE,
    tag         = "ia_no_intercept",
    description = "Joint bond+stock WITHOUT intercept"
  )
)

###############################################################################
## SECTION 3: SOURCE HELPER FUNCTIONS
###############################################################################

if (verbose) message("\nLoading helper functions...")

source(file.path(code_folder, "pp_figure_table.R"))
source(file.path(code_folder, "pricing_tables.R"))
source(file.path(code_folder, "insample_asset_pricing.R"))

# Load additional helpers as needed
if (file.exists(file.path(code_folder, "oos_pricing_helpers.R"))) {
  source(file.path(code_folder, "oos_pricing_helpers.R"))
}

###############################################################################
## SECTION 4: HELPER FUNCTIONS
###############################################################################

#' Construct .Rdata filename for a model
get_rdata_path <- function(model, results_path, return_type = "excess") {
  filename <- sprintf("%s_%s_alpha.w=1_beta.w=1_kappa=0_%s.Rdata",
                      return_type, model$model_type, model$tag)
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
## SECTION 5.2: PRICING TABLES (joint_no_intercept only)
###############################################################################

if (verbose) {
  message("\n")
  message(strrep("=", 60))
  message("SECTION 2: Pricing Tables (Joint Model, No Intercept)")
  message(strrep("=", 60))
}

# Find the joint_no_intercept model
joint_model <- IA_MODELS[[5]]  # joint_no_intercept

# Load joint model results
joint_env <- load_model_results(joint_model, results_path)

if (is.null(joint_env)) {
  warning("Joint model results not found. Skipping pricing tables.")
} else {

  if (verbose) {
    message("\nLoading joint_no_intercept results...")
    message("  model_type = '", joint_model$model_type, "'")
    message("  tag        = '", joint_model$tag, "'")
  }

  # Load into global environment for pricing functions
  load(get_rdata_path(joint_model, results_path), envir = .GlobalEnv)

  # Check if IS_AP exists
  if (!exists("IS_AP")) {
    warning("IS_AP not found in results. Run insample_asset_pricing first.")
  } else {

    if (verbose) message("\nGenerating Table IA.2: In-Sample Pricing...")

    # Table 2 equivalent: IS Pricing
    tryCatch({
      is_pricing <- IS_AP$is_pricing_result

      if (!is.null(is_pricing)) {
        # Format and save IS pricing table
        tex_lines <- c(
          "\\begin{table}[tb!]",
          "\\caption{In-sample cross-sectional asset pricing (no intercept)}\\label{tab:ia-is-pricing}",
          "\\begin{center}",
          "\\scalebox{0.85}{",
          "\\begin{tabular}{lcccccccc}",
          "\\toprule",
          "& BMA-20\\% & BMA-40\\% & BMA-60\\% & BMA-80\\% & CAPM & FF5 & HKM & KNS \\\\",
          "\\midrule"
        )

        # Add metric rows
        metrics <- c("RMSEdm", "MAPEdm", "R2OLS", "R2GLS")
        for (m in metrics) {
          if (m %in% rownames(is_pricing) || m %in% is_pricing$metric) {
            row_data <- if ("metric" %in% names(is_pricing)) {
              as.numeric(is_pricing[is_pricing$metric == m, -1])
            } else {
              as.numeric(is_pricing[m, ])
            }
            row_str <- paste0(m, " & ", paste(sprintf("%.3f", row_data[1:8]), collapse = " & "), " \\\\")
            tex_lines <- c(tex_lines, row_str)
          }
        }

        tex_lines <- c(tex_lines,
          "\\bottomrule",
          "\\end{tabular}",
          "}",
          "\\end{center}",
          "\\end{table}"
        )

        is_tex_path <- file.path(tables_dir, "table_ia_is_pricing.tex")
        writeLines(tex_lines, is_tex_path)
        if (verbose) message("  Saved: ", is_tex_path)
      }
    }, error = function(e) {
      warning("Error generating IS pricing table: ", e$message)
    })

    # Table 3 equivalent: OS Pricing
    if (verbose) message("\nGenerating Table IA.3: Out-of-Sample Pricing...")

    tryCatch({
      if (exists("kns_out") && !is.null(kns_out)) {
        # Use KNS out-of-sample results if available
        if (verbose) message("  Using KNS out-of-sample results")

        # Generate OS pricing table similar to Table 3
        # This would use the pricing_tables.R functions
      } else {
        if (verbose) message("  KNS out-of-sample results not available")
      }
    }, error = function(e) {
      warning("Error generating OS pricing table: ", e$message)
    })
  }
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
