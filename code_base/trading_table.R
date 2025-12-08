# ============================================================
#  trading_table.R - Table 6: Trading the BMA-SDF
#  ------------------------------------------------------------
#  Generates Table 6 Panel A: In-sample trading performance
#  of BMA-SDF and benchmark models.
# ============================================================

#' Generate Table 6 Panel A: In-sample Trading Performance
#'
#' Computes trading statistics for SDF mimicking portfolios:
#' Mean, SR, IR, Skewness, and Kurtosis.
#'
#' @param IS_AP In-sample asset pricing results containing sdf_mim
#' @param output_path Directory to save output files
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return List with results data frame and LaTeX table
#'
#' @details
#' All factors are scaled to have the same monthly volatility as CAPM.
#' Mean and ratios are annualized. Kurtosis is excess kurtosis.
#' IR is computed as alpha / residual_vol from regression on EqualWeight.
#'
#' @examples
#' \dontrun{
#'   result <- generate_table_6_panel_a(IS_AP, output_path = "output/paper/tables")
#' }
generate_table_6_panel_a <- function(IS_AP,
                                     output_path = "output/paper/tables",
                                     verbose = TRUE) {

  if (is.null(IS_AP$sdf_mim)) {
    stop("IS_AP$sdf_mim is required but not found")
  }

  ##-----------------------------------------------------------------------##
  ## 1. Extract and prepare data                                           ##
  ##-----------------------------------------------------------------------##
  sdf_mim <- IS_AP$sdf_mim

  # Columns we need (in order for the table)
  cols_needed <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                   "Top-80%", "Top-MPR-80%",
                   "KNS", "RP-PCA", "FF5", "HKM", "CAPMB", "CAPM", "EqualWeight")

  # Check which columns exist

  missing_cols <- setdiff(cols_needed, colnames(sdf_mim))
  if (length(missing_cols) > 0) {
    warning("Missing columns in sdf_mim: ", paste(missing_cols, collapse = ", "))
  }

  # Use only available columns
  cols_avail <- intersect(cols_needed, colnames(sdf_mim))
  if (length(cols_avail) == 0) {
    stop("No required columns found in sdf_mim")
  }

  # Extract data matrix (exclude date column if present)
  if ("date" %in% colnames(sdf_mim)) {
    data_mat <- as.matrix(sdf_mim[, cols_avail, drop = FALSE])
  } else {
    data_mat <- as.matrix(sdf_mim[, cols_avail, drop = FALSE])
  }

  if (verbose) {
    message("Table 6 Panel A: Using ", ncol(data_mat), " columns, ",
            nrow(data_mat), " observations")
  }

  ##-----------------------------------------------------------------------##
  ## 2. Scale all factors to have same monthly vol as CAPM                 ##
  ##-----------------------------------------------------------------------##
  if (!"CAPM" %in% colnames(data_mat)) {
    stop("CAPM column required for volatility scaling")
  }

  target_vol <- sd(data_mat[, "CAPM"], na.rm = TRUE)

  scaled_mat <- data_mat
  for (col in colnames(scaled_mat)) {
    col_vol <- sd(scaled_mat[, col], na.rm = TRUE)
    if (col_vol > 0) {
      scaled_mat[, col] <- scaled_mat[, col] * (target_vol / col_vol)
    }
  }

  if (verbose) {
    message("  Scaled all factors to CAPM monthly vol: ",
            round(target_vol * 100, 4), "%")
  }

  ##-----------------------------------------------------------------------##
  ## 3. Compute statistics                                                 ##
  ##-----------------------------------------------------------------------##

  # Helper: compute excess kurtosis
  excess_kurtosis <- function(x) {
    x <- x[!is.na(x)]
    n <- length(x)
    if (n < 4) return(NA_real_)
    m <- mean(x)
    s <- sd(x)
    kurt <- mean(((x - m) / s)^4)
    # Excess kurtosis = kurtosis - 3
    kurt - 3
  }

  # Helper: compute skewness
  skewness <- function(x) {
    x <- x[!is.na(x)]
    n <- length(x)
    if (n < 3) return(NA_real_)
    m <- mean(x)
    s <- sd(x)
    mean(((x - m) / s)^3)
  }

  # Helper: compute IR (alpha / residual_vol, annualized)
  compute_ir <- function(y, benchmark) {
    y <- as.numeric(y)
    benchmark <- as.numeric(benchmark)
    valid <- !is.na(y) & !is.na(benchmark)
    if (sum(valid) < 10) return(NA_real_)

    fit <- lm(y[valid] ~ benchmark[valid])
    alpha <- coef(fit)[1]
    resid_vol <- sd(residuals(fit))

    if (resid_vol == 0) return(NA_real_)
    # Annualize: alpha * 12 / (resid_vol * sqrt(12)) = alpha * sqrt(12) / resid_vol
    (alpha / resid_vol) * sqrt(12)
  }

  # Get EqualWeight as benchmark for IR
  if (!"EqualWeight" %in% colnames(scaled_mat)) {
    warning("EqualWeight not found, IR will be NA")
    ew_benchmark <- rep(NA, nrow(scaled_mat))
  } else {
    ew_benchmark <- scaled_mat[, "EqualWeight"]
  }

  # Compute statistics for each column
  stats_list <- list()

  for (col in colnames(scaled_mat)) {
    x <- scaled_mat[, col]

    # Mean: annualized, in percent
    mean_ann <- mean(x, na.rm = TRUE) * 12 * 100

    # SR: annualized
    sr_ann <- (mean(x, na.rm = TRUE) / sd(x, na.rm = TRUE)) * sqrt(12)

    # IR: annualized (EqualWeight gets "--")
    if (col == "EqualWeight") {
      ir_ann <- NA_real_  # Will display as "--"
    } else {
      ir_ann <- compute_ir(x, ew_benchmark)
    }

    # Skewness
    skew_val <- skewness(x)

    # Excess Kurtosis
    kurt_val <- excess_kurtosis(x)

    stats_list[[col]] <- c(
      Mean = mean_ann,
      SR = sr_ann,
      IR = ir_ann,
      Skew = skew_val,
      Kurt = kurt_val
    )
  }

  # Combine into data frame
  stats_df <- as.data.frame(do.call(cbind, stats_list))
  rownames(stats_df) <- c("Mean", "SR", "IR", "Skew", "Kurt")

  ##-----------------------------------------------------------------------##
  ## 4. Rename columns for LaTeX output                                    ##
  ##-----------------------------------------------------------------------##
  col_rename <- c(
    "BMA-20%" = "20%",
    "BMA-40%" = "40%",
    "BMA-60%" = "60%",
    "BMA-80%" = "80%",
    "Top-80%" = "TOP_gamma",
    "Top-MPR-80%" = "TOP_lambda",
    "KNS" = "KNS",
    "RP-PCA" = "RPPCA",
    "FF5" = "FF5",
    "HKM" = "HKM",
    "CAPMB" = "MKTB",
    "CAPM" = "MKTS",
    "EqualWeight" = "EW"
  )

  # Reorder and rename
  final_order <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                   "Top-80%", "Top-MPR-80%",
                   "KNS", "RP-PCA", "FF5", "HKM", "CAPMB", "CAPM", "EqualWeight")
  final_order <- intersect(final_order, colnames(stats_df))

  stats_df <- stats_df[, final_order, drop = FALSE]
  colnames(stats_df) <- col_rename[colnames(stats_df)]

  ##-----------------------------------------------------------------------##
  ## 5. Generate LaTeX table                                               ##
  ##-----------------------------------------------------------------------##

  # Format numbers
  format_num <- function(x, digits = 2) {
    if (is.na(x)) return("--")
    if (x < 0) {
      return(sprintf("$-$%.*f", digits, abs(x)))
    } else {
      return(sprintf("%.*f", digits, x))
    }
  }

  # Build LaTeX rows
  latex_lines <- c()

  # Header
  latex_lines <- c(latex_lines,
    "\\begin{table}[tbh!]",
    "\\begin{center}",
    "\\caption{Trading the BMA-SDF and benchmark models}\\label{tab:tab-fmp}\\vspace{-2mm}",
    "\\resizebox{16.5cm}{!}{",
    "\\begin{tabular}{lcccc|ccccccccc}\\toprule",
    " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & TOP $\\gamma$ & TOP $\\lambda$ & KNS & RPPCA & FF5 & HKM & MKTB & MKTS & EW \\\\ \\cmidrule(lr){2-5}",
    " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  &  &  \\\\ \\midrule",
    " \\multicolumn{14}{c}{\\textbf{Panel A:} In-sample -- 1986:01 to 2022:12 ($T=444$)} \\\\",
    " \\midrule"
  )

  # Data rows
  row_names <- c("Mean", "SR", "IR", "Skew", "Kurt")
  for (rn in row_names) {
    vals <- sapply(stats_df[rn, ], function(v) format_num(v, digits = 2))
    latex_lines <- c(latex_lines,
      paste0(rn, " & ", paste(vals, collapse = " & "), " \\\\"))
  }

  # Footer (Panel A only)
  latex_lines <- c(latex_lines,
    "\\midrule",
    "\\end{tabular}",
    "}",
    "\\end{center}",
    "\\end{table}"
  )

  latex_table <- paste(latex_lines, collapse = "\n")

  ##-----------------------------------------------------------------------##
  ## 6. Save outputs                                                       ##
  ##-----------------------------------------------------------------------##
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
  }

  # Save CSV
  csv_path <- file.path(output_path, "table_6_panel_a_trading.csv")
  write.csv(stats_df, csv_path, row.names = TRUE)
  if (verbose) message("  Saved: ", csv_path)

  # Save LaTeX
  tex_path <- file.path(output_path, "table_6_panel_a_trading.tex")
  writeLines(latex_table, tex_path)
  if (verbose) message("  Saved: ", tex_path)

  ##-----------------------------------------------------------------------##
  ## 7. Return results                                                     ##
  ##-----------------------------------------------------------------------##
  invisible(list(
    stats = stats_df,
    latex = latex_table,
    scaled_data = scaled_mat,
    target_vol = target_vol
  ))
}
