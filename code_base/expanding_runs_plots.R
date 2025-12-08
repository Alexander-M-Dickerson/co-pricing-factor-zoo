#' Generate Heatmaps of Top Factors Over Time (Expanding Window Analysis)
#'
#' Reads results from time-varying estimation (.rds format) and generates
#' heatmaps showing the top factors by posterior probability over time.
#'
#' @param rds_path       Path to the ALL_RESULTS.rds file from run_time_varying_estimation()
#' @param psi_level      Shrinkage level to use: 0.2, 0.4, 0.6, or 0.8 (default: 0.8)
#' @param top_n          Number of top factors to show (default: 5)
#' @param output_path    Directory to save figures (default: "output/paper/figures")
#' @param figure_prefix  Prefix for output filenames (default: "fig6a")
#' @param verbose        Print progress messages (default: TRUE)
#'
#' @return List containing:
#'   - top_factors_prob: Named list of top factors by date
#'   - plot: The ggplot object
#'   - output_file: Path to saved PDF
#'
#' @details
#' This function reads the combined results from expanding window estimation
#' and creates a heatmap showing which factors have the highest posterior
#' inclusion probabilities at each estimation date. Factors are ordered by
#' their frequency of appearance in the top N across all dates.
#'
#' The input .rds file is expected to contain `gammas_panel`, a data frame
#' with columns: date, factor, psi_level, prob.
#'
#' @examples
#' \dontrun{
#'   result <- expanding_runs_plots(
#'     rds_path = "output/time_varying/bond_stock_with_sp/SS_excess_..._ALL_RESULTS.rds",
#'     psi_level = 0.8,
#'     output_path = "output/paper/figures"
#'   )
#' }

