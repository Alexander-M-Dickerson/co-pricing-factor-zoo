# =========================================================================
#  plot_nfac_sr()   ---  Figure 3: Number of Factors & Sharpe Ratio
# =========================================================================
# Creates a two-panel figure showing:
#   (A) Posterior distribution of the number of factors
#   (B) Posterior distribution of the SDF-implied Sharpe ratio
#
# Saves the PDF under main_path/output_folder.
#
# Required
# --------
#   results          list returned by run_bayesian_mcmc()
#                    Must contain sdf_path and gamma_path for each prior
#
# Metadata (for filename construction)
# ------------------------------------
#   return_type      "excess" or "duration"
#   model_type       "bond", "stock", "bond_stock_with_sp", "treasury"
#   tag              run identifier (e.g., "baseline")
#
# Optional (with sensible defaults)
# ---------------------------------
#   prior_labels     labels for priors (default: c("20%","40%","60%","80%"))
#   prior_choice     which prior to use (default: last one, typically "80%")
#   main_path        root folder (default: ".")
#   output_folder    sub-folder for figures (default: "figures")
#   width, height    inches of saved figure (default: 12x7)
#   verbose          print progress messages (default: TRUE)
#   grid_option      grid lines: "All", "None", "Horizontal" (default: "All")
#
# Returns
# -------
#   Invisible list(plot = <combined patchwork>, fig_file = <path>)
# =========================================================================

