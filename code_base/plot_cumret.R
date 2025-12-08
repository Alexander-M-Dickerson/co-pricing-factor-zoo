#' Plot Cumulative Returns for Portfolio Strategies
#'
#' Creates a cumulative return plot showing portfolio growth over time.
#' Portfolios are ordered by final value in the legend.
#'
#' @param df_scaled Data frame with date column and portfolio return columns (scaled)
#' @param factor_vec Character vector of portfolio/model names to plot
#' @param color_vec Character vector of colors (same order as factor_vec)
#' @param line_types_vec Character vector of line types (same order as factor_vec)
#' @param legend_position Numeric vector of length 2 for legend position (x, y)
#' @param dollar_step Numeric, spacing for y-axis breaks
#' @param x_tick_font_size Numeric, font size for x-axis tick labels
#' @param y_tick_font_size Numeric, font size for y-axis tick labels
#' @param dollar_label_size Numeric, font size for endpoint dollar labels
#' @param legend_font_size Numeric, font size for legend text
#' @param y_axis_title_size Numeric, font size for y-axis title
#' @param output_dir Character, directory to save the figure (figures subdir created)
#' @param fig_name Character, filename for the saved figure
#' @param width Numeric, figure width in inches
#' @param height Numeric, figure height in inches
#' @param save_plot Logical, whether to save the plot to file
#' @param verbose Logical, print progress messages
#'
#' @return ggplot object (invisibly)