expanding_runs_plots <- function(
    rds_path,
    psi_level     = 0.8,
    top_n         = 5,
    output_path   = "output/paper/figures",
    figure_prefix = "fig6a",
    verbose       = TRUE
) {

  ## ── packages ──────────────────────────────────────────────────────────────
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
  library(ggplot2)
  library(lubridate)

  talk <- function(...) if (isTRUE(verbose)) message(...)

  ## ── 1. Validate and load RDS file ─────────────────────────────────────────
  if (!file.exists(rds_path)) {
    stop("RDS file not found: ", rds_path, call. = FALSE)
  }

  talk("Loading: ", rds_path)
  combined_results <- readRDS(rds_path)

  # Check for gammas_panel

  if (is.null(combined_results$gammas_panel) ||
      nrow(combined_results$gammas_panel) == 0) {
    stop("gammas_panel not found or empty in RDS file.", call. = FALSE)
  }

  gammas_panel <- combined_results$gammas_panel

  talk("  Found ", length(unique(gammas_panel$date)), " estimation dates")
  talk("  Found ", length(unique(gammas_panel$factor)), " factors")
  talk("  Available psi_levels: ", paste(sort(unique(gammas_panel$psi_level)), collapse = ", "))

  ## ── 2. Filter to specified shrinkage level ────────────────────────────────
  if (!psi_level %in% unique(gammas_panel$psi_level)) {
    stop("psi_level ", psi_level, " not found. Available: ",
         paste(unique(gammas_panel$psi_level), collapse = ", "), call. = FALSE)
  }

  gammas_filtered <- gammas_panel %>%
    filter(psi_level == !!psi_level)

  talk("  Using psi_level = ", psi_level, " (", nrow(gammas_filtered), " rows)")

  ## ── 3. Identify top N factors for each date ───────────────────────────────
  dates <- sort(unique(gammas_filtered$date))

  top_factors_prob <- lapply(dates, function(d) {
    gammas_filtered %>%
      filter(date == d) %>%
      arrange(desc(prob)) %>%
      slice_head(n = top_n) %>%
      pull(factor)
  })
  names(top_factors_prob) <- as.character(dates)

  talk("  Identified top ", top_n, " factors for each of ", length(dates), " dates")

  ## ── 4. Build long data frame for heatmap ──────────────────────────────────
  df_long <- map_df(names(top_factors_prob), function(d) {
    tibble(
      date   = as.Date(d),
      factor = top_factors_prob[[d]],
      Rank   = seq_along(top_factors_prob[[d]])
    )
  })

  ## ── 5. Order factors by frequency, then by how often they are Rank 1 ──────
  ordering <- df_long %>%
    group_by(factor) %>%
    summarise(
      total_n = dplyr::n(),
      rank1   = sum(Rank == 1),
      .groups = "drop"
    ) %>%
    arrange(desc(total_n), desc(rank1)) %>%
    pull(factor)

  df_long <- df_long %>%
    mutate(factor = factor(factor, levels = rev(ordering)))

  ## ── 6. Create heatmap ─────────────────────────────────────────────────────
  # Plotting parameters
  x_tick_size      <- 14
  legend_text_size <- 14
  y_label_size     <- 14
  plot_width       <- 12
  plot_height      <- 7
  plot_units       <- "in"

  # Normalize dates to January 1st of each year for x-axis labels
  df_plot <- df_long %>%
    mutate(date_label = as.Date(paste0(format(date, "%Y"), "-01-01")))

  # Determine edge years to blank out (year before first data, year after last data)
  # These appear on the axis due to ggplot's date_breaks but have no data
  data_years <- as.numeric(unique(format(df_plot$date_label, "%Y")))
  year_before_first <- as.Date(paste0(min(data_years) - 1, "-01-01"))
  year_after_last   <- as.Date(paste0(max(data_years) + 1, "-01-01"))

  # Create the plot
  p <- ggplot(df_plot, aes(x = date_label, y = factor, fill = Rank)) +
    geom_tile(colour = "white") +
    scale_x_date(
      date_breaks = "1 year",
      labels = function(x) {
        labs <- format(x, "%Y")
        # Blank out edge year labels (year before/after data range)
        labs[x == year_before_first] <- ""
        labs[x == year_after_last]   <- ""
        labs
      }
    ) +
    scale_fill_gradient(
      low = "#08519c",
      high = "#c6dbef",
      name = "Rank"
    ) +
    labs(x = "", y = "", title = "") +
    theme_minimal() +
    theme(
      panel.border    = element_rect(colour = "black", fill = NA, linewidth = 1),
      axis.text.x     = element_text(angle = 45, hjust = 1, size = x_tick_size),
      axis.text.y     = element_text(size = y_label_size),
      axis.title.y    = element_text(size = y_label_size),
      legend.position = "right",
      legend.text     = element_text(size = legend_text_size),
      legend.title    = element_text(size = legend_text_size),
      legend.background      = element_rect(colour = "black", fill = "white"),
      legend.box.background  = element_rect(colour = "white", fill = "white")
    ) +
    guides(fill = guide_legend(reverse = FALSE))

  ## ── 7. Save figure ────────────────────────────────────────────────────────
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE)
  }

  # Construct output filename
  psi_label <- sprintf("%d", round(psi_level * 100))
  output_file <- file.path(output_path,
                           paste0(figure_prefix, "_top", top_n, "_prob_psi", psi_label, ".pdf"))

  suppressWarnings({
    ggsave(output_file, plot = p,
           width = plot_width, height = plot_height, units = plot_units)
  })

  talk("Saved: ", output_file)

  ## ── 8. Return results ─────────────────────────────────────────────────────
  invisible(list(
    top_factors_prob = top_factors_prob,
    plot             = p,
    output_file      = output_file,
    df_long          = df_long
  ))
}


#' Generate Figure 6 Panel A: Top Factors Heatmap (Forward Expanding)
#'
#' Convenience wrapper for expanding_runs_plots() with standard output naming.
#'
#' @param rds_path       Path to the ALL_RESULTS.rds file
#' @param psi_level      Shrinkage level (default: 0.8)
#' @param top_n          Number of top factors (default: 5)
#' @param output_path    Output directory
#' @param verbose        Print progress
#'
#' @return List with plot and data
#'
#' @examples
#' \dontrun{
#'   generate_figure_6a(
#'     rds_path = "output/time_varying/bond_stock_with_sp/SS_..._ALL_RESULTS.rds"
#'   )
#' }

generate_figure_6a <- function(
    rds_path,
    psi_level   = 0.8,
    top_n       = 5,
    output_path = "output/paper/figures",
    verbose     = TRUE
) {
  expanding_runs_plots(
    rds_path      = rds_path,
    psi_level     = psi_level,
    top_n         = top_n,
    output_path   = output_path,
    figure_prefix = "fig6a",
    verbose       = verbose
  )
}
