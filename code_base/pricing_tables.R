# =========================================================================
#  pricing_tables.R  ---  Generate Tables 2 & 3: IS and OS Pricing
# =========================================================================
#' Functions to collect pricing results across model types and generate
#' LaTeX tables for in-sample (Table 2) and out-of-sample (Table 3) pricing.
#'
#' Paper role: aggregate saved pricing diagnostics into the manuscript's
#' cross-sectional comparison tables.
#' Paper refs: Eq. (1); Table 2; Table 3; Figure 5; Table IA.XVI; Table IA.XIX
#'
#' Main Functions:
#'   run_pricing_multi()    - Collect IS/OS pricing across model types
#'   generate_table_2()     - In-sample cross-sectional pricing (Table 2)
#'   generate_table_3()     - Out-of-sample cross-sectional pricing (Table 3)
#'   generate_pricing_tables() - Generate both tables
# =========================================================================

library(dplyr)

# =========================================================================
#  Model column mapping: IS_AP column names -> Table display names
# =========================================================================

# Models to include in tables (order matters for column ordering)
PRICING_MODELS <- c(
  "BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
  "CAPM", "CAPMB", "FF5", "HKM",
  "Top-80%-All", "KNS", "RP-PCA"
)

# =========================================================================
#  run_pricing_multi: Collect IS and OS pricing across model types
# =========================================================================
#' Collect in-sample and out-of-sample pricing results across model types
#'
#' @param results_path Path to results folder
#' @param data_path Path to data folder (for OOS test assets)
#' @param model_types Vector of model types to process
#' @param return_type Return type (e.g., "excess")
#' @param alpha.w Beta prior hyperparameter
#' @param beta.w Beta prior hyperparameter
#' @param kappa Factor tilt
#' @param tag Run identifier
#' @param run_oos Logical, whether to run out-of-sample pricing
#' @param save_output Logical, save results to RDS?
#' @param output_path Path for saving output
#' @param output_name Filename for saved output
#' @param verbose Print progress?
#'
#' @details
#' This loader is intentionally table-oriented: it reuses saved BMA-SDF objects
#' rather than re-estimating models, then aligns the benchmark columns to the
#' manuscript's Table 2/Table 3 comparison set.
#'
#' @return List with is_results and os_results (each a list by model_type)
run_pricing_multi <- function(results_path,
                              data_path,
                              model_types = c("bond_stock_with_sp", "stock", "bond"),
                              return_type = "excess",
                              alpha.w = 1,
                              beta.w = 1,
                              kappa = 0,
                              tag = "baseline",
                              run_oos = TRUE,
                              save_output = TRUE,
                              output_path = NULL,
                              output_name = "pricing_results.rds",
                              verbose = TRUE) {

  if (verbose) {
    message("\n", strrep("=", 60))
    message("COLLECTING PRICING RESULTS ACROSS MODEL TYPES")
    message(strrep("=", 60), "\n")
  }

  is_results <- list()
  os_results <- list()

  for (model_type in model_types) {
    if (verbose) message("--- Processing: ", model_type, " ---")

    # Construct filename
    rdata_filename <- sprintf(
      "%s_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s.Rdata",
      return_type, model_type, alpha.w, beta.w, kappa, tag
    )
    rdata_path <- file.path(results_path, model_type, rdata_filename)

    # Check file exists
    if (!file.exists(rdata_path)) {
      warning("  File not found: ", rdata_path, ". Skipping.")
      is_results[[model_type]] <- NULL
      os_results[[model_type]] <- NULL
      next
    }

    # Load into global environment (required for os_asset_pricing to work)
    # Save existing global vars to restore later
    existing_vars <- ls(envir = .GlobalEnv)

    load(rdata_path, envir = .GlobalEnv)

    if (verbose) message("  Loaded: ", rdata_filename)

    # Paper: Table 2 is read directly from the saved in-sample pricing block.
    # Table 3 and Figure 5 then reuse the same saved estimation object for the
    # out-of-sample asset-pricing exercise.
    # ---- Extract IS results ----
    IS_AP_local <- get("IS_AP", envir = .GlobalEnv)

    if (!is.null(IS_AP_local$is_pricing_result)) {
      # Filter to only the models we need
      is_df <- IS_AP_local$is_pricing_result
      cols_to_keep <- c("metric", intersect(PRICING_MODELS, colnames(is_df)))
      is_results[[model_type]] <- is_df[, cols_to_keep, drop = FALSE]

      if (verbose) {
        message("  IS pricing: ", ncol(is_results[[model_type]]) - 1, " models")
      }
    } else {
      warning("  IS_AP$is_pricing_result not found")
      is_results[[model_type]] <- NULL
    }

    # ---- Run OS pricing if requested ----
    if (run_oos) {
      tryCatch({
        # Load OOS test assets - handle date columns correctly
        # Bond file has date as first column
        # Stock file has date as first column (must remove when combining)

        bond_oos_file <- file.path(data_path, "bond_oosample_all_excess.csv")
        stock_oos_file <- file.path(data_path, "equity_os_77.csv")

        # Check if required OOS files exist
        if (model_type == "bond_stock_with_sp" && (!file.exists(bond_oos_file) || !file.exists(stock_oos_file))) {
          warning("  OOS files missing for combined model: ", bond_oos_file, " and/or ", stock_oos_file)
        } else if (model_type == "bond" && !file.exists(bond_oos_file)) {
          warning("  OOS file missing for bond model: ", bond_oos_file)
        } else if (model_type == "stock" && !file.exists(stock_oos_file)) {
          warning("  OOS file missing for stock model: ", stock_oos_file)
        }

        R_oos_data <- NULL

        if (model_type == "bond_stock_with_sp") {
          # Combined: Rb (with date) + Rs (without date)
          if (file.exists(bond_oos_file) && file.exists(stock_oos_file)) {
            Rb <- read.csv(bond_oos_file, check.names = FALSE)
            Rs <- read.csv(stock_oos_file, check.names = FALSE)[, -1, drop = FALSE]  # Remove date column
            R_oos_data <- cbind(Rb, Rs)
          }
        } else if (model_type == "bond") {
          # Bond only: just Rb (with date)
          if (file.exists(bond_oos_file)) {
            R_oos_data <- read.csv(bond_oos_file, check.names = FALSE)
          }
        } else if (model_type == "stock") {
          # Stock only: just Rs (with date)
          if (file.exists(stock_oos_file)) {
            R_oos_data <- read.csv(stock_oos_file, check.names = FALSE)
          }
        }

        if (!is.null(R_oos_data)) {
          if (verbose) message("  OOS assets: ", ncol(R_oos_data) - 1, " portfolios")

          # Get required objects from global env
          data_list_local <- get("data_list", envir = .GlobalEnv)
          frequentist_models_local <- get("frequentist_models", envir = .GlobalEnv)
          kns_out_local <- get("kns_out", envir = .GlobalEnv)
          rp_out_local <- get("rp_out", envir = .GlobalEnv)
          pca_out_local <- if (exists("pca_out", envir = .GlobalEnv)) {
            get("pca_out", envir = .GlobalEnv)
          } else NULL
          intercept_local <- get("intercept", envir = .GlobalEnv)

          # Run OOS pricing
          os_metrics <- os_asset_pricing(
            R_oss = R_oos_data,
            IS_AP = IS_AP_local,
            f1 = data_list_local$f1,
            f2 = data_list_local$f2,
            fac_freq = data_list_local$fac_freq,
            frequentist_models = frequentist_models_local,
            kns_out = kns_out_local,
            rp_out = rp_out_local,
            pca_out = pca_out_local,
            intercept = intercept_local,
            date_start = "1986-01-31",
            verbose = FALSE
          )

          # Filter to only the models we need
          cols_to_keep <- c("metric", intersect(PRICING_MODELS, colnames(os_metrics)))
          os_results[[model_type]] <- os_metrics[, cols_to_keep, drop = FALSE]

          if (verbose) {
            message("  OS pricing: ", ncol(os_results[[model_type]]) - 1, " models")
          }
        } else {
          os_results[[model_type]] <- NULL
        }
      }, error = function(e) {
        warning("  OS pricing failed: ", e$message)
        os_results[[model_type]] <<- NULL
      })
    }

    # Clean up global environment (remove loaded objects)
    new_vars <- setdiff(ls(envir = .GlobalEnv), existing_vars)
    rm(list = new_vars, envir = .GlobalEnv)
  }

  # Combine results
  output <- list(
    is_results = is_results,
    os_results = os_results
  )

  # Save if requested
  if (save_output && !is.null(output_path)) {
    save_file <- file.path(output_path, output_name)
    saveRDS(output, save_file)
    if (verbose) message("\nSaved results to: ", save_file)
  }

  if (verbose) {
    message("\n", strrep("=", 60))
    message("PRICING COLLECTION COMPLETE")
    message(strrep("=", 60), "\n")
  }

  invisible(output)
}