plot_cumret <- function(
    df_scaled,
    factor_vec,
    color_vec          = c("red", "#66C2A5", "black", "lightblue", "royalblue4", "purple"),
    line_types_vec     = c("solid", "solid", "solid", "dashed", "dashed", "dashed"),
    legend_position    = c(0.02, 0.98),
    dollar_step        = 50,
    x_tick_font_size   = 16,
    y_tick_font_size   = 14,
    dollar_label_size  = 5,
    legend_font_size   = 16,
    y_axis_title_size  = 16,
    output_dir         = NULL,
    fig_name           = "oos_cumret.pdf",
    width              = 12,
    height             = 7,
    save_plot          = TRUE,
    verbose            = TRUE
) {
  
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  
  ## -------------------------------------------------------------------------
  ## 1. Validate Inputs
  ## -------------------------------------------------------------------------
  
  if (!"date" %in% colnames(df_scaled)) {
    stop("df_scaled must contain a 'date' column")
  }
  
  # Check which factors exist
  available_cols <- setdiff(colnames(df_scaled), "date")
  missing_factors <- setdiff(factor_vec, available_cols)
  
  if (length(missing_factors) > 0) {
    warning("The following factors not found in data and will be skipped: ",
            paste(missing_factors, collapse = ", "))
    
    # Remove missing factors and corresponding colors/linetypes
    keep_idx <- factor_vec %in% available_cols
    factor_vec <- factor_vec[keep_idx]
    color_vec <- color_vec[keep_idx]
    line_types_vec <- line_types_vec[keep_idx]
  }
  
  if (length(factor_vec) == 0) {
    stop("No valid factors to plot")
  }
  
  # Ensure vectors are same length
  if (length(color_vec) < length(factor_vec)) {
    color_vec <- rep_len(color_vec, length(factor_vec))
  }
  if (length(line_types_vec) < length(factor_vec)) {
    line_types_vec <- rep_len(line_types_vec, length(factor_vec))
  }
  
  # Name the vectors
  names(color_vec) <- factor_vec
  names(line_types_vec) <- factor_vec
  
  ## -------------------------------------------------------------------------
  ## 2. Compute cumulative returns
  ## -------------------------------------------------------------------------

  if (verbose) cat("Computing cumulative returns...\n")

  # Define legend label mapping (internal name -> display name)
  legend_labels <- c(
    "EqualWeight" = "EW",
    "RP-PCA"      = "RPPCA"
  )

  # Helper function to rename portfolio for display
  rename_portfolio <- function(x) {
    ifelse(x %in% names(legend_labels), legend_labels[x], x)
  }

  # Get ordering by final dollar value
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    mutate(portfolio = rename_portfolio(portfolio)) %>%
    group_by(portfolio) %>%
    arrange(date) %>%
    mutate(dollar = exp(cumsum(ret))) %>%
    slice_tail(n = 1) %>%
    ungroup() %>%
    arrange(desc(dollar)) %>%
    mutate(portfolio = factor(portfolio, levels = unique(portfolio))) -> ordering_df

  # Now use this order in the full dataset
  plot_data <- df_scaled %>%
    dplyr::select(date, all_of(factor_vec)) %>%
    pivot_longer(-date, names_to = "portfolio", values_to = "ret") %>%
    mutate(portfolio = rename_portfolio(portfolio)) %>%
    group_by(portfolio) %>%
    arrange(date) %>%
    mutate(dollar = exp(cumsum(ret))) %>%
    ungroup() %>%
    mutate(portfolio = factor(portfolio, levels = levels(ordering_df$portfolio)))

  # Also rename the color_vec and line_types_vec keys
  names(color_vec) <- rename_portfolio(names(color_vec))
  names(line_types_vec) <- rename_portfolio(names(line_types_vec))
  
  # Get last dollar values for endpoint labels
  last_dollar <- plot_data %>%
    group_by(portfolio) %>%
    slice_tail(n = 1) %>%
    ungroup()
  
  last_dollar$dollar <- round(last_dollar$dollar, 0)
  
  ## -------------------------------------------------------------------------
  ## 3. Custom y-axis breaks
  ## -------------------------------------------------------------------------
  
  y_max <- max(plot_data$dollar, na.rm = TRUE)
  dollar_breaks <- seq(from = dollar_step, to = ceiling(y_max + dollar_step), by = dollar_step)
  
  ## -------------------------------------------------------------------------
  ## 4. Define custom colors and line types (reorder to match legend order)
  ## -------------------------------------------------------------------------
  
  ordered_levels <- levels(plot_data$portfolio)
  color_vec_ordered <- color_vec[ordered_levels]
  line_types_vec_ordered <- line_types_vec[ordered_levels]
  
  ## -------------------------------------------------------------------------
  ## 5. Plot
  ## -------------------------------------------------------------------------
  
  if (verbose) cat("Creating plot...\n")
  
  p <- ggplot(plot_data, aes(x = date, y = dollar, color = portfolio, linetype = portfolio)) +
    geom_line(linewidth = 1) +
    geom_point(data = last_dollar, size = 2, show.legend = FALSE) +
    geom_text(
      data = last_dollar,
      aes(label = sprintf("%.0f", dollar)),
      hjust = -0.1, vjust = 0.5,
      show.legend = FALSE,
      size = dollar_label_size
    ) +
    geom_hline(yintercept = 1, linetype = "dashed", color = "gray50") +
    scale_color_manual(values = color_vec_ordered) +
    scale_linetype_manual(values = line_types_vec_ordered) +
    scale_y_log10(
      breaks = dollar_breaks,
      labels = dollar_format(accuracy = 1)
    ) +
    scale_x_date(
      breaks = seq(as.Date("2004-08-01"), as.Date("2023-08-01"), by = "1 year"),
      labels = format(seq(as.Date("2004-08-01"), as.Date("2023-08-01"), by = "1 year"), "%Y-%m")
    ) +
    labs(
      x = NULL,
      y = "Portfolio Value in $",
      title = ""
    ) +
    theme_minimal() +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major.y = element_line(color = "gray85"),
      panel.grid.major.x = element_blank(),
      axis.text.x = element_text(angle = 45, hjust = 1, size = x_tick_font_size),
      axis.text.y = element_text(size = y_tick_font_size),
      axis.title.y = element_text(size = y_axis_title_size),
      panel.border = element_rect(color = "black", fill = NA, linewidth = 1),
      legend.title = element_blank(),
      legend.position = legend_position,
      legend.justification = c("left", "top"),
      legend.background = element_rect(fill = "white", color = "black", linewidth = 0.4),
      legend.text = element_text(size = legend_font_size)
    ) +
    coord_cartesian(clip = "off")
  
  ## -------------------------------------------------------------------------
  ## 6. Save Plot
  ## -------------------------------------------------------------------------
  
  if (save_plot && !is.null(output_dir)) {
    # Create figures directory if needed
    figures_dir <- file.path(output_dir, "figures")
    if (!dir.exists(figures_dir)) {
      dir.create(figures_dir, recursive = TRUE)
      if (verbose) cat("Created figures directory: ", figures_dir, "\n")
    }
    
    full_path <- file.path(figures_dir, fig_name)
    
    ggsave(
      filename = full_path,
      plot = p,
      width = width,
      height = height,
      units = "in"
    )
    
    if (verbose) cat("Figure saved to: ", full_path, "\n")
  }
  
  ## -------------------------------------------------------------------------
  ## 7. Return Plot Object
  ## -------------------------------------------------------------------------
  
  invisible(p)
}