#' Portfolio Analytics Visualization Library
#'
#' A collection of professional plots for showcasing portfolio performance
#' to prospective investors. All plots inherit consistent styling.
#'
#' Plots included:
#'   1. plot_cumret()           - Cumulative returns (wealth growth)
#'   2. plot_drawdown()         - Drawdown analysis over time
#'   3. plot_rolling_sr()       - Rolling Sharpe ratio
#'   4. plot_risk_return()      - Risk-return scatter (efficient frontier style)
#'   5. plot_annual_returns()   - Annual returns heatmap/bar chart
#'   6. plot_return_distribution() - Return distribution comparison
#'   7. plot_performance_dashboard() - Multi-panel summary dashboard

library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(patchwork)

## =============================================================================
## SHARED THEME AND STYLING
## =============================================================================

#' Get base theme for all portfolio plots
#' @param base_size Base font size
get_portfolio_theme <- function(base_size = 14) {
  theme_minimal(base_size = base_size) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "gray85", linewidth = 0.3),
      panel.grid.major.x = element_blank(),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.8),
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.title = element_text(face = "bold"),
      legend.title = element_blank(),
      legend.background = element_rect(fill = "white", color = "black", linewidth = 0.3),
      plot.title = element_text(face = "bold", hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5, color = "gray40")
    )
}

#' Default color palette for portfolios
#' @param n Number of colors needed
get_default_colors <- function(n = 6) {
  base_colors <- c(
    "red", "#66C2A5", "black", "#4393C3", "royalblue4", 
    "purple", "#D55E00", "#009E73", "#F0E442", "#CC79A7",
    "darkgreen", "orange", "brown", "pink", "cyan"
  )
  if (n <= length(base_colors)) {
    return(base_colors[1:n])
  } else {
    return(rep_len(base_colors, n))
  }
}

#' Validate and prepare data for plotting
#' @param df_scaled Data frame with date and return columns
#' @param factor_vec Portfolios to include
#' @param color_vec Colors (optional)
#' @param line_types_vec Line types (optional)
prepare_plot_data <- function(df_scaled, factor_vec, color_vec = NULL, line_types_vec = NULL) {
  
  if (!"date" %in% colnames(df_scaled)) {
    stop("df_scaled must contain a 'date' column")
  }
  
  available_cols <- setdiff(colnames(df_scaled), "date")
  missing_factors <- setdiff(factor_vec, available_cols)
  
  if (length(missing_factors) > 0) {
    warning("Factors not found (skipped): ", paste(missing_factors, collapse = ", "))
    factor_vec <- intersect(factor_vec, available_cols)
  }
  
  if (length(factor_vec) == 0) stop("No valid factors to plot")
  
  # Set default colors/linetypes
  if (is.null(color_vec)) {
    color_vec <- get_default_colors(length(factor_vec))
  }
  if (is.null(line_types_vec)) {
    line_types_vec <- rep("solid", length(factor_vec))
  }
  
  # Extend if needed
  color_vec <- rep_len(color_vec, length(factor_vec))
  line_types_vec <- rep_len(line_types_vec, length(factor_vec))
  
  names(color_vec) <- factor_vec
  names(line_types_vec) <- factor_vec
  
  list(
    factor_vec = factor_vec,
    color_vec = color_vec,
    line_types_vec = line_types_vec
  )
}

## =============================================================================
## 1. CUMULATIVE RETURNS PLOT
## =============================================================================

#' Plot Cumulative Returns (Wealth Growth)
#'
#' Shows growth of $1 invested in each portfolio over time.
#'
#' @param df_scaled Data frame with date column and portfolio return columns
#' @param factor_vec Character vector of portfolio names to plot
#' @param color_vec Character vector of colors
#' @param line_types_vec Character vector of line types
#' @param legend_position Legend position (x, y) or keyword
#' @param dollar_step Y-axis break spacing
#' @param show_endpoint_labels Show final dollar values
#' @param output_dir Directory to save figure
#' @param fig_name Filename
#' @param width Figure width
#' @param height Figure height
#' @param save_plot Whether to save
#' @param verbose Print messages
#'
#' @return ggplot object
plot_cumret <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    legend_position    = c(0.02, 0.98),
    dollar_step        = 50,
    show_endpoint_labels = TRUE,
    output_dir         = NULL,
    fig_name           = "oos_cumret.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  # Prepare data
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, line_types_vec)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  line_types_vec <- prep$line_types_vec
  
  if (verbose) cat("Creating cumulative returns plot...\n")
  
  # Compute cumulative returns and order by final value
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    group_by(portfolio) %>%
    arrange(date) %>%
    mutate(dollar = exp(cumsum(ret))) %>%
    ungroup()
  
  # Get ordering by final value
  ordering <- plot_data %>%
    group_by(portfolio) %>%
    slice_tail(n = 1) %>%
    arrange(desc(dollar)) %>%
    pull(portfolio)
  
  plot_data <- plot_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  # Reorder colors/linetypes
  color_vec_ordered <- color_vec[ordering]
  line_types_vec_ordered <- line_types_vec[ordering]
  
  # Last values for labels
  last_dollar <- plot_data %>%
    group_by(portfolio) %>%
    slice_tail(n = 1) %>%
    ungroup() %>%
    mutate(dollar_label = round(dollar, 0))
  
  # Y-axis breaks
  y_max <- max(plot_data$dollar, na.rm = TRUE)
  dollar_breaks <- seq(dollar_step, ceiling(y_max / dollar_step) * dollar_step + dollar_step, by = dollar_step)
  
  # Build plot
  p <- ggplot(plot_data, aes(x = date, y = dollar, color = portfolio, linetype = portfolio)) +
    geom_line(linewidth = 1) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "gray50", linewidth = 0.5) +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_y_log10(breaks = dollar_breaks, labels = dollar_format(accuracy = 1)) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    labs(x = NULL, y = "Portfolio Value ($)", title = "Cumulative Returns") +
    get_portfolio_theme() +
    theme(
      legend.position = legend_position,
      legend.justification = c("left", "top")
    )
  
  if (show_endpoint_labels) {
    p <- p +
      geom_point(data = last_dollar, size = 2.5, show.legend = FALSE) +
      geom_text(
        data = last_dollar,
        aes(label = sprintf("$%d", dollar_label)),
        hjust = -0.1, vjust = 0.5, size = 4, show.legend = FALSE
      ) +
      coord_cartesian(clip = "off", xlim = c(min(plot_data$date), max(plot_data$date) + 180))
  }
  
  # Save
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 2. DRAWDOWN PLOT
## =============================================================================

