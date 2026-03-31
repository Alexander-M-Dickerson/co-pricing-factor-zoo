# ---------------------------------------------------------------------
#  plot_cumulative_sr.R
#  Functions for computing and plotting cumulative Sharpe ratio figures
# ---------------------------------------------------------------------

#' Compute cumulative factor-implied Sharpe ratios
#'
#' Loads .Rdata workspace and computes cumulative Sharpe ratios by
#' iteratively adding factors ranked by posterior probability.
#'
#' @param main_path Project root path
#' @param output_folder Output folder relative to main_path (default: "output")
#' @param model_type Model type (default: "bond_stock_with_sp")
#' @param return_type Return type: "excess" or "duration" (default: "duration")
#' @param kappa Kappa parameter (default: 0)
#' @param alpha.w Alpha weight (default: 1)
#' @param beta.w Beta weight (default: 1)
#' @param tag Results tag (default: "baseline")
#' @param prior_labels Labels for prior shrinkage levels
#' @param verbose Print progress messages (default: TRUE)
#' @return A tibble with cumulative SR results for all shrinkage levels
#'
cumulative_sharpe_ratio <- function(main_path,
                                    output_folder = "output",
                                    model_type    = "bond_stock_with_sp",
                                    return_type   = "duration",
                                    kappa         = 0,
                                    alpha.w       = 1,
                                    beta.w        = 1,
                                    tag           = "baseline",
                                    prior_labels  = c("20%", "40%", "60%", "80%"),
                                    verbose       = TRUE) {

  # ---- 0.  locate & load workspace into local environment ---------------
  subdir <- if (model_type == "bond_stock_with_sp") {
    file.path("unconditional", "bond_stock_with_sp")
  } else {
    "unconditional"
  }

  fname <- sprintf(
    "%s_%s_alpha.w=%g_beta.w=%g_kappa=%s_%s.Rdata",
    return_type, model_type, alpha.w, beta.w, as.character(kappa), tag
  )
  rdata_path <- file.path(main_path, output_folder, subdir, fname)

  if (!file.exists(rdata_path)) {
    stop("Workspace not found: ", rdata_path)
  }

  if (verbose) message("Loading workspace: ", rdata_path)

  # Load into local environment to avoid global pollution
  load_env <- new.env()
  load(rdata_path, envir = load_env)

  if (!exists("results", envir = load_env, inherits = FALSE)) {
    stop("`results` object not found inside ", rdata_path)
  }

  results <- get("results", envir = load_env)

  # --------------------------------------------------------------------
  #  Get required objects from loaded environment
  # --------------------------------------------------------------------
  if (!requireNamespace("matrixStats", quietly = TRUE)) {
    stop("matrixStats package is required.")
  }
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("dplyr package is required.")
  }
  if (!requireNamespace("tibble", quietly = TRUE)) {
    stop("tibble package is required.")
  }

  # Get factor classification vectors from loaded environment
  if (!exists("stock_names", envir = load_env) ||
      !exists("bond_names", envir = load_env) ||
      !exists("nontraded_names", envir = load_env)) {
    stop("stock_names, bond_names, nontraded_names must exist in workspace.")
  }

  stock_set     <- get("stock_names", envir = load_env)
  bond_set      <- get("bond_names", envir = load_env)
  nontraded_set <- get("nontraded_names", envir = load_env)

  # Get factor matrices
  if (!exists("f1", envir = load_env)) {
    stop("f1 must exist in workspace.")
  }
  f1 <- get("f1", envir = load_env)
  f2 <- if (exists("f2", envir = load_env)) get("f2", envir = load_env) else NULL

  f_raw      <- cbind(f1, f2)
  f_centered <- scale(f_raw, center = TRUE, scale = FALSE)
  factor_sd  <- matrixStats::colSds(f_centered)
  factor_nm  <- colnames(f_centered)
  K          <- length(factor_nm)

  Sigma_full <- crossprod(f_centered) / (nrow(f_centered) - 1)

  prob_mat <- sapply(results, \(r) colMeans(r$gamma_path))
  rownames(prob_mat) <- factor_nm

  out <- vector("list", length(results))

  for (i in seq_along(results)) {

    res_i      <- results[[i]]
    median_num <- median(rowSums(res_i$gamma_path))
    sr_m_i     <- apply(res_i$sdf_path, 1, sd) * sqrt(12)

    top_idx   <- order(prob_mat[, i], decreasing = TRUE, na.last = NA)
    sd_all    <- factor_sd[top_idx]
    Sigma_ord <- Sigma_full[top_idx, top_idx, drop = FALSE]

    lambda_i <- res_i$lambda_path
    if (ncol(lambda_i) == K + 1L) {
      lambda_i <- lambda_i[, -1, drop = FALSE]
    }

    lambda_ord    <- lambda_i[, top_idx, drop = FALSE]
    lambda_scaled <- sweep(lambda_ord, 2, sd_all, "/")

    tbl_list <- vector("list", K)

    if (verbose) {
      ptm <- proc.time()
    }

    for (k in seq_len(K)) {

      lam_k   <- lambda_scaled[, 1:k, drop = FALSE]
      Sigma_k <- Sigma_ord[1:k, 1:k, drop = FALSE]

      fac_k_name <- factor_nm[top_idx][k]
      col_tag <- if (fac_k_name %in% stock_set)      "tomato"      else
        if (fac_k_name %in% bond_set)       "royalblue1"  else
          if (fac_k_name %in% nontraded_set)  "royalblue4"  else
            "grey50"

      quad  <- rowSums((lam_k %*% Sigma_k) * lam_k)
      sr_f  <- sqrt(quad) * sqrt(12)
      ratio <- (quad * 12) / (sr_m_i^2)

      tbl_list[[k]] <- tibble::tibble(
        shrinkage   = prior_labels[i],
        n_factors   = k,
        median_num  = median_num,
        factor_name = fac_k_name,
        colour      = col_tag,
        SR_mean     = mean(sr_f),
        SR_q08      = quantile(sr_f, 0.08),
        SR_q92      = quantile(sr_f, 0.92),
        Ratio_mean  = mean(ratio),
        Ratio_q08   = quantile(ratio, 0.08),
        Ratio_q92   = quantile(ratio, 0.92)
      )
    }

    if (verbose) {
      elapsed <- proc.time() - ptm
      message("Shrinkage ", prior_labels[i], " elapsed time: ",
              round(elapsed["elapsed"], 2), " seconds")
    }

    out[[i]] <- dplyr::bind_rows(tbl_list)
  }

  # Return combined tibble for all shrinkage levels
  dplyr::bind_rows(out)
}


