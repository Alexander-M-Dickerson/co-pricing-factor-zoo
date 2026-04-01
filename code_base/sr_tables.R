# =========================================================================
#  sr_tables.R  ---  Generate LaTeX Tables from SR Decomposition Results
# =========================================================================
# Functions to create Tables 1, 4, and 5 from sr_decomposition() output.
#
# Paper role: render the SR-decomposition outputs into manuscript-ready LaTeX.
# Paper refs: Table 1; Table 4; Table 5; IA.5; IA.6; Table IA.XVIII
#
# Main Functions:
#   generate_sr_tables()      - Generate all tables (1, 4, 5) in one call
#   generate_table_1()        - Table 1: Top 5 factor contributions
#   generate_table_4()        - Table 4: SR decomposition by factor type
#   generate_table_5()        - Table 5: DR vs CF decomposition
#
# Helper Functions:
#   extract_block()           - Extract and pivot a factor group block
#   format_latex_value()      - Format numeric values for LaTeX
#   build_latex_row()         - Build a single LaTeX table row
# =========================================================================

library(dplyr)
library(tidyr)


# =========================================================================
#  Helper: Extract and pivot a factor group block
# =========================================================================
#' Extract metrics for a factor type and pivot to wide format
#'
#' @param data Tibble from sr_decomposition()
#' @param factor_type Factor type to filter (e.g., "Top 5 Factors")
#' @param metrics Vector of metrics to include
#' @param shrinkage_levels Shrinkage level order
#' @param suffix Optional suffix for column names (for horizontal concat)
#' @return Wide-format tibble with metrics as rows, shrinkage as columns
extract_block <- function(data,
                          factor_type,
                          metrics = c("Mean", "5%", "95%",
                                      "E[SR_f|data]", "E[SR^2_f/SR^2_m|data]"),
                          shrinkage_levels = c("20%", "40%", "60%", "80%"),
                          suffix = NULL) {

  result <- data %>%
    filter(factor_type == !!factor_type,
           metric %in% metrics) %>%
    dplyr::select(shrinkage, metric, value) %>%
    mutate(shrinkage = factor(shrinkage, levels = shrinkage_levels)) %>%
    pivot_wider(names_from = shrinkage, values_from = value) %>%
    arrange(match(metric, metrics))

  # Add suffix to column names if provided (except metric column)
  if (!is.null(suffix) && nchar(suffix) > 0) {
    result <- result %>%
      rename_with(~ paste0(.x, suffix), -metric)
  }

  result
}


# =========================================================================
#  Helper: Format numeric value for LaTeX
# =========================================================================
#' Format a numeric value for LaTeX output
#'
#' @param x Numeric value
#' @param digits Number of decimal places
#' @param is_integer Whether to format as integer
#' @return Formatted string
format_latex_value <- function(x, digits = 2, is_integer = FALSE) {
  if (is.na(x)) return("")
  if (is_integer) {
    return(formatC(round(x), format = "d"))
  }
  formatC(x, digits = digits, format = "f")
}


# =========================================================================
#  Helper: Build a LaTeX table row
# =========================================================================
#' Build a single LaTeX row from values
#'
#' @param label Row label (first column)
#' @param values Vector of numeric values
#' @param digits Decimal places for formatting
#' @param is_integer Format as integers
#' @param spacer_positions Positions to insert "&" spacer (for multi-panel)
#' @return LaTeX row string
build_latex_row <- function(label, values, digits = 2, is_integer = FALSE,
                            spacer_positions = NULL) {
  formatted <- sapply(values, format_latex_value, digits = digits,
                      is_integer = is_integer)

  # Insert spacers at specified positions
  if (!is.null(spacer_positions)) {
    for (pos in sort(spacer_positions, decreasing = TRUE)) {
      if (pos <= length(formatted)) {
        formatted <- append(formatted, "", after = pos)
      }
    }
  }

  paste0(label, " & ", paste(formatted, collapse = " & "), " \\\\")
}


