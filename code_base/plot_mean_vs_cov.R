# ============================================================
#  Diagnostic plot: E[R]  vs  –cov(M,R)
#  ------------------------------------------------------------
#  * Always plots the WITH-intercept regression line
#  * R² comes from the NO-intercept (“constrained”) model
#    when constrained = TRUE   (default)
#  * Handles any number of out-of-sample CSV files
#  * Exports one PDF per plot, white background, OS-safe names
# ============================================================

plot_mean_vs_cov <- function(
    main_path     = "~/Dropbox/DJM_Bayesian_RR",
    output_folder = "output",
    return_type   = "excess",
    model_type    = "bond_stock_with_sp",
    alpha.w       = 1,
    beta.w        = 1,
    kappa         = 0,
    tag           = "baseline",
    intercept     = TRUE,          # affects workspace filename only
    data_folder   = "paper.data.rr",
    os_pricing    = "data.csv",    # may be one file or a character vector
    sr_scale      = "80%",
    width         = 3.25,
    height        = 3.25,
    units         = "in",
    constrained   = TRUE           # use R² from no-intercept model
) {
  
  ## ---- 0. Normalise main path (works on Windows & macOS) -------------------
  main_path <- normalizePath(main_path, winslash = "/", mustWork = FALSE)
  
  ## ---- 1. Construct workspace filename ------------------------------------
  int_suffix <- if (intercept) "" else "_no_intercept"
  rdata_file <- paste0(
    return_type, "_", model_type,
    "_alpha.w=", alpha.w,
    "_beta.w=", beta.w,
    "_kappa=",  kappa,
    int_suffix, "_", tag, ".Rdata"
  )
  rdata_path <- file.path(main_path, output_folder, rdata_file)
  if (!file.exists(rdata_path))
    stop("Workspace not found:\n", rdata_path, call. = FALSE)
  
  ## ---- 2. Load workspace into its own env ---------------------------------
  e <- new.env(parent = emptyenv())
  load(rdata_path, envir = e)    # loads e$results, e$R, e$f2, …
  
  ## ---- 3. Helper to compute vectors ---------------------------------------
  build_vectors <- function(asset_mat, sdf) {
    list(
      minus_cov = (1 - cov(asset_mat, sdf))^12 - 1,
      meansR    = (1 + colMeans(asset_mat, na.rm = TRUE))^12 - 1
    )
  }
  
  idx <- match(sr_scale, c("20%", "40%", "60%", "80%"))
  if (is.na(idx))
    stop("`sr_scale` must be one of \"20%\", \"40%\", \"60%\", \"80%\".")
  bma_sdf <- e$results[[idx]]$bma_sdf
  
  ## ---- 4. In-sample vectors ------------------------------------------------
  vec_in <- build_vectors(cbind(e$R, e$f2), bma_sdf)
  
  ## ---- 5. Out-of-sample vectors -------------------------------------------
  suppressPackageStartupMessages(library(readr))
  os_pricing <- as.character(os_pricing)      # ensure character vector
  
  if (length(os_pricing) == 1L) {
    # --- single CSV ⇒ make vec_oos *match* vec_in’s structure ---
    csv_path <- file.path(main_path, data_folder, os_pricing)
    if (!file.exists(csv_path))
      stop("CSV not found:\n", csv_path, call. = FALSE)
    os_mat  <- as.matrix(read_csv(csv_path, show_col_types = FALSE)[, -1])
    vec_oos <- build_vectors(os_mat, bma_sdf)       # flat list
    single_file <- TRUE
    file_label  <- tools::file_path_sans_ext(basename(os_pricing))
  } else {
    # --- multiple CSVs ⇒ keep original list-of-lists behaviour ---
    vec_oos <- lapply(os_pricing, function(csv_name) {
      csv_path <- file.path(main_path, data_folder, csv_name)
      if (!file.exists(csv_path))
        stop("CSV not found:\n", csv_path, call. = FALSE)
      os_mat <- as.matrix(read_csv(csv_path, show_col_types = FALSE)[, -1])
      build_vectors(os_mat, bma_sdf)
    })
    names(vec_oos) <- tools::file_path_sans_ext(basename(os_pricing))
    single_file <- FALSE
  }
  
  ## ---- 6. Plot factory -----------------------------------------------------
  make_plot <- function(v, title_suffix = "") {
    
    df <- data.frame(minus_cov = v$minus_cov, meansR = v$meansR)
    
    # 6.1  always fit WITH-intercept line (this is what we draw)
    lm_free <- lm(meansR ~ minus_cov, df)
    slope   <- coef(lm_free)[2]
    
    # 6.2  decide which R² to annotate
    if (constrained) {
      R2 <- 1 - var(df$meansR-df$minus_cov)/var(df$meansR)
    } else {
      R2 <- summary(lm_free)$r.squared
    }
    
    # 6.3  build the ggplot
    suppressPackageStartupMessages(library(ggplot2))
    ggplot(df, aes(minus_cov, meansR)) +
      geom_point(size = 1.4, colour = "black") +
      geom_smooth(method = "lm", se = TRUE, level = 0.95,
                  colour = "royalblue4", fill = "royalblue4",
                  alpha = 0.15, linewidth = 0.6) +
      geom_abline(intercept = mean(v$meansR - v$minus_cov),
                  slope     = 1,
                  linetype  = "22", linewidth = 0.6,
                  colour    = "tomato") +
      annotate("text",
               x = quantile(v$minus_cov, 0.02),  # shifted left
               y = quantile(v$meansR,   0.35),   # shifted up
               label  = "45 degree line",
               colour = "tomato", hjust = 0, size = 3.3) +
      annotate("text",
               x = mean(v$minus_cov),
               y = max(v$meansR),
               vjust = 1,
               label = sprintf("Constrained R²: %.0f%%", 100 * R2),
               size  = 4.2) +
      annotate("text",
               x = mean(v$minus_cov),
               y = min(v$meansR),
               vjust  = -0.3,
               colour = "royalblue4",
               label  = sprintf("Fitted slope: %.2f", slope),
               size   = 4) +
      labs(x = "-cov(M,R)", y = "E[R]", subtitle = title_suffix) +
      theme_minimal(base_family = "sans") +
      theme(
        panel.grid.minor = element_blank(),
        panel.background = element_rect(fill = "white", colour = NA),
        plot.background  = element_rect(fill = "white", colour = NA)
      )
  }
  
  p_in     <- make_plot(vec_in)
  
  plot_oos <- make_plot(vec_oos)
  
  
  ## ---- 7. Export PDFs ------------------------------------------------------
  fig_dir <- file.path(main_path, "figures")
  dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)
  
  safe_scale <- gsub("%", "pct", sr_scale, fixed = TRUE)
  
  export_plot <- function(pg, suffix) {
    fname <- paste0(
      "mean_vs_cov_", safe_scale, "_", model_type, suffix, ".pdf"
    )
    ggsave(file.path(fig_dir, fname),
           plot   = pg,
           device = cairo_pdf,
           width  = width, height = height, units = units, bg = "white")
    message("Saved: ", file.path(fig_dir, fname))
  }
  
  ## 7.1  In-sample plot -------------------------------------------------------
  export_plot(p_in, if (constrained) "_constr" else "")
  
  ## 7.2  Out-of-sample plot(s) ----------------------------------------------
  if (inherits(plot_oos, "gg")) {                # single CSV → one ggplot
    suffix <- paste0("_", file_label, "_oos",
                     if (constrained) "_constr" else "")
    export_plot(plot_oos, suffix)
    
  } else {                                       # multiple CSVs → list
    for (nm in names(plot_oos)) {
      suffix <- paste0("_", nm, "_oos",
                       if (constrained) "_constr" else "")
      export_plot(plot_oos[[nm]], suffix)
    }
  }
  invisible(list(in_sample = p_in, oos = plot_oos))
}