#' Evaluate Out-of-Sample Performance for Paper (Slimmed Version)
#'
#' Computes out-of-sample portfolio returns and generates only the paper outputs:
#' - Figure 7: Cumulative return plot (fig7_oos_cumret.pdf)
#' - Table 6 Panel B: Trading performance table (table_6_panel_b_trading.tex)
#'
#' @param combined_results List returned by run_time_varying_estimation()
#' @param main_path       Project root path
#' @param data_folder     Data subfolder
#' @param f2              File name(s) for traded factors
#' @param R               File name(s) for test assets
#' @param fac_freq        File name for frequentist factors
#' @param vol_scale       Model to use for volatility scaling (default: "MKTS")
#' @param factor_vec      Portfolios to include in plots
#' @param color_vec       Colors for each portfolio
#' @param line_types_vec  Line types for each portfolio
#' @param legend_position Legend position (x, y)
#' @param dollar_step     Y-axis dollar spacing
#' @param fig_width       Figure width in inches
#' @param fig_height      Figure height in inches
#' @param verbose         Print progress messages?
#'
#' @return List containing:
#'   - oos_returns_scaled: Volatility-scaled returns data.frame
#'   - performance_short: Short performance metrics table
#'   - latex_table: LaTeX code for Table 6 Panel B
#'   - cumret_plot: ggplot object for Figure 7

