# =========================================================================
#  plot_thousands_oos_densities.R  ---  Density Plots for Thousands OOS Tests
# =========================================================================
#' Generate density plots for thousands OOS pricing tests (Figures 5 & 8)
#'
#' Creates density plots comparing OOS pricing metrics across three IS models:
#' - Co-pricing BMA (bond_stock_with_sp)
#' - Bond BMA (bond)
#' - Stock BMA (stock)
#'
#' All models price the same OOS test assets (co_pricing universe).
#'
#' Main Function:
#'   plot_thousands_oos_densities() - Generate all 4 density plots for a figure
# =========================================================================


#' Plot density distributions for thousands OOS tests
#'
#' Generates 4 density plots (R2GLS, R2OLS, RMSEdm, MAPEdm) showing the
#' distribution of OOS pricing metrics across thousands of test asset subsets.
#' Each plot shows 3 densities: Co-pricing BMA, Bond BMA, Stock BMA.
#'
#' @param thousands_oos_results List from run_thousands_oos_tests()
#' @param model_col Which BMA model column to use (default: "BMA-80%")
#' @param os_estim Which OOS universe to use (default: "co_pricing")
#' @param output_path Path to save figures
#' @param figure_prefix Prefix for output files (e.g., "fig5" or "fig8")
#' @param text_size Text size for annotations (default: 2.5)
#' @param width Figure width in inches (default: 3.25)
#' @param height Figure height in inches (default: 3.25)
#' @param axis_text_size Size for axis text (default: 7)
#' @param verbose Print progress messages
#'
#' @return List of ggplot objects (invisibly)
#'
#' @examples
#' \dontrun{
#'   # Figure 5 (excess returns)
#'   thousands_oos <- readRDS("data/thousands_oos_results.rds")
#'   plot_thousands_oos_densities(
#'     thousands_oos_results = thousands_oos,
#'     output_path = "output/paper/figures",
#'     figure_prefix = "fig5"
#'   )
#'
#'   # Figure 8 (duration-adjusted)
#'   thousands_oos_dur <- readRDS("data/thousands_oos_results_duration.rds")
#'   plot_thousands_oos_densities(
#'     thousands_oos_results = thousands_oos_dur,
#'     output_path = "output/paper/figures",
#'     figure_prefix = "fig8"
#'   )
#' }
plot_thousands_oos_densities <- function(thousands_oos_results,
                                          model_col = "BMA-80%",
                                          os_estim = "co_pricing",
                                          output_path = "output/paper/figures",
                                          figure_prefix = "fig5",
                                          text_size = 2.5,
                                          width = 3.25,
                                          height = 3.25,
                                          axis_text_size = 7,
                                          verbose = TRUE) {

  # Load required packages
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' required. Install with: install.packages('ggplot2')")
  }
  if (!requireNamespace("tidyr", quietly = TRUE)) {
    stop("Package 'tidyr' required. Install with: install.packages('tidyr')")
  }
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' required. Install with: install.packages('dplyr')")
  }

  library(ggplot2)
  library(tidyr)
  library(dplyr)

  # Create output directory
  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)

  # Metric specifications
  metric_specs <- list(
    R2GLS  = list(short = "GLS",  x_anno_fn = function(x) max(x, na.rm = TRUE) - 0.45),
    R2OLS  = list(short = "OLS",  x_anno = -0.95),
    RMSEdm = list(short = "RMSE", x_anno = 0),
    MAPEdm = list(short = "MAPE", x_anno = 0)
  )

  # Extract data for each IS model type
  if (verbose) message("Extracting data for density plots...")

  # Helper to extract metric values from a data.table
  extract_metric <- function(dt, metric_name, col_name) {
    if (is.null(dt)) return(NULL)
    dt_filtered <- dt[dt$metric == metric_name, ]
    if (nrow(dt_filtered) == 0) return(NULL)
    if (!col_name %in% names(dt_filtered)) return(NULL)
    as.numeric(dt_filtered[[col_name]])
  }

  # Build density plot for one metric
  make_density_plot <- function(metric_name) {

    spec <- metric_specs[[metric_name]]

    # Get values for each IS model
    vals_cp <- extract_metric(thousands_oos_results$bond_stock_with_sp[[os_estim]],
                               metric_name, model_col)
    vals_bond <- extract_metric(thousands_oos_results$bond[[os_estim]],
                                 metric_name, model_col)
    vals_stock <- extract_metric(thousands_oos_results$stock[[os_estim]],
                                  metric_name, model_col)

    # Check if we have data
    if (is.null(vals_cp) && is.null(vals_bond) && is.null(vals_stock)) {
      warning("No data found for metric: ", metric_name)
      return(NULL)
    }

    # Build tibble
    vals <- tibble::tibble(
      `Co-pricing BMA` = vals_cp,
      `Bond BMA` = vals_bond,
      `Stock BMA` = vals_stock
    )

    # Pivot to long format
    long <- tidyr::pivot_longer(vals, everything(),
                                 names_to = "series", values_to = "value")

    # Remove NAs
    long <- long[!is.na(long$value), ]

    if (nrow(long) == 0) {
      warning("No valid data for metric: ", metric_name)
      return(NULL)
    }

    # Compute means
    mu <- colMeans(vals, na.rm = TRUE)
    mu <- round(mu, ifelse(metric_name == "R2OLS", 2, 3))

    # Color palette
    pal <- c(`Co-pricing BMA` = "red",
             `Bond BMA` = "blue",
             `Stock BMA` = "yellow")

    # Determine x coordinate for annotations
    x_coord <- if (is.function(spec$x_anno_fn)) {
      spec$x_anno_fn(long$value)
    } else {
      spec$x_anno
    }

    # X-axis limits
    x_limits <- if (metric_name == "R2OLS") {
      c(-1, 1)
    } else if (metric_name == "R2GLS") {
      c(min(long$value, na.rm = TRUE), max(long$value, na.rm = TRUE))
    } else {
      c(0, max(long$value, na.rm = TRUE))
    }

    # Build plot
    p <- ggplot(long, aes(x = value, fill = series)) +
      geom_density(alpha = 0.20) +
      scale_fill_manual(values = pal, guide = "none") +
      scale_x_continuous(limits = x_limits) +
      coord_cartesian(xlim = x_limits, ylim = c(0, NA)) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Co-pricing BMA" ^.(spec$short) == .(mu["Co-pricing BMA"])),
               hjust = 0, vjust = 2, size = text_size) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Bond BMA" ^.(spec$short) == .(mu["Bond BMA"])),
               hjust = 0, vjust = 3.5, size = text_size) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Stock BMA" ^.(spec$short) == .(mu["Stock BMA"])),
               hjust = 0, vjust = 5, size = text_size) +
      labs(x = NULL, y = "Density") +
      theme_minimal() +
      theme(
        panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.5),
        axis.text.x = element_text(size = axis_text_size)
      )

    p
  }

  # Generate all 4 plots
  if (verbose) message("Generating density plots...")

  plots <- list()
  metric_to_fig <- c(R2GLS = "1", R2OLS = "2", RMSEdm = "3", MAPEdm = "4")

  for (metric_name in names(metric_specs)) {
    if (verbose) message("  ", metric_name, "...")

    p <- make_density_plot(metric_name)

    if (!is.null(p)) {
      # Save plot
      fig_num <- metric_to_fig[[metric_name]]
      filename <- sprintf("%s_%s_%s.pdf", figure_prefix, fig_num,
                          tolower(metric_specs[[metric_name]]$short))
      filepath <- file.path(output_path, filename)

      ggplot2::ggsave(filepath, plot = p, width = width, height = height, device = "pdf")

      if (verbose) message("    Saved: ", filename)

      plots[[metric_name]] <- p
    }
  }

  if (verbose) {
    message("Density plots complete.")
    message("  Figures saved to: ", normalizePath(output_path))
  }

  invisible(list(
    plots = plots,
    output_path = output_path,
    figure_prefix = figure_prefix
  ))
}


