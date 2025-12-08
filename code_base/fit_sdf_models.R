# ============================================================
#  fit_sdf_models.R - SDF Time Series Analysis (Figures 10-12)
#  ------------------------------------------------------------
#  Fits ARIMA + GARCH models to SDF time series and generates:
#    - Figure 10: SDF time series plot (BMA)
#    - Figure 11: SDF volatility comparison (BMA vs CAPMB vs FF5)
#    - Figure 12: Predictability bar plots (1m and 12m horizons)
#
#  Also generates additional diagnostic plots when paper_only = FALSE.
# ============================================================

# Check required packages
req_pkgs <- c("forecast", "rugarch", "tibble", "dplyr", "lubridate",
              "ggplot2", "ggtext", "scales", "purrr", "tidyr",
              "sandwich", "car", "zoo", "glue", "proxyC")
missing  <- req_pkgs[!vapply(req_pkgs, requireNamespace,
                             FUN.VALUE = FALSE, quietly = TRUE)]
if (length(missing))
  stop("Please install packages: ", paste(missing, collapse = ", "))

#' Fit ARIMA + GARCH Models to SDF Time Series
#'
#' Fits ARIMA and GARCH(1,1) models to multiple SDF series and generates
#' time series plots, volatility plots, and predictability bar charts.
#'
#' @param results_path Path to results folder containing .Rdata files
#' @param return_type Return type prefix (default: "excess")
#' @param model_type Model type (default: "bond_stock_with_sp")
#' @param alpha.w Beta prior hyperparameter (default: 1)
#' @param beta.w Beta prior hyperparameter (default: 1)
#' @param kappa Factor tilt parameter (default: 0)
#' @param tag Tag suffix for .Rdata filename
#' @param shrinkage Which shrinkage level to use (1-4, default: 4 = 80%)
#' @param output_path Output directory for figures
#' @param paper_only If TRUE, only generate Figures 10, 11, 12 (default: TRUE)
#' @param adj_1m If FALSE (default), use OLS standard errors for 1-month predictability.
#'   If TRUE, use Newey-West with lag=15, adjust=FALSE, sandwich=FALSE.
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return List with fitted models, data, and p-values
#'
#' @examples
#' \dontrun{
#'   result <- fit_sdf_models(
#'     results_path = "output/unconditional",
#'     model_type = "bond_stock_with_sp",
#'     output_path = "output/paper/figures",
#'     paper_only = TRUE
#'   )
#' }
fit_sdf_models <- function(
    results_path  = "output/unconditional",
    return_type   = "excess",
    model_type    = "bond_stock_with_sp",
    alpha.w       = 1,
    beta.w        = 1,
    kappa         = 0,
    tag           = "baseline",
    shrinkage     = 4,
    output_path   = "output/paper/figures",
    paper_only    = TRUE,
    adj_1m        = FALSE,
    verbose       = TRUE
) {

  ##-----------------------------------------------------------------------##
  ## 1.  Locate and load workspace                                         ##
  ##-----------------------------------------------------------------------##
  ws_name <- sprintf("%s_%s_alpha.w=%g_beta.w=%g_kappa=%s_%s.Rdata",
                     return_type, model_type, alpha.w, beta.w, kappa, tag)
  ws_path <- file.path(results_path, model_type, ws_name)

  if (!file.exists(ws_path)) {
    stop("Workspace not found: ", ws_path)
  }

  if (verbose) message("Loading: ", ws_path)

  ws_env <- new.env(parent = emptyenv())
  load(ws_path, envir = ws_env)

  # Validate required objects
  stopifnot(
    exists("results", envir = ws_env),
    exists("IS_AP",   envir = ws_env),
    !is.null(ws_env$IS_AP$sdf_mat)
  )

  # Check for fac object (may have different structure)
  has_fac <- exists("fac", envir = ws_env) && !is.null(ws_env$fac$f_all_raw)

  ##-----------------------------------------------------------------------##
  ## 2.  Extract SDF data                                                  ##
  ##-----------------------------------------------------------------------##
  # BMA SDF from results
  sdf_vec <- as.numeric(ws_env$results[[shrinkage]]$bma_sdf)

  # Get dates from IS_AP$sdf_mat or IS_AP$dates
  if (!is.null(ws_env$IS_AP$dates)) {
    date_seq <- as.Date(ws_env$IS_AP$dates)
  } else if ("date" %in% colnames(ws_env$IS_AP$sdf_mat)) {
    date_seq <- as.Date(ws_env$IS_AP$sdf_mat$date)
  } else {
    # Fallback to generated dates
    date_seq <- seq(as.Date("1986-01-01"), by = "month",
                    length.out = length(sdf_vec)) |>
      lubridate::ceiling_date("month") - lubridate::days(1)
  }

  # Extract other SDF series from IS_AP$sdf_mat (exclude date column)
  sdf_mat_raw <- ws_env$IS_AP$sdf_mat
  if ("date" %in% colnames(sdf_mat_raw)) {
    other_mat <- as.matrix(sdf_mat_raw[, colnames(sdf_mat_raw) != "date", drop = FALSE])
  } else {
    other_mat <- as.matrix(sdf_mat_raw)
  }

  # Build non-traded-factor SDF if fac object exists
  if (has_fac) {
    Lambda <- colMeans(ws_env$results[[shrinkage]]$lambda_path)
    names(Lambda) <- c("CONST", ws_env$fac$all_factor_names)

    nt_idx <- which(names(Lambda)[-1] %in% ws_env$fac$nontraded_names) + 1L
    if (length(nt_idx) > 0) {
      Lambda_nt <- Lambda[c(1, nt_idx)]
      f_nt <- ws_env$fac$f_all_raw[, names(Lambda_nt)[-1], drop = FALSE]
      Lambda_f_nt <- Lambda_nt[-1] / proxyC::colSds(f_nt)
      sdf_nt <- as.vector(1 - f_nt %*% Lambda_f_nt)
      sdf_nt <- 1 + sdf_nt - mean(sdf_nt)
      other_mat <- cbind(other_mat, NT = sdf_nt)
    }
  }

  model_names <- colnames(other_mat)

  if (verbose) {
    message("  SDF series: BMA + ", length(model_names), " other models")
    message("  Time period: ", min(date_seq), " to ", max(date_seq))
  }

  ##-----------------------------------------------------------------------##
  ## 3.  Helper for ARIMA + GARCH fit                                      ##
  ##-----------------------------------------------------------------------##
  fit_one <- function(x_ts) {
    ## --- ARIMA ---------------------------------------------------------- ##
    arima_fit <- forecast::auto.arima(
      x_ts, ic = "bic", stepwise = FALSE, allowmean = TRUE,
      parallel = FALSE, max.d = 0)
    mu_vec  <- as.numeric(fitted(arima_fit))
    resids  <- residuals(arima_fit)

    ## --- sGARCH(1,1) using ARMA order from ARIMA ------------------------ ##
    arma_order <- arima_fit$arma[c(1, 2)]
    spec <- rugarch::ugarchspec(
      variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
      mean.model     = list(armaOrder = arma_order, include.mean = TRUE),
      distribution.model = "norm")
    garch_fit <- rugarch::ugarchfit(spec, x_ts, solver = "hybrid")
    sigma_vec <- garch_fit@fit$sigma

    ## robust coefficient matrix
    rob_mat <- garch_fit@fit$robust.matcoef[, 1:2, drop = FALSE]
    colnames(rob_mat) <- c("estimate", "robust_se")

    list(
      arima        = arima_fit,
      mu           = mu_vec,
      resid        = resids,
      sigma        = sigma_vec,
      garch_params = rob_mat
    )
  }

  ##-----------------------------------------------------------------------##
  ## 4.  Fit models                                                        ##
  ##-----------------------------------------------------------------------##
  if (verbose) message("Fitting ARIMA + GARCH models...")

  # Determine start year from data
  start_year <- as.numeric(format(min(date_seq), "%Y"))
  start_month <- as.numeric(format(min(date_seq), "%m"))

  # BMA fit
  ts_bma  <- ts(sdf_vec, start = c(start_year, start_month), frequency = 12)
  fit_bma <- fit_one(ts_bma)

  # Determine which models to fit based on paper_only
  if (paper_only) {
    # Only fit models needed for Figures 10, 11, 12
    models_to_fit <- intersect(c("CAPMB", "FF5"), model_names)
  } else {
    models_to_fit <- model_names
  }

  fits_other <- list()
  for (nm in models_to_fit) {
    if (verbose) message("  Fitting: ", nm)
    fits_other[[nm]] <- fit_one(
      ts(other_mat[, nm], start = c(start_year, start_month), frequency = 12)
    )
  }

  ##-----------------------------------------------------------------------##
  ## 5.  Create output directory                                           ##
  ##-----------------------------------------------------------------------##
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
  }

  ##-----------------------------------------------------------------------##
  ## 6.  Recession shading data                                            ##
  ##-----------------------------------------------------------------------##
  recess <- tibble::tribble(
    ~start,       ~end,
    "1990-07-01", "1991-03-01",
    "2001-03-01", "2001-11-01",
    "2007-12-01", "2009-06-01",
    "2020-02-01", "2020-04-01"
  ) |> dplyr::mutate(start = as.Date(start), end = as.Date(end))

  # Plot dimensions
  ts_width  <- 12
  ts_height <- 7
  size_y <- 12
  size_x <- 12
  size_l <- 11

  ##-----------------------------------------------------------------------##
  ## 7.  Figure 10: SDF Time Series Plot (BMA only)                        ##
  ##-----------------------------------------------------------------------##
  if (verbose) message("Generating Figure 10: SDF Time Series (BMA)...")

  plot_ts_bma <- function() {
    df_long <- tibble::tibble(
      date = date_seq,
      SDF  = sdf_vec,
      Mean = fit_bma$mu
    ) |> tidyr::pivot_longer(-date, names_to = "type", values_to = "value")

    ymin <- min(df_long$value, na.rm = TRUE) - 0.35

    p <- ggplot2::ggplot() +
      ggplot2::geom_rect(
        data = recess,
        ggplot2::aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
        fill = "lightblue", alpha = 0.4, colour = NA, show.legend = FALSE
      ) +
      ggplot2::geom_line(
        data = df_long[df_long$type == "SDF", ],
        ggplot2::aes(date, value, colour = "line_SDF"),
        linewidth = 0.8, show.legend = TRUE
      ) +
      ggplot2::geom_line(
        data = df_long[df_long$type == "Mean", ],
        ggplot2::aes(date, value, colour = "line_Mean"),
        linewidth = 1.2, show.legend = TRUE
      ) +
      ggplot2::geom_hline(yintercept = 1, colour = "darkgrey") +
      ggplot2::scale_colour_manual(
        values = c(line_SDF = "black", line_Mean = "tomato"),
        labels = c(line_SDF = "BMA-SDF", line_Mean = "BMA-SDF conditional mean"),
        breaks = c("line_SDF", "line_Mean"),
        guide = ggplot2::guide_legend(override.aes = list(linewidth = 1))
      ) +
      ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
      ggplot2::labs(x = "Date", y = "SDF", colour = NULL) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.text.y  = ggplot2::element_text(size = size_y),
        axis.text.x  = ggplot2::element_text(size = size_x),
        legend.text  = ggplot2::element_text(size = size_l),
        legend.title = ggplot2::element_blank(),
        legend.position = c(0.01, 0.03),
        legend.justification = c(0, 0),
        legend.key.width = grid::unit(1.5, "cm")
      )

    # NBER recession legend
    sq_x <- max(df_long$date) - 1700
    sq_y <- ymin + 0.20

    p <- p +
      ggplot2::annotate("point", x = sq_x, y = sq_y,
                        shape = 15, size = 5, colour = "lightblue") +
      ggplot2::annotate("text", x = sq_x + 200, y = sq_y,
                        hjust = 0, size = 4.2, label = "NBER recessions")

    p
  }

  p_fig10 <- plot_ts_bma()
  ggplot2::ggsave(
    file.path(output_path, "SDF_Time_Series_BMA.pdf"),
    p_fig10, width = ts_width, height = ts_height, units = "in"
  )
  if (verbose) message("  Saved: SDF_Time_Series_BMA.pdf")

  ##-----------------------------------------------------------------------##
  ## 8.  Figure 11: SDF Volatility Comparison (BMA / CAPMB / FF5)          ##
  ##-----------------------------------------------------------------------##
  if (verbose) message("Generating Figure 11: SDF Volatility Comparison...")

  # Annualized volatility
  vol_list_ann <- list(BMA = fit_bma$sigma * sqrt(12))
  for (nm in names(fits_other)) {
    vol_list_ann[[nm]] <- fits_other[[nm]]$sigma * sqrt(12)
  }

  # Check if required models exist
  models_cmp <- intersect(c("BMA", "CAPMB", "FF5"), names(vol_list_ann))

  if (length(models_cmp) >= 2) {
    df_cmp <- purrr::imap_dfr(models_cmp, function(nm, idx) {
      tibble::tibble(date = date_seq, vol = vol_list_ann[[nm]], model = nm)
    })

    col_map <- c(BMA = "black", CAPMB = "#5BC0DE", FF5 = "#B36AE2")
    lt_map  <- c(BMA = "solid", CAPMB = "dashed", FF5 = "dotdash")

    # Event dates
    specific_dates_raw <- as.Date(paste0(
      c("1987-11","1997-12","2000-04","2003-04","2008-10",
        "2008-04","2015-07","2020-04","2022-03","1993-03"), "-01"
    ))
    specific_dates <- lubridate::ceiling_date(specific_dates_raw, "month") -
      lubridate::days(1)
    specific_events <- c("Black Monday","Asia crisis","Dotcom",
                         "Iraq inv.","Lehman","Bear Stearns",
                         "Greece def.","Covid","Ukraine","WTC")

    p_fig11 <- ggplot2::ggplot(df_cmp,
                               ggplot2::aes(date, vol, colour = model, linetype = model)) +
      ggplot2::geom_rect(
        data = recess,
        ggplot2::aes(xmin = start, xmax = end, ymin = -Inf, ymax = Inf),
        inherit.aes = FALSE, fill = "lightblue", alpha = 0.4, colour = NA
      ) +
      ggplot2::geom_line(linewidth = 1.1) +
      ggplot2::scale_colour_manual(values = col_map) +
      ggplot2::scale_linetype_manual(values = lt_map) +
      ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
      ggplot2::labs(x = "", y = "SDF conditional volatility", colour = NULL, linetype = NULL) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.text.y  = ggplot2::element_text(size = size_y),
        axis.text.x  = ggplot2::element_text(size = size_x),
        legend.text  = ggplot2::element_text(size = 12),
        legend.position = c(0.02, 0.98),
        legend.justification = c(0, 1),
        legend.direction = "vertical",
        legend.key.width = grid::unit(1.4, "cm")
      )

    # Add event markers on BMA line
    for (i in seq_along(specific_dates)) {
      d  <- specific_dates[i]
      lab <- specific_events[i]
      yv  <- df_cmp$vol[df_cmp$model == "BMA" & df_cmp$date == d]
      if (length(yv) == 1) {
        p_fig11 <- p_fig11 +
          ggplot2::annotate("point", x = d, y = yv,
                            shape = 21, size = 3, stroke = 1,
                            colour = "red", fill = NA) +
          ggplot2::annotate("text", x = d, y = yv + 0.15,
                            label = lab, colour = "red",
                            size = 5, hjust = 0.5, vjust = -0.2)
      }
    }

    # NBER legend
    y_max <- max(df_cmp$vol, na.rm = TRUE)
    sq_x  <- max(df_cmp$date) - 1700
    sq_y  <- y_max - 0.05

    p_fig11 <- p_fig11 +
      ggplot2::annotate("point", x = sq_x, y = sq_y,
                        shape = 15, size = 5, colour = "lightblue") +
      ggplot2::annotate("text", x = sq_x + 200, y = sq_y,
                        hjust = 0, size = 4.2, label = "NBER recessions")

    ggplot2::ggsave(
      file.path(output_path, "SDF_Volatility_BMA_CAPMB_FF5.pdf"),
      p_fig11, width = ts_width, height = ts_height, units = "in"
    )
    if (verbose) message("  Saved: SDF_Volatility_BMA_CAPMB_FF5.pdf")
  } else {
    warning("Not enough models for Figure 11 (need BMA, CAPMB, FF5)")
  }

  ##-----------------------------------------------------------------------##
  ## 9.  Figure 12: Predictability Bar Plots                               ##
  ##-----------------------------------------------------------------------##
  pred_pvals_1m  <- list()
  pred_pvals_12m <- list()

  # Check if we have the factor data needed for predictability
  if (has_fac && !is.null(ws_env$fac$f_all_raw) && ncol(ws_env$fac$f_all_raw) >= 54) {

    if (verbose) message("Generating Figure 12: Predictability Bar Plots...")

    # Get bond/stock factor columns (columns 15-54)
    bond_stock <- colnames(ws_env$fac$f_all_raw[, 15:54])

    ##--- Figure 12 Panel A: 1-month predictability ---##
    build_predict_plot_1m <- function(label, mu_vec, vol_vec) {
      x1 <- (vol_vec ^ 2) * mu_vec
      x2 <- vol_vec ^ 2

      r2   <- numeric(length(bond_stock))
      f_pv <- numeric(length(bond_stock))

      for (j in seq_along(bond_stock)) {
        y   <- log1p(ws_env$fac$f_all_raw[, bond_stock[j]])
        fit <- lm(y ~ x1 + x2)

        # OLS R² (unchanged by SE choice)
        r2[j] <- summary(fit)$r.squared

        if (adj_1m) {
          # Newey-West (Bartlett kernel) robust F-test, 15 lags
          nw_vcov <- sandwich::NeweyWest(fit, lag = 15, prewhite = FALSE,
                                         adjust = FALSE, sandwich = FALSE)

          keep_coef <- intersect(c("x1", "x2"), names(coef(fit))[!is.na(coef(fit))])

          if (length(keep_coef) == 0) {
            f_pv[j] <- NA_real_
          } else {
            lh <- car::linearHypothesis(fit, paste0(keep_coef, " = 0"),
                                        vcov. = nw_vcov, test = "F", singular.ok = TRUE)
            f_pv[j] <- lh$`Pr(>F)`[2]
          }
        } else {
          # Standard OLS F-test
          fit_sum <- summary(fit)
          f_pv[j] <- 1 - pf(fit_sum$fstatistic[1], fit_sum$fstatistic[2], fit_sum$fstatistic[3])
        }
      }

      sig_flag <- cut(f_pv, breaks = c(-Inf, .05, .1, Inf),
                      labels = c("p < .05", "p < .10", "p > .10"), include.lowest = TRUE)

      factor_type <- ifelse(bond_stock %in% ws_env$fac$bond_names,
                            "Bond factors", "Equity factors")

      df_bar <- tibble::tibble(
        factor = bond_stock, R2 = r2, type = factor_type, signif = sig_flag
      ) |>
        dplyr::arrange(dplyr::desc(R2)) |>
        dplyr::mutate(factor = factor(factor, levels = factor))

      pct05 <- round(100 * mean(f_pv < .05, na.rm = TRUE))
      pct10 <- round(100 * mean(f_pv < .10, na.rm = TRUE))
      pctHi <- 100 - pct10

      alpha_labels <- c(
        `p < .05` = glue::glue("p < .05 ({pct05}%)"),
        `p < .10` = glue::glue("p < .10 ({pct10}%)"),
        `p > .10` = glue::glue("p > .10 ({pctHi}%)")
      )

      col_map   <- c(`Bond factors` = "royalblue1", `Equity factors` = "tomato")
      alpha_map <- c(`p < .05` = 1, `p < .10` = 0.6, `p > .10` = 0.3)

      med_val <- median(r2)
      med_lab <- sprintf("Median R\u00b2 (%.2f%%)", round(100 * med_val, 2))

      p_bar <- ggplot2::ggplot(df_bar,
                               ggplot2::aes(factor, R2, fill = type, alpha = signif)) +
        ggplot2::geom_col(colour = NA) +
        ggplot2::geom_hline(
          ggplot2::aes(yintercept = med_val, linetype = "Median"),
          colour = "black", linewidth = 0.7, show.legend = TRUE
        ) +
        ggplot2::scale_fill_manual(
          values = col_map, name = NULL,
          guide = ggplot2::guide_legend(order = 1, override.aes = list(alpha = 1, linetype = "blank"))
        ) +
        ggplot2::scale_alpha_manual(
          values = alpha_map, labels = alpha_labels, name = NULL,
          guide = ggplot2::guide_legend(order = 2, override.aes = list(fill = "darkgrey", colour = NA, linetype = "blank"))
        ) +
        ggplot2::scale_linetype_manual(
          values = setNames("dashed", "Median"),
          labels = setNames(med_lab, "Median"),
          name = NULL,
          guide = ggplot2::guide_legend(order = 3, override.aes = list(fill = NA, alpha = 1, colour = "black"))
        ) +
        ggplot2::scale_x_discrete(limits = levels(df_bar$factor)) +
        ggplot2::labs(x = NULL, y = "R\u00b2") +
        ggplot2::theme_bw() +
        ggplot2::theme(
          panel.grid.major.x = ggplot2::element_blank(),
          axis.text.x = ggplot2::element_text(
            angle = 90, vjust = 0.5, size = size_x,
            colour = ifelse(df_bar$type == "Bond factors", "royalblue1", "tomato")
          ),
          axis.text.y  = ggplot2::element_text(size = size_y),
          axis.title.y = ggplot2::element_text(size = size_y + 2),
          legend.position = c(0.97, 0.97),
          legend.justification = c(1, 1),
          legend.direction = "vertical",
          legend.text = ggplot2::element_text(size = 10),
          legend.box.background = ggplot2::element_blank()
        )

      ggplot2::ggsave(
        file.path(output_path, paste0("Predictability1m_", label, ".pdf")),
        p_bar, width = ts_width, height = ts_height, units = "in"
      )

      names(f_pv) <- bond_stock
      f_pv
    }

    pred_pvals_1m$BMA <- build_predict_plot_1m("BMA", fit_bma$mu, fit_bma$sigma)
    if (verbose) message("  Saved: Predictability1m_BMA.pdf")

    ##--- Figure 12 Panel B: 12-month predictability ---##
    build_predict_plot_12m <- function(label, mu_vec, vol_vec, months = 12) {
      roll_fun <- function(x) {
        zoo::rollapply(x, width = months, by = 1, align = "right",
                       FUN = sum, fill = NA, na.rm = FALSE)
      }

      r2_long   <- numeric(length(bond_stock))
      f_pv_long <- numeric(length(bond_stock))

      x1_full <- (vol_vec ^ 2) * mu_vec
      x2_full <- vol_vec ^ 2

      for (j in seq_along(bond_stock)) {
        y_full <- roll_fun(log1p(ws_env$fac$f_all_raw[, bond_stock[j]]))
        y_full <- y_full[!is.na(y_full)]
        obs    <- length(y_full)

        y  <- y_full
        x1 <- x1_full[1:obs]
        x2 <- x2_full[1:obs]

        fit <- lm(y ~ x1 + x2)

        # Newey-West vcov
        nw_vcov <- sandwich::NeweyWest(fit, lag = 15, prewhite = FALSE, adjust = TRUE, sandwich = TRUE)

        keep_coef <- intersect(c("x1", "x2"), names(coef(fit))[!is.na(coef(fit))])

        if (length(keep_coef) == 0) {
          p_val <- NA_real_
        } else {
          lh <- car::linearHypothesis(fit, paste0(keep_coef, " = 0"),
                                      vcov. = nw_vcov, test = "F", singular.ok = TRUE)
          p_val <- lh$`Pr(>F)`[2]
        }

        r2_long[j]   <- summary(fit)$r.squared
        f_pv_long[j] <- p_val
      }

      sig_flag <- cut(f_pv_long, breaks = c(-Inf, .05, .1, Inf),
                      labels = c("p < .05", "p < .10", "p > .10"), include.lowest = TRUE)

      factor_type <- ifelse(bond_stock %in% ws_env$fac$bond_names,
                            "Bond factors", "Equity factors")

      df_bar <- tibble::tibble(
        factor = bond_stock, R2 = r2_long, type = factor_type, signif = sig_flag
      ) |>
        dplyr::arrange(dplyr::desc(R2)) |>
        dplyr::mutate(factor = factor(factor, levels = factor))

      pct05 <- round(100 * mean(f_pv_long < .05, na.rm = TRUE))
      pct10 <- round(100 * mean(f_pv_long < .10, na.rm = TRUE))
      pctHi <- 100 - pct10

      alpha_labels <- c(
        `p < .05` = glue::glue("p < .05 ({pct05}%)"),
        `p < .10` = glue::glue("p < .10 ({pct10}%)"),
        `p > .10` = glue::glue("p > .10 ({pctHi}%)")
      )

      col_map   <- c(`Bond factors` = "royalblue1", `Equity factors` = "tomato")
      alpha_map <- c(`p < .05` = 1, `p < .10` = 0.6, `p > .10` = 0.3)

      med_val <- median(r2_long, na.rm = TRUE)
      med_lab <- sprintf("Median R\u00b2 (%.2f%%)", round(100 * med_val, 2))

      p_bar <- ggplot2::ggplot(df_bar,
                               ggplot2::aes(factor, R2, fill = type, alpha = signif)) +
        ggplot2::geom_col(colour = NA) +
        ggplot2::geom_hline(
          ggplot2::aes(yintercept = med_val, linetype = "Median"),
          colour = "black", linewidth = 0.7
        ) +
        ggplot2::scale_fill_manual(
          values = col_map, name = NULL,
          guide = ggplot2::guide_legend(order = 1, override.aes = list(alpha = 1, linetype = "blank"))
        ) +
        ggplot2::scale_alpha_manual(
          values = alpha_map, labels = alpha_labels, name = NULL,
          guide = ggplot2::guide_legend(order = 2, override.aes = list(fill = "darkgrey", colour = NA, linetype = "blank"))
        ) +
        ggplot2::scale_linetype_manual(
          values = setNames("dashed", "Median"),
          labels = setNames(med_lab, "Median"),
          name = NULL,
          guide = ggplot2::guide_legend(order = 3, override.aes = list(fill = NA, alpha = 1, colour = "black"))
        ) +
        ggplot2::scale_x_discrete(limits = levels(df_bar$factor)) +
        ggplot2::labs(x = NULL, y = "R\u00b2 (12-month return)") +
        ggplot2::theme_bw() +
        ggplot2::theme(
          panel.grid.major.x = ggplot2::element_blank(),
          axis.text.x = ggplot2::element_text(
            angle = 90, vjust = 0.5, size = size_x,
            colour = ifelse(df_bar$type == "Bond factors", "royalblue1", "tomato")
          ),
          axis.text.y  = ggplot2::element_text(size = size_y),
          axis.title.y = ggplot2::element_text(size = size_y + 2),
          legend.position = c(0.97, 0.97),
          legend.justification = c(1, 1),
          legend.direction = "vertical",
          legend.text = ggplot2::element_text(size = 10),
          legend.box.background = ggplot2::element_blank()
        )

      ggplot2::ggsave(
        file.path(output_path, paste0("Predictability12m_", label, ".pdf")),
        p_bar, width = ts_width, height = ts_height, units = "in"
      )

      names(f_pv_long) <- bond_stock
      f_pv_long
    }

    pred_pvals_12m$BMA <- build_predict_plot_12m("BMA", fit_bma$mu, fit_bma$sigma)
    if (verbose) message("  Saved: Predictability12m_BMA.pdf")

  } else {
    if (verbose) message("  Skipping Figure 12: factor data not available")
  }

  ##-----------------------------------------------------------------------##
  ## 10. Return results                                                    ##
  ##-----------------------------------------------------------------------##
  if (verbose) message("Done.")

  make_df <- function(lst) {
    tibble::tibble(date = date_seq) |>
      dplyr::bind_cols(tibble::as_tibble(lst))
  }

  mean_list <- c(BMA = list(fit_bma$mu), purrr::map(fits_other, "mu"))
  sigma_list <- c(BMA = list(fit_bma$sigma), purrr::map(fits_other, "sigma"))
  param_list <- c(BMA = list(fit_bma$garch_params), purrr::map(fits_other, "garch_params"))

  invisible(list(
    fits = list(
      arima = c(BMA = list(fit_bma$arima), purrr::map(fits_other, "arima")),
      garch = list(sigma = sigma_list, params = param_list)
    ),
    data = list(
      mean_forecast = make_df(mean_list),
      volatility    = make_df(sigma_list)
    ),
    p_values = list(
      predictability_pvalues_1m  = pred_pvals_1m,
      predictability_pvalues_12m = pred_pvals_12m
    ),
    figures_saved = c(
      "SDF_Time_Series_BMA.pdf",
      "SDF_Volatility_BMA_CAPMB_FF5.pdf",
      "Predictability1m_BMA.pdf",
      "Predictability12m_BMA.pdf"
    )
  ))
}