# =========================================================================
#  Table 1: Top 5 Factor Contributions to SDF
# =========================================================================
#' Generate Table 1: Most likely (top five) factor contributions to the SDF
#'
#' Paper refs: Table 1; Figure 2; Figure 4; Sec. 3.1.1
#'
#' @param res_tbl_top Named list from run_sr_decomposition_multi()
#' @param output_path Path to save .tex file (NULL = don't save)
#' @param verbose Print progress
#' @return List with latex_lines and data
generate_table_1 <- function(res_tbl_top,
                             output_path = NULL,
                             verbose = TRUE) {

  if (verbose) message("Generating Table 1: Top 5 Factor Contributions...")

  metrics <- c("E[SR_f|data]", "E[SR^2_f/SR^2_m|data]")

  # Extract data for each panel
  get_top5_block <- function(data) {
    if (is.null(data)) return(NULL)
    extract_block(data, "Top 5 Factors", metrics = metrics)
  }

  panel_a <- get_top5_block(res_tbl_top$bond_stock_with_sp)
  panel_b <- get_top5_block(res_tbl_top$bond)
  panel_c <- get_top5_block(res_tbl_top$stock)

  # Build LaTeX
  latex_lines <- c(
    "\\begin{table}[tb!]",
    "\\begin{center}",
    "\\caption{Most likely (top five) factor contributions to the SDF}\\label{tab:table-model-dim2-top-non-top}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccccccccccccc}",
    "\\toprule",
    "& \\multicolumn{4}{c}{\\textbf{Panel A}: Co-pricing SDF} & & \\multicolumn{4}{c}{\\textbf{Panel B}: Bond SDF} & & \\multicolumn{4}{c}{\\textbf{Panel C}: Stock SDF} \\\\ \\cmidrule{2-5}\\cmidrule{7-10}\\cmidrule{12-15}",
    "\\text{Total prior SR: }& 20\\% & 40\\% & 60\\% & 80\\% & & 20\\% & 40\\% & 60\\% & 80\\% & & 20\\% & 40\\% & 60\\% & 80\\% \\\\ \\midrule"
  )

  # Row 1: E[SR_f|data]
  vals_a <- if (!is.null(panel_a)) as.numeric(panel_a[1, 2:5]) else rep(NA, 4)
  vals_b <- if (!is.null(panel_b)) as.numeric(panel_b[1, 2:5]) else rep(NA, 4)
  vals_c <- if (!is.null(panel_c)) as.numeric(panel_c[1, 2:5]) else rep(NA, 4)
  all_vals <- c(vals_a, NA, vals_b, NA, vals_c)
  latex_lines <- c(latex_lines,
                   paste0("$\\mathbb{E}[SR_f|\\text{data}]$ & ",
                          paste(sapply(all_vals, function(x) if(is.na(x)) "" else format_latex_value(x, 2)),
                                collapse = " & "), " \\\\"))

  # Row 2: E[SR^2_f/SR^2_m|data]
  vals_a <- if (!is.null(panel_a)) as.numeric(panel_a[2, 2:5]) else rep(NA, 4)
  vals_b <- if (!is.null(panel_b)) as.numeric(panel_b[2, 2:5]) else rep(NA, 4)
  vals_c <- if (!is.null(panel_c)) as.numeric(panel_c[2, 2:5]) else rep(NA, 4)
  all_vals <- c(vals_a, NA, vals_b, NA, vals_c)
  latex_lines <- c(latex_lines,
                   paste0("$\\mathbb{E}\\left[\\frac{SR^2_f}{SR^2_m}|\\text{data}\\right]$ & ",
                          paste(sapply(all_vals, function(x) if(is.na(x)) "" else format_latex_value(x, 2)),
                                collapse = " & "), " \\\\"))

  latex_lines <- c(latex_lines,
                   "\\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   "\t{\\footnotesize Posterior mean of implied Sharpe ratios achievable with the most likely (top five) factors, $\\mathbb{E}[SR_f|\\text{data}]$, and their share of the SDF squared Sharpe ratio, $\\mathbb{E}\\big[SR^2_f/SR^2_m|\\text{data}\\big]$.",
                   "    Panels A, B and C report results using the corresponding factor zoos, for the co-pricing, bond-only, and stock-only BMA-SDFs, respectively.",
                   "    Top five co-pricing factors are PEADB, IVOL, PEAD, CREDIT and YSP.",
                   "    Top five bond factors are PEADB, CREDIT, MOMBS, IVOL and YSP.",
                   "    Top five stock factors are PEAD, MKTS, IVOL, CMAs and EPUT.",
                   "    The total prior Sharpe ratio  is expressed as a share of the ex post maximum Sharpe ratio of the test assets.",
                   "}",
                   "\\end{spacing}",
                   "\\vspace{-4mm}",
                   "\\end{table}")

  # Save if path provided
  if (!is.null(output_path)) {
    tex_file <- file.path(output_path, "table_1_top5_factors.tex")
    dir.create(dirname(tex_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(latex_lines, tex_file)
    if (verbose) message("  Saved: ", tex_file)
  }

  invisible(list(
    latex_lines = latex_lines,
    data = list(panel_a = panel_a, panel_b = panel_b, panel_c = panel_c)
  ))
}


# =========================================================================
#  Table 4: BMA-SDF Dimensionality and SR by Factor Type
# =========================================================================
#' Generate Table 4: BMA-SDF dimensionality and SR decomposition by factor type
#'
#' Paper refs: Table 4; Figure 3; Sec. 3.2
#'
#' @param res_tbl_top Named list from run_sr_decomposition_multi()
#' @param output_path Path to save .tex file (NULL = don't save)
#' @param verbose Print progress
#' @return List with latex_lines and data
generate_table_4 <- function(res_tbl_top,
                             output_path = NULL,
                             verbose = TRUE) {

  if (verbose) message("Generating Table 4: SR Decomposition by Factor Type...")

  metrics <- c("Mean", "5%", "95%", "E[SR_f|data]", "E[SR^2_f/SR^2_m|data]")
  metric_labels <- c("Mean", "5\\%", "95\\%",
                     "$\\mathbb{E}[SR_f|\\text{data}]$",
                     "$\\mathbb{E}\\big[\\frac{SR^2_f}{SR^2_m}|\\text{data}\\big]$")
  metric_digits <- c(2, 0, 0, 2, 2)
  metric_is_int <- c(FALSE, TRUE, TRUE, FALSE, FALSE)

  # Helper to build panel rows
  build_panel_rows <- function(left_block, right_block, left_label, right_label) {
    rows <- c(
      paste0(" & \\multicolumn{4}{c}{", left_label, "} &  & \\multicolumn{4}{c}{", right_label, "} \\\\ \\cmidrule(lr){2-5} \\cmidrule(lr){7-10}")
    )

    for (i in seq_along(metrics)) {
      left_vals <- if (!is.null(left_block)) as.numeric(left_block[i, 2:5]) else rep(NA, 4)
      right_vals <- if (!is.null(right_block)) as.numeric(right_block[i, 2:5]) else rep(NA, 4)

      fmt_left <- sapply(left_vals, format_latex_value,
                         digits = metric_digits[i], is_integer = metric_is_int[i])
      fmt_right <- sapply(right_vals, format_latex_value,
                          digits = metric_digits[i], is_integer = metric_is_int[i])

      rows <- c(rows,
                paste0(metric_labels[i], " & ",
                       paste(fmt_left, collapse = " & "), " &  & ",
                       paste(fmt_right, collapse = " & "), " \\\\"))
    }
    rows
  }

  # Start LaTeX
  latex_lines <- c(
    "\\begin{table}[tb!]",
    "\\begin{center}",
    "\\caption{BMA-SDF dimensionality and Sharpe ratio decomposition by factor type}\\label{tab:table-model-dim1}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccccccccc} \\toprule",
    "& \\multicolumn{4}{c}{Total prior SR} &  & \\multicolumn{4}{c}{Total prior SR} \\\\",
    "& 20\\% & 40\\% & 60\\% & 80\\% &  & 20\\% & 40\\% & 60\\% & 80\\% \\\\",
    "\\midrule"
  )

  # Panel A: Co-pricing
  if (!is.null(res_tbl_top$bond_stock_with_sp)) {
    data_a <- res_tbl_top$bond_stock_with_sp
    nt_a <- extract_block(data_a, "Nontraded factors", metrics)
    tr_a <- extract_block(data_a, "Tradable factors", metrics)
    bd_a <- extract_block(data_a, "Bond tradable factors", metrics)
    st_a <- extract_block(data_a, "Stock tradable factors", metrics)

    latex_lines <- c(latex_lines,
                     "\\multicolumn{10}{c}{\\textbf{Panel A}: Co-pricing BMA-SDF} \\\\ \\midrule",
                     build_panel_rows(nt_a, tr_a, "Nontradable factors", "Tradable factors"),
                     build_panel_rows(bd_a, st_a, "Tradable bond factors", "Tradable stock factors"))
  }

  # Panel B: Bond
  if (!is.null(res_tbl_top$bond)) {
    data_b <- res_tbl_top$bond
    nt_b <- extract_block(data_b, "Nontraded factors", metrics)
    tr_b <- extract_block(data_b, "Tradable factors", metrics)

    latex_lines <- c(latex_lines,
                     "\\midrule",
                     "\\multicolumn{10}{c}{\\textbf{Panel B}: Bond BMA-SDF} \\\\ \\midrule",
                     build_panel_rows(nt_b, tr_b, "Nontradable factors", "Tradable factors"))
  }

  # Panel C: Stock
  if (!is.null(res_tbl_top$stock)) {
    data_c <- res_tbl_top$stock
    nt_c <- extract_block(data_c, "Nontraded factors", metrics)
    tr_c <- extract_block(data_c, "Tradable factors", metrics)

    latex_lines <- c(latex_lines,
                     "\\midrule",
                     "\\multicolumn{10}{c}{\\textbf{Panel C}: Stock BMA-SDF} \\\\ \\midrule",
                     build_panel_rows(nt_c, tr_c, "Nontradable factors", "Tradable factors"))
  }

  latex_lines <- c(latex_lines,
                   "\\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   "\t{\\footnotesize",
                   "The table reports posterior means of number of factors (along with the $90\\%$ confidence intervals), implied Sharpe ratios $\\mathbb{E}[SR_f|\\text{data}]$, and the ratio of $SR_f^2$ to the total SDF-implied squared Sharpe ratio $\\mathbb{E}\\big[SR^2_f/SR^2_m|\\text{data}\\big]$ for different subsets of factors. Subsets are tradable and nontradable factors,  and within tradables we further separate bond and stock factors.",
                   "Panels A, B and C report results for the co-pricing, bond-only and stock-only BMA-SDFs, respectively, using the corresponding factor zoos. The sample period is 1986:01 to 2022:12 ($T = 444$).",
                   "}",
                   "\\end{spacing}",
                   "\\vspace{-4mm}",
                   "\\end{table}")

  # Save if path provided
  if (!is.null(output_path)) {
    tex_file <- file.path(output_path, "table_4_sr_by_factor_type.tex")
    dir.create(dirname(tex_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(latex_lines, tex_file)
    if (verbose) message("  Saved: ", tex_file)
  }

  invisible(list(latex_lines = latex_lines))
}


# =========================================================================
#  Table 5: Discount Rate vs Cash-Flow News
# =========================================================================
#' Generate Table 5: Discount rate vs. cash-flow news
#'
#' Paper refs: Table 5; IA.5; IA.6.2
#'
#' @param res_tbl_top Named list from run_sr_decomposition_multi()
#' @param output_path Path to save .tex file (NULL = don't save)
#' @param verbose Print progress
#' @return List with latex_lines and data
generate_table_5 <- function(res_tbl_top,
                             output_path = NULL,
                             verbose = TRUE) {

  if (verbose) message("Generating Table 5: DR vs CF Decomposition...")

  metrics <- c("Mean", "5%", "95%", "E[SR_f|data]", "E[SR^2_f/SR^2_m|data]")
  metric_labels <- c("Mean", "5\\%", "95\\%",
                     "$\\mathbb{E}[SR_f|\\text{data}]$",
                     "$\\mathbb{E}\\big[\\frac{SR^2_f}{SR^2_m}|\\text{data}\\big]$")
  metric_digits <- c(2, 0, 0, 2, 2)
  metric_is_int <- c(FALSE, TRUE, TRUE, FALSE, FALSE)

  # Helper to build panel rows
  build_panel_rows <- function(dr_block, cf_block) {
    rows <- character(0)
    for (i in seq_along(metrics)) {
      dr_vals <- if (!is.null(dr_block)) as.numeric(dr_block[i, 2:5]) else rep(NA, 4)
      cf_vals <- if (!is.null(cf_block)) as.numeric(cf_block[i, 2:5]) else rep(NA, 4)

      fmt_dr <- sapply(dr_vals, format_latex_value,
                       digits = metric_digits[i], is_integer = metric_is_int[i])
      fmt_cf <- sapply(cf_vals, format_latex_value,
                       digits = metric_digits[i], is_integer = metric_is_int[i])

      rows <- c(rows,
                paste0(metric_labels[i], " & ",
                       paste(fmt_dr, collapse = " & "), " &  & ",
                       paste(fmt_cf, collapse = " & "), " \\\\"))
    }
    rows
  }

  # Start LaTeX
  latex_lines <- c(
    "\\begin{table}[tb!]",
    "\\begin{center}",
    "\\caption{Discount rate vs. cash-flow news}\\label{tab:table-model-dim1-dr-cf}\\vspace{-2mm}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccccccccc} \\toprule",
    "  & \\multicolumn{4}{c}{Discount rate news} &  & \\multicolumn{4}{c}{Cash-flow news} \\\\\\cmidrule(lr){2-5} \\cmidrule(lr){7-10}",
    " & \\multicolumn{4}{c}{Total prior SR} &  & \\multicolumn{4}{c}{Total prior SR} \\\\",
    " & 20\\% & 40\\% & 60\\% & 80\\% &  & 20\\% & 40\\% & 60\\% & 80\\% \\\\",
    "\\midrule"
  )

  # Panel A: Co-pricing
  if (!is.null(res_tbl_top$bond_stock_with_sp)) {
    data_a <- res_tbl_top$bond_stock_with_sp
    dr_a <- extract_block(data_a, "DR factors", metrics)
    cf_a <- extract_block(data_a, "CF factors", metrics)

    latex_lines <- c(latex_lines,
                     "\\multicolumn{10}{c}{\\textbf{Panel A}: Co-pricing BMA-SDF, tradable bond and stock factors} \\\\ \\midrule",
                     build_panel_rows(dr_a, cf_a))
  }

  # Panel B: Bond
  if (!is.null(res_tbl_top$bond)) {
    data_b <- res_tbl_top$bond
    dr_b <- extract_block(data_b, "DR factors", metrics)
    cf_b <- extract_block(data_b, "CF factors", metrics)

    latex_lines <- c(latex_lines,
                     "\\midrule",
                     "\\multicolumn{10}{c}{\\textbf{Panel B}: Bond BMA-SDF, tradable bond factors} \\\\ \\midrule",
                     build_panel_rows(dr_b, cf_b))
  }

  # Panel C: Stock
  if (!is.null(res_tbl_top$stock)) {
    data_c <- res_tbl_top$stock
    dr_c <- extract_block(data_c, "DR factors", metrics)
    cf_c <- extract_block(data_c, "CF factors", metrics)

    latex_lines <- c(latex_lines,
                     " \\midrule",
                     "\\multicolumn{10}{c}{\\textbf{Panel C}: Stock BMA-SDF, tradable stock factors} \\\\ \\midrule",
                     build_panel_rows(dr_c, cf_c))
  }

  latex_lines <- c(latex_lines,
                   "\\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   "\t{\\footnotesize",
                   "The table reports posterior means of number of factors (along with the $90\\%$ confidence intervals), implied Sharpe ratios $\\mathbb{E}[SR_f|\\text{data}]$, and the ratio of $SR_f^2$ to the total SDF-implied squared Sharpe ratio $\\mathbb{E}\\big[SR^2_f/SR^2_m|\\text{data}\\big]$ for discount rate and cash-flow news driven tradable factors, respectively. The discount rate vs. cash-flow news decomposition follows \\cite{Vuolteenaho_2002} and uses the repo's DR/CF factor classification. Panels A, B and C report, respectively, results for the co-pricing, bond-only, and stock-only BMA-SDFs, using the corresponding factor zoos.",
                   "}",
                   "\\end{spacing}",
                   "\\vspace{-4mm}",
                   "\\end{table}")

  # Save if path provided
  if (!is.null(output_path)) {
    tex_file <- file.path(output_path, "table_5_dr_vs_cf.tex")
    dir.create(dirname(tex_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(latex_lines, tex_file)
    if (verbose) message("  Saved: ", tex_file)
  }

  invisible(list(latex_lines = latex_lines))
}


# =========================================================================
#  Main Function: Generate All SR Tables
# =========================================================================
#' Generate all SR decomposition tables (1, 4, 5)
#'
#' @param res_tbl_top Named list from run_sr_decomposition_multi()
#' @param output_path Path to save .tex files
#' @param tables Which tables to generate (default: c(1, 4, 5))
#' @param verbose Print progress
#' @return List with results for each table
generate_sr_tables <- function(res_tbl_top,
                               output_path = NULL,
                               tables = c(1, 4, 5),
                               verbose = TRUE) {

  if (verbose) {
    message("\n", strrep("=", 60))
    message("GENERATING SR DECOMPOSITION TABLES")
    message(strrep("=", 60), "\n")
  }

  results <- list()

  if (1 %in% tables) {
    results$table_1 <- generate_table_1(res_tbl_top, output_path, verbose)
  }

  if (4 %in% tables) {
    results$table_4 <- generate_table_4(res_tbl_top, output_path, verbose)
  }

  if (5 %in% tables) {
    results$table_5 <- generate_table_5(res_tbl_top, output_path, verbose)
  }

  if (verbose) {
    message("\n", strrep("=", 60))
    message("TABLE GENERATION COMPLETE")
    if (!is.null(output_path)) {
      message("Tables saved to: ", normalizePath(output_path))
    }
    message(strrep("=", 60), "\n")
  }

  invisible(results)
}


# =========================================================================
#  Treasury Table: SR Decomposition for Treasury Component
# =========================================================================
#' Generate SR Decomposition Table for Treasury Component
#'
#' Creates a LaTeX table showing BMA-SDF dimensionality and Sharpe ratio
#' decomposition for the treasury model, with Nontradable and Tradable
#' factor panels side by side.
#'
#' @param sr_decomp_data Tibble from sr_decomposition() for treasury model
#' @param output_path Path to save .tex file (NULL = don't save)
#' @param table_name Filename for .tex file (default: "table_treasury_sr_decomp.tex")
#' @param n_nontraded Number of non-traded factors (for footnote)
#' @param n_traded Number of traded factors (for footnote)
#' @param verbose Print progress
#' @return List with latex_lines and data
generate_table_treasury_sr <- function(sr_decomp_data,
                                       output_path = NULL,
                                       table_name = "table_treasury_sr_decomp.tex",
                                       n_nontraded = 14,
                                       n_traded = 16,
                                       verbose = TRUE) {

  if (verbose) message("Generating Treasury SR Decomposition Table...")

  if (is.null(sr_decomp_data)) {
    warning("sr_decomp_data is NULL. Cannot generate treasury SR table.")
    return(NULL)
  }

  metrics <- c("Mean", "5%", "95%", "E[SR_f|data]", "E[SR^2_f/SR^2_m|data]")
  metric_labels <- c("Mean", "5\\%", "95\\%",
                     "$\\mathbb{E}[SR_f|\\text{data}]$",
                     "$\\mathbb{E}\\big[\\frac{SR^2_f}{SR^2_m}|\\text{data}\\big]$")
  metric_digits <- c(2, 0, 0, 2, 2)
  metric_is_int <- c(FALSE, TRUE, TRUE, FALSE, FALSE)

  # Extract nontraded and tradable factor blocks
  nt_block <- extract_block(sr_decomp_data, "Nontraded factors", metrics)
  tr_block <- extract_block(sr_decomp_data, "Tradable factors", metrics)

  if (verbose) {
    message("  Nontraded block rows: ", if(!is.null(nt_block)) nrow(nt_block) else 0)
    message("  Tradable block rows: ", if(!is.null(tr_block)) nrow(tr_block) else 0)
  }

  # Build LaTeX table
  latex_lines <- c(
    "\\begin{table}[tbh!]",
    "\\begin{center}",
    "\\caption{BMA-SDF dimensionality and Sharpe ratio decomposition for Treasury component}\\label{tab:table-model-dim-t-bond}",
    "\\scalebox{.8}{",
    "\\begin{tabular}{lcccccccccc} \\toprule",
    "& \\multicolumn{4}{c}{Total prior SR} &  & \\multicolumn{4}{c}{Total prior SR} \\\\",
    "& 20\\% & 40\\% & 60\\% & 80\\% &  & 20\\% & 40\\% & 60\\% & 80\\% \\\\  \\cmidrule(lr){2-5} \\cmidrule(lr){7-10}",
    " & \\multicolumn{4}{c}{Nontradable factors} &  & \\multicolumn{4}{c}{Tradable factors} \\\\ \\cmidrule(lr){2-5} \\cmidrule(lr){7-10}"
  )

  # Add data rows
  for (i in seq_along(metrics)) {
    nt_vals <- if (!is.null(nt_block) && nrow(nt_block) >= i) {
      as.numeric(nt_block[i, 2:5])
    } else {
      rep(NA, 4)
    }
    tr_vals <- if (!is.null(tr_block) && nrow(tr_block) >= i) {
      as.numeric(tr_block[i, 2:5])
    } else {
      rep(NA, 4)
    }

    fmt_nt <- sapply(nt_vals, format_latex_value,
                     digits = metric_digits[i], is_integer = metric_is_int[i])
    fmt_tr <- sapply(tr_vals, format_latex_value,
                     digits = metric_digits[i], is_integer = metric_is_int[i])

    latex_lines <- c(latex_lines,
                     paste0(metric_labels[i], " & ",
                            paste(fmt_nt, collapse = " & "), " &  & ",
                            paste(fmt_tr, collapse = " & "), " \\\\"))
  }

  # Footnote text
  footnote <- sprintf(
    "The table reports posterior means of number of factors (along with the $90\\%%$ confidence intervals), implied Sharpe ratios $\\mathbb{E}[SR_f|\\text{data}]$, and the ratio of $SR_f^2$ to the total SDF-implied squared Sharpe ratio $\\mathbb{E}\\big[SR^2_f/SR^2_m|\\text{data}\\big]$,
of the %d nontradable and %d tradable bond factors used in the treasury replication.
Test assets are the Treasury components of the 50 corporate bond portfolios in the repo's bond test-asset set. The sample period is 1986:01 to 2022:12 ($T = 444$).",
    n_nontraded, n_traded
  )

  latex_lines <- c(latex_lines,
                   "\\bottomrule",
                   "\\end{tabular}",
                   "}",
                   "\\end{center}",
                   "\\begin{spacing}{1}",
                   paste0("\t{\\footnotesize ", footnote),
                   "    }",
                   "\\end{spacing}",
                   "\\vspace{-0.5cm}",
                   "\\end{table}")

  # Save if path provided
  if (!is.null(output_path)) {
    tex_file <- file.path(output_path, table_name)
    dir.create(dirname(tex_file), recursive = TRUE, showWarnings = FALSE)
    writeLines(latex_lines, tex_file)
    if (verbose) message("  Saved: ", tex_file)
  }

  invisible(list(
    latex_lines = latex_lines,
    data = list(nontraded = nt_block, tradable = tr_block)
  ))
}
