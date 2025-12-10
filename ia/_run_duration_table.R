#!/usr/bin/env Rscript
###############################################################################
## _run_duration_table.R - Generate Duration-Adjusted Bond Returns Table
## ---------------------------------------------------------------------------
##
## This script generates the cross-sectional asset pricing performance table
## for duration-adjusted bond returns.
##
## TABLE STRUCTURE:
##   Panel A: In-sample co-pricing stocks and bonds (bond_stock_with_sp, duration)
##   Panel B: In-sample pricing bonds (bond, duration)
##   Panel C: Out-of-sample co-pricing stocks and bonds (bond_stock_with_sp, duration)
##   Panel D: Out-of-sample pricing bonds (bond, duration)
##
## REQUIRED INPUT FILES:
##   - output/unconditional/bond_stock_with_sp/duration_bond_stock_with_sp_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata
##   - output/unconditional/bond/duration_bond_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata
##   - data/bond_insample_test_assets_50_duration_tmt.csv (OOS test assets for bonds)
##   - data/equity_os_77.csv (OOS test assets for stocks)
##
## OUTPUT:
##   - ia/output/paper/tables/table_duration_pricing.tex
##
## USAGE:
##   From R:
##     source("ia/_run_duration_table.R")
##
##   From terminal:
##     Rscript ia/_run_duration_table.R
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
results_path   <- "output/unconditional"
ia_output      <- "ia/output"
paper_output   <- file.path(ia_output, "paper")
tables_dir     <- file.path(paper_output, "tables")
code_folder    <- "code_base"
data_folder    <- "data"

# Create directories
for (d in c(tables_dir)) {
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
}

# Settings
verbose        <- TRUE
return_type    <- "duration"
alpha.w        <- 1
beta.w         <- 1
kappa          <- 0
tag            <- "baseline"

###############################################################################
## SECTION 2: SOURCE HELPER FUNCTIONS
###############################################################################

if (verbose) message("\nLoading helper functions...")

source(file.path(code_folder, "pricing_tables.R"))
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "outsample_asset_pricing.R"))

###############################################################################
## SECTION 3: HELPER FUNCTIONS
###############################################################################

#' Construct .Rdata filename for a duration model
get_duration_rdata_path <- function(model_type, results_path) {
  filename <- sprintf("duration_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s.Rdata",
                      model_type, alpha.w, beta.w, kappa, tag)
  file.path(results_path, model_type, filename)
}

#' Load model results into an environment
load_model_results <- function(model_type, results_path, verbose = TRUE) {
  rdata_path <- get_duration_rdata_path(model_type, results_path)

  if (!file.exists(rdata_path)) {
    warning("Results file not found: ", rdata_path)
    return(NULL)
  }

  if (verbose) message("  Loading: ", rdata_path)

  env <- new.env()
  load(rdata_path, envir = env)
  return(env)
}

###############################################################################
## SECTION 4: COLLECT IN-SAMPLE PRICING RESULTS
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("COLLECTING DURATION PRICING RESULTS")
  message(strrep("=", 60))
}

# Model columns in order (matching table header)
model_cols <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                "CAPM", "CAPMB", "FF5", "HKM",
                "Top-80%-All", "KNS", "RP-PCA")

is_results <- list()
os_results <- list()

# ---- Panel A: bond_stock_with_sp IS ----
if (verbose) message("\n--- Processing: bond_stock_with_sp (duration) ---")

bswsp_env <- load_model_results("bond_stock_with_sp", results_path, verbose)

if (!is.null(bswsp_env)) {
  if (exists("IS_AP", envir = bswsp_env)) {
    IS_AP_bswsp <- get("IS_AP", envir = bswsp_env)
    if (!is.null(IS_AP_bswsp$is_pricing_result)) {
      is_results$bond_stock_with_sp <- IS_AP_bswsp$is_pricing_result
      if (verbose) message("  IS pricing: ", ncol(is_results$bond_stock_with_sp) - 1, " models")
    }
  } else {
    warning("  IS_AP not found in bond_stock_with_sp model")
  }
} else {
  warning("  bond_stock_with_sp duration model not found")
}

# ---- Panel B: bond IS ----
if (verbose) message("\n--- Processing: bond (duration) ---")

bond_env <- load_model_results("bond", results_path, verbose)

if (!is.null(bond_env)) {
  if (exists("IS_AP", envir = bond_env)) {
    IS_AP_bond <- get("IS_AP", envir = bond_env)
    if (!is.null(IS_AP_bond$is_pricing_result)) {
      is_results$bond <- IS_AP_bond$is_pricing_result
      if (verbose) message("  IS pricing: ", ncol(is_results$bond) - 1, " models")
    }
  } else {
    warning("  IS_AP not found in bond model")
  }
} else {
  warning("  bond duration model not found")
}