evaluate_performance_paper <- function(
    combined_results,
    main_path        = NULL,
    data_folder      = NULL,
    f2               = NULL,
    R                = NULL,
    fac_freq         = NULL,
    vol_scale        = "MKTS",
    factor_vec       = NULL,
    color_vec        = NULL,
    line_types_vec   = NULL,
    legend_position  = c(0.02, 0.98),
    dollar_step      = 50,
    fig_width        = 12,
    fig_height       = 7,
    verbose          = TRUE
) {

  library(dplyr)
  library(lubridate)
  library(xtable)

  ## -------------------------------------------------------------------------
  ## 1. Extract Metadata and Validate
  ## -------------------------------------------------------------------------

  if (!"metadata" %in% names(combined_results)) {
    stop("combined_results must contain 'metadata' element")
  }

  metadata <- combined_results$metadata
  holding_period <- metadata$holding_period

  if (verbose) {
    cat("\n")
    cat("=====================================\n")
    cat("PAPER: OUT-OF-SAMPLE PERFORMANCE\n")
    cat("=====================================\n\n")
    cat("Holding period: ", holding_period, " months\n")
    cat("Analysis period: ", metadata$date_start, " to ", metadata$date_end, "\n\n")
  }

  ## -------------------------------------------------------------------------
  ## 2. Setup Paths
  ## -------------------------------------------------------------------------

  # Use metadata paths if not provided
  if (is.null(main_path)) main_path <- metadata$paths$main_path
  if (is.null(data_folder)) data_folder <- metadata$paths$data_folder

  # Validate required parameters
  if (is.null(main_path)) stop("main_path must be provided")
  if (is.null(data_folder)) stop("data_folder must be provided")
  if (is.null(f2)) stop("f2 file name(s) must be provided")
  if (is.null(R)) stop("R file name(s) must be provided")
  if (is.null(fac_freq)) stop("fac_freq file name must be provided")

  data_path <- if (dir.exists(data_folder)) {
    data_folder
  } else {
    file.path(main_path, data_folder)
  }

  if (!dir.exists(data_path)) {
    stop("data_folder does not exist: ", data_path)
  }

  path_data <- function(file) file.path(data_path, file)

  ## -------------------------------------------------------------------------
  ## 3. Load Asset Return Data
  ## -------------------------------------------------------------------------

  if (verbose) cat("Loading asset return data...\n")

  # Load f2, R, and fac_freq using existing helpers
  f2_data <- load_and_combine_files(f2, path_data, "f2", verbose = verbose)
  R_data <- load_and_combine_files(R, path_data, "R", verbose = verbose)
  fac_freq_data <- load_and_combine_files(fac_freq, path_data, "fac_freq", verbose = verbose)

  # Validate and align all three datasets
  aligned <- validate_and_align_dates(
    data_list = list(f2 = f2_data, R = R_data, fac_freq = fac_freq_data),
    date_start = NULL,
    date_end = NULL,
    verbose = FALSE
  )

  # Extract aligned data
  f2_aligned <- aligned$data$f2
  R_aligned <- aligned$data$R
  fac_freq_aligned <- aligned$data$fac_freq

  # Create combined R + f2 dataset for RP-PCA, PCA, KNS models
  Rc_aligned <- merge(R_aligned, f2_aligned, by = "date", all = FALSE, sort = TRUE)

  # Convert to matrices
  f2_returns <- as.matrix(f2_aligned[, -1, drop = FALSE])
  f2_dates <- f2_aligned$date

  R_returns <- as.matrix(R_aligned[, -1, drop = FALSE])
  R_dates <- R_aligned$date

  fac_freq_returns <- as.matrix(fac_freq_aligned[, -1, drop = FALSE])
  fac_freq_dates <- fac_freq_aligned$date

  Rc_returns <- as.matrix(Rc_aligned[, -1, drop = FALSE])
  Rc_dates <- Rc_aligned$date

  if (verbose) {
    cat("  Aligned data period: ", aligned$date_range["start"], " to ",
        aligned$date_range["end"], "\n")
    cat("  f2: ", nrow(f2_aligned), " dates x ", ncol(f2_returns), " factors\n")
    cat("  R: ", nrow(R_aligned), " dates x ", ncol(R_returns), " assets\n")
    cat("  Rc (R+f2): ", nrow(Rc_aligned), " dates x ", ncol(Rc_returns), " columns\n\n")
  }

  ## -------------------------------------------------------------------------
  ## 4. Extract Weights Panel
  ## -------------------------------------------------------------------------

  df_weights <- combined_results$weights_panel

  if (verbose) {
    cat("Weights panel: ", nrow(df_weights), " rows\n")
    cat("Unique models: ", length(unique(df_weights$model)), "\n")
    cat("Unique dates: ", length(unique(df_weights$date)), "\n\n")
  }

  ## -------------------------------------------------------------------------
  ## 5. Helper: Determine Data Source for Each Model
  ## -------------------------------------------------------------------------

  get_model_data <- function(model_name) {
    if (grepl("^BMA-", model_name)) {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (grepl("^Top-", model_name)) {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (model_name == "RP-PCAf2") {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (model_name == "RP-PCA") {
      return(list(returns = Rc_returns, dates = Rc_dates, name = "Rc"))
    }
    if (model_name == "KNSf2") {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    if (model_name == "KNS") {
      return(list(returns = Rc_returns, dates = Rc_dates, name = "Rc"))
    }
    if (model_name %in% c("Tangency", "MinVar", "EqualWeight", "Optimal")) {
      return(list(returns = f2_returns, dates = f2_dates, name = "f2"))
    }
    return(list(returns = fac_freq_returns, dates = fac_freq_dates, name = "fac_freq"))
  }

  ## -------------------------------------------------------------------------
  ## 6. Compute Out-of-Sample Returns
  ## -------------------------------------------------------------------------

  if (verbose) cat("Computing out-of-sample portfolio returns...\n")

  unique_models <- unique(df_weights$model)
  unique_weight_dates <- sort(unique(df_weights$date))

  if (!inherits(unique_weight_dates, "Date")) {
    unique_weight_dates <- as.Date(unique_weight_dates)
  }

  oos_results_list <- list()

  for (model_name in unique_models) {

    if (verbose) cat("  Processing model: ", model_name, "\n")

    model_data <- get_model_data(model_name)
    returns_matrix <- model_data$returns
    returns_dates <- model_data$dates
    asset_names <- colnames(returns_matrix)

    model_weights <- df_weights %>%
      filter(model == model_name) %>%
      arrange(date)

    if (!inherits(model_weights$date, "Date")) {
      model_weights$date <- as.Date(model_weights$date)
    }

    model_oos_returns <- list()

    for (i in seq_along(unique_weight_dates)) {

      weight_date <- unique_weight_dates[i]
      wts_at_date <- model_weights[model_weights$date == weight_date, ]

      if (nrow(wts_at_date) == 0) next

      weight_vec <- setNames(wts_at_date$weight, wts_at_date$factor)

      # Handle missing factors
      missing_factors <- setdiff(names(weight_vec), asset_names)
      if (length(missing_factors) > 0) {
        missing_pct <- length(missing_factors) / length(weight_vec) * 100
        if (missing_pct > 90) next
        weight_vec <- weight_vec[names(weight_vec) %in% asset_names]
        if (length(weight_vec) > 0) {
          weight_vec <- weight_vec / sum(weight_vec)
        }
      }

      if (length(weight_vec) == 0) next

      # Find return dates
      weight_date_obj <- as.Date(weight_date, origin = "1970-01-01")
      return_start_date <- weight_date_obj %m+% months(1)
      return_end_date <- weight_date_obj %m+% months(holding_period)

      return_period_idx <- which(returns_dates >= return_start_date &
                                   returns_dates <= return_end_date)

      if (length(return_period_idx) == 0) next

      for (ret_idx in return_period_idx) {
        ret_date <- returns_dates[ret_idx]
        ret_row <- returns_matrix[ret_idx, , drop = FALSE]
        factor_returns <- ret_row[1, names(weight_vec)]

        if (any(is.na(factor_returns))) {
          factor_returns[is.na(factor_returns)] <- 0
        }

        portfolio_return <- sum(weight_vec * factor_returns)

        model_oos_returns[[length(model_oos_returns) + 1]] <- data.frame(
          date = ret_date,
          weight_date = as.Date(weight_date, origin = "1970-01-01"),
          return = portfolio_return,
          stringsAsFactors = FALSE
        )
      }
    }

    if (length(model_oos_returns) > 0) {
      model_df <- do.call(rbind, model_oos_returns)
      model_df$model <- model_name
      oos_results_list[[model_name]] <- model_df
    }
  }

  if (verbose) cat("  All models processed.\n\n")

  ## -------------------------------------------------------------------------
  ## 7. Combine Results into Wide Format
  ## -------------------------------------------------------------------------

  if (length(oos_results_list) == 0) {
    stop("No out-of-sample returns computed for any model")
  }

  oos_long <- do.call(rbind, oos_results_list)
  rownames(oos_long) <- NULL

  oos_wide <- oos_long %>%
    select(date, model, return) %>%
    tidyr::pivot_wider(names_from = model, values_from = return, values_fn = mean) %>%
    arrange(date)

  if (verbose) {
    cat("Out-of-sample returns computed:\n")
    cat("  Date range: ", format(min(oos_wide$date), "%Y-%m-%d"), " to ",
        format(max(oos_wide$date), "%Y-%m-%d"), "\n")
    cat("  Number of dates: ", nrow(oos_wide), "\n")
    cat("  Number of models: ", ncol(oos_wide) - 1, "\n\n")
  }

  ## -------------------------------------------------------------------------
  ## 8. Add Raw Benchmark Factors
  ## -------------------------------------------------------------------------

  if (verbose) cat("Adding raw benchmark factors...\n")

  oos_dates <- oos_wide$date
  fac_freq_df <- data.frame(date = fac_freq_dates, fac_freq_returns, check.names = FALSE)

  benchmark_factors <- c("MKTS", "MKTB")
  available_benchmarks <- intersect(benchmark_factors, colnames(fac_freq_df))

  if (length(available_benchmarks) > 0) {
    existing_cols <- colnames(oos_wide)
    new_benchmarks <- setdiff(available_benchmarks, existing_cols)

    if (length(new_benchmarks) > 0) {
      benchmark_df <- fac_freq_df %>%
        dplyr::select(date, all_of(new_benchmarks)) %>%
        dplyr::filter(date %in% oos_dates)

      oos_wide <- oos_wide %>%
        dplyr::left_join(benchmark_df, by = "date")

      if (verbose) cat("  Added: ", paste(new_benchmarks, collapse = ", "), "\n")
    }
  }

  if (verbose) cat("\n")

  ## -------------------------------------------------------------------------
  ## 9. Volatility Scaling
  ## -------------------------------------------------------------------------

  oos_returns_raw <- as.data.frame(oos_wide)
  model_cols <- setdiff(colnames(oos_returns_raw), "date")

  if (!is.null(vol_scale) && vol_scale %in% model_cols) {
    if (verbose) cat("Applying volatility scaling to match: ", vol_scale, "\n")

    target_vol <- sd(oos_returns_raw[[vol_scale]], na.rm = TRUE)

    if (verbose) cat("  Target monthly vol: ", round(target_vol * 100, 4), "%\n\n")

    oos_returns_scaled <- oos_returns_raw
    for (col in model_cols) {
      col_vol <- sd(oos_returns_raw[[col]], na.rm = TRUE)
      if (col_vol > 0) {
        scale_factor <- target_vol / col_vol
        oos_returns_scaled[[col]] <- oos_returns_raw[[col]] * scale_factor
      }
    }
  } else {
    oos_returns_scaled <- oos_returns_raw
    target_vol <- NA
  }

  ## -------------------------------------------------------------------------
  ## 10. Compute Performance Metrics
  ## -------------------------------------------------------------------------

  if (verbose) cat("Computing performance metrics...\n")

  calc_mean_ann <- function(x) mean(x, na.rm = TRUE) * 12 * 100
  calc_vol_ann <- function(x) sd(x, na.rm = TRUE) * sqrt(12) * 100
  calc_sr <- function(x) (mean(x, na.rm = TRUE) / sd(x, na.rm = TRUE)) * sqrt(12)

  calc_sortino <- function(x) {
    mu <- mean(x, na.rm = TRUE)
    downside <- x[x < 0]
    if (length(downside) < 2) return(NA)
    downside_vol <- sd(downside, na.rm = TRUE)
    if (downside_vol == 0) return(NA)
    (mu / downside_vol) * sqrt(12)
  }

  calc_skew <- function(x) {
    n <- sum(!is.na(x))
    if (n < 3) return(NA)
    x_clean <- x[!is.na(x)]
    x_centered <- x_clean - mean(x_clean)
    s <- sd(x_clean)
    if (s == 0) return(NA)
    mean(x_centered^3) / s^3
  }

  calc_excess_kurt <- function(x) {
    n <- sum(!is.na(x))
    if (n < 4) return(NA)
    x_clean <- x[!is.na(x)]
    x_centered <- x_clean - mean(x_clean)
    s <- sd(x_clean)
    if (s == 0) return(NA)
    mean(x_centered^4) / s^4 - 3
  }

  calc_ir <- function(y, benchmark) {
    if (all(is.na(benchmark)) || all(is.na(y))) return(NA)
    valid_idx <- !is.na(y) & !is.na(benchmark)
    if (sum(valid_idx) < 10) return(NA)
    y_clean <- y[valid_idx]
    x_clean <- benchmark[valid_idx]
    fit <- lm(y_clean ~ x_clean)
    alpha_month <- coef(fit)["(Intercept)"]
    resid_vol <- sd(resid(fit))
    if (resid_vol == 0) return(NA)
    (alpha_month / resid_vol) * sqrt(12)
  }

  # Get EW as benchmark for IR
  ew_col <- if ("EW" %in% model_cols) "EW" else if ("EqualWeight" %in% model_cols) "EqualWeight" else NULL
  ew_returns <- if (!is.null(ew_col)) oos_returns_scaled[[ew_col]] else rep(NA, nrow(oos_returns_scaled))

  perf_list <- list()
  for (col in model_cols) {
    x <- oos_returns_scaled[[col]]
    perf_list[[col]] <- data.frame(
      Model = col,
      Mean = calc_mean_ann(x),
      Vol = calc_vol_ann(x),
      SR = calc_sr(x),
      ST = calc_sortino(x),
      IR = if (col == ew_col) NA else calc_ir(x, ew_returns),
      Skew = calc_skew(x),
      Kurt = calc_excess_kurt(x),
      stringsAsFactors = FALSE
    )
  }

  perf_df <- do.call(rbind, perf_list)
  rownames(perf_df) <- NULL

  # Rename EqualWeight to EW for display
  perf_df_display <- perf_df
  perf_df_display$Model[perf_df_display$Model == "EqualWeight"] <- "EW"

  # Create short table
  short_models <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                    "Top-80%", "Top-MPR-80%", "KNS", "RP-PCA",
                    "FF5", "HKM", "MKTB", "MKTS", "EW")

  perf_short <- perf_df_display %>%
    filter(Model %in% short_models)

  desired_order <- short_models
  perf_short <- perf_short[match(intersect(desired_order, perf_short$Model), perf_short$Model), ]

  ## -------------------------------------------------------------------------
  ## 11. Generate Combined Table 6 (Panel A + Panel B)
  ## -------------------------------------------------------------------------

  if (verbose) cat("Generating Combined Table 6 (Panel A + Panel B)...\n")

  # Read Panel A data from CSV (generated by generate_table_6_panel_a)
  panel_a_csv <- file.path(metadata$paths$output_folder, "paper", "tables", "table_6_panel_a_trading.csv")
  panel_a_data <- NULL
  if (file.exists(panel_a_csv)) {
    panel_a_data <- read.csv(panel_a_csv, row.names = 1, check.names = FALSE)
    if (verbose) cat("  Loaded Panel A data from: ", panel_a_csv, "\n")
  } else {
    warning("Panel A CSV not found: ", panel_a_csv, ". Table will only contain Panel B.")
  }

  # Panel B date range
  date_start_b <- format(min(oos_wide$date), "%Y:%m")
  date_end_b <- format(max(oos_wide$date), "%Y:%m")
  T_obs_b <- nrow(oos_wide)

  # Column order for table (internal names)
  col_order_internal <- c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%",
                          "Top-80%", "Top-MPR-80%", "KNS", "RP-PCA",
                          "FF5", "HKM", "MKTB", "MKTS", "EW")

  # Prepare Panel B data
  models_avail_b <- intersect(col_order_internal, perf_df_display$Model)
  df_b <- perf_df_display %>% filter(Model %in% models_avail_b)
  df_b <- df_b[match(intersect(col_order_internal, df_b$Model), df_b$Model), ]

  n_models <- nrow(df_b)

  # Format function - always 2 decimal places
  fmt_num <- function(x, digits = 2) {
    if (is.na(x)) return("--")
    if (x < 0) {
      sprintf("$-$%.2f", abs(x))
    } else {
      sprintf("%.2f", x)
    }
  }

  # Build LaTeX table
  latex <- character()
  latex <- c(latex, "\\begin{table}[tbh!]")
  latex <- c(latex, "\\begin{center}")
  latex <- c(latex, "\\caption{Trading the BMA-SDF and benchmark models}\\label{tab:tab-fmp}\\vspace{-2mm}")
  latex <- c(latex, "\\resizebox{16.5cm}{!}{")
  latex <- c(latex, "\\begin{tabular}{lcccc|ccccccccc}\\toprule")
  latex <- c(latex, " & \\multicolumn{4}{c}{BMA-SDF prior Sharpe ratio} & TOP $\\gamma$ & TOP $\\lambda$ & KNS & RPPCA & FF5 & HKM & MKTB & MKTS & EW \\\\ \\cmidrule(lr){2-5}")
  latex <- c(latex, " & 20\\% & 40\\% & 60\\% & \\multicolumn{1}{c}{80\\%} &  &  &  &  &  &  &  &  &  \\\\ \\midrule")

  # Panel A (if available)
  if (!is.null(panel_a_data)) {
    latex <- c(latex, " \\multicolumn{14}{c}{\\textbf{Panel A:} In-sample -- 1986:01 to 2022:12 ($T=444$)} \\\\")
    latex <- c(latex, " \\midrule")

    # Map Panel A column names to table order
    col_map_a <- c("20%" = "20%", "40%" = "40%", "60%" = "60%", "80%" = "80%",
                   "TOP_gamma" = "TOP_gamma", "TOP_lambda" = "TOP_lambda",
                   "KNS" = "KNS", "RPPCA" = "RPPCA", "FF5" = "FF5", "HKM" = "HKM",
                   "MKTB" = "MKTB", "MKTS" = "MKTS", "EW" = "EW")

    panel_a_order <- c("20%", "40%", "60%", "80%", "TOP_gamma", "TOP_lambda",
                       "KNS", "RPPCA", "FF5", "HKM", "MKTB", "MKTS", "EW")
    panel_a_avail <- intersect(panel_a_order, colnames(panel_a_data))

    metrics_a <- c("Mean", "SR", "IR", "Skew", "Kurt")
    for (metric in metrics_a) {
      if (metric %in% rownames(panel_a_data)) {
        row_vals <- sapply(panel_a_avail, function(col) {
          val <- panel_a_data[metric, col]
          if (metric == "IR" && col == "EW") return("--")
          fmt_num(val)
        })
        latex <- c(latex, paste0(metric, " & ", paste(row_vals, collapse = " & "), " \\\\"))
      }
    }
    latex <- c(latex, "\\midrule")
  }

  # Panel B
  latex <- c(latex, paste0(" \\multicolumn{14}{c}{\\textbf{Panel B:} Out-of-sample -- ",
                           date_start_b, " to ", date_end_b, " ($T=", T_obs_b, "$)} \\\\"))
  latex <- c(latex, " \\midrule")

  # Panel B metrics (NO ST - removed as requested)
  metrics_b <- c("Mean", "SR", "IR", "Skew", "Kurt")

  for (metric in metrics_b) {
    row_vals <- sapply(df_b$Model, function(m) {
      val <- df_b[[metric]][df_b$Model == m]
      if (metric == "IR" && m == "EW") return("--")
      fmt_num(val)
    })
    latex <- c(latex, paste0(metric, " & ", paste(row_vals, collapse = " & "), " \\\\"))
  }

  latex <- c(latex, "\\midrule")
  latex <- c(latex, "\\end{tabular}")
  latex <- c(latex, "}")
  latex <- c(latex, "\\end{center}")

  # Full caption from tab6.txt
  latex <- c(latex, "\\begin{spacing}{1}")
  latex <- c(latex, "{\\footnotesize")
  latex <- c(latex, "    In-sample (Panel A) and out-of-sample (Panel B) performance of the co-pricing BMA-SDF tradable portfolio across prior SR levels, the `TOP' model factors portfolios, the latent co-pricing factor models (KNS and RPPCA), notable benchmark models (FF5, HKM, MKTS, MKTB) and the equally-weighted portfolio (EW) of all (40) tradable factors.")
  latex <- c(latex, "    The in-sample weights for the tradable portfolios are formed scaling the (posterior means of the) MPRs to sum to one in each specification considered.")
  latex <- c(latex, "    The Top $\\gamma$ ($\\lambda$) model uses the MPRs from the most likely (highest absolute MPRs) factors with 80\\% shrinkage.")
  latex <- c(latex, "    These factors are: PEADB, PEAD, CMAs, CRY and MOMBS ($\\gamma$) and PEADB, MOMBS, CRY, PEAD and CMAs ($\\lambda$).")
  latex <- c(latex, "    For KNS, the weights are obtained directly from the \\citet{KozakNagelSantosh_2020} procedure.")
  latex <- c(latex, "    For RPPCA, FF5 and HKM, the weights are estimated via GMM.")
  latex <- c(latex, "    In Panel B, the results are strictly out-of-sample.")
  latex <- c(latex, "    An expanding window is used with an initial window of 222 months to conduct the estimation.")
  latex <- c(latex, "    These weights are then used to invest in the factors over the next 12 months.")
  latex <- c(latex, "    Thereafter, we re-estimate the models in an expanding fashion every year.")
  latex <- c(latex, "    The Top model input factors change dynamically at each estimation.")
  latex <- c(latex, "    For KNS, we re-conduct the two-fold cross-validation at every estimation to pin down the optimal parameters.")
  latex <- c(latex, "    For RPPCA, we re-estimate the PCs at every estimation.")
  latex <- c(latex, "    The Mean is annualized and presented in percent.")
  latex <- c(latex, "    The Sharpe ratio and Information ratio are annualized.")
  latex <- c(latex, "    The benchmark factor to compute the IR is the EW factor.")
  latex <- c(latex, "    Skew and Kurt are skewness and kurtosis, respectively.")
  latex <- c(latex, "    The models are estimated with the 83 bond and stock portfolios and the 40 tradable bond and stock factors ($N = 123$).")
  latex <- c(latex, "    For the BMA-SDFs, we report results for a range of prior Sharpe ratio values that are set as 20\\%, 40\\%, 60\\% and 80\\% of the ex post maximum Sharpe ratio of the relevant portfolios and factors. In Panel B, this ratio changes with the expanding window.")
  latex <- c(latex, "    The IS period is 1986:01 to 2022:12 ($T=444$) and the OS period is 2004:07 to 2022:12 ($T=222$).")
  latex <- c(latex, "    }")
  latex <- c(latex, "\\end{spacing}")
  latex <- c(latex, "\\vspace{-4mm}")
  latex <- c(latex, "\\end{table}")

  latex_table <- paste(latex, collapse = "\n")

  ## -------------------------------------------------------------------------
  ## 12. Save LaTeX Table
  ## -------------------------------------------------------------------------

  output_base <- metadata$paths$output_folder
  tables_dir <- file.path(output_base, "paper", "tables")

  if (!dir.exists(tables_dir)) {
    dir.create(tables_dir, recursive = TRUE)
    if (verbose) cat("Created tables directory: ", tables_dir, "\n")
  }

  table_file <- file.path(tables_dir, "table_6_trading.tex")
  writeLines(latex_table, table_file)
  if (verbose) cat("Table 6 (combined) saved to: ", table_file, "\n")

  ## -------------------------------------------------------------------------
  ## 13. Generate Figure 7 (Cumulative Return Plot)
  ## -------------------------------------------------------------------------

  cumret_plot <- NULL

  if (!is.null(factor_vec) && length(factor_vec) > 0) {

    if (verbose) cat("\nGenerating Figure 7 (cumulative returns)...\n")

    if (!exists("plot_cumret", mode = "function")) {
      warning("plot_cumret() function not found. Please source plot_portfolio_analytics.R")
    } else {

      figures_base <- file.path(output_base, "paper")

      cumret_plot <- plot_cumret(
        df_scaled          = oos_returns_scaled,
        factor_vec         = factor_vec,
        color_vec          = color_vec,
        line_types_vec     = line_types_vec,
        legend_position    = legend_position,
        dollar_step        = dollar_step,
        output_dir         = figures_base,
        fig_name           = "fig7_oos_cumret.pdf",
        width              = fig_width,
        height             = fig_height,
        save_plot          = TRUE,
        verbose            = verbose
      )
    }
  }

  ## -------------------------------------------------------------------------
  ## 14. Return Results
  ## -------------------------------------------------------------------------

  return(list(
    oos_returns_scaled = oos_returns_scaled,
    performance_short  = perf_short,
    latex_table        = latex_table,
    cumret_plot        = cumret_plot
  ))
}