#' Generate all density plots for Figures 5 and 8
#'
#' Convenience wrapper that generates both Figure 5 (excess returns) and
#' Figure 8 (duration-adjusted) density plots.
#'
#' @param thousands_oos_results Results from run_thousands_oos_tests() (excess)
#' @param thousands_oos_results_duration Results from run_thousands_oos_tests(duration_mode=TRUE)
#' @param output_path Path to save figures
#' @param verbose Print progress messages
#'
#' @return List with fig5 and fig8 results (invisibly)
generate_figures_5_and_8 <- function(thousands_oos_results,
                                      thousands_oos_results_duration = NULL,
                                      output_path = "output/paper/figures",
                                      verbose = TRUE) {

  results <- list()

  # Figure 5: Excess returns
  if (!is.null(thousands_oos_results)) {
    if (verbose) message("\n=== Generating Figure 5 (Excess Returns) ===")
    results$fig5 <- plot_thousands_oos_densities(
      thousands_oos_results = thousands_oos_results,
      output_path = output_path,
      figure_prefix = "fig5",
      verbose = verbose
    )
  }

  # Figure 8: Duration-adjusted
  if (!is.null(thousands_oos_results_duration)) {
    if (verbose) message("\n=== Generating Figure 8 (Duration-Adjusted) ===")
    results$fig8 <- plot_thousands_oos_densities(
      thousands_oos_results = thousands_oos_results_duration,
      output_path = output_path,
      figure_prefix = "fig8",
      verbose = verbose
    )
  }

  invisible(results)
}