# =========================================================================
#  Helper: Format numeric value for LaTeX
# =========================================================================
format_price_value <- function(x, digits = 3, is_r2 = FALSE) {
  if (is.na(x)) return("")
  if (is_r2 && x < 0) {
    # Format negative R2 with minus sign
    return(paste0("$-$", formatC(abs(x), digits = digits, format = "f")))
  }
  formatC(x, digits = digits, format = "f")
}


# =========================================================================
#  Helper: Build panel rows for pricing table
# =========================================================================
build_pricing_panel_rows <- function(data, model_cols, digits = 3) {
  if (is.null(data)) return(character(0))

  metrics <- c("RMSEdm", "MAPEdm", "R2OLS", "R2GLS")
  metric_labels <- c("RMSE", "MAPE", "$R^2_{\\text{OLS}}$", "$R^2_{\\text{GLS}}$")

  rows <- character(0)
  for (i in seq_along(metrics)) {
    metric_row <- data[data$metric == metrics[i], ]
    if (nrow(metric_row) == 0) next

    # Extract values for each model column
    vals <- sapply(model_cols, function(m) {
      if (m %in% colnames(metric_row)) {
        as.numeric(metric_row[[m]])
      } else {
        NA
      }
    })

    is_r2 <- metrics[i] %in% c("R2OLS", "R2GLS")
    formatted <- sapply(vals, format_price_value, digits = digits, is_r2 = is_r2)

    rows <- c(rows, paste0(metric_labels[i], " & ",
                           paste(formatted, collapse = " & "), " \\\\"))
  }
  rows
}