#' Plot Drawdowns Over Time
#'
#' Shows the percentage decline from peak for each portfolio.
#' Helps investors understand downside risk and recovery patterns.
#'
#' @inheritParams plot_cumret
#' @return ggplot object
plot_drawdown <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    legend_position    = c(0.98, 0.02),
    output_dir         = NULL,
    fig_name           = "oos_drawdown.pdf",
    width              = 12,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, line_types_vec)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  line_types_vec <- prep$line_types_vec
  
  if (verbose) cat("Creating drawdown plot...\n")
  
  # Compute drawdowns
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    group_by(portfolio) %>%
    arrange(date) %>%
    mutate(
      cumret = exp(cumsum(ret)),
      peak = cummax(cumret),
      drawdown = (cumret - peak) / peak * 100  # Percentage
    ) %>%
    ungroup()
  
  # Order by average drawdown (best = least negative)
  ordering <- plot_data %>%
    group_by(portfolio) %>%
    summarise(avg_dd = mean(drawdown), .groups = "drop") %>%
    arrange(desc(avg_dd)) %>%
    pull(portfolio)
  
  plot_data <- plot_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  line_types_vec_ordered <- line_types_vec[ordering]
  
  # Max drawdown annotations
  max_dd <- plot_data %>%
    group_by(portfolio) %>%
    slice_min(drawdown, n = 1) %>%
    slice_head(n = 1) %>%
    ungroup()
  
  p <- ggplot(plot_data, aes(x = date, y = drawdown, color = portfolio, linetype = portfolio)) +
    geom_line(linewidth = 0.8) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_point(data = max_dd, size = 2, show.legend = FALSE) +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    labs(
      x = NULL, 
      y = "Drawdown (%)", 
      title = "Portfolio Drawdowns",
      subtitle = "Percentage decline from peak value"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = legend_position,
      legend.justification = c("right", "bottom")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 3. ROLLING SHARPE RATIO PLOT
## =============================================================================

#' Plot Rolling Sharpe Ratio
#'
#' Shows time-varying risk-adjusted performance using rolling windows.
#'
#' @inheritParams plot_cumret
#' @param window Rolling window in months (default 36 = 3 years)
#' @return ggplot object
plot_rolling_sr <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    window             = 36,
    legend_position    = c(0.02, 0.02),
    output_dir         = NULL,
    fig_name           = "oos_rolling_sr.pdf",
    width              = 12,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, line_types_vec)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  line_types_vec <- prep$line_types_vec
  
  if (verbose) cat("Creating rolling Sharpe ratio plot (", window, "-month window)...\n", sep = "")
  
  # Compute rolling Sharpe ratio
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    group_by(portfolio) %>%
    arrange(date) %>%
    mutate(
      roll_mean = zoo::rollmean(ret, k = window, fill = NA, align = "right"),
      roll_sd = zoo::rollapply(ret, width = window, FUN = sd, fill = NA, align = "right"),
      roll_sr = (roll_mean / roll_sd) * sqrt(12)  # Annualized
    ) %>%
    ungroup() %>%
    filter(!is.na(roll_sr))
  
  # Order by ending Sharpe ratio
  ordering <- plot_data %>%
    group_by(portfolio) %>%
    slice_tail(n = 1) %>%
    arrange(desc(roll_sr)) %>%
    pull(portfolio)
  
  plot_data <- plot_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  line_types_vec_ordered <- line_types_vec[ordering]
  
  p <- ggplot(plot_data, aes(x = date, y = roll_sr, color = portfolio, linetype = portfolio)) +
    geom_line(linewidth = 0.8) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_hline(yintercept = c(0.5, 1.0), color = "gray70", linewidth = 0.3, linetype = "dashed") +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    labs(
      x = NULL, 
      y = "Sharpe Ratio (Annualized)", 
      title = paste0("Rolling ", window, "-Month Sharpe Ratio"),
      subtitle = "Risk-adjusted performance over time"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = legend_position,
      legend.justification = c("left", "bottom")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 4. RISK-RETURN SCATTER PLOT
## =============================================================================

#' Plot Risk-Return Profile
#'
#' Scatter plot showing annualized return vs volatility for each portfolio.
#' Includes iso-Sharpe ratio lines for context.
#'
#' @inheritParams plot_cumret
#' @param show_sr_lines Show iso-Sharpe ratio reference lines
#' @param highlight_portfolios Portfolios to highlight with labels
#' @return ggplot object
plot_risk_return <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    show_sr_lines      = TRUE,
    highlight_portfolios = NULL,
    output_dir         = NULL,
    fig_name           = "oos_risk_return.pdf",
    width              = 10,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating risk-return scatter plot...\n")
  
  # Compute summary statistics
  stats <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    group_by(portfolio) %>%
    summarise(
      mean_ret = mean(ret, na.rm = TRUE) * 12 * 100,  # Annualized %
      vol = sd(ret, na.rm = TRUE) * sqrt(12) * 100,   # Annualized %
      sr = (mean(ret, na.rm = TRUE) / sd(ret, na.rm = TRUE)) * sqrt(12),
      .groups = "drop"
    )
  
  # Highlight labels
  if (is.null(highlight_portfolios)) {
    # Default: highlight top 3 by SR and bottom 1
    highlight_portfolios <- c(
      stats %>% slice_max(sr, n = 3) %>% pull(portfolio),
      stats %>% slice_min(sr, n = 1) %>% pull(portfolio)
    ) %>% unique()
  }
  
  stats <- stats %>%
    mutate(
      show_label = portfolio %in% highlight_portfolios,
      color = color_vec[portfolio]
    )
  
  # Build plot
  p <- ggplot(stats, aes(x = vol, y = mean_ret)) +
    geom_point(aes(color = portfolio), size = 4, show.legend = FALSE)
  
  # Add iso-Sharpe lines
  if (show_sr_lines) {
    max_vol <- max(stats$vol) * 1.1
    sr_lines <- data.frame(
      sr = c(0.25, 0.5, 0.75, 1.0),
      label = c("SR=0.25", "SR=0.5", "SR=0.75", "SR=1.0")
    )
    for (i in 1:nrow(sr_lines)) {
      p <- p + geom_abline(
        slope = sr_lines$sr[i], intercept = 0,
        color = "gray70", linetype = "dashed", linewidth = 0.4
      )
    }
    # Add SR labels at right edge
    p <- p + annotate(
      "text", x = max_vol * 0.95, 
      y = sr_lines$sr * max_vol * 0.95,
      label = sr_lines$label, 
      color = "gray50", size = 3, hjust = 1
    )
  }
  
  # Add labels for highlighted portfolios
  p <- p +
    ggrepel::geom_text_repel(
      data = filter(stats, show_label),
      aes(label = portfolio),
      size = 4, fontface = "bold",
      box.padding = 0.5, point.padding = 0.3,
      max.overlaps = 20
    ) +
    scale_color_manual(values = color_vec) +
    labs(
      x = "Annualized Volatility (%)",
      y = "Annualized Return (%)",
      title = "Risk-Return Profile",
      subtitle = "Higher and to the left is better"
    ) +
    get_portfolio_theme() +
    theme(legend.position = "none")
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 5. ANNUAL RETURNS BAR CHART
## =============================================================================

#' Plot Annual Returns by Year
#'
#' Grouped bar chart showing annual returns for each portfolio by year.
#'
#' @inheritParams plot_cumret
#' @return ggplot object
plot_annual_returns <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_annual_returns.pdf",
    width              = 14,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating annual returns bar chart...\n")
  
  # Compute annual returns
  annual_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    mutate(year = lubridate::year(date)) %>%
    pivot_longer(-c(date, year), names_to = "portfolio", values_to = "ret") %>%
    group_by(year, portfolio) %>%
    summarise(
      annual_ret = (exp(sum(ret)) - 1) * 100,  # Compound annual return %
      .groups = "drop"
    )
  
  # Order portfolios by average annual return
  ordering <- annual_data %>%
    group_by(portfolio) %>%
    summarise(avg = mean(annual_ret), .groups = "drop") %>%
    arrange(desc(avg)) %>%
    pull(portfolio)
  
  annual_data <- annual_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  
  p <- ggplot(annual_data, aes(x = factor(year), y = annual_ret, fill = portfolio)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    scale_fill_manual(values = color_vec_ordered) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      x = "Year",
      y = "Annual Return (%)",
      title = "Annual Returns by Year",
      subtitle = "Compound returns for each calendar year"
    ) +
    get_portfolio_theme() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      legend.position = "bottom",
      legend.justification = "center"
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 5.1 ANNUAL SHARPE RATIO BAR CHART
## =============================================================================

#' Plot Annual Sharpe Ratio by Year
#'
#' Grouped bar chart showing annual Sharpe ratio for each portfolio by year.
#'
#' @inheritParams plot_cumret
#' @return ggplot object
plot_annual_sr <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_annual_sr.pdf",
    width              = 14,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating annual Sharpe ratio bar chart...\n")
  
  # Compute annual Sharpe ratio
  annual_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    mutate(year = lubridate::year(date)) %>%
    pivot_longer(-c(date, year), names_to = "portfolio", values_to = "ret") %>%
    group_by(year, portfolio) %>%
    summarise(
      annual_sr = mean(ret, na.rm = TRUE) / sd(ret, na.rm = TRUE) * sqrt(12),
      .groups = "drop"
    )
  
  # Order portfolios by average annual SR
  ordering <- annual_data %>%
    group_by(portfolio) %>%
    summarise(avg = mean(annual_sr, na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(avg)) %>%
    pull(portfolio)
  
  annual_data <- annual_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  
  p <- ggplot(annual_data, aes(x = factor(year), y = annual_sr, fill = portfolio)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_hline(yintercept = c(0.5, 1.0, 1.5), color = "gray70", linewidth = 0.3, linetype = "dashed") +
    scale_fill_manual(values = color_vec_ordered) +
    labs(
      x = "Year",
      y = "Sharpe Ratio (Annualized)",
      title = "Annual Sharpe Ratio by Year",
      subtitle = "Risk-adjusted returns for each calendar year"
    ) +
    get_portfolio_theme() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      legend.position = "bottom",
      legend.justification = "center"
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 5.2 ANNUAL SORTINO RATIO BAR CHART
## =============================================================================

#' Plot Annual Sortino Ratio by Year
#'
#' Grouped bar chart showing annual Sortino ratio for each portfolio by year.
#' Sortino ratio uses downside deviation (only negative returns) as risk measure.
#'
#' @inheritParams plot_cumret
#' @return ggplot object
plot_annual_sortino <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_annual_sortino.pdf",
    width              = 14,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating annual Sortino ratio bar chart...\n")
  
  # Helper function for downside deviation
  calc_downside_dev <- function(x) {
    neg_returns <- x[x < 0]
    if (length(neg_returns) < 2) return(sd(x, na.rm = TRUE))  # Fallback to regular SD
    sqrt(mean(neg_returns^2))
  }
  
  # Compute annual Sortino ratio
  annual_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    mutate(year = lubridate::year(date)) %>%
    pivot_longer(-c(date, year), names_to = "portfolio", values_to = "ret") %>%
    group_by(year, portfolio) %>%
    summarise(
      mu = mean(ret, na.rm = TRUE),
      downside_dev = calc_downside_dev(ret),
      annual_sortino = mu / downside_dev * sqrt(12),
      .groups = "drop"
    ) %>%
    dplyr::select(year, portfolio, annual_sortino)
  
  # Order portfolios by average annual Sortino
  ordering <- annual_data %>%
    group_by(portfolio) %>%
    summarise(avg = mean(annual_sortino, na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(avg)) %>%
    pull(portfolio)
  
  annual_data <- annual_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  
  p <- ggplot(annual_data, aes(x = factor(year), y = annual_sortino, fill = portfolio)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_hline(yintercept = c(0.5, 1.0, 1.5, 2.0), color = "gray70", linewidth = 0.3, linetype = "dashed") +
    scale_fill_manual(values = color_vec_ordered) +
    labs(
      x = "Year",
      y = "Sortino Ratio (Annualized)",
      title = "Annual Sortino Ratio by Year",
      subtitle = "Return per unit of downside risk for each calendar year"
    ) +
    get_portfolio_theme() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      legend.position = "bottom",
      legend.justification = "center"
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 5.3 ANNUAL INFORMATION RATIO BAR CHART
## =============================================================================

#' Plot Annual Information Ratio by Year
#'
#' Grouped bar chart showing annual Information Ratio for each portfolio by year.
#' IR is computed as regression alpha divided by residual volatility vs EW benchmark.
#'
#' @inheritParams plot_cumret
#' @param benchmark Name of benchmark portfolio for IR calculation (default "EqualWeight")
#' @return ggplot object
plot_annual_ir <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    benchmark          = "EqualWeight",
    output_dir         = NULL,
    fig_name           = "oos_annual_ir.pdf",
    width              = 14,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating annual Information Ratio bar chart (vs ", benchmark, ")...\n", sep = "")
  
  # Check if benchmark exists
  if (!benchmark %in% colnames(df_scaled)) {
    warning("Benchmark '", benchmark, "' not found in data. Trying 'EW' as alternative.")
    if ("EW" %in% colnames(df_scaled)) {
      benchmark <- "EW"
    } else {
      stop("No valid benchmark found for IR calculation.")
    }
  }
  
  # Remove benchmark from factor_vec if present (can't compute IR vs itself)
  factor_vec_no_bench <- setdiff(factor_vec, benchmark)
  
  if (length(factor_vec_no_bench) == 0) {
    warning("No portfolios to compute IR for (only benchmark in factor_vec)")
    return(invisible(NULL))
  }
  
  # Helper function for annual IR calculation (regression-based)
  calc_annual_ir <- function(y, x) {
    if (length(y) < 3 || all(is.na(y)) || all(is.na(x))) return(NA_real_)
    
    valid_idx <- !is.na(y) & !is.na(x)
    if (sum(valid_idx) < 3) return(NA_real_)
    
    y_clean <- y[valid_idx]
    x_clean <- x[valid_idx]
    
    tryCatch({
      fit <- lm(y_clean ~ x_clean)
      alpha_month <- coef(fit)["(Intercept)"]
      resid_vol <- sd(resid(fit))
      if (resid_vol < 1e-10) return(NA_real_)
      ir <- (alpha_month / resid_vol) * sqrt(12)
      return(ir)
    }, error = function(e) NA_real_)
  }
  
  # Get benchmark returns
  bench_returns <- df_scaled[[benchmark]]
  
  # Compute annual IR for each portfolio
  annual_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec_no_bench)) %>%
    mutate(
      year = lubridate::year(date),
      bench = bench_returns
    ) %>%
    pivot_longer(-c(date, year, bench), names_to = "portfolio", values_to = "ret") %>%
    group_by(year, portfolio) %>%
    summarise(
      annual_ir = calc_annual_ir(ret, bench),
      .groups = "drop"
    )
  
  # Order portfolios by average annual IR
  ordering <- annual_data %>%
    group_by(portfolio) %>%
    summarise(avg = mean(annual_ir, na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(avg)) %>%
    pull(portfolio)
  
  annual_data <- annual_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  # Filter color_vec to only include non-benchmark portfolios
  color_vec_filtered <- color_vec[names(color_vec) %in% factor_vec_no_bench]
  color_vec_ordered <- color_vec_filtered[ordering]
  
  p <- ggplot(annual_data, aes(x = factor(year), y = annual_ir, fill = portfolio)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    geom_hline(yintercept = c(-0.5, 0.5, 1.0), color = "gray70", linewidth = 0.3, linetype = "dashed") +
    scale_fill_manual(values = color_vec_ordered) +
    labs(
      x = "Year",
      y = "Information Ratio (Annualized)",
      title = "Annual Information Ratio by Year",
      subtitle = paste0("Alpha / Tracking Error vs ", benchmark, " benchmark")
    ) +
    get_portfolio_theme() +
    theme(
      axis.text.x = element_text(angle = 0, hjust = 0.5),
      legend.position = "bottom",
      legend.justification = "center"
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 6. RETURN DISTRIBUTION PLOT
## =============================================================================

#' Plot Return Distributions
#'
#' Density plots comparing the distribution of monthly returns.
#' Shows fat tails and skewness visually.
#'
#' @inheritParams plot_cumret
#' @param show_stats Show mean and volatility annotations
#' @return ggplot object
plot_return_distribution <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    show_stats         = TRUE,
    output_dir         = NULL,
    fig_name           = "oos_return_dist.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating return distribution plot...\n")
  
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    mutate(ret_pct = ret * 100)  # Convert to percentage
  
  # Order by Sharpe ratio
  ordering <- plot_data %>%
    group_by(portfolio) %>%
    summarise(sr = mean(ret) / sd(ret), .groups = "drop") %>%
    arrange(desc(sr)) %>%
    pull(portfolio)
  
  plot_data <- plot_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  
  # Statistics for annotations
  stats <- plot_data %>%
    group_by(portfolio) %>%
    summarise(
      mean_ret = mean(ret_pct, na.rm = TRUE),
      sd_ret = sd(ret_pct, na.rm = TRUE),
      skew = moments::skewness(ret_pct, na.rm = TRUE),
      .groups = "drop"
    )
  
  p <- ggplot(plot_data, aes(x = ret_pct, fill = portfolio, color = portfolio)) +
    geom_density(alpha = 0.3, linewidth = 0.8) +
    geom_vline(xintercept = 0, color = "black", linewidth = 0.5, linetype = "dashed") +
    scale_fill_manual(values = color_vec_ordered) +
    scale_color_manual(values = color_vec_ordered) +
    labs(
      x = "Monthly Return (%)",
      y = "Density",
      title = "Return Distribution Comparison",
      subtitle = "Monthly return densities (volatility-scaled)"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = c(0.98, 0.98),
      legend.justification = c("right", "top")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 7. PERFORMANCE SUMMARY BAR CHART
## =============================================================================

#' Plot Performance Metrics Comparison
#'
#' Horizontal bar chart comparing key performance metrics across portfolios.
#'
#' @inheritParams plot_cumret
#' @param metrics Vector of metrics to display
#' @return ggplot object
plot_performance_bars <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    metrics            = c("SR", "Sortino", "MaxDD"),
    output_dir         = NULL,
    fig_name           = "oos_performance_bars.pdf",
    width              = 10,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating performance metrics bar chart...\n")
  
  # Compute all metrics
  stats <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    group_by(portfolio) %>%
    summarise(
      SR = (mean(ret, na.rm = TRUE) / sd(ret, na.rm = TRUE)) * sqrt(12),
      Sortino = {
        mu <- mean(ret, na.rm = TRUE)
        downside <- ret[ret < 0]
        downside_vol <- if (length(downside) > 1) sd(downside) else sd(ret, na.rm = TRUE)
        (mu / downside_vol) * sqrt(12)
      },
      MaxDD = {
        cumret <- exp(cumsum(ret))
        peak <- cummax(cumret)
        dd <- (cumret - peak) / peak
        min(dd) * 100
      },
      .groups = "drop"
    ) %>%
    pivot_longer(-portfolio, names_to = "metric", values_to = "value")
  
  # Filter to requested metrics
  stats <- stats %>% filter(metric %in% metrics)
  
  # Order portfolios by Sharpe ratio
  ordering <- stats %>%
    filter(metric == "SR") %>%
    arrange(desc(value)) %>%
    pull(portfolio)
  
  stats <- stats %>%
    mutate(
      portfolio = factor(portfolio, levels = rev(ordering)),  # Rev for horizontal
      metric = factor(metric, levels = metrics)
    )
  
  p <- ggplot(stats, aes(x = portfolio, y = value, fill = portfolio)) +
    geom_bar(stat = "identity", width = 0.7, show.legend = FALSE) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    facet_wrap(~metric, scales = "free_x", nrow = 1) +
    scale_fill_manual(values = color_vec[ordering]) +
    coord_flip() +
    labs(
      x = NULL,
      y = NULL,
      title = "Performance Metrics Comparison"
    ) +
    get_portfolio_theme() +
    theme(
      strip.text = element_text(face = "bold", size = 12),
      panel.spacing = unit(1.5, "lines")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 8. UNDERWATER (DRAWDOWN DURATION) PLOT
## =============================================================================

#' Plot Underwater Chart
#'
#' Shows drawdown periods as filled areas, emphasizing recovery time.
#'
#' @inheritParams plot_cumret
#' @return ggplot object
plot_underwater <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_underwater.pdf",
    width              = 12,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, NULL)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  
  if (verbose) cat("Creating underwater plot...\n")
  
  # Compute drawdowns
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    group_by(portfolio) %>%
    arrange(date) %>%
    mutate(
      cumret = exp(cumsum(ret)),
      peak = cummax(cumret),
      drawdown = (cumret - peak) / peak * 100
    ) %>%
    ungroup()
  
  # Order by average drawdown
  ordering <- plot_data %>%
    group_by(portfolio) %>%
    summarise(avg_dd = mean(drawdown), .groups = "drop") %>%
    arrange(desc(avg_dd)) %>%
    pull(portfolio)
  
  plot_data <- plot_data %>%
    mutate(portfolio = factor(portfolio, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  
  p <- ggplot(plot_data, aes(x = date, y = drawdown, fill = portfolio)) +
    geom_area(alpha = 0.6, position = "identity") +
    geom_line(aes(color = portfolio), linewidth = 0.3, show.legend = FALSE) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    facet_wrap(~portfolio, ncol = 2, scales = "fixed") +
    scale_fill_manual(values = color_vec_ordered) +
    scale_color_manual(values = color_vec_ordered) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    scale_x_date(date_labels = "%Y", date_breaks = "3 years") +
    labs(
      x = NULL,
      y = "Drawdown (%)",
      title = "Underwater Chart by Portfolio",
      subtitle = "Time spent below peak value"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "none",
      strip.text = element_text(face = "bold")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## 9. PERFORMANCE DASHBOARD (MULTI-PANEL)
## =============================================================================

#' Create Performance Dashboard
#'
#' Multi-panel figure combining cumulative returns, drawdowns, and metrics.
#' Perfect for investor presentations.
#'
#' @inheritParams plot_cumret
#' @return patchwork object
plot_dashboard <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    output_dir         = NULL,
    fig_name           = "oos_dashboard.pdf",
    width              = 16,
    height             = 12,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  prep <- prepare_plot_data(df_scaled, factor_vec, color_vec, line_types_vec)
  factor_vec <- prep$factor_vec
  color_vec <- prep$color_vec
  line_types_vec <- prep$line_types_vec
  
  if (verbose) cat("Creating performance dashboard...\n")
  
  # Create individual plots (without saving)
  p1 <- plot_cumret(df_scaled, factor_vec, color_vec, line_types_vec, 
                    save_plot = FALSE, verbose = FALSE) +
    labs(title = "A. Cumulative Returns") +
    theme(legend.position = c(0.02, 0.98), legend.justification = c("left", "top"))
  
  p2 <- plot_drawdown(df_scaled, factor_vec, color_vec, line_types_vec,
                      save_plot = FALSE, verbose = FALSE) +
    labs(title = "B. Drawdowns") +
    theme(legend.position = "none")
  
  p3 <- plot_rolling_sr(df_scaled, factor_vec, color_vec, line_types_vec,
                        save_plot = FALSE, verbose = FALSE) +
    labs(title = "C. Rolling 36-Month Sharpe Ratio") +
    theme(legend.position = "none")
  
  p4 <- plot_risk_return(df_scaled, factor_vec, color_vec,
                         save_plot = FALSE, verbose = FALSE) +
    labs(title = "D. Risk-Return Profile")
  
  # Combine using patchwork
  dashboard <- (p1 | p2) / (p3 | p4) +
    plot_annotation(
      title = "Portfolio Performance Dashboard",
      subtitle = paste("Out-of-Sample Period:", 
                       format(min(df_scaled$date), "%Y-%m"), "to",
                       format(max(df_scaled$date), "%Y-%m")),
      theme = theme(
        plot.title = element_text(size = 18, face = "bold", hjust = 0.5),
        plot.subtitle = element_text(size = 12, hjust = 0.5, color = "gray40")
      )
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), dashboard, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(dashboard)
}

## =============================================================================
## 10. GENERATE ALL PLOTS
## =============================================================================

#' Generate All Portfolio Analytics Plots
#'
#' Convenience function to generate all available plots at once.
#'
#' @inheritParams plot_cumret
#' @return List of all plot objects
generate_all_plots <- function(
    df_scaled,
    factor_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    output_dir         = NULL,
    benchmark          = "EqualWeight",
    verbose            = TRUE
) {
  
  if (verbose) cat("\n========================================\n")
  if (verbose) cat("Generating All Portfolio Analytics Plots\n")
  if (verbose) cat("========================================\n\n")
  
  plots <- list()
  
  plots$cumret <- plot_cumret(df_scaled, factor_vec, color_vec, line_types_vec,
                              output_dir = output_dir, verbose = verbose)
  
  plots$drawdown <- plot_drawdown(df_scaled, factor_vec, color_vec, line_types_vec,
                                  output_dir = output_dir, verbose = verbose)
  
  plots$rolling_sr <- plot_rolling_sr(df_scaled, factor_vec, color_vec, line_types_vec,
                                      output_dir = output_dir, verbose = verbose)
  
  plots$risk_return <- plot_risk_return(df_scaled, factor_vec, color_vec,
                                        output_dir = output_dir, verbose = verbose)
  
  plots$annual_returns <- plot_annual_returns(df_scaled, factor_vec, color_vec,
                                              output_dir = output_dir, verbose = verbose)
  
  plots$annual_sr <- plot_annual_sr(df_scaled, factor_vec, color_vec,
                                    output_dir = output_dir, verbose = verbose)
  
  plots$annual_sortino <- plot_annual_sortino(df_scaled, factor_vec, color_vec,
                                              output_dir = output_dir, verbose = verbose)
  
  plots$annual_ir <- plot_annual_ir(df_scaled, factor_vec, color_vec,
                                    benchmark = benchmark,
                                    output_dir = output_dir, verbose = verbose)
  
  plots$return_dist <- plot_return_distribution(df_scaled, factor_vec, color_vec,
                                                output_dir = output_dir, verbose = verbose)
  
  plots$performance_bars <- plot_performance_bars(df_scaled, factor_vec, color_vec,
                                                  output_dir = output_dir, verbose = verbose)
  
  plots$underwater <- plot_underwater(df_scaled, factor_vec, color_vec,
                                      output_dir = output_dir, verbose = verbose)
  
  plots$dashboard <- plot_dashboard(df_scaled, factor_vec, color_vec, line_types_vec,
                                    output_dir = output_dir, verbose = verbose)
  
  if (verbose) cat("\n========================================\n")
  if (verbose) cat("All plots generated successfully!\n")
  if (verbose) cat("========================================\n")
  
  invisible(plots)
}

## =============================================================================
## =============================================================================
##
##                    WEIGHT ANALYSIS PLOTS
##
## =============================================================================
## =============================================================================

## =============================================================================
## W1. WEIGHT TIME SERIES - TOP N FACTORS (FACETED BY MODEL)
## =============================================================================

#' Plot Weight Time Series for Top N Factors
#'
#' For each model in model_vec, plots the time-series evolution of the top N 
#' factors (by unconditional average weight). Creates faceted subplots.
#'
#' @param weights_panel Data frame with columns: date, model, factor, weight
#' @param model_vec Character vector of models to plot
#' @param n_top Number of top factors to show per model (default 5)
#' @param color_palette Color palette for factors (NULL for default)
#' @param output_dir Directory to save figures
#' @param fig_prefix Filename prefix
#' @param width Figure width
#' @param height Figure height
#' @param save_plot Whether to save
#' @param verbose Print messages
#'
#' @return List of ggplot objects (one per page if > 8 models)
plot_weight_timeseries <- function(
    weights_panel,
    model_vec,
    n_top              = 5,
    color_palette      = NULL,
    output_dir         = NULL,
    fig_prefix         = "oos_weight_ts",
    width              = 14,
    height             = 10,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating weight time-series plots...\n")
  
  # Validate inputs
  required_cols <- c("date", "model", "factor", "weight")
  if (!all(required_cols %in% colnames(weights_panel))) {
    stop("weights_panel must contain columns: ", paste(required_cols, collapse = ", "))
  }
  
  # Filter to requested models
  available_models <- unique(weights_panel$model)
  missing_models <- setdiff(model_vec, available_models)
  if (length(missing_models) > 0) {
    warning("Models not found (skipped): ", paste(missing_models, collapse = ", "))
    model_vec <- intersect(model_vec, available_models)
  }
  
  if (length(model_vec) == 0) {
    stop("No valid models to plot")
  }
  
  # Default color palette for factors (expanded for many unique factors)
  if (is.null(color_palette)) {
    color_palette <- c(
      "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00",
      "#FFFF33", "#A65628", "#F781BF", "#999999", "#66C2A5",
      "#1B9E77", "#D95F02", "#7570B3", "#E7298A", "#66A61E",
      "#E6AB02", "#A6761D", "#666666", "#8DD3C7", "#FFFFB3",
      "#BEBADA", "#FB8072", "#80B1D3", "#FDB462", "#B3DE69"
    )
  }
  
  # For each model, identify top N factors by average absolute weight
  get_top_factors <- function(df, model_name, n) {
    df %>%
      filter(model == model_name) %>%
      group_by(factor) %>%
      summarise(avg_weight = mean(abs(weight), na.rm = TRUE), .groups = "drop") %>%
      arrange(desc(avg_weight)) %>%
      slice_head(n = n) %>%
      pull(factor)
  }
  
  # Prepare data for each model
  plot_data_list <- lapply(model_vec, function(m) {
    top_factors <- get_top_factors(weights_panel, m, n_top)
    
    weights_panel %>%
      filter(model == m, factor %in% top_factors) %>%
      mutate(
        factor = factor(factor, levels = top_factors),
        model = m
      ) %>%
      dplyr::select(date, model, factor, weight)
  })
  
  plot_data <- do.call(rbind, plot_data_list)
  plot_data$model <- factor(plot_data$model, levels = model_vec)
  
  # Split into pages of max 8 models
  n_models <- length(model_vec)
  models_per_page <- 8
  n_pages <- ceiling(n_models / models_per_page)
  
  plots <- list()
  
  for (page in 1:n_pages) {
    start_idx <- (page - 1) * models_per_page + 1
    end_idx <- min(page * models_per_page, n_models)
    page_models <- model_vec[start_idx:end_idx]
    
    page_data <- plot_data %>% filter(model %in% page_models)
    
    # Determine grid layout
    n_page_models <- length(page_models)
    if (n_page_models <= 2) {
      ncol <- n_page_models
      nrow <- 1
    } else if (n_page_models <= 4) {
      ncol <- 2
      nrow <- 2
    } else {
      ncol <- 2
      nrow <- 4
    }
    
    p <- ggplot(page_data, aes(x = date, y = weight, color = factor)) +
      geom_line(linewidth = 0.8) +
      geom_hline(yintercept = 0, color = "gray50", linewidth = 0.3, linetype = "dashed") +
      facet_wrap(~model, ncol = ncol, scales = "free_y") +
      scale_color_manual(values = rep_len(color_palette, length(unique(page_data$factor)))) +
      scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
      scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
      labs(
        x = NULL,
        y = "Portfolio Weight",
        title = paste0("Factor Weight Evolution Over Time (Top ", n_top, " Factors per Model)"),
        subtitle = if (n_pages > 1) paste0("Page ", page, " of ", n_pages) else NULL
      ) +
      get_portfolio_theme() +
      theme(
        legend.position = "bottom",
        legend.title = element_blank(),
        strip.text = element_text(face = "bold", size = 11),
        panel.spacing = unit(1, "lines")
      ) +
      guides(color = guide_legend(nrow = 2))
    
    plots[[page]] <- p
    
    if (save_plot && !is.null(output_dir)) {
      figures_dir <- file.path(output_dir, "figures")
      if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
      
      fig_name <- if (n_pages > 1) {
        paste0(fig_prefix, "_page", page, ".pdf")
      } else {
        paste0(fig_prefix, ".pdf")
      }
      
      ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
      if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
    }
  }
  
  invisible(plots)
}

## =============================================================================
## W2. WEIGHT CONCENTRATION (HERFINDAHL INDEX) OVER TIME
## =============================================================================

#' Plot Weight Concentration Over Time
#'
#' Shows the Herfindahl-Hirschman Index (HHI) of portfolio weights over time.
#' HHI = sum(w_i^2). Higher values = more concentrated portfolio.
#' Also shows effective number of factors = 1/HHI.
#'
#' @inheritParams plot_weight_timeseries
#' @return ggplot object
plot_weight_concentration <- function(
    weights_panel,
    model_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    legend_position    = c(0.98, 0.98),
    output_dir         = NULL,
    fig_name           = "oos_weight_concentration.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating weight concentration plot...\n")
  
  # Filter to requested models
  available_models <- unique(weights_panel$model)
  model_vec <- intersect(model_vec, available_models)
  
  if (length(model_vec) == 0) stop("No valid models to plot")
  
  # Default colors/linetypes
  if (is.null(color_vec)) color_vec <- get_default_colors(length(model_vec))
  if (is.null(line_types_vec)) line_types_vec <- rep("solid", length(model_vec))
  color_vec <- rep_len(color_vec, length(model_vec))
  line_types_vec <- rep_len(line_types_vec, length(model_vec))
  names(color_vec) <- model_vec
  names(line_types_vec) <- model_vec
  
  # Compute HHI for each model-date
  hhi_data <- weights_panel %>%
    filter(model %in% model_vec) %>%
    group_by(date, model) %>%
    summarise(
      hhi = sum(weight^2, na.rm = TRUE),
      eff_n = 1 / sum(weight^2, na.rm = TRUE),
      .groups = "drop"
    )
  
  # Order by average HHI (least concentrated first)
  ordering <- hhi_data %>%
    group_by(model) %>%
    summarise(avg_hhi = mean(hhi, na.rm = TRUE), .groups = "drop") %>%
    arrange(avg_hhi) %>%
    pull(model)
  
  hhi_data <- hhi_data %>%
    mutate(model = factor(model, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  line_types_vec_ordered <- line_types_vec[ordering]
  
  # Create two-panel plot: HHI and Effective N
  p1 <- ggplot(hhi_data, aes(x = date, y = hhi, color = model, linetype = model)) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    labs(
      x = NULL,
      y = "Herfindahl Index (HHI)",
      title = "A. Weight Concentration (HHI)",
      subtitle = "Higher = more concentrated"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = legend_position,
      legend.justification = c("right", "top")
    )
  
  p2 <- ggplot(hhi_data, aes(x = date, y = eff_n, color = model, linetype = model)) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    labs(
      x = NULL,
      y = "Effective Number of Factors",
      title = "B. Portfolio Diversification (1/HHI)",
      subtitle = "Higher = more diversified"
    ) +
    get_portfolio_theme() +
    theme(legend.position = "none")
  
  p <- p1 / p2 +
    plot_annotation(
      title = "Portfolio Weight Concentration Analysis",
      theme = theme(
        plot.title = element_text(size = 16, face = "bold", hjust = 0.5)
      )
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## W3. AVERAGE WEIGHT DISTRIBUTION (BAR CHART)
## =============================================================================

#' Plot Average Weight Distribution by Model
#'
#' Shows the time-series average weights for each factor, grouped by model.
#' Useful for comparing which factors dominate each model.
#'
#' @inheritParams plot_weight_timeseries
#' @param n_top Number of top factors to show (default 10)
#' @return ggplot object
plot_weight_distribution <- function(
    weights_panel,
    model_vec,
    n_top              = 10,
    output_dir         = NULL,
    fig_name           = "oos_weight_distribution.pdf",
    width              = 14,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating weight distribution plot...\n")
  
  # Filter to requested models
  available_models <- unique(weights_panel$model)
  model_vec <- intersect(model_vec, available_models)
  
  if (length(model_vec) == 0) stop("No valid models to plot")
  
  # Compute average weights per model-factor
  avg_weights <- weights_panel %>%
    filter(model %in% model_vec) %>%
    group_by(model, factor) %>%
    summarise(avg_weight = mean(weight, na.rm = TRUE), .groups = "drop")
  
  # Get top N factors across all models (by max absolute weight)
  top_factors <- avg_weights %>%
    group_by(factor) %>%
    summarise(max_abs_weight = max(abs(avg_weight), na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(max_abs_weight)) %>%
    slice_head(n = n_top) %>%
    pull(factor)
  
  # Filter and order
  plot_data <- avg_weights %>%
    filter(factor %in% top_factors) %>%
    mutate(
      factor = factor(factor, levels = rev(top_factors)),  # Reverse for coord_flip
      model = factor(model, levels = model_vec)
    )
  
  # Color palette for models
  model_colors <- get_default_colors(length(model_vec))
  names(model_colors) <- model_vec
  
  p <- ggplot(plot_data, aes(x = factor, y = avg_weight, fill = model)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    coord_flip() +
    scale_fill_manual(values = model_colors) +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    labs(
      x = NULL,
      y = "Average Weight",
      title = paste0("Average Factor Weights by Model (Top ", n_top, " Factors)"),
      subtitle = "Time-series average of portfolio weights"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "bottom",
      legend.title = element_blank(),
      axis.text.y = element_text(size = 11)
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## W4. WEIGHT HEATMAP (FACTOR x TIME)
## =============================================================================

#' Plot Weight Heatmap
#'
#' Creates a heatmap showing factor weights over time for a single model.
#' Time on x-axis, factors on y-axis, color = weight.
#'
#' @inheritParams plot_weight_timeseries
#' @param model_name Single model to plot
#' @param n_top Number of top factors to show
#' @return ggplot object
plot_weight_heatmap <- function(
    weights_panel,
    model_name,
    n_top              = 15,
    output_dir         = NULL,
    fig_name           = NULL,
    width              = 14,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating weight heatmap for ", model_name, "...\n", sep = "")
  
  # Filter to model
  model_data <- weights_panel %>%
    filter(model == model_name)
  
  if (nrow(model_data) == 0) {
    warning("Model '", model_name, "' not found in weights_panel")
    return(invisible(NULL))
  }
  
  # Get top N factors by average absolute weight
  top_factors <- model_data %>%
    group_by(factor) %>%
    summarise(avg_abs = mean(abs(weight), na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(avg_abs)) %>%
    slice_head(n = n_top) %>%
    pull(factor)
  
  # Prepare data
  plot_data <- model_data %>%
    filter(factor %in% top_factors) %>%
    mutate(factor = factor(factor, levels = rev(top_factors)))
  
  # Diverging color scale centered at 0
  max_abs <- max(abs(plot_data$weight), na.rm = TRUE)
  
  p <- ggplot(plot_data, aes(x = date, y = factor, fill = weight)) +
    geom_tile() +
    scale_fill_gradient2(
      low = "#2166AC", mid = "white", high = "#B2182B",
      midpoint = 0,
      limits = c(-max_abs, max_abs),
      labels = scales::percent_format(accuracy = 1),
      name = "Weight"
    ) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years", expand = c(0, 0)) +
    labs(
      x = NULL,
      y = NULL,
      title = paste0("Factor Weight Heatmap: ", model_name),
      subtitle = paste0("Top ", n_top, " factors by average absolute weight")
    ) +
    get_portfolio_theme() +
    theme(
      axis.text.y = element_text(size = 10),
      panel.grid = element_blank(),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 0.8)
    )
  
  if (is.null(fig_name)) {
    fig_name <- paste0("oos_weight_heatmap_", gsub("[^a-zA-Z0-9]", "_", model_name), ".pdf")
  }
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## W5. WEIGHT STABILITY (TURNOVER) OVER TIME
## =============================================================================

#' Plot Weight Turnover Over Time
#'
#' Shows portfolio turnover (sum of absolute weight changes) over time.
#' Lower turnover = more stable portfolio = lower transaction costs.
#'
#' @inheritParams plot_weight_timeseries
#' @return ggplot object
plot_weight_turnover <- function(
    weights_panel,
    model_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    legend_position    = c(0.02, 0.98),
    output_dir         = NULL,
    fig_name           = "oos_weight_turnover.pdf",
    width              = 12,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating weight turnover plot...\n")
  
  # Filter to requested models
  available_models <- unique(weights_panel$model)
  model_vec <- intersect(model_vec, available_models)
  
  if (length(model_vec) == 0) stop("No valid models to plot")
  
  # Default colors/linetypes
  if (is.null(color_vec)) color_vec <- get_default_colors(length(model_vec))
  if (is.null(line_types_vec)) line_types_vec <- rep("solid", length(model_vec))
  color_vec <- rep_len(color_vec, length(model_vec))
  line_types_vec <- rep_len(line_types_vec, length(model_vec))
  names(color_vec) <- model_vec
  names(line_types_vec) <- model_vec
  
  # Compute turnover for each model-date
  turnover_data <- weights_panel %>%
    filter(model %in% model_vec) %>%
    arrange(model, factor, date) %>%
    group_by(model, factor) %>%
    mutate(weight_change = abs(weight - lag(weight))) %>%
    ungroup() %>%
    group_by(date, model) %>%
    summarise(
      turnover = sum(weight_change, na.rm = TRUE) / 2,  # Divide by 2 to avoid double-counting
      .groups = "drop"
    ) %>%
    filter(!is.na(turnover))
  
  # Order by average turnover (lowest first = most stable)
  ordering <- turnover_data %>%
    group_by(model) %>%
    summarise(avg_turnover = mean(turnover, na.rm = TRUE), .groups = "drop") %>%
    arrange(avg_turnover) %>%
    pull(model)
  
  turnover_data <- turnover_data %>%
    mutate(model = factor(model, levels = ordering))
  
  color_vec_ordered <- color_vec[ordering]
  line_types_vec_ordered <- line_types_vec[ordering]
  
  p <- ggplot(turnover_data, aes(x = date, y = turnover, color = model, linetype = model)) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
    labs(
      x = NULL,
      y = "Turnover (one-way)",
      title = "Portfolio Turnover Over Time",
      subtitle = "Sum of absolute weight changes (lower = more stable)"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = legend_position,
      legend.justification = c("left", "top")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## W6. WEIGHT SUMMARY STATISTICS TABLE (AS PLOT)
## =============================================================================

#' Plot Weight Summary Statistics
#'
#' Creates a summary table-as-plot showing key weight statistics:
#' - Average number of non-zero factors
#' - Average HHI (concentration)
#' - Average turnover
#' - Max weight
#'
#' @inheritParams plot_weight_timeseries
#' @return ggplot object (table)
plot_weight_summary <- function(
    weights_panel,
    model_vec,
    output_dir         = NULL,
    fig_name           = "oos_weight_summary.pdf",
    width              = 10,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating weight summary table...\n")
  
  # Filter to requested models
  available_models <- unique(weights_panel$model)
  model_vec <- intersect(model_vec, available_models)
  
  if (length(model_vec) == 0) stop("No valid models to plot")
  
  # Compute summary statistics
  summary_stats <- weights_panel %>%
    filter(model %in% model_vec) %>%
    group_by(model, date) %>%
    summarise(
      n_nonzero = sum(abs(weight) > 0.001, na.rm = TRUE),
      hhi = sum(weight^2, na.rm = TRUE),
      max_weight = max(abs(weight), na.rm = TRUE),
      .groups = "drop"
    ) %>%
    group_by(model) %>%
    summarise(
      `Avg # Factors` = as.character(round(mean(n_nonzero, na.rm = TRUE), 1)),
      `Avg HHI` = as.character(round(mean(hhi, na.rm = TRUE), 3)),
      `Effective N` = as.character(round(1 / mean(hhi, na.rm = TRUE), 1)),
      `Avg Max Wt` = scales::percent(mean(max_weight, na.rm = TRUE), accuracy = 0.1),
      .groups = "drop"
    )
  
  # Add turnover
  turnover_stats <- weights_panel %>%
    filter(model %in% model_vec) %>%
    arrange(model, factor, date) %>%
    group_by(model, factor) %>%
    mutate(weight_change = abs(weight - lag(weight))) %>%
    ungroup() %>%
    group_by(date, model) %>%
    summarise(turnover = sum(weight_change, na.rm = TRUE) / 2, .groups = "drop") %>%
    group_by(model) %>%
    summarise(`Avg Turnover` = scales::percent(mean(turnover, na.rm = TRUE), accuracy = 0.1), .groups = "drop")
  
  summary_stats <- summary_stats %>%
    left_join(turnover_stats, by = "model") %>%
    rename(Model = model)
  
  # Order by HHI (need to convert back to numeric for sorting)
  summary_stats <- summary_stats %>%
    arrange(as.numeric(`Avg HHI`))
  
  # Create table plot using ggplot
  # Convert to long format for plotting (all values are now character)
  summary_long <- summary_stats %>%
    pivot_longer(-Model, names_to = "Metric", values_to = "Value") %>%
    mutate(
      Metric = factor(Metric, levels = c("Avg # Factors", "Effective N", "Avg HHI", 
                                         "Avg Max Wt", "Avg Turnover")),
      Model = factor(Model, levels = rev(summary_stats$Model))
    )
  
  p <- ggplot(summary_long, aes(x = Metric, y = Model, label = Value)) +
    geom_tile(fill = "white", color = "gray80") +
    geom_text(size = 4) +
    scale_x_discrete(position = "top") +
    labs(
      title = "Portfolio Weight Summary Statistics",
      subtitle = "Diversification and stability metrics by model",
      x = NULL, y = NULL
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
      plot.subtitle = element_text(hjust = 0.5, color = "gray40"),
      axis.text.x = element_text(face = "bold", size = 11),
      axis.text.y = element_text(size = 11),
      panel.grid = element_blank(),
      axis.ticks = element_blank()
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## W7. STACKED AREA CHART OF WEIGHTS
## =============================================================================

#' Plot Stacked Area Chart of Weights
#'
#' Shows how total portfolio allocation is distributed across factors over time.
#' Uses absolute weights (normalized to 100%).
#'
#' @inheritParams plot_weight_timeseries
#' @param model_name Single model to plot
#' @param n_top Number of top factors (remainder grouped as "Other")
#' @return ggplot object
plot_weight_stacked <- function(
    weights_panel,
    model_name,
    n_top              = 8,
    color_palette      = NULL,
    output_dir         = NULL,
    fig_name           = NULL,
    width              = 12,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating stacked weight chart for ", model_name, "...\n", sep = "")
  
  # Filter to model
  model_data <- weights_panel %>%
    filter(model == model_name)
  
  if (nrow(model_data) == 0) {
    warning("Model '", model_name, "' not found")
    return(invisible(NULL))
  }
  
  # Get top N factors
  top_factors <- model_data %>%
    group_by(factor) %>%
    summarise(avg_abs = mean(abs(weight), na.rm = TRUE), .groups = "drop") %>%
    arrange(desc(avg_abs)) %>%
    slice_head(n = n_top) %>%
    pull(factor)
  
  # Group others
  plot_data <- model_data %>%
    mutate(
      factor_group = if_else(factor %in% top_factors, factor, "Other"),
      abs_weight = abs(weight)
    ) %>%
    group_by(date, factor_group) %>%
    summarise(abs_weight = sum(abs_weight, na.rm = TRUE), .groups = "drop") %>%
    # Normalize to 100%
    group_by(date) %>%
    mutate(pct_weight = abs_weight / sum(abs_weight) * 100) %>%
    ungroup()
  
  # Order factors
  factor_order <- c(top_factors, "Other")
  plot_data <- plot_data %>%
    mutate(factor_group = factor(factor_group, levels = factor_order))
  
  # Colors (expanded palette for many factors)
  if (is.null(color_palette)) {
    color_palette <- c(
      "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00",
      "#FFFF33", "#A65628", "#F781BF", "#999999", "#66C2A5",
      "#1B9E77", "#D95F02", "#7570B3", "#E7298A", "#66A61E"
    )
  }
  colors <- c(rep_len(color_palette, n_top), "gray70")
  names(colors) <- factor_order
  
  p <- ggplot(plot_data, aes(x = date, y = pct_weight, fill = factor_group)) +
    geom_area(alpha = 0.8) +
    scale_fill_manual(values = colors) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years", expand = c(0, 0)) +
    scale_y_continuous(labels = function(x) paste0(x, "%"), expand = c(0, 0)) +
    labs(
      x = NULL,
      y = "Portfolio Allocation (%)",
      title = paste0("Portfolio Composition Over Time: ", model_name),
      subtitle = paste0("Top ", n_top, " factors + Other (by absolute weight)")
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "bottom",
      legend.title = element_blank()
    ) +
    guides(fill = guide_legend(nrow = 2))
  
  if (is.null(fig_name)) {
    fig_name <- paste0("oos_weight_stacked_", gsub("[^a-zA-Z0-9]", "_", model_name), ".pdf")
  }
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## W8. GENERATE ALL WEIGHT PLOTS
## =============================================================================

#' Generate All Weight Analysis Plots
#'
#' Convenience function to generate all weight-related plots.
#'
#' @inheritParams plot_weight_timeseries
#' @param df_scaled Returns data (for colors consistency)
#' @return List of all plot objects
generate_weight_plots <- function(
    weights_panel,
    model_vec,
    color_vec          = NULL,
    line_types_vec     = NULL,
    n_top              = 5,
    output_dir         = NULL,
    verbose            = TRUE
) {
  
  if (verbose) cat("\n========================================\n")
  if (verbose) cat("Generating Weight Analysis Plots\n")
  if (verbose) cat("========================================\n\n")
  
  # Set defaults
  if (is.null(color_vec)) color_vec <- get_default_colors(length(model_vec))
  if (is.null(line_types_vec)) line_types_vec <- rep("solid", length(model_vec))
  names(color_vec) <- model_vec
  names(line_types_vec) <- model_vec
  
  plots <- list()
  
  # 1. Weight time series (faceted)
  plots$weight_ts <- plot_weight_timeseries(
    weights_panel, model_vec, n_top = n_top,
    output_dir = output_dir, verbose = verbose
  )
  
  # 2. Concentration over time
  plots$concentration <- plot_weight_concentration(
    weights_panel, model_vec, color_vec, line_types_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 3. Weight distribution (bar chart)
  plots$distribution <- plot_weight_distribution(
    weights_panel, model_vec, n_top = 10,
    output_dir = output_dir, verbose = verbose
  )
  
  # 4. Heatmaps for each model
  plots$heatmaps <- lapply(model_vec, function(m) {
    plot_weight_heatmap(weights_panel, m, n_top = 15,
                        output_dir = output_dir, verbose = verbose)
  })
  names(plots$heatmaps) <- model_vec
  
  # 5. Turnover
  plots$turnover <- plot_weight_turnover(
    weights_panel, model_vec, color_vec, line_types_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 6. Summary table
  plots$summary <- plot_weight_summary(
    weights_panel, model_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 7. Stacked charts for each model
  plots$stacked <- lapply(model_vec, function(m) {
    plot_weight_stacked(weights_panel, m, n_top = 8,
                        output_dir = output_dir, verbose = verbose)
  })
  names(plots$stacked) <- model_vec
  
  if (verbose) cat("\n========================================\n")
  if (verbose) cat("Weight analysis plots generated!\n")
  if (verbose) cat("========================================\n")
  
  invisible(plots)
}

## =============================================================================
## =============================================================================
##
##                    TAIL RISK & DOWNSIDE PROTECTION PLOTS
##
## =============================================================================
## =============================================================================

## =============================================================================
## T1. VALUE-AT-RISK (VaR) COMPARISON
## =============================================================================

#' Plot Value-at-Risk Comparison
#'
#' Shows historical VaR at specified confidence levels across portfolios.
#' VaR represents the maximum expected loss at a given confidence level.
#'
#' @param df_scaled Data frame with date column and portfolio return columns
#' @param factor_vec Character vector of portfolio names to include
#' @param confidence_levels Vector of confidence levels (default c(0.95, 0.99))
#' @param color_vec Colors for portfolios
#' @param output_dir Directory to save figures
#' @param fig_name Output filename
#' @param width Figure width
#' @param height Figure height
#' @param save_plot Whether to save
#' @param verbose Print messages
#'
#' @return ggplot object
plot_var_comparison <- function(
    df_scaled,
    factor_vec,
    confidence_levels  = c(0.95, 0.99),
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_var_comparison.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating VaR comparison plot...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  factor_vec <- intersect(factor_vec, available_cols)
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Default colors
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  color_vec <- rep_len(color_vec, length(factor_vec))
  names(color_vec) <- factor_vec
  
  # Compute VaR for each portfolio at each confidence level
  var_data <- expand.grid(
    portfolio = factor_vec,
    confidence = confidence_levels,
    stringsAsFactors = FALSE
  )
  
  var_data$VaR <- sapply(1:nrow(var_data), function(i) {
    returns <- df_scaled[[var_data$portfolio[i]]]
    # VaR is the negative of the quantile (loss is positive)
    -quantile(returns, probs = 1 - var_data$confidence[i], na.rm = TRUE)
  })
  
  # Convert to percentage and annualize (monthly data)
  var_data$VaR_pct <- var_data$VaR * 100
  var_data$confidence_label <- paste0(var_data$confidence * 100, "% VaR")
  
  # Order by 95% VaR (lowest risk first)
  var_95 <- var_data %>%
    filter(confidence == 0.95) %>%
    arrange(VaR_pct)
  
  var_data$portfolio <- factor(var_data$portfolio, levels = var_95$portfolio)
  
  p <- ggplot(var_data, aes(x = portfolio, y = VaR_pct, fill = confidence_label)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    coord_flip() +
    scale_fill_manual(values = c("95% VaR" = "#3182BD", "99% VaR" = "#DE2D26")) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      x = NULL,
      y = "Monthly Value-at-Risk (%)",
      title = "Value-at-Risk Comparison",
      subtitle = "Maximum expected monthly loss at given confidence level (historical)",
      fill = NULL
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "bottom",
      axis.text.y = element_text(size = 11)
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T2. EXPECTED SHORTFALL (CVaR) COMPARISON
## =============================================================================

#' Plot Expected Shortfall (CVaR) Comparison
#'
#' Shows Expected Shortfall (Conditional VaR) - the average loss beyond VaR.
#' This answers "When things go bad, how bad do they get on average?"
#'
#' @inheritParams plot_var_comparison
#' @return ggplot object
plot_cvar_comparison <- function(
    df_scaled,
    factor_vec,
    confidence_levels  = c(0.95, 0.99),
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_cvar_comparison.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating Expected Shortfall (CVaR) comparison plot...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  factor_vec <- intersect(factor_vec, available_cols)
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Default colors
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  color_vec <- rep_len(color_vec, length(factor_vec))
  names(color_vec) <- factor_vec
  
  # Compute CVaR (Expected Shortfall) for each portfolio
  cvar_data <- expand.grid(
    portfolio = factor_vec,
    confidence = confidence_levels,
    stringsAsFactors = FALSE
  )
  
  cvar_data$CVaR <- sapply(1:nrow(cvar_data), function(i) {
    returns <- df_scaled[[cvar_data$portfolio[i]]]
    var_threshold <- quantile(returns, probs = 1 - cvar_data$confidence[i], na.rm = TRUE)
    # CVaR is the average of returns below VaR (as positive loss)
    -mean(returns[returns <= var_threshold], na.rm = TRUE)
  })
  
  cvar_data$CVaR_pct <- cvar_data$CVaR * 100
  cvar_data$confidence_label <- paste0(cvar_data$confidence * 100, "% CVaR")
  
  # Order by 95% CVaR (lowest risk first)
  cvar_95 <- cvar_data %>%
    filter(confidence == 0.95) %>%
    arrange(CVaR_pct)
  
  cvar_data$portfolio <- factor(cvar_data$portfolio, levels = cvar_95$portfolio)
  
  p <- ggplot(cvar_data, aes(x = portfolio, y = CVaR_pct, fill = confidence_label)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    coord_flip() +
    scale_fill_manual(values = c("95% CVaR" = "#3182BD", "99% CVaR" = "#DE2D26")) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      x = NULL,
      y = "Expected Shortfall (%)",
      title = "Expected Shortfall (CVaR) Comparison",
      subtitle = "Average loss when losses exceed VaR threshold",
      fill = NULL
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "bottom",
      axis.text.y = element_text(size = 11)
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T3. UPSIDE/DOWNSIDE CAPTURE RATIO
## =============================================================================

#' Plot Upside/Downside Capture Ratio
#'
#' Shows how much of the benchmark's gains vs losses the portfolio captures.
#' Ideal: High upside capture, low downside capture.
#'
#' @inheritParams plot_var_comparison
#' @param benchmark Name of benchmark column (default "MKTS")
#' @return ggplot object
plot_capture_ratio <- function(
    df_scaled,
    factor_vec,
    benchmark          = "MKTS",
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_capture_ratio.pdf",
    width              = 10,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating upside/downside capture ratio plot...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  
  if (!benchmark %in% available_cols) {
    stop("Benchmark '", benchmark, "' not found in data")
  }
  
  factor_vec <- intersect(factor_vec, available_cols)
  factor_vec <- setdiff(factor_vec, benchmark)  # Remove benchmark from portfolios
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Get benchmark returns
  bench_returns <- df_scaled[[benchmark]]
  up_months <- bench_returns > 0
  down_months <- bench_returns < 0
  
  # Compute capture ratios
  capture_data <- data.frame(
    portfolio = factor_vec,
    stringsAsFactors = FALSE
  )
  
  capture_data$upside_capture <- sapply(factor_vec, function(p) {
    port_returns <- df_scaled[[p]]
    if (sum(up_months, na.rm = TRUE) == 0) return(NA)
    (mean(port_returns[up_months], na.rm = TRUE) / mean(bench_returns[up_months], na.rm = TRUE)) * 100
  })
  
  capture_data$downside_capture <- sapply(factor_vec, function(p) {
    port_returns <- df_scaled[[p]]
    if (sum(down_months, na.rm = TRUE) == 0) return(NA)
    (mean(port_returns[down_months], na.rm = TRUE) / mean(bench_returns[down_months], na.rm = TRUE)) * 100
  })
  
  # Compute capture ratio (upside / downside) - higher is better
  capture_data$capture_ratio <- capture_data$upside_capture / capture_data$downside_capture
  
  # Default colors
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  color_vec <- rep_len(color_vec, length(factor_vec))
  names(color_vec) <- factor_vec
  
  # Create scatter plot
  p <- ggplot(capture_data, aes(x = downside_capture, y = upside_capture, color = portfolio)) +
    # Reference lines
    geom_hline(yintercept = 100, color = "gray50", linetype = "dashed", linewidth = 0.5) +
    geom_vline(xintercept = 100, color = "gray50", linetype = "dashed", linewidth = 0.5) +
    # Diagonal line (capture ratio = 1)
    geom_abline(intercept = 0, slope = 1, color = "gray70", linetype = "dotted", linewidth = 0.5) +
    # Ideal quadrant shading (high upside, low downside)
    annotate("rect", xmin = 0, xmax = 100, ymin = 100, ymax = Inf,
             fill = "green", alpha = 0.1) +
    annotate("text", x = 50, y = max(capture_data$upside_capture, na.rm = TRUE) * 0.95,
             label = "Ideal Zone", color = "darkgreen", size = 3, fontface = "italic") +
    # Points
    geom_point(size = 5) +
    ggrepel::geom_text_repel(aes(label = portfolio), size = 3.5, show.legend = FALSE) +
    scale_color_manual(values = color_vec) +
    scale_x_continuous(labels = function(x) paste0(x, "%")) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      x = paste0("Downside Capture vs ", benchmark, " (%)"),
      y = paste0("Upside Capture vs ", benchmark, " (%)"),
      title = "Upside/Downside Capture Ratio",
      subtitle = paste0("Benchmark: ", benchmark, " | Above diagonal = favorable asymmetry"),
      color = NULL
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "none"
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T4. WIN RATE OVER TIME (ROLLING)
## =============================================================================

#' Plot Rolling Win Rate
#'
#' Shows the percentage of positive months over a rolling window.
#' Demonstrates consistency of returns over time.
#'
#' @inheritParams plot_var_comparison
#' @param window Rolling window in months (default 36)
#' @param line_types_vec Line types for each portfolio
#' @param legend_position Legend position
#' @return ggplot object
plot_rolling_winrate <- function(
    df_scaled,
    factor_vec,
    window             = 36,
    color_vec          = NULL,
    line_types_vec     = NULL,
    legend_position    = c(0.02, 0.02),
    output_dir         = NULL,
    fig_name           = "oos_rolling_winrate.pdf",
    width              = 12,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating rolling win rate plot...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  factor_vec <- intersect(factor_vec, available_cols)
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Default colors/linetypes
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  if (is.null(line_types_vec)) line_types_vec <- rep("solid", length(factor_vec))
  color_vec <- rep_len(color_vec, length(factor_vec))
  line_types_vec <- rep_len(line_types_vec, length(factor_vec))
  names(color_vec) <- factor_vec
  names(line_types_vec) <- factor_vec
  
  # Compute rolling win rate
  winrate_list <- lapply(factor_vec, function(p) {
    returns <- df_scaled[[p]]
    wins <- as.numeric(returns > 0)
    rolling_wr <- zoo::rollmean(wins, k = window, fill = NA, align = "right") * 100
    
    data.frame(
      date = df_scaled$date,
      portfolio = p,
      winrate = rolling_wr,
      stringsAsFactors = FALSE
    )
  })
  
  winrate_data <- do.call(rbind, winrate_list)
  winrate_data <- winrate_data[!is.na(winrate_data$winrate), ]
  
  # Order legend by ending win rate
  end_wr <- winrate_data %>%
    group_by(portfolio) %>%
    filter(date == max(date)) %>%
    arrange(desc(winrate)) %>%
    pull(portfolio)
  
  winrate_data$portfolio <- factor(winrate_data$portfolio, levels = end_wr)
  color_vec_ordered <- color_vec[end_wr]
  line_types_vec_ordered <- line_types_vec[end_wr]
  
  p <- ggplot(winrate_data, aes(x = date, y = winrate, color = portfolio, linetype = portfolio)) +
    geom_hline(yintercept = 50, color = "gray50", linetype = "dashed", linewidth = 0.5) +
    geom_hline(yintercept = 60, color = "gray70", linetype = "dotted", linewidth = 0.3) +
    geom_hline(yintercept = 70, color = "gray70", linetype = "dotted", linewidth = 0.3) +
    geom_line(linewidth = 0.8) +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_x_date(date_labels = "%Y", date_breaks = "2 years") +
    scale_y_continuous(labels = function(x) paste0(x, "%"), limits = c(0, 100)) +
    labs(
      x = NULL,
      y = "Win Rate (%)",
      title = paste0("Rolling ", window, "-Month Win Rate"),
      subtitle = "Percentage of positive months (above 50% = more wins than losses)"
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = legend_position,
      legend.justification = c("left", "bottom")
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T5. TAIL RISK SUMMARY TABLE
## =============================================================================

#' Plot Tail Risk Summary Table
#'
#' Creates a visual table summarizing key tail risk metrics.
#'
#' @inheritParams plot_var_comparison
#' @param benchmark Benchmark for capture ratios
#' @return ggplot object
plot_tail_risk_summary <- function(
    df_scaled,
    factor_vec,
    benchmark          = "MKTS",
    output_dir         = NULL,
    fig_name           = "oos_tail_risk_summary.pdf",
    width              = 12,
    height             = 6,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating tail risk summary table...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  factor_vec <- intersect(factor_vec, available_cols)
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Get benchmark returns (if available)
  has_benchmark <- benchmark %in% available_cols
  if (has_benchmark) {
    bench_returns <- df_scaled[[benchmark]]
    up_months <- bench_returns > 0
    down_months <- bench_returns < 0
  }
  
  # Compute metrics for each portfolio
  summary_list <- lapply(factor_vec, function(p) {
    returns <- df_scaled[[p]]
    
    # Basic stats
    n_obs <- sum(!is.na(returns))
    win_rate <- mean(returns > 0, na.rm = TRUE) * 100
    
    # VaR and CVaR
    var_95 <- -quantile(returns, 0.05, na.rm = TRUE) * 100
    var_99 <- -quantile(returns, 0.01, na.rm = TRUE) * 100
    cvar_95 <- -mean(returns[returns <= quantile(returns, 0.05, na.rm = TRUE)], na.rm = TRUE) * 100
    
    # Max drawdown (simple approximation from cumulative returns)
    cumret <- cumprod(1 + returns)
    peak <- cummax(cumret)
    drawdown <- (cumret - peak) / peak
    max_dd <- min(drawdown, na.rm = TRUE) * 100
    
    # Skewness and Kurtosis
    skew <- moments::skewness(returns, na.rm = TRUE)
    kurt <- moments::kurtosis(returns, na.rm = TRUE)
    
    # Capture ratios (if benchmark available)
    if (has_benchmark && p != benchmark) {
      up_capture <- (mean(returns[up_months], na.rm = TRUE) / 
                       mean(bench_returns[up_months], na.rm = TRUE)) * 100
      down_capture <- (mean(returns[down_months], na.rm = TRUE) / 
                         mean(bench_returns[down_months], na.rm = TRUE)) * 100
    } else {
      up_capture <- NA
      down_capture <- NA
    }
    
    data.frame(
      Portfolio = p,
      `Win Rate` = sprintf("%.1f%%", win_rate),
      `95% VaR` = sprintf("%.2f%%", var_95),
      `99% VaR` = sprintf("%.2f%%", var_99),
      `95% CVaR` = sprintf("%.2f%%", cvar_95),
      `Max DD` = sprintf("%.1f%%", max_dd),
      Skewness = sprintf("%.2f", skew),
      Kurtosis = sprintf("%.2f", kurt),
      `Up Capture` = if (!is.na(up_capture)) sprintf("%.0f%%", up_capture) else "N/A",
      `Down Capture` = if (!is.na(down_capture)) sprintf("%.0f%%", down_capture) else "N/A",
      check.names = FALSE,
      stringsAsFactors = FALSE
    )
  })
  
  summary_df <- do.call(rbind, summary_list)
  
  # Convert to long format for plotting
  summary_long <- summary_df %>%
    pivot_longer(-Portfolio, names_to = "Metric", values_to = "Value") %>%
    mutate(
      Metric = factor(Metric, levels = c("Win Rate", "95% VaR", "99% VaR", "95% CVaR",
                                         "Max DD", "Skewness", "Kurtosis",
                                         "Up Capture", "Down Capture")),
      Portfolio = factor(Portfolio, levels = rev(factor_vec))
    )
  
  p <- ggplot(summary_long, aes(x = Metric, y = Portfolio, label = Value)) +
    geom_tile(fill = "white", color = "gray80") +
    geom_text(size = 3.5) +
    scale_x_discrete(position = "top") +
    labs(
      title = "Tail Risk Summary Statistics",
      subtitle = if (has_benchmark) paste0("Capture ratios vs ", benchmark) else NULL,
      x = NULL, y = NULL
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
      plot.subtitle = element_text(hjust = 0.5, color = "gray40"),
      axis.text.x = element_text(face = "bold", size = 10, angle = 45, hjust = 0),
      axis.text.y = element_text(size = 11),
      panel.grid = element_blank(),
      axis.ticks = element_blank()
    )
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T6. WORST MONTHS COMPARISON
## =============================================================================

#' Plot Worst Months Comparison
#'
#' Shows the N worst months for each portfolio, allowing comparison of
#' tail events across strategies.
#'
#' @inheritParams plot_var_comparison
#' @param n_worst Number of worst months to show (default 10)
#' @return ggplot object
plot_worst_months <- function(
    df_scaled,
    factor_vec,
    n_worst            = 10,
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_worst_months.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating worst months comparison plot...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  factor_vec <- intersect(factor_vec, available_cols)
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Default colors
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  color_vec <- rep_len(color_vec, length(factor_vec))
  names(color_vec) <- factor_vec
  
  # Get worst months for each portfolio
  worst_list <- lapply(factor_vec, function(p) {
    returns <- df_scaled[[p]]
    dates <- df_scaled$date
    
    # Get indices of worst N months
    worst_idx <- order(returns)[1:n_worst]
    
    data.frame(
      portfolio = p,
      rank = 1:n_worst,
      date = dates[worst_idx],
      return_pct = returns[worst_idx] * 100,
      stringsAsFactors = FALSE
    )
  })
  
  worst_data <- do.call(rbind, worst_list)
  
  # Order portfolios by their worst month (least bad first)
  worst_month_order <- worst_data %>%
    filter(rank == 1) %>%
    arrange(desc(return_pct)) %>%
    pull(portfolio)
  
  worst_data$portfolio <- factor(worst_data$portfolio, levels = worst_month_order)
  
  p <- ggplot(worst_data, aes(x = factor(rank), y = return_pct, fill = portfolio)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    scale_fill_manual(values = color_vec[worst_month_order]) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      x = "Rank (1 = Worst)",
      y = "Monthly Return (%)",
      title = paste0("Worst ", n_worst, " Months Comparison"),
      subtitle = "Lower (less negative) bars indicate better downside protection",
      fill = NULL
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "bottom",
      axis.text.x = element_text(size = 10)
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T7. DRAWDOWN RECOVERY ANALYSIS
## =============================================================================

#' Plot Drawdown Recovery Analysis
#'
#' Shows major drawdown events with their depth, duration, and recovery time.
#'
#' @inheritParams plot_var_comparison
#' @param n_drawdowns Number of worst drawdowns to analyze (default 5)
#' @return ggplot object (or list for multiple portfolios)
plot_drawdown_recovery <- function(
    df_scaled,
    factor_vec,
    n_drawdowns        = 5,
    color_vec          = NULL,
    output_dir         = NULL,
    fig_name           = "oos_drawdown_recovery.pdf",
    width              = 14,
    height             = 8,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  if (verbose) cat("Creating drawdown recovery analysis plot...\n")
  
  # Validate inputs
  available_cols <- setdiff(colnames(df_scaled), "date")
  factor_vec <- intersect(factor_vec, available_cols)
  if (length(factor_vec) == 0) stop("No valid portfolios found")
  
  # Default colors
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  color_vec <- rep_len(color_vec, length(factor_vec))
  names(color_vec) <- factor_vec
  
  # Ensure dates are proper Date class
  dates <- as.Date(df_scaled$date)
  
  # Function to identify drawdown periods
  identify_drawdowns <- function(returns, dates, n_dd) {
    cumret <- cumprod(1 + returns)
    peak <- cummax(cumret)
    drawdown <- (cumret - peak) / peak
    
    # Find local minima (trough points)
    dd_troughs <- which(diff(sign(diff(drawdown))) == 2) + 1
    
    if (length(dd_troughs) == 0) {
      # No clear troughs, use worst points
      dd_troughs <- order(drawdown)[1:min(n_dd, length(drawdown))]
    }
    
    # Get the N worst drawdowns
    trough_depths <- drawdown[dd_troughs]
    worst_idx <- order(trough_depths)[1:min(n_dd, length(dd_troughs))]
    worst_troughs <- dd_troughs[worst_idx]
    
    # For each trough, find peak before and recovery after
    dd_info <- lapply(worst_troughs, function(trough_idx) {
      # Find peak before trough
      peak_idx <- which.max(cumret[1:trough_idx])
      
      # Find recovery (back to peak level) after trough
      recovery_idx <- NA_integer_
      recovery_date_val <- as.Date(NA)
      if (trough_idx < length(cumret)) {
        post_trough <- cumret[(trough_idx + 1):length(cumret)]
        recovery_rel <- which(post_trough >= cumret[peak_idx])
        if (length(recovery_rel) > 0) {
          recovery_idx <- trough_idx + recovery_rel[1]
          recovery_date_val <- dates[recovery_idx]
        }
      }
      
      data.frame(
        peak_date = dates[peak_idx],
        trough_date = dates[trough_idx],
        recovery_date = recovery_date_val,
        depth_pct = drawdown[trough_idx] * 100,
        duration_months = trough_idx - peak_idx,
        recovery_months = if (!is.na(recovery_idx)) recovery_idx - trough_idx else NA_integer_,
        stringsAsFactors = FALSE
      )
    })
    
    do.call(rbind, dd_info)
  }
  
  # Compute for each portfolio
  dd_list <- lapply(factor_vec, function(p) {
    returns <- df_scaled[[p]]
    dd_info <- identify_drawdowns(returns, dates, n_drawdowns)
    dd_info$portfolio <- p
    dd_info$rank <- 1:nrow(dd_info)
    dd_info
  })
  
  dd_data <- do.call(rbind, dd_list)
  dd_data$portfolio <- factor(dd_data$portfolio, levels = factor_vec)
  
  # Create summary visualization
  dd_summary <- dd_data %>%
    mutate(
      total_months = duration_months + ifelse(is.na(recovery_months), 0, recovery_months),
      recovered = !is.na(recovery_months)
    )
  
  p <- ggplot(dd_summary, aes(x = factor(rank), y = depth_pct, fill = portfolio)) +
    geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
    geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
    # Add text labels for recovery time
    geom_text(aes(label = ifelse(is.na(recovery_months), "Not\nrecovered", 
                                 paste0(recovery_months, "m"))),
              position = position_dodge(width = 0.8), vjust = 1.5, size = 2.5) +
    scale_fill_manual(values = color_vec) +
    scale_y_continuous(labels = function(x) paste0(x, "%")) +
    labs(
      x = "Drawdown Rank (1 = Deepest)",
      y = "Drawdown Depth (%)",
      title = paste0("Top ", n_drawdowns, " Drawdowns: Depth and Recovery"),
      subtitle = "Labels show months to recovery (from trough to previous peak)",
      fill = NULL
    ) +
    get_portfolio_theme() +
    theme(
      legend.position = "bottom"
    ) +
    guides(fill = guide_legend(nrow = 1))
  
  if (save_plot && !is.null(output_dir)) {
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) dir.create(figures_dir, recursive = TRUE)
    ggsave(file.path(figures_dir, fig_name), p, width = width, height = height)
    if (verbose) cat("  Saved:", file.path(figures_dir, fig_name), "\n")
  }
  
  invisible(p)
}

## =============================================================================
## T8. GENERATE ALL TAIL RISK PLOTS
## =============================================================================

#' Generate All Tail Risk Plots
#'
#' Convenience function to generate all tail risk visualizations.
#'
#' @inheritParams plot_var_comparison
#' @param benchmark Benchmark for capture ratios
#' @param line_types_vec Line types for rolling plots
#' @return List of all plot objects
generate_tail_risk_plots <- function(
    df_scaled,
    factor_vec,
    benchmark          = "MKTS",
    color_vec          = NULL,
    line_types_vec     = NULL,
    output_dir         = NULL,
    verbose            = TRUE
) {
  
  if (verbose) cat("\n========================================\n")
  if (verbose) cat("Generating Tail Risk & Downside Plots\n")
  if (verbose) cat("========================================\n\n")
  
  # Set defaults
  if (is.null(color_vec)) color_vec <- get_default_colors(length(factor_vec))
  if (is.null(line_types_vec)) line_types_vec <- rep("solid", length(factor_vec))
  
  plots <- list()
  
  # 1. VaR comparison
  plots$var <- plot_var_comparison(
    df_scaled, factor_vec, color_vec = color_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 2. CVaR comparison
  plots$cvar <- plot_cvar_comparison(
    df_scaled, factor_vec, color_vec = color_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 3. Capture ratio
  plots$capture <- plot_capture_ratio(
    df_scaled, factor_vec, benchmark = benchmark, color_vec = color_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 4. Rolling win rate
  plots$winrate <- plot_rolling_winrate(
    df_scaled, factor_vec, color_vec = color_vec, line_types_vec = line_types_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 5. Tail risk summary
  plots$summary <- plot_tail_risk_summary(
    df_scaled, factor_vec, benchmark = benchmark,
    output_dir = output_dir, verbose = verbose
  )
  
  # 6. Worst months
  plots$worst_months <- plot_worst_months(
    df_scaled, factor_vec, color_vec = color_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  # 7. Drawdown recovery
  plots$dd_recovery <- plot_drawdown_recovery(
    df_scaled, factor_vec, color_vec = color_vec,
    output_dir = output_dir, verbose = verbose
  )
  
  if (verbose) cat("\n========================================\n")
  if (verbose) cat("Tail risk plots generated!\n")
  if (verbose) cat("========================================\n")
  
  invisible(plots)
}