#' Plot cumulative factor-implied Sharpe ratio
#'
#' Creates a figure showing cumulative SR as factors are added
#' in order of posterior probability.
#'
#' @param sharpe_tbl Tibble from cumulative_sharpe_ratio()
#' @param sr_shrinkage Which shrinkage level to plot (default: "80%")
#' @param use_ratio If TRUE, plot SR^2 ratio instead of SR (default: FALSE)
#' @param main_path Project root path (default: ".")
#' @param output_folder Output folder for figure (default: "figures")
#' @param fig_name Output filename (default: "cum_sr_plot.pdf")
#' @param width Figure width in inches (default: 12)
#' @param height Figure height in inches (default: 7)
#' @param units Units for dimensions (default: "in")
#' @param y_axis_text_size Y axis text size (default: 12)
#' @param x_axis_text_size X axis text size (default: 9)
#' @param y_label_text_size Y label text size (default: 16)
#' @param legend_text_size Legend text size (default: 12)
#' @param verbose Print progress messages (default: TRUE)
#' @return The ggplot object (invisibly)
#'
plot_cumulative_sr <- function(
    sharpe_tbl,
    sr_shrinkage        = "80%",
    use_ratio           = FALSE,
    # ---------- export controls ------------------------------------------
    main_path           = ".",
    output_folder       = "figures",
    fig_name            = "cum_sr_plot.pdf",
    width               = 12,
    height              = 7,
    units               = "in",
    # ---------- font sizes -----------------------------------------------
    y_axis_text_size    = 12,
    x_axis_text_size    = 9,
    y_label_text_size   = 16,
    legend_text_size    = 12,
    # ---------- misc ------------------------------------------------------
    verbose             = TRUE
) {

  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("ggplot2 package is required.")
  }
  if (!requireNamespace("ggtext", quietly = TRUE)) {
    stop("ggtext package is required.")
  }
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("dplyr package is required.")
  }

  # ------------------------------------------------------------------ #
  # 1.  filter & arrange
  # ------------------------------------------------------------------ #
  dat <- sharpe_tbl %>%
    dplyr::filter(shrinkage == sr_shrinkage) %>%
    dplyr::arrange(n_factors)

  if (nrow(dat) == 0) {
    warning("No rows for shrinkage = ", sr_shrinkage)
    return(invisible(NULL))
  }

  # ------------------------------------------------------------------ #
  # 2.  choose columns (SR or ratio)
  # ------------------------------------------------------------------ #
  prefix     <- if (use_ratio) "Ratio" else "SR"
  mean_col   <- paste0(prefix, "_mean")
  q08_col    <- paste0(prefix, "_q08")
  q92_col    <- paste0(prefix, "_q92")
  y_lab      <- if (use_ratio)
    expression(paste("Mean ", SR[f]^2 / SR[m]^2))
  else
    "Cumulative factor-implied SR"

  # ------------------------------------------------------------------ #
  # 3.  styling maps (unchanged)
  # ------------------------------------------------------------------ #
  col_map   <- c(nontraded = "royalblue4",
                 bond      = "royalblue1",
                 stock     = "tomato")
  shape_map <- c(nontraded = 17, bond = 15, stock = 16)
  lab_map   <- c(nontraded = "Nontraded Factors",
                 bond      = "Traded Bond Factors",
                 stock     = "Traded Equity Factors")

  dat <- dat %>%
    dplyr::mutate(block = dplyr::case_when(
      colour == "royalblue4" ~ "nontraded",
      colour == "royalblue1" ~ "bond",
      colour == "tomato"     ~ "stock",
      TRUE                   ~ "other"
    ))

  present_blocks <- intersect(names(col_map), unique(dat$block))
  col_map   <- col_map[present_blocks]
  shape_map <- shape_map[present_blocks]
  lab_map   <- lab_map[present_blocks]

  # ------------------------------------------------------------------ #
  # 4.  axis labels & iteration numbers
  # ------------------------------------------------------------------ #
  # Build per-label color vector for axis text (avoids ggtext HTML rendering
  # issues with ggsave/PDF device)
  label_colours <- dat$colour
  plain_labels  <- dat$factor_name

  iter_y <- min(dat[[q08_col]]) -
    0.05 * (max(dat[[q92_col]]) - min(dat[[q08_col]]))

  med_fac <- unique(dat$median_num)
  add_med <- length(med_fac) == 1 && !is.na(med_fac)

  # data for ribbon & paths
  rib_dat <- dat %>%
    dplyr::distinct(n_factors,
                    mean_val = .data[[mean_col]],
                    q08_val  = .data[[q08_col]],
                    q92_val  = .data[[q92_col]]) %>%
    dplyr::arrange(n_factors)

  # ------------------------------------------------------------------ #
  # 5.  build plot
  # ------------------------------------------------------------------ #
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = n_factors,
                                          y = .data[[mean_col]],
                                          colour = block, shape = block)) +

    # ribbon
    ggplot2::geom_ribbon(data = rib_dat,
                         ggplot2::aes(x = n_factors,
                                      ymin = q08_val, ymax = q92_val),
                         inherit.aes = FALSE,
                         fill  = "lightblue", colour = NA, alpha = 0.30) +

    # mean path
    ggplot2::geom_line(data = rib_dat,
                       ggplot2::aes(x = n_factors, y = mean_val),
                       colour = "#ADD8E6", linewidth = 1, inherit.aes = FALSE) +

    # dashed bounds
    ggplot2::geom_line(data = rib_dat,
                       ggplot2::aes(x = n_factors, y = q08_val),
                       colour = "#87CEEB", linewidth = 0.5, linetype = "dashed",
                       inherit.aes = FALSE) +
    ggplot2::geom_line(data = rib_dat,
                       ggplot2::aes(x = n_factors, y = q92_val),
                       colour = "#87CEEB", linewidth = 0.5, linetype = "dashed",
                       inherit.aes = FALSE) +

    # markers
    ggplot2::geom_point(size = 3) +

    ggplot2::scale_colour_manual(values = col_map,
                                 labels = lab_map, breaks = present_blocks) +
    ggplot2::scale_shape_manual(values = shape_map,
                                labels = lab_map, breaks = present_blocks) +

    ggplot2::scale_x_continuous(breaks = dat$n_factors, labels = plain_labels) +

    ggplot2::labs(x = NULL, y = y_lab, colour = NULL, shape = NULL) +

    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid   = ggplot2::element_blank(),
      panel.border = ggplot2::element_rect(colour = "black", fill = NA, linewidth = 0.7),
      axis.text.x  = ggplot2::element_text(
        angle = 45, hjust = 1, vjust = 1,
        size = x_axis_text_size,
        colour = label_colours),
      axis.text.y  = ggplot2::element_text(size = y_axis_text_size),
      axis.title.y = ggplot2::element_text(size = y_label_text_size),
      legend.text  = ggplot2::element_text(colour = "black",
                                           size = legend_text_size),
      legend.position      = c(0.97, 0.03),
      legend.justification = c(1, 0)
    ) +

    ggplot2::geom_text(ggplot2::aes(y = iter_y,
                                    label = ifelse(n_factors %% 5 == 0, n_factors, "")),
                       colour = "black", size = 3, vjust = 1, show.legend = FALSE) +

    { if (add_med)
      ggplot2::geom_vline(xintercept = med_fac,
                          linetype   = "dashed",
                          colour     = "red",
                          linewidth  = 0.6)
    else NULL }

  # ------------------------------------------------------------------ #
  # 6.  export
  # ------------------------------------------------------------------ #
  file_out <- file.path(main_path, output_folder, fig_name)
  dir.create(dirname(file_out), recursive = TRUE, showWarnings = FALSE)

  ggplot2::ggsave(file_out, plot = p,
                  width = width, height = height, units = units)

  if (verbose) {
    message("Cum. Sharpe Ratio figure exported -> ",
            normalizePath(file_out, winslash = "/", mustWork = FALSE))
  }

  # Return plot invisibly (NO print() to avoid Rplots.pdf)
  invisible(p)
}
