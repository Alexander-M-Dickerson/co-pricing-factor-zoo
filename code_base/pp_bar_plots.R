# ──────────────────────────────────────────────────────────────────────────
#  pp_bar_subplots()  –  Panel-A/B bar plots for probabilities & risk prices
# ──────────────────────────────────────────────────────────────────────────
# Args
#   results        : list returned by run_bayesian_mcmc()          (required)
#   prior_labels   : vector of prior-SR labels                     (default 20/40/60/80 %)
#   prior_choice   : which prior column to plot (label or index)   (default last)
#   intercept      : TRUE keeps λ-intercept row, FALSE drops it    (default TRUE)
#   main_path      : root folder                                   (default ".")
#   output_folder  : sub-folder for figures                        (default "figures")
#   fig_name       : file name for PDF                             (default "posterior_bars.pdf")
#   width,height   : inches                                        (default 10×8)
#   verbose        : TRUE → message when file written
#
# Returns
#   the patchwork gg object (also printed)
# ──────────────────────────────────────────────────────────────────────────
pp_bar_subplots <- function(results,
                            prior_labels   = c("20%","40%","60%","80%"),
                            prior_choice   = tail(prior_labels, 1),  # default last
                            panelA_title     = "(A)  Posterior probabilities",   
                            panelB_title     = "(B)  Posterior market prices of risk", 
                            intercept      = TRUE,
                            main_path      = ".",
                            output_folder  = "figures",
                            fig_name       = "posterior_bars.pdf",
                            panel_title_size = 14,
                            axis_title_size = 11,   # NEW
                            width          = 12,
                            height         = 7,
                            highlight_N    = 14,
                            #  style controls
                            prob_thresh    = 0.50,
                            y_axis_text_size = 11,
                            x_axis_text_size = 9,
                            legend_text_size = 9,
                            latex_font       = FALSE,   
                            verbose        = TRUE) {
  
  # -- factor names from caller’s f1/f2 ------------------------------------
  if (!exists("f1", inherits = TRUE))
    stop("f1 (and optionally f2) must exist in calling environment.")
  f1 <- get("f1", inherits = TRUE)
  f2 <- if (exists("f2", inherits = TRUE)) get("f2", inherits = TRUE) else NULL
  factor_names <- colnames(cbind(f1, f2))
  
  # -- matrices -------------------------------------------------------------
  prob_mat <- sapply(results, \(r) colMeans(r$gamma_path))
  colnames(prob_mat) <- prior_labels
  rownames(prob_mat) <- factor_names
  
  risk_mat <- sapply(results, \(r) colMeans(r$lambda_path))
  colnames(risk_mat) <- prior_labels
  if (nrow(risk_mat) == length(factor_names) + 1) {
    rownames(risk_mat) <- c("Constant", factor_names)
    if (!intercept) risk_mat <- risk_mat[-1, , drop = FALSE] else
      risk_mat <- risk_mat[-1, ]           # strip intercept either way
  } else rownames(risk_mat) <- factor_names
  
  # -- which column to plot --------------------------------------------------
  col_idx <- if (is.numeric(prior_choice)) prior_choice else
    match(prior_choice, prior_labels)
  if (is.na(col_idx)) stop("`prior_choice` not found in prior_labels.")
  
  # -- order factors low → high by prob -------------------------------------
  order_idx <- order(prob_mat[, col_idx])
  factor_ord <- factor_names[order_idx]
  
  # -- tidy data frames ------------------------------------------------------
  library(dplyr)
  df_prob <- data.frame(Factor = factor(factor_ord, levels = factor_ord),
                        Prob   = prob_mat[factor_ord, col_idx])
  
  df_risk <- data.frame(Factor = factor(factor_ord, levels = factor_ord),
                        Risk   = risk_mat[factor_ord, col_idx] * sqrt(12))
  
  
  ## ── helper: axis-label text & base font ─────────────────────────────────────
  if (!requireNamespace("latex2exp", quietly = TRUE)) {
    warning("Package {latex2exp} not available – using plain labels.")
    y_lab_prob <- "E[gamma | data]"
    y_lab_risk <- "E[lambda | data]"
  } else {
    y_lab_prob <- "Posterior probability"
    y_lab_risk <- "Posterior MPR (annual)"
  }
  
  base_family <- ""   # leave font as default (avoids showtext complexity)
  
  ### ── plotting block with legend + styling controls ──────────────────────
  library(ggplot2)
  library(patchwork)
  
  # 1.  COLOUR MAPPING -------------------------------------------------------
  f1_names <- colnames(f1)
  f2_names <- if (!is.null(f2)) colnames(f2) else character(0)
  
  ## initialise type vector for every factor, default "Unknown"
  type_vec <- rep("Unknown", length(factor_ord))
  names(type_vec) <- factor_ord
  
  ## ---- CASE 1: we have a separate f2 block (self-pricing models) ----------
  if (!is.null(f2)) {
    type_vec[factor_ord %in% f1_names] <- "Non-traded"
    
    # split f2 into bond vs equity using counts
    n_bond <- if (is.null(n_bondfac)) 0 else n_bondfac
    n_stock<- if (is.null(n_stockfac)) 0 else n_stockfac
    
    bond_names  <- if (n_bond  > 0) f2_names[ seq_len(n_bond) ]               else character(0)
    stock_names <- if (n_stock > 0) f2_names[ seq(n_bond + 1, n_bond + n_stock) ] else character(0)
    
    type_vec[factor_ord %in% bond_names ] <- "Bond"
    type_vec[factor_ord %in% stock_names] <- "Equity"
    
    ## ---- CASE 2: no f2 block (no-self-pricing models) -----------------------
  } else {
    # the order in f1 is: [non-traded | bond | equity]  according to counts
    nt_idx <- seq_len(n_nontraded)
    
    bd_idx <- if (!is.null(n_bondfac) && n_bondfac > 0)
      (n_nontraded + 1) :
      (n_nontraded + n_bondfac)        else integer(0)
    
    st_idx <- if (!is.null(n_stockfac) && n_stockfac > 0)
      (max(bd_idx, n_nontraded) + 1) :
      (max(bd_idx, n_nontraded) + n_stockfac) else integer(0)
    
    type_vec[f1_names[nt_idx]] <- "Non-traded"
    if (length(bd_idx)) type_vec[f1_names[bd_idx]] <- "Bond"
    if (length(st_idx)) type_vec[f1_names[st_idx]] <- "Equity"
  }
  
  ## final palette -----------------------------------------------------------
  fill_pal <- c("Non-traded" = "royalblue4",
                "Bond"       = "royalblue1",
                "Equity"     = "tomato")
  
  
  # 2. tidy data -------------------------------------------------------------
  df_prob <- data.frame(Factor = factor(factor_ord, levels = factor_ord),
                        Prob   = prob_mat[factor_ord, col_idx],
                        Type   = type_vec)
  
  df_risk <- data.frame(Factor = factor(factor_ord, levels = factor_ord),
                        Risk   = risk_mat[factor_ord, col_idx] * sqrt(12),
                        Type   = type_vec)
  
  ## choose where to place the “Prior probability” label --------------------
  label_offset <- if (all(df_prob$Prob < 0.55, na.rm = TRUE)) +0.02 else 0.02
  
  # 3. Panel A  -------------------------------------------------------------
  pA <- ggplot(df_prob, aes(Factor, Prob, fill = Type)) +
    geom_col() +
    geom_hline(yintercept = prob_thresh, linetype = "dashed", colour = "black") +
    annotate("text",
             x      = factor_ord[ceiling(length(factor_ord) / 2)],
             y      = prob_thresh + label_offset,   # ← uses ±0.02 as needed
             label  = "Prior probability",
             hjust  = 0.5, vjust = -0.3,
             size   = legend_text_size / 2.2) +
    scale_fill_manual(values = fill_pal, guide = "none") +
    labs(title = panelA_title,
         y = y_lab_prob, x = NULL) +
    theme_bw(base_size = 11, base_family = base_family) +
    theme(axis.text.x  = element_blank(),
          axis.ticks.x = element_blank(),
          axis.text.y  = element_text(size = y_axis_text_size),
          plot.title   = element_text(size = panel_title_size, hjust = 0),
          panel.grid.major.x = element_blank(),
          panel.grid.minor.x = element_blank())
  
  
  
  # 4. Panel B  -------------------------------------------------------------
  pB <- ggplot(df_risk, aes(Factor, Risk, fill = Type)) +
    geom_col() +
    scale_fill_manual(values = fill_pal,
                      breaks = c("Non-traded","Bond","Equity"),
                      labels = c("Non-traded factors",
                                 "Bond factors",
                                 "Equity factors"),
                      guide  = guide_legend(override.aes = list(size = 3))) +
    labs(title = panelB_title,
         y = y_lab_risk, x = NULL) +
    theme_bw(base_size = 11, base_family = base_family) +
    theme(
      axis.text.x      = element_text(angle = 90, vjust = 0.5, hjust = 1,
                                      size = x_axis_text_size),
      axis.ticks.x     = element_line(),
      axis.text.y      = element_text(size = y_axis_text_size),
      axis.title.y     = element_text(size = axis_title_size),     # NEW
      legend.position        = "inside",                           # show inside
      legend.position.inside = c(0.02, 0.98),                      # top-left
      legend.justification   = c(0, 1),
      legend.title           = element_blank(),
      legend.text            = element_text(size = legend_text_size),
      legend.key.size        = unit(0.25, "cm"),
      legend.background      = element_blank(),
      plot.title             = element_text(size = panel_title_size, hjust = 0),
      panel.grid.major.x = element_blank(),   # ← remove vertical major gridlines
      panel.grid.minor.x = element_blank()    # ← remove vertical minor gridlines
    )
  
  
  
  # 5. combine, save, return -------------------------------------------------
  combined <- pA / pB + plot_layout(heights = c(1, 1))
  print(combined)
  
  file_out <- file.path(main_path, output_folder, fig_name)
  dir.create(dirname(file_out), recursive = TRUE, showWarnings = FALSE)
  ggsave(file_out, combined, width = width, height = height, units = "in")
  if (verbose) message("Bar-plot figure exported → ", normalizePath(file_out))
  
  print(combined)
  invisible(combined)
  ### ────────────────────────────────────────────────────────────────────────
}