plot_nfac_sr <- function(results,
                         # Metadata for filename
                         return_type      = "excess",
                         model_type       = "bond_stock_with_sp",
                         tag              = "baseline",
                         # Prior selection
                         prior_labels     = c("20%", "40%", "60%", "80%"),
                         prior_choice     = NULL,
                         # Output paths
                         main_path        = ".",
                         output_folder    = "figures",
                         # Figure dimensions
                         width            = 12,
                         height           = 7,
                         # Display options
                         verbose          = TRUE,
                         grid_option      = c("All", "None", "Horizontal"),
                         # Text sizes
                         x_text_size      = 12,
                         y_text_size      = 12,
                         axis_title_size  = 12,
                         panel_title_size = 14,
                         legend_text_size = 12) {

  ## ---- 0a. Validate required packages ---------------------------------------
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' required. Install with: install.packages('ggplot2')")
  }
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("Package 'patchwork' required. Install with: install.packages('patchwork')")
  }

  ## ---- 0b. Validate inputs --------------------------------------------------
  if (is.null(results) || !is.list(results)) {
    stop("'results' must be a non-null list from run_bayesian_mcmc()")
  }

  # Check that sdf_path exists in results
  if (is.null(results[[1]]$sdf_path)) {
    stop("results must contain 'sdf_path'. Ensure MCMC was run with SDF tracking enabled.")
  }

  ## ---- 0c. Construct filename with metadata ---------------------------------
  fig_basename <- sprintf("figure_3_nfac_sr_%s_%s_%s",
                          return_type, model_type, tag)
  fig_name <- paste0(fig_basename, ".pdf")

  ## ---- 0d. Grid option selector ---------------------------------------------
  grid_option <- match.arg(grid_option)

  grid_theme <- switch(grid_option,
                       "All" = ggplot2::theme(),
                       "None" = ggplot2::theme(panel.grid.major = ggplot2::element_blank(),
                                               panel.grid.minor = ggplot2::element_blank()),
                       "Horizontal" = ggplot2::theme(panel.grid.major.x = ggplot2::element_blank(),
                                                     panel.grid.minor.x = ggplot2::element_blank())
  )

  ## ---- 0e. Prior selection --------------------------------------------------
  if (is.null(prior_labels) || length(prior_labels) != length(results)) {
    prior_labels <- paste0(seq_along(results))
  }

  if (is.null(prior_choice)) {
    prior_choice <- tail(prior_labels, 1)
  }

  pr_idx <- if (is.numeric(prior_choice)) {
    prior_choice
  } else {
    match(prior_choice, prior_labels)
  }

  if (is.na(pr_idx) || pr_idx < 1 || pr_idx > length(results)) {
    stop("prior_choice '", prior_choice, "' not recognised. ",
         "Available: ", paste(prior_labels, collapse = ", "))
  }

  if (verbose) {
    message("  Using prior: ", prior_labels[pr_idx], " (index ", pr_idx, ")")
  }

  ## ---- 1. Compute inputs for the plots --------------------------------------
  # SDF Sharpe ratios: SD of SDF path * sqrt(12) for annualization
  sdf_sr <- sapply(results, function(r)
    apply(t(r$sdf_path), 2, sd) * sqrt(12))

  sdf_sr_focus <- sdf_sr[, pr_idx]
  n_fac <- rowSums(results[[pr_idx]]$gamma_path)

  # Horizontal reference (thin dashed line) for Panel A - prior distribution
  n_col <- ncol(results[[pr_idx]]$gamma_path)
  y_cut <- 1 / n_col

  ## ---- 2. Panel A: Posterior distribution of number of factors --------------
  nf_q <- quantile(n_fac, c(0.025, 0.50, 0.975))

  pA <- ggplot2::ggplot(data.frame(n_fac = n_fac), ggplot2::aes(x = n_fac)) +
    ggplot2::geom_histogram(ggplot2::aes(y = ggplot2::after_stat(density)),
                            binwidth = 1, boundary = 0.5,
                            colour = "grey30", fill = "skyblue") +
    ggplot2::geom_hline(yintercept = 0, linewidth = 1, show.legend = FALSE) +
    # Prior distribution reference line
    ggplot2::geom_hline(ggplot2::aes(yintercept = y_cut,
                                     linetype = "Prior distribution",
                                     colour = "Prior distribution"),
                        linewidth = 0.5) +
    # Posterior median line
    ggplot2::geom_vline(data = data.frame(xint = nf_q[2]),
                        ggplot2::aes(xintercept = xint,
                                     colour = "Posterior Median",
                                     linetype = "Posterior Median"),
                        linewidth = 0.8) +
    # 95% CI lines
    ggplot2::geom_vline(data = data.frame(xint = nf_q[c(1, 3)]),
                        ggplot2::aes(xintercept = xint,
                                     colour = "Posterior 95% CI",
                                     linetype = "Posterior 95% CI"),
                        linewidth = 0.8) +
    # Colour and linetype scales
    ggplot2::scale_colour_manual(
      name = NULL,
      breaks = c("Prior distribution", "Posterior Median", "Posterior 95% CI"),
      values = c("Prior distribution" = "black",
                 "Posterior Median" = "red",
                 "Posterior 95% CI" = "orange")
    ) +
    ggplot2::scale_linetype_manual(
      name = NULL,
      breaks = c("Prior distribution", "Posterior Median", "Posterior 95% CI"),
      values = c("Prior distribution" = "dashed",
                 "Posterior Median" = "dashed",
                 "Posterior 95% CI" = "dotted")
    ) +
    ggplot2::labs(
      title = "(A)  Posterior distribution of the number of factors",
      x = "Number of factors",
      y = "Density"
    ) +
    ggplot2::theme_bw() + grid_theme +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(size = x_text_size),
      axis.text.y = ggplot2::element_text(size = y_text_size),
      axis.title = ggplot2::element_text(size = axis_title_size),
      plot.title = ggplot2::element_text(size = panel_title_size, hjust = 0),
      legend.text = ggplot2::element_text(size = legend_text_size),
      legend.title = ggplot2::element_blank(),
      legend.position = "inside",
      legend.position.inside = c(0.98, 0.95),
      legend.justification = c(1, 1)
    )

  ## ---- 3. Panel B: Posterior SR distribution (density) ----------------------
  sr_vec <- as.numeric(sdf_sr_focus)
  sr_vec <- sr_vec[!is.na(sr_vec)]

  sr_q <- quantile(sr_vec, c(0.05, 0.95))
  sr_lo <- sr_q[1]
  sr_hi <- sr_q[2]

  dens <- density(sr_vec)
  dens_df <- data.frame(x = dens$x, y = dens$y)

  pB <- ggplot2::ggplot() +
    ggplot2::geom_area(
      data = subset(dens_df, x >= sr_lo & x <= sr_hi),
      ggplot2::aes(x = x, y = y, fill = "Posterior 90% CI"),
      alpha = 0.6, colour = NA
    ) +
    ggplot2::geom_line(
      data = dens_df,
      ggplot2::aes(x = x, y = y),
      colour = "black", linewidth = 0.8, show.legend = FALSE
    ) +
    ggplot2::scale_fill_manual(
      name = NULL,
      breaks = "Posterior 90% CI",
      values = c("Posterior 90% CI" = "lightblue")
    ) +
    ggplot2::labs(
      title = "(B)  Posterior distribution of the SDF-implied Sharpe ratio",
      x = "Sharpe ratio",
      y = "PDF"
    ) +
    ggplot2::theme_bw() + grid_theme +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(size = x_text_size),
      axis.text.y = ggplot2::element_text(size = y_text_size),
      axis.title = ggplot2::element_text(size = axis_title_size),
      plot.title = ggplot2::element_text(size = panel_title_size, hjust = 0),
      legend.text = ggplot2::element_text(size = legend_text_size),
      legend.title = ggplot2::element_blank(),
      legend.position = "inside",
      legend.position.inside = c(0.02, 0.95),
      legend.justification = c(0, 1)
    )

  ## ---- 4. Combine panels & save ---------------------------------------------
  combined <- pA / pB + patchwork::plot_layout(heights = c(1, 1))

  out_path <- file.path(main_path, output_folder)
  if (!dir.exists(out_path)) {
    dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
  }

  save_file <- file.path(out_path, fig_name)
  # @exhibit Figure 3 | IA treasury analogue
  ggplot2::ggsave(save_file, combined,
                  width = width, height = height, units = "in")

  if (verbose) {
    message("Figure exported -> ", normalizePath(save_file))
  }

  ## ---- 5. Return results ----------------------------------------------------
  invisible(list(
    plot = combined,
    fig_file = save_file,
    prior_used = prior_labels[pr_idx],
    n_factors_summary = nf_q,
    sr_summary = sr_q
  ))
}