###############################################################################
## SECTION 5: GENERATE OUT-OF-SAMPLE PRICING RESULTS
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("GENERATING OUT-OF-SAMPLE PRICING")
  message(strrep("=", 60))
}

# OOS test asset files for duration-adjusted returns
bond_oos_file <- file.path(data_folder, "bond_insample_test_assets_50_duration_tmt.csv")
stock_oos_file <- file.path(data_folder, "equity_os_77.csv")

# Check file existence
if (!file.exists(bond_oos_file)) {
  warning("Bond OOS file not found: ", bond_oos_file)
}
if (!file.exists(stock_oos_file)) {
  warning("Stock OOS file not found: ", stock_oos_file)
}

# Read OOS test assets
Rb_oos <- if (file.exists(bond_oos_file)) {
  read.csv(bond_oos_file, check.names = FALSE)
} else NULL

Rs_oos <- if (file.exists(stock_oos_file)) {
  read.csv(stock_oos_file, check.names = FALSE)
} else NULL

# ---- Panel C: bond_stock_with_sp OS ----
if (verbose) message("\n--- Panel C: bond_stock_with_sp OOS ---")

if (!is.null(bswsp_env) && !is.null(Rb_oos) && !is.null(Rs_oos)) {
  tryCatch({
    # Combine bond and stock OOS assets (remove date from Rs to avoid duplicate)
    R_oos_combined <- cbind(Rb_oos, Rs_oos[, -1, drop = FALSE])
    if (verbose) message("  Combined OOS assets: ", ncol(R_oos_combined) - 1, " portfolios")

    # Extract required objects from environment
    IS_AP_local <- get("IS_AP", envir = bswsp_env)
    frequentist_models_local <- get("frequentist_models", envir = bswsp_env)
    kns_out_local <- get("kns_out", envir = bswsp_env)
    rp_out_local <- get("rp_out", envir = bswsp_env)
    pca_out_local <- if (exists("pca_out", envir = bswsp_env)) get("pca_out", envir = bswsp_env) else NULL
    intercept_local <- get("intercept", envir = bswsp_env)

    # Get f1, f2, fac_freq from data_list if available
    if (exists("data_list", envir = bswsp_env)) {
      data_list_local <- get("data_list", envir = bswsp_env)
      f1_local <- data_list_local$f1
      f2_local <- data_list_local$f2
      fac_freq_local <- data_list_local$fac_freq
    } else {
      f1_local <- get("f1", envir = bswsp_env)
      f2_local <- if (exists("f2", envir = bswsp_env)) get("f2", envir = bswsp_env) else NULL
      fac_freq_local <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
    }

    if (verbose) {
      message("  f1: ", nrow(f1_local), " x ", ncol(f1_local))
      message("  f2: ", if(is.null(f2_local)) "NULL" else paste(nrow(f2_local), "x", ncol(f2_local)))
    }

    # Run OOS pricing
    if (verbose) message("  Running os_asset_pricing()...")
    os_result_bswsp <- os_asset_pricing(
      R_oss              = R_oos_combined,
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

    if (!is.null(os_result_bswsp) && is.data.frame(os_result_bswsp)) {
      os_results$bond_stock_with_sp <- os_result_bswsp
      if (verbose) message("  SUCCESS: ", ncol(os_result_bswsp) - 1, " models evaluated")
    }

  }, error = function(e) {
    warning("  ERROR in bond_stock_with_sp OOS pricing: ", e$message)
  })
} else {
  warning("  Skipping Panel C: missing model or OOS data")
}

# ---- Panel D: bond OS ----
if (verbose) message("\n--- Panel D: bond OOS ---")

if (!is.null(bond_env) && !is.null(Rb_oos)) {
  tryCatch({
    if (verbose) message("  Bond OOS assets: ", ncol(Rb_oos) - 1, " portfolios")

    # Extract required objects from environment
    IS_AP_local <- get("IS_AP", envir = bond_env)
    frequentist_models_local <- get("frequentist_models", envir = bond_env)
    kns_out_local <- get("kns_out", envir = bond_env)
    rp_out_local <- get("rp_out", envir = bond_env)
    pca_out_local <- if (exists("pca_out", envir = bond_env)) get("pca_out", envir = bond_env) else NULL
    intercept_local <- get("intercept", envir = bond_env)

    # Get f1, f2, fac_freq from data_list if available
    if (exists("data_list", envir = bond_env)) {
      data_list_local <- get("data_list", envir = bond_env)
      f1_local <- data_list_local$f1
      f2_local <- data_list_local$f2
      fac_freq_local <- data_list_local$fac_freq
    } else {
      f1_local <- get("f1", envir = bond_env)
      f2_local <- if (exists("f2", envir = bond_env)) get("f2", envir = bond_env) else NULL
      fac_freq_local <- read.csv(file.path(data_folder, "frequentist_factors.csv"), check.names = FALSE)
    }

    if (verbose) {
      message("  f1: ", nrow(f1_local), " x ", ncol(f1_local))
      message("  f2: ", if(is.null(f2_local)) "NULL" else paste(nrow(f2_local), "x", ncol(f2_local)))
    }

    # Run OOS pricing
    if (verbose) message("  Running os_asset_pricing()...")
    os_result_bond <- os_asset_pricing(
      R_oss              = Rb_oos,
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

    if (!is.null(os_result_bond) && is.data.frame(os_result_bond)) {
      os_results$bond <- os_result_bond
      if (verbose) message("  SUCCESS: ", ncol(os_result_bond) - 1, " models evaluated")
    }

  }, error = function(e) {
    warning("  ERROR in bond OOS pricing: ", e$message)
  })
} else {
  warning("  Skipping Panel D: missing model or OOS data")
}

###############################################################################
## SECTION 6: GENERATE LATEX TABLE
###############################################################################

if (verbose) {
  message("\n", strrep("=", 60))
  message("GENERATING LATEX TABLE")
  message(strrep("=", 60))
}

# Build LaTeX table
latex_lines <- c(
  "\\begin{table}[tbp] ",
  "\\begin{center}",
  "\\caption{Cross-sectional asset pricing performance:  Duration-adjusted bond returns}\\label{tab:is_pricing_duration_baseline}",
  "\\resizebox{16.5cm}{!}{%",
  "\\begin{tabular}{lcccc|ccccccc}\\toprule",
  " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
  " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
)

# Panel A: In-sample co-pricing
if (!is.null(is_results$bond_stock_with_sp)) {
  latex_lines <- c(latex_lines,
                   "\\multicolumn{12}{c}{\\textbf{Panel A}: In-sample co-pricing stocks and bonds} \\\\ \\midrule",
                   build_pricing_panel_rows(is_results$bond_stock_with_sp, model_cols),
                   "\\midrule")
  if (verbose) message("  Added Panel A: In-sample co-pricing")
} else {
  warning("  Panel A: No IS results for bond_stock_with_sp")
}

# Panel B: In-sample pricing bonds
if (!is.null(is_results$bond)) {
  latex_lines <- c(latex_lines,
                   "\\multicolumn{12}{c}{\\textbf{Panel B}: In-sample pricing bonds} \\\\ \\midrule",
                   build_pricing_panel_rows(is_results$bond, model_cols),
                   "\\midrule")
  if (verbose) message("  Added Panel B: In-sample pricing bonds")
} else {
  warning("  Panel B: No IS results for bond")
}

# Panel C: Out-of-sample co-pricing
if (!is.null(os_results$bond_stock_with_sp)) {
  latex_lines <- c(latex_lines,
                   "\\multicolumn{12}{c}{\\textbf{Panel C}: Out-of-sample co-pricing stocks and bonds} \\\\ \\midrule",
                   build_pricing_panel_rows(os_results$bond_stock_with_sp, model_cols),
                   "\\midrule")
  if (verbose) message("  Added Panel C: Out-of-sample co-pricing")
} else {
  warning("  Panel C: No OOS results for bond_stock_with_sp")
}

# Panel D: Out-of-sample pricing bonds
if (!is.null(os_results$bond)) {
  latex_lines <- c(latex_lines,
                   "\\multicolumn{12}{c}{\\textbf{Panel D}: Out-of-sample pricing bonds} \\\\ \\midrule",
                   build_pricing_panel_rows(os_results$bond, model_cols))
  if (verbose) message("  Added Panel D: Out-of-sample pricing bonds")
} else {
  warning("  Panel D: No OOS results for bond")
}

# Close table
latex_lines <- c(latex_lines,
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
tex_path <- file.path(tables_dir, "table_duration_pricing.tex")
writeLines(latex_lines, tex_path)

if (verbose) {
  message("\n", strrep("=", 60))
  message("DURATION TABLE GENERATION COMPLETE")
  message(strrep("=", 60))
  message("\nSaved to: ", tex_path)
}

###############################################################################
## CLEANUP
###############################################################################

# Clean up environments
rm(bswsp_env, bond_env)
gc(verbose = FALSE)

# Close any remaining graphics devices
if (length(dev.list()) > 0) graphics.off()
