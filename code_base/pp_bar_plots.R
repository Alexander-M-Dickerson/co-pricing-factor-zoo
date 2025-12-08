# =========================================================================
#  pp_bar_plots.R  ---  Figure 4: Posterior Probabilities & Risk Prices
# =========================================================================
#' Generate Figure 4: Panel bar plots for posterior probabilities and
#' market prices of risk
#'
#' Panel A shows posterior inclusion probabilities for each factor.
#' Panel B shows posterior mean market prices of risk (annualized).
#' Factors are ordered by posterior probability (low to high).
#' Colors distinguish Non-traded, Bond, and Equity factors.
#'
#' @param results List returned by run_bayesian_mcmc() (one element per prior)
#' @param return_type Return type string for filename (e.g., "excess")
#' @param model_type Model type string for filename (e.g., "bond_stock_with_sp")
#' @param tag Tag string for filename (e.g., "baseline")
#' @param prior_labels Vector of prior-SR labels (default: c("20%","40%","60%","80%"))
#' @param prior_choice Which prior to plot (label or index, default: last)
#' @param prob_thresh Probability threshold for dashed reference line (default: 0.50)
#' @param panelA_title Title for Panel A (default: "(A) Posterior probabilities")
#' @param panelB_title Title for Panel B (default: "(B) Posterior market prices of risk")
#' @param main_path Root folder for output (default: ".")
#' @param output_folder Sub-folder for figures (default: "figures")
#' @param width Figure width in inches (default: 12)
#' @param height Figure height in inches (default: 7)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return List with fig_file path and the ggplot object
#'
#' @details
#' Requires f1, f2 (optional), and factor name vectors (nontraded_names,
#' bond_names, stock_names) to exist in the calling environment.
#' These are loaded from the .Rdata file.
# =========================================================================

