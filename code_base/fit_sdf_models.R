req_pkgs <- c("forecast", "rugarch", "tibble", "dplyr", "lubridate",
              "readr", "slider", "ggplot2","ggtext", "scales", "purrr", "tidyr")
missing  <- req_pkgs[!vapply(req_pkgs, requireNamespace,
                             FUN.VALUE = FALSE, quietly = TRUE)]
if (length(missing))
  stop("Please install packages: ", paste(missing, collapse = ", "))

fit_sdf_models <- function(
    main_path     = "/Users/ASUS/Dropbox/DJM_Bayesian_RR",
    data_folder   = "paper.data.rr",
    output_folder = "output",
    return_type   = "excess",
    model_type    = "bond_stock_with_sp",
    kappa         = 0,
    alpha.w       = 1,
    beta.w        = 1,
    tag           = "baseline",
    shrinkage     = 4,
    width         = 3.25,      # ACF plot width  (in)
    height        = 3.25,      # ACF plot height (in)
    ann_size      = 4) {       # annotation text size
  
  ##-----------------------------------------------------------------------##
  ## 1.  Locate workspace                                                  ##
  ##-----------------------------------------------------------------------##
  ws_name <- sprintf("%s_%s_alpha.w=%g_beta.w=%g_kappa=%s_%s.Rdata",
                     return_type, model_type, alpha.w, beta.w, kappa, tag)
  ws_path <- file.path(main_path, output_folder, ws_name)
  if (!file.exists(ws_path)) stop("Workspace not found: ", ws_path)
  
  ws_env <- new.env(parent = emptyenv())
  load(ws_path, envir = ws_env)
  stopifnot(
    exists("results", envir = ws_env),
    exists("fac",     envir = ws_env),
    exists("IS_AP",   envir = ws_env),
    !is.null(ws_env$fac$f_all_raw),
    !is.null(ws_env$IS_AP$sdf_mat)
  )
  
  ##-----------------------------------------------------------------------##
  ## 2.  Data                                                               ##
  ##-----------------------------------------------------------------------##
  sdf_vec <- as.numeric(ws_env$results[[shrinkage]]$bma_sdf)
  
  # ----- build non-traded-factor SDF (sdf_nt) ---------------------------- #
  Lambda <- colMeans(ws_env$results[[shrinkage]]$lambda_path)
  names(Lambda) <- c("CONST", (ws_env$fac$all_factor_names))
  
  nt_idx <- which(names(Lambda)[-1] %in% ws_env$fac$nontraded_names) + 1L
  Lambda_nt <- Lambda[c(1, nt_idx)]
  
  f_nt <- ws_env$fac$f_all_raw[, names(Lambda_nt)[-1], drop = FALSE]
  Lambda_f_nt <- Lambda_nt[-1] / proxyC::colSds(f_nt)
  
  sdf_nt <- as.vector(1 - f_nt %*% Lambda_f_nt)
  sdf_nt <- 1 + sdf_nt - mean(sdf_nt)
  
  # ----- combine all SDF series ----------------------------------------- #
  other_mat   <- cbind(ws_env$IS_AP$sdf_mat, NT = sdf_nt)   # add NT column
  model_names <- colnames(other_mat)
  
  date_seq <- seq(as.Date("1986-01-01"), by = "month",
                  length.out = length(sdf_vec)) |>
    lubridate::ceiling_date("month") - lubridate::days(1)
  
  
  ##-----------------------------------------------------------------------##
  ## 3.  Helper for ARIMA + GARCH fit                                       ##
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
    sigma_vec <- garch_fit@fit$sigma                 # conditional σ_t
    
    ## robust coefficient matrix: columns 1 = est, 2 = robust s.e.
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
  
  ## ---------- BMA ------------------------------------------------------- ##
  ts_bma  <- ts(sdf_vec, start = c(1986, 1), frequency = 12)
  fit_bma <- fit_one(ts_bma)
  
  ## ---------- Other models --------------------------------------------- ##
  fits_other <- purrr::map(model_names, \(nm)
                           fit_one(ts(other_mat[, nm], start = c(1986, 1), frequency = 12)))
  names(fits_other) <- model_names
  
  ##-----------------------------------------------------------------------##
  ## 4.  Directories                                                        ##
  ##-----------------------------------------------------------------------##
  fig_dir <- file.path(main_path, "figures", "time_series_fit")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  
  ##-----------------------------------------------------------------------##
  ## 5.  ACF plots (as previously defined)                                  ##
  ##-----------------------------------------------------------------------##
  # ... (identical ACF generating code from previous version) ...
  # keep the entire gen_acf_plots() definition unchanged
  
  gen_acf_plots <- function(series, fit_obj, label, is_bma = FALSE) {
    # -- identical to previous reply, omitted here for brevity --
    # (no calls to map/walk/tidyr inside this helper)
    # produce ACF_SDF_<label>.pdf and ACF_SqErr_<label>.pdf
  }
  
  ## generate ACFs
  gen_acf_plots(sdf_vec, fit_bma, "BMA", TRUE)
  purrr::walk(model_names,
              \(nm) gen_acf_plots(other_mat[, nm], fits_other[[nm]], nm, FALSE))
  
  ##-----------------------------------------------------------------------##
  ## 6.  Time-series plots (SDF & conditional mean)                         ##
  ##-----------------------------------------------------------------------##
  recess <- tibble::tribble(
    ~start,       ~end,
    "1990-07-01", "1991-03-01",
    "2001-03-01", "2001-11-01",
    "2007-12-01", "2009-06-01",
    "2020-02-01", "2020-04-01") |>
    dplyr::mutate(start = as.Date(start), end = as.Date(end))
  
  ts_width  <- 12
  ts_height <- 7
  size_y <- 12
  size_x <- 12
  size_l <- 11
  
  ##-----------------------------------------------------------------------##
  ## 6.  Time-series plots (SDF & conditional mean)                         ##
  ##-----------------------------------------------------------------------##
  recess <- tibble::tribble(
    ~start,       ~end,
    "1990-07-01", "1991-03-01",
    "2001-03-01", "2001-11-01",
    "2007-12-01", "2009-06-01",
    "2020-02-01", "2020-04-01") |>
    dplyr::mutate(start = as.Date(start), end = as.Date(end))
  
  plot_ts <- function(series, mu, label) {
    ## ------------------------------------------------------------------ ##
    ##  build long dataframe                                              ##
    ## ------------------------------------------------------------------ ##
    df_long <- tibble::tibble(date = date_seq,
                              SDF  = series,
                              Mean = mu) |>
      tidyr::pivot_longer(-date, names_to = "type", values_to = "value")
    
    ymin <- min(df_long$value, na.rm = TRUE) - 0.35   # room for legends
    
    ## ------------------------------------------------------------------ ##
    ##  base plot                                                         ##
    ## ------------------------------------------------------------------ ##
    p <- ggplot2::ggplot() +
      ## recession shading (no legend key)
      ggplot2::geom_rect(data = recess,
                         ggplot2::aes(xmin = start, xmax = end,
                                      ymin = -Inf, ymax = Inf),
                         fill = "lightblue", alpha = 0.4, colour = NA,
                         show.legend = FALSE) +
      ## SDF line (draw first)
      ggplot2::geom_line(data = df_long[df_long$type == "SDF", ],
                         ggplot2::aes(date, value, colour = "line_SDF"),
                         linewidth = 0.8, show.legend = TRUE) +
      ## conditional mean line (draw second so it sits on top)
      ggplot2::geom_line(data = df_long[df_long$type == "Mean", ],
                         ggplot2::aes(date, value, colour = "line_Mean"),
                         linewidth = 1.2, show.legend = TRUE) +
      ggplot2::geom_hline(yintercept = 1, colour = "darkgrey") +
      
      ggplot2::scale_colour_manual(
        values = c(line_SDF = "black", line_Mean = "tomato"),
        labels = c(line_SDF  = paste0(label, "-SDF"),
                   line_Mean = paste0(label, "-SDF conditional mean")),
        breaks = c("line_SDF", "line_Mean"),
        guide  = ggplot2::guide_legend(override.aes = list(linewidth = 1))
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
        legend.position = c(0.01, 0.03),          # bottom-left inside plot
        legend.justification = c(0, 0),
        legend.key.width = grid::unit(1.5, "cm")
      )
    
    ## ------------------------------------------------------------------ ##
    ##  add manual square legend for recessions (bottom-right)            ##
    ## ------------------------------------------------------------------ ##
    sq_x <- max(df_long$date) - 1700         # shift a good distance left
    sq_y <- ymin + 0.20                      # vertical anchor
    
    p <- p +
      ggplot2::annotate("point",
                        x = sq_x, y = sq_y,
                        shape = 15, size = 5,                # slightly larger square
                        colour = "lightblue", fill = "lightblue") +
      ggplot2::annotate("text",
                        x = sq_x + 200, y = sq_y,
                        hjust = 0, size = 4.2,               # larger text
                        label = "NBER recessions")
    
    ## ------------------------------------------------------------------ ##
    ##  save                                                              ##
    ## ------------------------------------------------------------------ ##
    ggplot2::ggsave(file.path(fig_dir,
                              paste0("SDF_Time_Series_", label, ".pdf")),
                    p, width = ts_width, height = ts_height, units = "in")
  }
  
  ## Generate PDFs
  plot_ts(sdf_vec, fit_bma$mu, "BMA")
  purrr::walk(model_names,
              \(nm) plot_ts(other_mat[, nm], fits_other[[nm]]$mu, nm))
  
  
  
  plot_ts(sdf_vec, fit_bma$mu, "BMA")
  purrr::walk(model_names,
              \(nm) plot_ts(other_mat[, nm], fits_other[[nm]]$mu, nm))
  
  ##----------------------------------------------------------------------- ##
  ## 7.  Time-series plots of annualised SDF volatility                     ##
  ##----------------------------------------------------------------------- ##
  
  vol_list_ann <- c(
    BMA = list(fit_bma$sigma * sqrt(12)),
    purrr::map(fits_other, \(obj) obj$sigma * sqrt(12))
  )
  
  # -------- plotting helper  ---------------------------------------------
  vol_width  <- 12
  vol_height <- 7
  
  plot_vol <- function(vol_vec, label) {
    df <- tibble::tibble(date = date_seq, Vol = vol_vec)
    ymin <- min(df$Vol, na.rm = TRUE) - 0.3
    
    p <- ggplot2::ggplot() +
      ggplot2::geom_rect(data = recess,
                         ggplot2::aes(xmin = start, xmax = end,
                                      ymin = -Inf, ymax = Inf),
                         fill = "lightblue", alpha = 0.4, colour = NA) +
      ggplot2::geom_line(data = df,
                         ggplot2::aes(date, Vol, colour = "vol_line"),
                         linewidth = 1.1) +
      ggplot2::scale_colour_manual(
        values = c(vol_line = "black"),
        labels = c(vol_line = paste0(label, "-SDF volatility")),
        guide  = ggplot2::guide_legend(override.aes = list(linewidth = 2))
      ) +
      ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
      ggplot2::labs(x = "", y = "Annualised volatility", colour = NULL) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.text.y  = ggplot2::element_text(size = size_y),
        axis.text.x  = ggplot2::element_text(size = size_x),
        legend.text  = ggplot2::element_text(size = size_l),
        legend.title = ggplot2::element_blank(),
        legend.position = c(0.02, 0.08),
        legend.justification = c(0, 0),
        legend.key.width = grid::unit(1.5, "cm")
      ) 
    ## ------------------------------------------------------------------ ##
    ##  add manual square legend for recessions (bottom-right)            ##
    ## ------------------------------------------------------------------ ##
    sq_x <- max(df$date) - 1700         # shift a good distance left
    sq_y <- ymin + 0.20                      # vertical anchor
    
    p <- p +
      ggplot2::annotate("point",
                        x = sq_x, y = sq_y,
                        shape = 15, size = 5,                # slightly larger square
                        colour = "lightblue", fill = "lightblue") +
      ggplot2::annotate("text",
                        x = sq_x + 200, y = sq_y,
                        hjust = 0, size = 4.2,               # larger text
                        label = "NBER recessions")
    
    
    ggplot2::ggsave(file.path(fig_dir,
                              paste0("SDF_Volatility_", label, ".pdf")),
                    p, width = vol_width, height = vol_height, units = "in")
  }
  
  # -------- individual volatility PDFs -----------------------------------
  plot_vol(vol_list_ann$BMA, "BMA")
  purrr::iwalk(fits_other, \(obj, nm)
               plot_vol(vol_list_ann[[nm]], nm))
  
  # ---------- comparison plot (BMA / CAPMB / FF5) ------------------------
  models_cmp <- c("BMA", "CAPMB", "FF5")
  df_cmp <- purrr::imap_dfr(models_cmp, \(nm, idx)
                            tibble::tibble(date = date_seq,
                                           vol  = vol_list_ann[[nm]],
                                           model = nm))
  
  # colour & linetype maps
  col_map <- c(BMA = "black",
               CAPMB = "#5BC0DE",      # light blue
               FF5   = "#B36AE2")      # light purple
  lt_map  <- c(BMA = "solid",
               CAPMB = "dashed",
               FF5   = "dotdash")
  
  # event dates: convert to month-end to match date_seq
  # forecast t+1 at t (added month to specicif dates)
  specific_dates_raw <- as.Date(paste0(
    c("1987-11","1997-12","2000-04","2003-04","2008-10",
      "2008-04","2015-07","2020-04","2022-03","1993-03"), "-01"))
  specific_dates <- lubridate::ceiling_date(specific_dates_raw, "month") -
    lubridate::days(1)
  specific_events <- c("Black Monday","Asia crisis","Dotcom",
                       "Iraq inv.","Lehman","Bear Stearns",
                       "Greece def.","Covid","Ukraine","WTC")
  
  p_cmp <- ggplot2::ggplot(df_cmp,
                           ggplot2::aes(date, vol,
                                        colour = model, linetype = model)) +
    ggplot2::geom_rect(data = recess,
                       ggplot2::aes(xmin = start, xmax = end,
                                    ymin = -Inf, ymax = Inf),
                       inherit.aes = FALSE,
                       fill = "lightblue", alpha = 0.4, colour = NA) +
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
      legend.key.width = grid::unit(1.4,"cm")
    ) 
  
  # add hollow red points & labels on BMA line
  for (i in seq_along(specific_dates)) {
    d  <- specific_dates[i]
    lab <- specific_events[i]
    yv  <- df_cmp$vol[df_cmp$model == "BMA" & df_cmp$date == d]
    if (length(yv) == 1) {
      p_cmp <- p_cmp +
        ggplot2::annotate("point",
                          x = d, y = yv,
                          shape = 21, size = 3, stroke = 1,
                          colour = "red", fill = NA) +
        ggplot2::annotate("text",
                          x = d, y = yv + 0.15,
                          label = lab, colour = "red",
                          size = 5, hjust = 0.5, vjust = -0.2)
    }
  }
  
  ## --- manual NBER legend (square + text) – top-right --------------------
  y_max <- max(df_cmp$vol, na.rm = TRUE)
  sq_x  <- max(df_cmp$date) - 1700     # move square in from right edge
  sq_y  <- y_max - 0.05                # a little below the top frame
  
  p_cmp <- p_cmp +
    ggplot2::annotate("point",
                      x = sq_x, y = sq_y,
                      shape = 15, size = 5,
                      colour = "lightblue") +
    ggplot2::annotate("text",
                      x = sq_x + 200, y = sq_y,
                      hjust = 0, size = 4.2,
                      label = "NBER recessions")
  
  
  ggplot2::ggsave(file.path(fig_dir,
                            "SDF_Volatility_BMA_CAPMB_FF5.pdf"),
                  p_cmp, width = vol_width, height = vol_height, units = "in")
  
  
  # ---------- Nontraded BMA Volatility -----------------------------------
  {
    ## pull annualised volatility already computed for NT
    vol_nt <- vol_list_ann$NT              # σ_t √12 for the NT SDF
    
    df_nt <- tibble::tibble(date = date_seq,
                            vol  = vol_nt,
                            model = "Non-traded")
    
    ## style maps to match the comparison plot
    col_map <- c(`Non-traded` = "black")
    lt_map  <- c(`Non-traded` = "solid")
    
    p_nt <- ggplot2::ggplot(df_nt,
                            ggplot2::aes(date, vol,
                                         colour = model, linetype = model)) +
      ggplot2::geom_rect(data = recess,
                         ggplot2::aes(xmin = start, xmax = end,
                                      ymin = -Inf, ymax = Inf),
                         inherit.aes = FALSE,
                         fill = "lightblue", alpha = 0.4, colour = NA) +
      ggplot2::geom_line(linewidth = 1.1) +
      ggplot2::scale_colour_manual(values = col_map) +
      ggplot2::scale_linetype_manual(values = lt_map) +
      ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
      ggplot2::labs(x = "",
                    y = "SDF volatility from nontradable factors",
                    colour = NULL, linetype = NULL) +
      ggplot2::theme_bw() +
      ggplot2::theme(
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.text.y  = ggplot2::element_text(size = size_y),
        axis.text.x  = ggplot2::element_text(size = size_x),
        legend.position = "none"       
      )
    
    ## event annotations (aligned with circles) ---------------------------
    events_df <- tibble::tibble(date  = specific_dates,
                                label = specific_events) |>
      dplyr::mutate(
        date = lubridate::ceiling_date(date, "month") - lubridate::days(1),
        vol  = vol_nt[match(date, df_nt$date)]) |>
      dplyr::filter(!is.na(vol))
    
    p_nt <- p_nt +
      ggplot2::geom_point(
        data  = events_df,
        ggplot2::aes(date, vol),
        shape = 21, size = 3, stroke = 1,
        colour = "red", fill = NA, inherit.aes = FALSE) +
      ggplot2::geom_text(
        data  = events_df,
        ggplot2::aes(date, vol, label = label),
        colour = "red", size = 5,
        hjust = 0.5, vjust = -2,          # small upward nudge
        inherit.aes = FALSE)
    
    y_max <- max(df_nt$vol, na.rm = TRUE)
    sq_x  <- min(df_nt$date) + 250     # move square in from right edge
    sq_y  <- y_max - 0.01                # a little below the top frame
    
    p_nt <- p_nt +
      ggplot2::annotate("point",
                        x = sq_x, y = sq_y,
                        shape = 15, size = 5,
                        colour = "lightblue") +
      ggplot2::annotate("text",
                        x = sq_x + 200, y = sq_y,
                        hjust = 0, size = 4.2,
                        label = "NBER recessions")
    
    
    ggplot2::ggsave(file.path(fig_dir,
                              "SDF_Volatility_Nontraded_BMA.pdf"),
                    p_nt, width = vol_width, height = vol_height, units = "in")
  }
  
  # ---------- Unspanned volatility (BMA vol ⟂ others) --------------------
  {
    ## --- annualised volatility series --------------------------------- ##
    Y <- vol_list_ann$BMA
    X <- cbind(vol_list_ann$CAPM,
               vol_list_ann$CAPMB,
               vol_list_ann$KNS,
               vol_list_ann$`RP-PCA`,
               vol_list_ann$FF5,
               vol_list_ann$HKM)
    colnames(X) <- c("CAPM","CAPMB","KNS","RP-PCA","FF5","HKM")
    
    ## --- OLS residuals: unspanned volatility --------------------------- ##
    res_unsp <- lm(Y ~ X)$residuals        # already annualised units
    
    df_unsp <- tibble::tibble(date = date_seq, vol = res_unsp)
    
    ## --- plot ----------------------------------------------------------- ##
    p_un <- ggplot2::ggplot(df_unsp, ggplot2::aes(date, vol)) +
      ggplot2::geom_rect(data = recess,
                         ggplot2::aes(xmin = start, xmax = end,
                                      ymin = -Inf, ymax = Inf),
                         inherit.aes = FALSE,
                         fill = "lightblue", alpha = 0.4, colour = NA) +
      ggplot2::geom_line(colour = "black", linewidth = 1.1) +
      ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
      ggplot2::labs(x = "", y = "Unspanned volatility") +
      ggplot2::theme_bw() +
      ggplot2::theme(
        panel.grid.major = ggplot2::element_blank(),
        panel.grid.minor = ggplot2::element_blank(),
        axis.text.y  = ggplot2::element_text(size = size_y),
        axis.text.x  = ggplot2::element_text(size = size_x),
        legend.position = "none"
      )
    
    ## red hollow markers + labels (same formatting as other once-off plots)
    events_df <- tibble::tibble(date  = specific_dates,
                                label = specific_events) |>
      dplyr::mutate(
        date = lubridate::ceiling_date(date, "month") - lubridate::days(1),
        vol  = res_unsp[match(date, df_unsp$date)]) |>
      dplyr::filter(!is.na(vol))
    
    p_un <- p_un +
      ggplot2::geom_point(
        data = events_df,
        ggplot2::aes(date, vol),
        shape = 21, size = 3, stroke = 1,
        colour = "red", fill = NA, inherit.aes = FALSE) +
      ggplot2::geom_text(
        data = events_df,
        ggplot2::aes(date, vol, label = label),
        colour = "red", size = 5,
        hjust = 0.5, vjust = 2, inherit.aes = FALSE)
    
    y_max <- max(df_unsp$vol, na.rm = TRUE)
    sq_x  <- min(df_unsp$date) + 250     # move square in from right edge
    sq_y  <- y_max - 0.01                # a little below the top frame
    
    p_un <- p_un +
      ggplot2::annotate("point",
                        x = sq_x, y = sq_y,
                        shape = 15, size = 5,
                        colour = "lightblue") +
      ggplot2::annotate("text",
                        x = sq_x + 200, y = sq_y,
                        hjust = 0, size = 4.2,
                        label = "NBER recessions")
    
    ggplot2::ggsave(file.path(fig_dir,
                              "SDF_Volatility_Unspanned.pdf"),
                    p_un, width = vol_width, height = vol_height, units = "in")
  }
  
  
  # ---------- Predictability bar-plot section (for every SDF) -----------
  pred_pvals_1m <- list()   # will hold p-values for each SDF
  
  {
    build_predict_plot <- function(label, mu_vec, vol_vec, model_type) {
      
      bond_stock<-  colnames( ws_env$fac$f_all_raw[,c(15:54)] )
      ## ------------------------- regressions ----------------------------- ##
      x1 <- (vol_vec ^ 2) * mu_vec
      x2 <- vol_vec ^ 2
      
      r2   <- f_pv <- numeric(ncol(ws_env$fac$f_all_raw[,c(bond_stock)]))
      
      for (j in seq_along(r2)) {
        y   <- log1p(ws_env$fac$f_all_raw[,c(bond_stock)][, j])
        fit <- summary(lm(y ~ x1 + x2))
        r2[j]   <- fit$r.squared
        f_pv[j] <- 1 - pf(fit$fstatistic[1],
                          fit$fstatistic[2],
                          fit$fstatistic[3])
      }
      ## ------------------------- buckets & data -------------------------- ##
      sig_flag <- cut(f_pv,
                      breaks = c(-Inf, .05, .1, Inf),
                      labels = c("p < .05", "p < .10", "p > .10"))
      
      if (model_type == 'bond' || model_type == 'bond_stock_with_sp') {
        factor_type <- ifelse(colnames(ws_env$fac$f_all_raw[,c(bond_stock)]) %in% ws_env$fac$bond_names,
                              "Bond factors", "Equity factors")
      } else if (model_type == 'stock') {
        factor_type <- ifelse(colnames(ws_env$fac$f_all_raw[,c(bond_stock)]) %in% ws_env$fac$stock_names,
                              "Bond factors", "Equity factors")
      }
      
      df_bar <- tibble::tibble(
        factor = colnames(ws_env$fac$f_all_raw[,c(bond_stock)]),
        R2     = r2,
        type   = factor_type,
        signif = sig_flag
      ) |>
        dplyr::arrange(dplyr::desc(R2)) |>
        dplyr::mutate(factor = factor(factor, levels = factor))
      
      ## x-axis labels coloured via <span> + ggtext ------------------------ ##
      label_cols <- ifelse(df_bar$type == "Bond factors",
                           "royalblue1", "tomato")
      axis_lab   <- setNames(
        paste0("<span style='color:", label_cols, "'>",
               df_bar$factor, "</span>"),
        df_bar$factor)
      
      ## ------------------------- legend maps ----------------------------- ##
      pct05 <- round(100 * mean(f_pv <  .05   ))
      pct10 <- round(100 * mean(f_pv <  .10   ))
      pctHi <- 100 -pct10
      
      alpha_labels <- c(
        `p < .05` = glue::glue("p < .05 ({pct05}%)"),
        `p < .10` = glue::glue("p < .10 ({pct10}%)"),
        `p > .10` = glue::glue("p > .10 ({pctHi}%)"))
      
      col_map   <- c(`Bond factors`   = "royalblue1",
                     `Equity factors` = "tomato")
      alpha_map <- c(`p < .05` = 1, `p < .10` = 0.6, `p > .10` = 0.3)
      
      med_val <- median(r2)
      med_lab <- sprintf("Median R² (%.2f%%)", round(100 * med_val, 2))
      
      ## ------------------------- plot ------------------------------------ ##
      p_bar <- ggplot2::ggplot(df_bar,
                               ggplot2::aes(factor, R2, fill = type, alpha = signif)) +
        ggplot2::geom_col(colour = NA) +
        ggplot2::geom_hline(
          ggplot2::aes(yintercept = med_val, linetype = "Median"),
          colour = "black", linewidth = 0.7, show.legend = TRUE) +
        ggplot2::scale_fill_manual(
          values = col_map, name = NULL,
          guide = ggplot2::guide_legend(order = 1,
                                        override.aes = list(alpha = 1, linetype = "blank"))) +
        ggplot2::scale_alpha_manual(
          values = alpha_map, labels = alpha_labels, name = NULL,
          guide = ggplot2::guide_legend(order = 2,
                                        override.aes = list(fill = "darkgrey",
                                                            colour = NA, linetype = "blank"))) +
        ggplot2::scale_linetype_manual(
          values = setNames("dashed", "Median"),
          labels = setNames(med_lab,   "Median"),
          name   = NULL,
          guide  = ggplot2::guide_legend(order = 3,
                                         override.aes = list(fill = NA, alpha = 1,
                                                             colour = "black"))) +
        ggplot2::scale_x_discrete(limits = levels(df_bar$factor),
                                  labels = axis_lab) +
        ggplot2::labs(x = NULL, y = "R²") +
        ggplot2::theme_bw() +
        ggplot2::theme(
          panel.grid.major.x = ggplot2::element_blank(),
          axis.text.x  = ggtext::element_markdown(angle = 90, vjust = 0.5,
                                                  size = size_x),
          axis.text.y  = ggplot2::element_text(size = size_y),
          axis.title.y = ggplot2::element_text(size = size_y + 2),
          legend.position = c(0.97, 0.97),
          legend.justification = c(1, 1),
          legend.direction = "vertical",
          legend.text  = ggplot2::element_text(size = 10),
          legend.box.background = ggplot2::element_blank())
      
      ## ------------------------- save ------------------------------------ ##
      ggplot2::ggsave(
        file.path(fig_dir, paste0("Predictability1m_", label, ".pdf")),
        p_bar, width = ts_width, height = ts_height, units = "in")
      names(f_pv) <- colnames(ws_env$fac$f_all_raw[, c(bond_stock)])  # ← name the vector
      return(f_pv)
    }
    
    pred_pvals_1m$BMA <- build_predict_plot("BMA", fit_bma$mu, fit_bma$sigma,
                                            model_type)
    
    purrr::iwalk(fits_other, \(obj, nm)
                 pred_pvals_1m[[nm]] <<- build_predict_plot(nm, obj$mu, obj$sigma,
                                                            model_type))
    
  }
  
  #############################################################################
  #  Long-horizon predictability bar-plots (12-month cumulative returns)      #
  #############################################################################
  pred_pvals_12m <- list()    # holds 12-month p-value vectors
  
  {
    ## helper ----------------------------------------------------------------
    build_predict_plot_long_term <- function(label, mu_vec, vol_vec,
                                             months = 12, drop = 0) {
      ## ------------------------------------------------ rolling function --
      roll_fun <- function(x)
        zoo::rollapply(x, width = months, by = 1, align = "right",
                       FUN = sum, fill = NA, na.rm = FALSE)
      
      ## ------------------------------------------------ storage ----------
      bond_stock<-  colnames( ws_env$fac$f_all_raw[,c(15:54)] )
      r2_long   <- numeric(ncol(ws_env$fac$f_all_raw[,c(bond_stock)]))
      f_pv_long <- numeric(ncol(ws_env$fac$f_all_raw[,c(bond_stock)]))
      
      x1_full <- (vol_vec ^ 2) * mu_vec
      x2_full <- vol_vec ^ 2
      
      for (j in seq_len(ncol(ws_env$fac$f_all_raw[,c(bond_stock)]))) {
        ## cumulative log-returns -----------------------------------------
        y_full <- roll_fun(log1p(ws_env$fac$f_all_raw[,c(bond_stock)][, j]))
        y_full <- y_full[!is.na(y_full)]
        obs    <- length(y_full)
        
        y  <- y_full[(1 + drop):obs]
        x1 <- x1_full[1:(obs - drop)]
        x2 <- x2_full[1:(obs - drop)]
        
        fit <- lm(y ~ x1 + x2)
        
        ## Newey–West vcov (lag 15) ---------------------------------------
        nw_vcov <- sandwich::NeweyWest(fit, lag = 15,
                                       prewhite = FALSE, adjust = TRUE, sandwich = TRUE)
        
        ## robust F-test, allowing for aliased coeffs ---------------------
        ## keep only the coefficients that are present *and* not aliased (non-NA)
        keep_coef <- intersect(
          c("x1", "x2"),
          names(coef(fit))[!is.na(coef(fit))] )
        
        
        
        if (length(keep_coef) == 0) {
          p_val <- NA_real_
        } else {
          lh <- car::linearHypothesis(
            fit, paste0(keep_coef, " = 0"),
            vcov. = nw_vcov, test = "F", singular.ok = TRUE)
          p_val <- lh$`Pr(>F)`[2]
        }
        
        r2_long[j]   <- summary(fit)$r.squared
        f_pv_long[j] <- p_val
      }
      
      ## ------------------------------------------------ bar-plot ---------
      sig_flag <- cut(f_pv_long,
                      breaks = c(-Inf, .05, .1, Inf),
                      labels = c("p < .05", "p < .10", "p > .10"),
                      include.lowest = TRUE)
      
      factor_type <- ifelse(colnames(ws_env$fac$f_all_raw[,c(bond_stock)]) %in% ws_env$fac$bond_names,
                            "Bond factors", "Equity factors")
      
      df_bar <- tibble::tibble(
        factor = colnames(ws_env$fac$f_all_raw[,c(bond_stock)]),
        R2     = r2_long,
        type   = factor_type,
        signif = sig_flag) |>
        dplyr::arrange(dplyr::desc(R2)) |>
        dplyr::mutate(factor = factor(factor, levels = factor))
      
      ## shares for legend -------------------------------------------------
      pct05 <- round(100 * mean(f_pv_long <  .05, na.rm = TRUE))
      pct10 <- round(100 * mean(f_pv_long <  .10 ,
                                na.rm = TRUE))
      pctHi <- 100 - pct10
      
      alpha_labels <- c(
        `p < .05` = glue::glue("p < .05 ({pct05}%)"),
        `p < .10` = glue::glue("p < .10 ({pct10}%)"),
        `p > .10` = glue::glue("p > .10 ({pctHi}%)"))
      
      col_map   <- c(`Bond factors`   = "royalblue1",
                     `Equity factors` = "tomato")
      alpha_map <- c(`p < .05` = 1,
                     `p < .10` = 0.6,
                     `p > .10` = 0.3)
      
      med_val <- median(r2_long, na.rm = TRUE)
      med_lab <- sprintf("Median R² (%.2f%%)", round(100 * med_val, 2))
      
      p_bar <- ggplot2::ggplot(df_bar,
                               ggplot2::aes(factor, R2,
                                            fill = type, alpha = signif)) +
        ggplot2::geom_col(colour = NA) +
        ggplot2::geom_hline(
          ggplot2::aes(yintercept = med_val, linetype = "Median"),
          colour = "black", linewidth = 0.7) +
        ggplot2::scale_fill_manual(
          values = col_map, name = NULL,
          guide = ggplot2::guide_legend(order = 1,
                                        override.aes = list(alpha = 1, linetype = "blank"))) +
        ggplot2::scale_alpha_manual(
          values = alpha_map, labels = alpha_labels, name = NULL,
          guide = ggplot2::guide_legend(order = 2,
                                        override.aes = list(fill = "darkgrey",
                                                            colour = NA,
                                                            linetype = "blank"))) +
        ggplot2::scale_linetype_manual(
          values = setNames("dashed", "Median"),
          labels = setNames(med_lab,   "Median"),
          name   = NULL,
          guide  = ggplot2::guide_legend(order = 3,
                                         override.aes = list(fill = NA, alpha = 1,
                                                             colour = "black"))) +
        ggplot2::scale_x_discrete(limits = levels(df_bar$factor)) +
        ggplot2::labs(x = NULL, y = "R² (12-month return)") +
        ggplot2::theme_bw() +
        ggplot2::theme(
          panel.grid.major.x = ggplot2::element_blank(),
          axis.text.x  = ggtext::element_markdown(angle = 90, vjust = 0.5,
                                                  size = size_x,
                                                  colour = ifelse(df_bar$type ==
                                                                    "Bond factors",
                                                                  "royalblue1",
                                                                  "tomato")),
          axis.text.y  = ggplot2::element_text(size = size_y),
          axis.title.y = ggplot2::element_text(size = size_y + 2),
          legend.position = c(.97, .97),
          legend.justification = c(1, 1),
          legend.direction = "vertical",
          legend.text  = ggplot2::element_text(size = 10),
          legend.box.background = ggplot2::element_blank())
      
      ggplot2::ggsave(
        file.path(fig_dir, paste0("Predictability", months, "m_", label, ".pdf")),
        p_bar, width = ts_width, height = ts_height, units = "in")
      
      names(f_pv_long) <- colnames(ws_env$fac$f_all_raw[, c(bond_stock)])
      return(f_pv_long)
      
      
    }
    
    ## ---------- run long-term plots for each SDF ---------------------------
    # build_predict_plot_long_term("BMA", fit_bma$mu, fit_bma$sigma)
    # purrr::iwalk(fits_other,
    #              \(obj, nm) build_predict_plot_long_term(nm, obj$mu, obj$sigma))
    
    pred_pvals_12m$BMA <- build_predict_plot_long_term("BMA",
                                                       fit_bma$mu, fit_bma$sigma)
    
    purrr::iwalk(fits_other, \(obj, nm)
                 pred_pvals_12m[[nm]] <<- build_predict_plot_long_term(
                   nm, obj$mu, obj$sigma))
  }
  
  ##-----------------------------------------------------------------------##
  ##  Return: fits + data frames                                           ##
  ##-----------------------------------------------------------------------##
  make_df <- \(lst) tibble::tibble(date = date_seq) |>
    dplyr::bind_cols(tibble::as_tibble(lst))
  
  mean_list <- c(BMA = list(fit_bma$mu),
                 purrr::map(fits_other, "mu"))
  
  sigma_list <- c(BMA = list(fit_bma$sigma),
                  purrr::map(fits_other, "sigma"))
  
  param_list <- c(BMA = list(fit_bma$garch_params),
                  purrr::map(fits_other, "garch_params"))
  
  return(
    list(
      fits = list(
        arima = c(BMA = list(fit_bma$arima),
                  purrr::map(fits_other, "arima")),
        garch = list(
          sigma  = sigma_list,   # conditional σ_t vectors
          params = param_list    # robust coeffs & s.e.
        )
      ),
      data = list(
        mean_forecast = make_df(mean_list),
        volatility    = make_df(sigma_list)    # raw σ_t (monthly σ)
      ),
      p_values = list(
        predictability_pvalues_1m  = pred_pvals_1m,
        predictability_pvalues_12m = pred_pvals_12m
      )
    )
  )
}