# =========================================================================
#  generate_table_2: In-sample cross-sectional asset pricing
# =========================================================================
#' Generate Table 2: In-sample cross-sectional asset pricing performance
#'
#' Paper refs: Table 2; Sec. 3.1.2
#'
#' @param pricing_results List from run_pricing_multi()
#' @param output_path Path to save .tex file (NULL = don't save)
#' @param verbose Print progress
#' @return List with latex_lines
generate_table_2 <- function(pricing_results,
                             output_path = NULL,
                             verbose = TRUE) {

  if (verbose) message("Generating Table 2: In-sample Pricing...")

  is_results <- pricing_results$is_results

  # Model columns in order (matching table header)
  model_cols <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                  "CAPM", "CAPMB", "FF5", "HKM",
                  "Top-80%-All", "KNS", "RP-PCA")

  # Start LaTeX
  latex_lines <- c(
    "\\begin{table}[tbh!]",
    "\\begin{center}",
    "\\caption{In-sample cross-sectional asset pricing performance}\\label{tab:tab-is-pricing-excess}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccc|ccccccc}\\toprule",
    " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
    " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
  )

  # Panel A: Co-pricing
  if (!is.null(is_results$bond_stock_with_sp)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel A:} Co-pricing bonds and stocks} \\\\ \\midrule",
                     build_pricing_panel_rows(is_results$bond_stock_with_sp, model_cols),
                     " \\midrule")
  }

  # Panel B: Bond
  if (!is.null(is_results$bond)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel B}: Pricing bonds} \\\\ \\midrule",
                     build_pricing_panel_rows(is_results$bond, model_cols),
                     " \\midrule")
  }

  # Panel C: Stock
  if (!is.null(is_results$stock)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel C}: Pricing stocks} \\\\ \\midrule",
                     build_pricing_panel_rows(is_results$stock, model_cols))
  }

  latex_lines <- c(latex_lines,
                   " \\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   "\t{\\footnotesize",
                   "The table presents the cross-sectional in-sample asset pricing performance of different models pricing bonds and stocks jointly (Panel A), bonds only (Panel B) and stocks only (Panel C), respectively.",
                   "For the BMA-SDF, we provide results for prior Sharpe ratio  values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the test assets. TOP includes the top five factors with an average posterior probability greater than 50\\%.",
                   "CAPM is the standard single-factor model using MKTS, and CAPMB is the bond version using MKTB. FF5 is the five-factor model of \\cite{FamaFrench_1993}, HKM is the two-factor model of \\citet{HeKellyManela_2017}. KNS stands for the SDF estimation of \\citet{KozakNagelSantosh_2020} and RPPCA is the  risk premia PCA of \\cite{LettauPelger_2020}. Estimation details for the benchmark models are given in Appendix \\ref{sec:benchmark_models}.",
                   "Bond returns are computed in excess of the one-month risk-free rate of return.",
                   "By panel the models are estimated with the respective factor zoos and test assets.",
                   "Test assets are the 83 bond and stock portfolios and the 40 tradable bond and stock factors (Panel A), the 50 bond portfolios and  16 tradable bond factors (Panel B), and the 33 stock portfolios and 24 tradable stock factors (Panel C), respectively. All are described in Section \\ref{sec:data}.",
                   "All data are standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                   "}",
                   "\\end{spacing}",
                   "\\vspace{-4mm}",
                   "\\end{table}")

  # Save if path provided
  if (!is.null(output_path)) {
    tex_file <- file.path(output_path, "table_2_is_pricing.tex")
    dir.create(dirname(tex_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(latex_lines, tex_file)
    if (verbose) message("  Saved: ", tex_file)
  }

  invisible(list(latex_lines = latex_lines))
}


# =========================================================================
#  generate_table_3: Out-of-sample cross-sectional asset pricing
# =========================================================================
#' Generate Table 3: Out-of-sample cross-sectional asset pricing performance
#'
#' Paper refs: Table 3; Figure 5; Sec. 3.1.2
#'
#' @param pricing_results List from run_pricing_multi()
#' @param output_path Path to save .tex file (NULL = don't save)
#' @param verbose Print progress
#' @return List with latex_lines
generate_table_3 <- function(pricing_results,
                             output_path = NULL,
                             verbose = TRUE) {

  if (verbose) message("Generating Table 3: Out-of-sample Pricing...")

  os_results <- pricing_results$os_results

  # Check if OS results are empty
  if (is.null(os_results) || all(sapply(os_results, is.null))) {
    warning("  No OS pricing results available! Table 3 will be empty.")
    warning("  To regenerate: delete data/pricing_results.rds or set regenerate_pricing <- TRUE")
  }

  # Model columns in order (matching table header)
  model_cols <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                  "CAPM", "CAPMB", "FF5", "HKM",
                  "Top-80%-All", "KNS", "RP-PCA")

  # Start LaTeX
  latex_lines <- c(
    "\\begin{table}[tbh!]",
    "\\begin{center}",
    "\\caption{Out-of-sample cross-sectional asset pricing performance}\\label{tab:tab-os-pricing-excess}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccc|ccccccc} \\toprule",
    " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & CAPM & CAPMB & FF5 & HKM & TOP & KNS & RPPCA \\\\ \\cmidrule(lr){2-5}",
    " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  \\\\ \\midrule"
  )

  # Panel A: Co-pricing
  if (!is.null(os_results$bond_stock_with_sp)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel A}: Co-pricing bonds and stocks} \\\\ \\midrule",
                     build_pricing_panel_rows(os_results$bond_stock_with_sp, model_cols),
                     " \\midrule")
  }

  # Panel B: Bond
  if (!is.null(os_results$bond)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel B}: Pricing bonds} \\\\ \\midrule",
                     build_pricing_panel_rows(os_results$bond, model_cols),
                     " \\midrule")
  }

  # Panel C: Stock
  if (!is.null(os_results$stock)) {
    latex_lines <- c(latex_lines,
                     "\\multicolumn{12}{c}{\\textbf{Panel C}: Pricing stocks} \\\\ \\midrule",
                     build_pricing_panel_rows(os_results$stock, model_cols))
  }

  latex_lines <- c(latex_lines,
                   " \\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   "    {\\footnotesize",
                   "The table presents the cross-sectional out-of-sample asset pricing performance of different models pricing bonds and stocks jointly (Panel A), bonds only (Panel B) and stocks only (Panel C), respectively.",
                   "For the BMA-SDF, we provide results for prior Sharpe ratio values set to 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the test assets. TOP includes the top five factors with an average posterior probability greater than 50\\%.",
                   "CAPM is the standard single-factor model using MKTS, and CAPMB is the bond version using MKTB. FF5 is the five-factor model of \\cite{FamaFrench_1993}, HKM is the two-factor model of \\citet{HeKellyManela_2017}. KNS stands for the SDF estimation of \\citet{KozakNagelSantosh_2020} and RPPCA is the  risk premia PCA of \\cite{LettauPelger_2020}. Estimation details for the benchmark models are given in Appendix \\ref{sec:benchmark_models}.",
                   "Bond returns are computed in excess of the one-month risk-free rate of return.",
                   "The models are first estimated using the baseline IS test assets. The resulting SDF is then used to price (with no additional parameter estimation) each set of the OS assets.",
                   "The IS test assets are the same as in Table \\ref{tab:tab-is-pricing-excess}. OS test assets are the combined 154 bond and stock portfolios (Panel A), as well as the separate 77 bond and stock portfolios (Panels B and C). All are described in Section \\ref{sec:data}.",
                   "All data are standardized, that is, pricing errors are in Sharpe ratio units. The sample period is 1986:01 to 2022:12 ($T=444$).",
                   "}",
                   "\\end{spacing}",
                   "\\vspace{-4mm}",
                   "\\end{table}")

  # Save if path provided
  if (!is.null(output_path)) {
    tex_file <- file.path(output_path, "table_3_os_pricing.tex")
    dir.create(dirname(tex_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(latex_lines, tex_file)
    if (verbose) message("  Saved: ", tex_file)
  }

  invisible(list(latex_lines = latex_lines))
}


# =========================================================================
#  generate_pricing_tables: Generate both Tables 2 and 3
# =========================================================================
#' Generate Tables 2 and 3: In-sample and out-of-sample pricing
#'
#' @param pricing_results List from run_pricing_multi()
#' @param output_path Path to save .tex files
#' @param tables Which tables to generate (default: c(2, 3))
#' @param verbose Print progress
#' @return List with results for each table
generate_pricing_tables <- function(pricing_results,
                                    output_path = NULL,
                                    tables = c(2, 3),
                                    verbose = TRUE) {

  if (verbose) {
    message("\n", strrep("=", 60))
    message("GENERATING PRICING TABLES")
    message(strrep("=", 60), "\n")
  }

  results <- list()

  if (2 %in% tables) {
    results$table_2 <- generate_table_2(pricing_results, output_path, verbose)
  }

  if (3 %in% tables) {
    results$table_3 <- generate_table_3(pricing_results, output_path, verbose)
  }

  if (verbose) {
    message("\n", strrep("=", 60))
    message("PRICING TABLE GENERATION COMPLETE")
    if (!is.null(output_path)) {
      message("Tables saved to: ", normalizePath(output_path))
    }
    message(strrep("=", 60), "\n")
  }

  invisible(results)
}
