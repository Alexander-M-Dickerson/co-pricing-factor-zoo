plot_nfac_sr <- function(results,
                         prior_labels     = NULL,
                         prior_choice     = NULL,
                         main_path        = ".",
                         output_folder    = "figures",
                         fig_name         = "densities.pdf",
                         width            = 12,
                         height           = 7,
                         grid_option      = c("All"),
                         x_text_size      = 12,
                         y_text_size      = 12,
                         axis_title_size  = 12,
                         panel_title_size = 14,
                         legend_text_size = 12) {
  library(ggplot2)
  ## ── 0  Inputs & grid selector ──────────────────────────────────────────
  grid_option <- match.arg(grid_option)
  
  grid_theme <- switch(grid_option,
                       "All" = theme(),
                       "None" = theme(panel.grid.major = element_blank(),
                                      panel.grid.minor = element_blank()),
                       "Horizontal" = theme(panel.grid.major.x = element_blank(),
                                            panel.grid.minor.x = element_blank())
  )
  
  if (is.null(prior_labels))
    prior_labels <- paste0(seq_along(results))
  if (is.null(prior_choice))
    prior_choice <- tail(prior_labels, 1)
  
  pr_idx <- if (is.numeric(prior_choice)) prior_choice else
    match(prior_choice, prior_labels)
  if (is.na(pr_idx) || pr_idx < 1 || pr_idx > length(results))
    stop("prior_choice not recognised.")
  
  ## ── 1  Compute inputs for the plots ─────────────────────────────────────
  sdf_sr <- sapply(results, function(r)
    apply(t(r$sdf_path), 2, sd) * sqrt(12))
  
  sdf_sr_focus <- sdf_sr[, pr_idx]
  n_fac        <- rowSums(results[[pr_idx]]$gamma_path)
  
  ## horizontal reference (thin dashed line) for Panel A
  n_col <- ncol(results[[pr_idx]]$gamma_path)
  y_cut <- 1 / n_col
  
  ## ── 2  Panel A – Posterior number of factors ───────────────────────────
  library(ggplot2)
  
  nf_q <- quantile(n_fac, c(0.025, 0.50, 0.975))
  
  pA <- ggplot(data.frame(n_fac), aes(n_fac)) +
    geom_histogram(aes(y = after_stat(density)),
                   binwidth = 1, boundary = 0.5,
                   colour = "grey30", fill = "skyblue") +
    geom_hline(yintercept = 0, size = 1, show.legend = FALSE) +
    ## thin dashed "Prior distribution" line
    geom_hline(aes(yintercept = y_cut,
                   linetype   = "Prior distribution",
                   colour     = "Prior distribution"),
               size = 0.5) +
    ## posterior median line
    geom_vline(data = data.frame(xint = nf_q[2]),
               aes(xintercept = xint,
                   colour     = "Posterior Median",
                   linetype   = "Posterior Median"),
               size = 0.8) +
    ## 95 % CI lines
    geom_vline(data = data.frame(xint = nf_q[c(1, 3)]),
               aes(xintercept = xint,
                   colour     = "Posterior 95% CI",
                   linetype   = "Posterior 95% CI"),
               size = 0.8) +
    ## colour & linetype scales (now include Prior distribution)
    scale_colour_manual(name   = NULL,
                        breaks = c("Prior distribution",
                                   "Posterior Median",
                                   "Posterior 95% CI"),
                        values = c("Prior distribution" = "black",
                                   "Posterior Median"   = "red",
                                   "Posterior 95% CI"   = "orange")) +
    scale_linetype_manual(name   = NULL,
                          breaks = c("Prior distribution",
                                     "Posterior Median",
                                     "Posterior 95% CI"),
                          values = c("Prior distribution" = "dashed",
                                     "Posterior Median"   = "dashed",
                                     "Posterior 95% CI"   = "dotted")) +
    labs(title = "(A)  Posterior distribution of the number of factors",
         x = "Number of factors", y = "Density") +
    theme_bw() + grid_theme +
    theme(axis.text.x  = element_text(size = x_text_size),
          axis.text.y  = element_text(size = y_text_size),
          axis.title   = element_text(size = axis_title_size),
          plot.title   = element_text(size = panel_title_size, hjust = 0),
          legend.text  = element_text(size = legend_text_size),
          legend.title = element_blank(),
          legend.position        = "inside",
          legend.position.inside = c(0.98, 0.95),
          legend.justification   = c(1, 1))
  
  ## ── 3  Panel B – Posterior Sharpe-ratio distribution (DENSITY BASELINE) ──
  sr_vec <- as.numeric(sdf_sr_focus)
  sr_vec <- sr_vec[!is.na(sr_vec)]
  
  sr_q  <- quantile(sr_vec, c(0.05, 0.95))
  sr_lo <- sr_q[1]; sr_hi <- sr_q[2]
  
  dens    <- density(sr_vec)
  dens_df <- data.frame(x = dens$x, y = dens$y)
  
  pB <- ggplot() +
    geom_area(data = subset(dens_df, x >= sr_lo & x <= sr_hi),
              aes(x, y, fill = "Posterior 95% CI"),
              alpha = 0.6, colour = NA) +
    geom_line(data = dens_df,
              aes(x, y),
              colour = "black", size = 0.8, show.legend = FALSE) +
    scale_fill_manual(name   = NULL,
                      breaks = "Posterior 95% CI",
                      values = c("Posterior 95% CI" = "lightblue")) +
    labs(title = "(B)  Posterior distribution of the SDF-implied Sharpe ratio",
         x = "Sharpe ratio", y = "PDF") +
    theme_bw() + grid_theme +
    theme(axis.text.x  = element_text(size = x_text_size),
          axis.text.y  = element_text(size = y_text_size),
          axis.title   = element_text(size = axis_title_size),
          plot.title   = element_text(size = panel_title_size, hjust = 0),
          legend.text  = element_text(size = legend_text_size),
          legend.title = element_blank(),
          legend.position        = "inside",
          legend.position.inside = c(0.02, 0.95),
          legend.justification   = c(0, 1))
  
  ## ── 4  Combine & save ──────────────────────────────────────────────────
  library(patchwork)
  combined <- pA / pB + plot_layout(heights = c(1, 1))
  
  out_path <- file.path(main_path, output_folder)
  if (!dir.exists(out_path))
    dir.create(out_path, recursive = TRUE, showWarnings = FALSE)
  
  ggsave(file.path(out_path, fig_name),
         combined, width = width, height = height, units = "in")
  
  print(combined)
  invisible(combined)
}