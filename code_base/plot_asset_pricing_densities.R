plot_asset_pricing_densities <- function(main_path,
                                         output_folder   = "output",
                                         figures_folder  = "figures",
                                         tag             = "baseline",
                                         model_comp      = c("BMA-80%", "KNS"),
                                         is_estim        = "bond_stock_with_sp",
                                         os_estim        = "co_pricing",
                                         duration        = FALSE,
                                         text_size       = 2.5,
                                         width           = 3.25,
                                         height          = 3.25,
                                         axis_text_size  = 7 ) {
  
  ## 1. libraries
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(purrr)
  library(rlang)            # for `%||%`
  
  ## 2. load RDS & drill to required node
  rds_path <- file.path(main_path, output_folder,
                        sprintf("OS_metrics_%s.rds", tag))
  df <- readRDS(rds_path)
  
  x <- df[[is_estim]]
  if (duration && identical(is_estim, "bond_stock_with_sp"))
    x <- x$duration_adj
  x <- x[[os_estim]]
  
  ## 3. figure directory
  fig_dir <- file.path(main_path, figures_folder)
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  
  ## 4. helpers
  safe  <- function(z) gsub("%", "pct", z, fixed = TRUE)
  short <- function(z) dplyr::case_when(
    grepl("BMA", z) ~ "BMA",
    grepl("KNS", z) ~ "KNS",
    TRUE            ~ z
  )
  
  metric_specs <- list(
    R2GLS  = list(short = "GLS",  xlim = NULL,    x_anno = NULL, better_low = FALSE),
    R2OLS  = list(short = "OLS",  xlim = c(-1, 1), x_anno = -0.95, better_low = FALSE),
    RMSEdm = list(short = "RMSE", xlim = c(0, NA), x_anno = 0,      better_low = TRUE),
    MAPEdm = list(short = "MAPE", xlim = c(0, NA), x_anno = 0,      better_low = TRUE)
  )
  
  ## 5. two-model density plots (unchanged)
  make_plot <- function(metric_name) {
    spec <- metric_specs[[metric_name]]
    
    dat_wide <- x %>%
      filter(metric == metric_name) %>%
      select(all_of(model_comp))
    
    stopifnot(ncol(dat_wide) == 2L)
    
    names(dat_wide) <- short(names(dat_wide))
    m1 <- names(dat_wide)[1]
    m2 <- names(dat_wide)[2]
    
    beat_prob <- mean(
      if (spec$better_low) dat_wide[[m1]] < dat_wide[[m2]]
      else                 dat_wide[[m1]] > dat_wide[[m2]]
    ) * 100
    
    mu <- colMeans(dat_wide, na.rm = TRUE) |> round(2)
    
    dat_long <- pivot_longer(dat_wide,
                             everything(),
                             names_to = "model",
                             values_to = "value")
    
    pal <- setNames(c("red", "#66C2A5"), c(m1, m2))
    
    ggplot(dat_long, aes(value, fill = model)) +
      geom_density(alpha = .20) +
      scale_fill_manual(values = pal, guide = "none") +
      { if (is.null(spec$xlim)) scale_x_continuous()
        else                    scale_x_continuous(limits = spec$xlim) } +
      coord_cartesian(
        xlim = spec$xlim %||% range(dat_long$value),
        ylim = c(0, NA)
      ) +
      annotate("text",
               x = spec$x_anno %||% (max(dat_long$value) - .425),
               y = Inf,
               label = bquote(.(m1) ^.(spec$short) == .(mu[[m1]])),
               hjust = 0, vjust = 2,  size = text_size) +
      annotate("text",
               x = spec$x_anno %||% (max(dat_long$value) - .425),
               y = Inf,
               label = bquote(.(m2) ^.(spec$short) == .(mu[[m2]])),
               hjust = 0, vjust = 3.5, size = text_size) +
      annotate("text",
               x = spec$x_anno %||% (max(dat_long$value) - .425),
               y = Inf,
               label = bquote(.(spec$short) ^{.(m1)} ~
                                .(if (spec$better_low) "<" else ">") ~
                                .(spec$short) ^{.(m2)} ~ "=" ~
                                .(paste0(round(beat_prob, 2), "%"))),
               hjust = 0, vjust = 5,  size = text_size) +
      labs(x = NULL, y = "Density") +
      theme_minimal() +
      theme(panel.border = element_rect(colour = "black", fill = NA,
                                        linewidth = .5))
  }
  
  
  # 6. THREE-DISTRIBUTION PLOTS  (original + duration-adjusted)
  three_specs <- list(
    R2GLS  = list(short = "GLS",  x_anno = function(x) max(x) - 0.45),
    R2OLS  = list(short = "OLS",  x_anno = -0.95),
    RMSEdm = list(short = "RMSE", x_anno = 0),
    MAPEdm = list(short = "MAPE", x_anno = 0)
  )
  
  make_three <- function(metric_name, use_dur = FALSE) {
    
    spec <- three_specs[[metric_name]]
    if (is.null(spec))
      stop("Metric not recognised in three-panel list: ", metric_name,
           call. = FALSE)
    
    # ------------ choose correct node -----------------
    node_cp    <- if (use_dur) df$bond_stock_with_sp$duration_adj$co_pricing
    else         df$bond_stock_with_sp$co_pricing
    node_bond  <- if (use_dur) df$bond$duration_adj$co_pricing
    else         df$bond$co_pricing
    node_stock <- if (use_dur) df$stock$duration_adj$co_pricing
    else         df$stock$co_pricing
    
    fetch <- function(node, mdl)
      node %>% filter(metric == metric_name) %>% pull(mdl)
    
    mdl  <- model_comp[1]
    
    vals <- tibble::tibble(
      `Co-pricing BMA` = fetch(node_cp,   mdl),
      `Bond BMA`       = fetch(node_bond, mdl),
      `Stock BMA`      = fetch(node_stock, mdl)
    )
    
    long <- pivot_longer(vals, everything(),
                         names_to = "series", values_to = "value")
    
    mu <- colMeans(vals, na.rm = TRUE) |>
      round(ifelse(metric_name == "R2OLS", 2, 3))
    
    pal <- c(`Co-pricing BMA` = "red",
             `Bond BMA`       = "blue",
             `Stock BMA`      = "yellow")
    
    # ---- positioning tweaks for duration-adj GLS ----
    use_left <- use_dur && metric_name == "R2GLS"
    x_coord  <- if (use_left) -0.55 else
      if (is.function(spec$x_anno)) spec$x_anno(long$value) else spec$x_anno
    x_limits <- if (use_left) c(-0.60, max(long$value)) else
      if (metric_name == "R2OLS") c(-1, 1) else
        c(if (metric_name == "R2GLS") min(long$value) else 0,
          max(long$value))
    
    ggplot(long, aes(value, fill = series)) +
      geom_density(alpha = .20) +
      scale_fill_manual(values = pal, guide = "none") +
      scale_x_continuous(limits = x_limits) +
      coord_cartesian(xlim = x_limits, ylim = c(0, NA)) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Co-pricing BMA" ^.(spec$short) ==
                                .(mu["Co-pricing BMA"])),
               hjust = 0, vjust = 2,  size = text_size) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Bond BMA" ^.(spec$short) ==
                                .(mu["Bond BMA"])),
               hjust = 0, vjust = 3.5, size = text_size) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Stock BMA" ^.(spec$short) ==
                                .(mu["Stock BMA"])),
               hjust = 0, vjust = 5,   size = text_size) +
      labs(x = NULL, y = "Density") +
      theme_minimal() +
      theme(
        panel.border = element_rect(colour = "black", fill = NA, linewidth = .5),
        axis.text.x  = element_text(size = axis_text_size)  # NEW
      )
  }
  
  
  ## 7. build & write all plots
  metrics   <- names(metric_specs)
  plots     <- map(set_names(metrics), make_plot)
  
  walk2(plots, names(plots), \(plt, mtr) {
    ggsave(file.path(fig_dir,
                     sprintf("%s_%s_vs_%s_%s.pdf",
                             safe(mtr),
                             safe(short(model_comp[1])),
                             safe(short(model_comp[2])),
                             safe(tag))),
           plot   = plt,
           width  = width,
           height = height,
           device = "pdf")
  })
  
  three_metrics <- names(three_specs)
  
  three_plots_base <- map(set_names(three_metrics),
                          \(m) make_three(m, use_dur = FALSE))
  three_plots_dur  <- map(set_names(three_metrics),
                          \(m) make_three(m, use_dur = TRUE))
  
  walk2(three_plots_base, names(three_plots_base), \(plt, mtr) {
    fname <- sprintf("%s_threeDist_%s.pdf",
                     safe(mtr), safe(short(model_comp[1])))
    ggsave(file.path(fig_dir, fname),
           plot   = plt,
           width  = width,
           height = height,
           device = "pdf")
  })
  
  walk2(three_plots_dur, names(three_plots_dur), \(plt, mtr) {
    fname <- sprintf("%s_threeDist_%s_DurAdj.pdf",
                     safe(mtr), safe(short(model_comp[1])))
    ggsave(file.path(fig_dir, fname),
           plot   = plt,
           width  = width,
           height = height,
           device = "pdf")
  })
  
  # ---------------------------------------------------------------
  #   THREE-DISTRIBUTION PANELS — PRICING *BOND* and *STOCK*
  # ---------------------------------------------------------------
  
  # helper that tolerates either df$bond$equity or df$bond$bond$equity
  pluck_pricing_node <- function(root, type = c("bond", "equity")) {
    type <- match.arg(type)
    if (type == "bond") {
      return(root$bond   %||% root$bond$bond)       # df$xxx$bond
    } else {
      # equity node might be df$xxx$equity  OR df$xxx$bond$equity
      out <- root$equity
      if (is.null(out) && !is.null(root$bond))
        out <- root$bond$equity
      return(out)
    }
  }
  
  make_three_pricing <- function(metric_name, price_type = c("bond", "equity")) {
    
    price_type <- match.arg(price_type)   # "bond" or "equity"
    spec       <- three_specs[[metric_name]]
    
    node_cp    <- pluck_pricing_node(df$bond_stock_with_sp, price_type)
    node_bond  <- pluck_pricing_node(df$bond,                 price_type)
    node_stock <- pluck_pricing_node(df$stock,                price_type)
    
    fetch <- function(node, mdl)
      node %>% filter(metric == metric_name) %>% pull(mdl)
    
    mdl <- model_comp[1]   # e.g. "BMA-80%"
    
    vals <- tibble::tibble(
      `Co-pricing BMA` = fetch(node_cp,   mdl),
      `Bond BMA`       = fetch(node_bond, mdl),
      `Stock BMA`      = fetch(node_stock, mdl)
    )
    
    long <- tidyr::pivot_longer(vals, everything(),
                                names_to = "series", values_to = "value")
    
    mu <- colMeans(vals, na.rm = TRUE) |>
      round(ifelse(metric_name == "R2OLS", 2, 3))
    
    pal <- c(`Co-pricing BMA` = "red",
             `Bond BMA`       = "blue",
             `Stock BMA`      = "yellow")
    
    x_coord <- if (is.function(spec$x_anno))
      spec$x_anno(long$value) else spec$x_anno
    
    x_limits <- if (metric_name == "R2OLS") c(-1, 1) else
      c(if (metric_name == "R2GLS") min(long$value) else 0,
        max(long$value))
    
    ggplot(long, aes(value, fill = series)) +
      geom_density(alpha = .20) +
      scale_fill_manual(values = pal, guide = "none") +
      scale_x_continuous(limits = x_limits) +
      coord_cartesian(xlim = x_limits, ylim = c(0, NA)) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Co-pricing BMA" ^.(spec$short) ==
                                .(mu["Co-pricing BMA"])),
               hjust = 0, vjust = 2,  size = text_size) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Bond BMA" ^.(spec$short) ==
                                .(mu["Bond BMA"])),
               hjust = 0, vjust = 3.5, size = text_size) +
      annotate("text", x = x_coord, y = Inf,
               label = bquote("Stock BMA" ^.(spec$short) ==
                                .(mu["Stock BMA"])),
               hjust = 0, vjust = 5,   size = text_size) +
      labs(x = NULL, y = "Density") +
      theme_minimal() +
      theme(
        panel.border = element_rect(colour = "black", fill = NA, linewidth = .5),
        axis.text.x  = element_text(size = axis_text_size)   # user-controlled
      )
  }
  
  # ---- build & save PRICING-BOND plots ---------------------------------
  three_pb <- purrr::map(set_names(three_metrics),
                         \(m) make_three_pricing(m, "bond"))
  
  purrr::walk2(three_pb, names(three_pb), \(plt, mtr) {
    fname <- sprintf("%s_threeDist_BMA_PricingBond.pdf", safe(mtr))
    ggsave(file.path(fig_dir, fname),
           plot   = plt,
           width  = width,
           height = height,
           device = "pdf")
  })
  
  # ---- build & save PRICING-STOCK (equity) plots ------------------------
  three_ps <- purrr::map(set_names(three_metrics),
                         \(m) make_three_pricing(m, "equity"))
  
  purrr::walk2(three_ps, names(three_ps), \(plt, mtr) {
    fname <- sprintf("%s_threeDist_BMA_PricingStock.pdf", safe(mtr))
    ggsave(file.path(fig_dir, fname),
           plot   = plt,
           width  = width,
           height = height,
           device = "pdf")
  })
  
  # ---------------------------------------------------------------
  #   CDF CURVES  (BMA vs. KNS, single figure per metric)
  # ---------------------------------------------------------------
  
  cdf_metrics <- names(metric_specs)  # "R2GLS" "R2OLS" "RMSEdm" "MAPEdm"
  
  make_cdf <- function(metric_name) {
    
    bma_col <- model_comp[1]   # e.g. "BMA-80%"
    kns_col <- "KNS"
    
    fetch <- function(node, col)
      node %>% filter(metric == metric_name) %>% pull(col)
    
    vals <- tibble::tibble(
      `Co-pricing BMA` = fetch(df$bond_stock_with_sp$co_pricing, bma_col),
      `Bond BMA`       = fetch(df$bond$co_pricing,                bma_col),
      `Stock BMA`      = fetch(df$stock$co_pricing,               bma_col),
      `Co-pricing KNS` = fetch(df$bond_stock_with_sp$co_pricing,  kns_col)
    )
    
    long <- tidyr::pivot_longer(vals, everything(),
                                names_to = "series", values_to = "value")
    
    mu <- colMeans(vals, na.rm = TRUE) |>
      round(ifelse(metric_name == "R2OLS", 2, 3))
    
    pal <- c(`Co-pricing BMA` = "red",
             `Bond BMA`       = "blue",
             `Stock BMA`      = "orange",
             `Co-pricing KNS` = "darkgreen")
    
    # ---- axis limits and annotation x-coord ---------------------------
    x_limits <- if (metric_name == "R2OLS")
      c(-1, max(long$value, na.rm = TRUE))
    else
      range(long$value, na.rm = TRUE)
    
    x_coord <- x_limits[1] + 0.02 * diff(x_limits)
    
    ggplot(long, aes(value, colour = series)) +
      stat_ecdf(size = 1) +
      scale_colour_manual(values = pal, guide = "none") +
      scale_x_continuous(limits = x_limits) +          # NEW / UPDATED
      scale_y_continuous(limits = c(0, 1), expand = c(0.001, 0)) +
      labs(x = NULL, y = "Cumulative Probability") +
      annotate("text", x = x_coord, y = 1,
               label = bquote("Co-pricing BMA" ^.(metric_specs[[metric_name]]$short) ==
                                .(mu["Co-pricing BMA"])),
               hjust = 0, vjust = 1.5, size = text_size) +
      annotate("text", x = x_coord, y = 1,
               label = bquote("Bond BMA" ^.(metric_specs[[metric_name]]$short) ==
                                .(mu["Bond BMA"])),
               hjust = 0, vjust = 3,   size = text_size) +
      annotate("text", x = x_coord, y = 1,
               label = bquote("Stock BMA" ^.(metric_specs[[metric_name]]$short) ==
                                .(mu["Stock BMA"])),
               hjust = 0, vjust = 4.5, size = text_size) +
      annotate("text", x = x_coord, y = 1,
               label = bquote("Co-pricing KNS" ^.(metric_specs[[metric_name]]$short) ==
                                .(mu["Co-pricing KNS"])),
               hjust = 0, vjust = 6,   size = text_size) +
      theme_minimal() +
      theme(
        panel.border = element_rect(colour = "black", fill = NA, linewidth = .5),
        axis.text.x  = element_text(size = axis_text_size)
      )
  }
  
  
  # ---- build & save the CDF-curve figures ------------------------------
  cdf_plots <- purrr::map(set_names(cdf_metrics), make_cdf)
  
  purrr::walk2(cdf_plots, names(cdf_plots), \(plt, mtr) {
    fname <- sprintf("%s_CDFCurves.pdf", safe(mtr))
    ggsave(file.path(fig_dir, fname),
           plot   = plt,
           width  = width,
           height = height,
           device = "pdf")
  })
  
  # ---- add to the invisible return -------------------------------------
  invisible(c(two_model          = plots,
              three_dist         = three_plots_base,
              three_dist_dur     = three_plots_dur,
              three_dist_pbond   = three_pb,
              three_dist_pstock  = three_ps,
              cdf_curves         = cdf_plots))
  
}