pp_bar_plots <- function(results,
                         # Metadata for filename
                         return_type    = "excess",
                         model_type     = "bond_stock_with_sp",
                         tag            = "baseline",
                         # Prior selection
                         prior_labels   = c("20%", "40%", "60%", "80%"),
                         prior_choice   = tail(prior_labels, 1),
                         prob_thresh    = 0.50,
                         # Panel titles
                         panelA_title   = "(A)  Posterior probabilities",
                         panelB_title   = "(B)  Posterior market prices of risk",
                         # Output paths
                         main_path      = ".",
                         output_folder  = "figures",
                         # Figure dimensions
                         width          = 12,
                         height         = 7,
                         # Style options
                         panel_title_size = 14,
                         axis_title_size  = 11,
                         y_axis_text_size = 11,
                         x_axis_text_size = 9,
                         legend_text_size = 9,
                         # Verbosity
                         verbose        = TRUE) {

  # ── Load required packages ──────────────────────────────────────────────
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' required. Install with: install.packages('ggplot2')")
  }
  if (!requireNamespace("patchwork", quietly = TRUE)) {
    stop("Package 'patchwork' required. Install with: install.packages('patchwork')")
  }
  library(ggplot2)
  library(patchwork)

  # ── Get factor matrices from caller's environment ───────────────────────

  if (!exists("f1", inherits = TRUE)) {
    stop("f1 must exist in calling environment (loaded from .Rdata)")
  }
  f1 <- get("f1", inherits = TRUE)
  f2 <- if (exists("f2", inherits = TRUE)) get("f2", inherits = TRUE) else NULL

  factor_names <- colnames(cbind(f1, f2))

  # ── Get factor type vectors from caller's environment ───────────────────

  # These are pre-computed in the .Rdata file - use them directly
  nontraded_names_env <- if (exists("nontraded_names", inherits = TRUE)) {
    get("nontraded_names", inherits = TRUE)
  } else {
    colnames(f1)  # fallback
  }

  bond_names_env <- if (exists("bond_names", inherits = TRUE)) {
    get("bond_names", inherits = TRUE)
  } else {
    character(0)
  }

  stock_names_env <- if (exists("stock_names", inherits = TRUE)) {
    get("stock_names", inherits = TRUE)
  } else {
    character(0)
  }

  if (verbose) {
    message("Figure 4: Posterior Probabilities & Market Prices of Risk")
    message("  Non-traded factors: ", length(nontraded_names_env))
    message("  Bond factors: ", length(bond_names_env))
    message("  Stock factors: ", length(stock_names_env))
  }

  # ── Compute probability and risk matrices ───────────────────────────────
  prob_mat <- sapply(results, function(r) colMeans(r$gamma_path))
  colnames(prob_mat) <- prior_labels
  rownames(prob_mat) <- factor_names

  risk_mat <- sapply(results, function(r) colMeans(r$lambda_path))
  colnames(risk_mat) <- prior_labels

  # Handle intercept in lambda_path
  if (nrow(risk_mat) == length(factor_names) + 1) {
    rownames(risk_mat) <- c("Constant", factor_names)
    risk_mat <- risk_mat[-1, , drop = FALSE]  # strip intercept
  } else {
    rownames(risk_mat) <- factor_names
  }

  # ── Determine which prior column to plot ────────────────────────────────
  col_idx <- if (is.numeric(prior_choice)) {
    prior_choice
  } else {
    match(prior_choice, prior_labels)
  }
  if (is.na(col_idx)) {
    stop("`prior_choice` not found in prior_labels.")
  }

  if (verbose) {
    message("  Prior used: ", prior_labels[col_idx])
  }

  # ── Order factors by posterior probability (low to high) ────────────────
  order_idx <- order(prob_mat[, col_idx])
  factor_ord <- factor_names[order_idx]

  # ── Assign factor types ─────────────────────────────────────────────────
  type_vec <- rep("Unknown", length(factor_ord))
  names(type_vec) <- factor_ord

  type_vec[factor_ord %in% nontraded_names_env] <- "Non-traded"
  type_vec[factor_ord %in% bond_names_env]      <- "Bond"
  type_vec[factor_ord %in% stock_names_env]     <- "Equity"

  # Color palette

  fill_pal <- c("Non-traded" = "royalblue4",
                "Bond"       = "royalblue1",
                "Equity"     = "tomato")

  # ── Create tidy data frames ─────────────────────────────────────────────
  df_prob <- data.frame(
    Factor = factor(factor_ord, levels = factor_ord),
    Prob   = prob_mat[factor_ord, col_idx],
    Type   = type_vec
  )

  df_risk <- data.frame(
    Factor = factor(factor_ord, levels = factor_ord),
    Risk   = risk_mat[factor_ord, col_idx] * sqrt(12),  # annualize
    Type   = type_vec
  )

  # ── Y-axis labels ───────────────────────────────────────────────────────
  y_lab_prob <- "Posterior probability"
  y_lab_risk <- "Posterior MPR (annual)"

  # ── Panel A: Posterior Probabilities ────────────────────────────────────
  label_offset <- if (all(df_prob$Prob < 0.55, na.rm = TRUE)) 0.02 else 0.02

  pA <- ggplot(df_prob, aes(Factor, Prob, fill = Type)) +
    geom_col() +
    geom_hline(yintercept = prob_thresh, linetype = "dashed", colour = "black") +
    annotate("text",
             x      = factor_ord[ceiling(length(factor_ord) / 2)],
             y      = prob_thresh + label_offset,
             label  = "Prior probability",
             hjust  = 0.5, vjust = -0.3,
             size   = legend_text_size / 2.2) +
    scale_fill_manual(values = fill_pal, guide = "none") +
    labs(title = panelA_title,
         y = y_lab_prob, x = NULL) +
    theme_bw(base_size = 11) +
    theme(axis.text.x  = element_blank(),
          axis.ticks.x = element_blank(),
          axis.text.y  = element_text(size = y_axis_text_size),
          axis.title.y = element_text(size = axis_title_size),
          plot.title   = element_text(size = panel_title_size, hjust = 0),
          panel.grid.major.x = element_blank(),
          panel.grid.minor.x = element_blank())

  # ── Panel B: Market Prices of Risk ──────────────────────────────────────
  pB <- ggplot(df_risk, aes(Factor, Risk, fill = Type)) +
    geom_col() +
    scale_fill_manual(values = fill_pal,
                      breaks = c("Non-traded", "Bond", "Equity"),
                      labels = c("Non-traded factors",
                                 "Bond factors",
                                 "Equity factors"),
                      guide  = guide_legend(override.aes = list(size = 3))) +
    labs(title = panelB_title,
         y = y_lab_risk, x = NULL) +
    theme_bw(base_size = 11) +
    theme(
      axis.text.x            = element_text(angle = 90, vjust = 0.5, hjust = 1,
                                            size = x_axis_text_size),
      axis.ticks.x           = element_line(),
      axis.text.y            = element_text(size = y_axis_text_size),
      axis.title.y           = element_text(size = axis_title_size),
      legend.position        = "inside",
      legend.position.inside = c(0.02, 0.98),
      legend.justification   = c(0, 1),
      legend.title           = element_blank(),
      legend.text            = element_text(size = legend_text_size),
      legend.key.size        = unit(0.25, "cm"),
      legend.background      = element_blank(),
      plot.title             = element_text(size = panel_title_size, hjust = 0),
      panel.grid.major.x     = element_blank(),
      panel.grid.minor.x     = element_blank()
    )

  # ── Combine panels ──────────────────────────────────────────────────────
  combined <- pA / pB + plot_layout(heights = c(1, 1))

  # ── Construct filename and save ─────────────────────────────────────────
  fig_name <- sprintf("figure_4_posterior_bars_%s_%s_%s.pdf",
                      return_type, model_type, tag)
  fig_path <- file.path(main_path, output_folder, fig_name)
  dir.create(dirname(fig_path), recursive = TRUE, showWarnings = FALSE)

  ggsave(fig_path, combined, width = width, height = height, units = "in")

  if (verbose) {
    message("  Figure saved: ", fig_path)
  }

  # ── Return result ───────────────────────────────────────────────────────
  invisible(list(
    fig_file   = fig_path,
    plot       = combined,
    prior_used = prior_labels[col_idx],
    n_factors  = length(factor_names),
    factor_types = table(type_vec)
  ))
}
