# ============================================================
#  plot_mean_vs_cov.R - Mean vs Covariance Diagnostic Plots (Figure 9)
#  ------------------------------------------------------------
#  Plots E[R] vs -cov(M,R) to visualize SDF pricing performance.
#
#  Asset Pricing Equation:
#    E[R] = -cov(M, R) * (1/E[M])
#
#  When E[M] ~ 1 (normalized SDF), this simplifies to:
#    E[R] ~ -cov(M, R)
#
#  Under the null hypothesis that the model is correctly specified:
#    - Points should lie on the 45-degree line
#    - Constrained R^2 (forcing slope=1) measures fit quality
#
#  Computation:
#    - minus_cov: (1 - cov(assets, sdf))^12 - 1  [annualized]
#    - meansR:    (1 + mean(assets))^12 - 1       [annualized]
#
#  Usage:
#    Generates 2 plots per call: in-sample and out-of-sample
#    Call twice: once for bond_treasury, once for stock_treasury
#
#  Output files:
#    {figure_prefix}_{suffix_is}.pdf  - In-sample plot
#    {figure_prefix}_{suffix_os}.pdf  - Out-of-sample plot
#
# ============================================================

#' Plot Mean vs Covariance Diagnostic Figures
#'
#' Generates scatter plots of E[R] vs -cov(M,R) for in-sample and out-of-sample
#' test assets. These plots visualize how well the BMA SDF prices assets.
#'
#' @param results_path Path to the results folder containing .Rdata files
#' @param return_type Return type prefix (default: "excess")
#' @param model_type Model type (default: "treasury")
#' @param alpha.w Beta prior hyperparameter (default: 1)
#' @param beta.w Beta prior hyperparameter (default: 1)
#' @param kappa Factor tilt parameter (default: 0)
#' @param tag Tag suffix for the .Rdata filename
#' @param intercept Whether model includes intercept (default: TRUE)
#' @param data_folder Folder containing OOS data files
#' @param os_pricing Character vector of OOS CSV filenames
#' @param sr_scale Which shrinkage level to use ("20%", "40%", "60%", "80%")
#' @param output_path Output directory for figures
#' @param figure_prefix Prefix for output filenames (e.g., "fig9_1" for bond)
#' @param suffix_is Suffix for in-sample figure (default: "bond_is" or "stock_is")
#' @param suffix_os Suffix for out-of-sample figure (default: "bond_os" or "stock_os")
#' @param constrained Use R^2 from no-intercept (slope=1) model? (default: TRUE)
#' @param width Figure width in inches (default: 3.25)
#' @param height Figure height in inches (default: 3.25)
#' @param verbose Print progress messages (default: TRUE)
#'
#' @return List with paths to generated figures
#'
#' @examples
#' \dontrun{
#'   # Bond treasury figures
#'   plot_mean_vs_cov(
#'     results_path = "output/unconditional",
#'     model_type = "treasury",
#'     tag = "bond_treasury",
#'     figure_prefix = "fig9",
#'     suffix_is = "1_bond_is",
#'     suffix_os = "2_bond_os"
#'   )
#' }
plot_mean_vs_cov <- function(
    results_path  = "output/unconditional",
    return_type   = "excess",
    model_type    = "treasury",
    alpha.w       = 1,
    beta.w        = 1,
    kappa         = 0,
    tag           = "bond_treasury",
    intercept     = TRUE,
    data_folder   = "data",
    os_pricing    = "treasury_oosample_all_excess.csv",
    sr_scale      = "80%",
    output_path   = "output/paper/figures",
    figure_prefix = "fig9",
    suffix_is     = "1_bond_is",
    suffix_os     = "2_bond_os",
    constrained   = TRUE,
    width         = 3.25,
    height        = 3.25,
    verbose       = TRUE
) {

  ## ---- 0. Load required packages -------------------------------------------
  suppressPackageStartupMessages({
    library(ggplot2)
  })

  ## ---- 1. Construct workspace filename -------------------------------------
  int_suffix <- if (intercept) "" else "_no_intercept"
  rdata_file <- paste0(
    return_type, "_", model_type,
    "_alpha.w=", alpha.w,
    "_beta.w=", beta.w,
    "_kappa=",  kappa,
    int_suffix, "_", tag, ".Rdata"
  )
  rdata_path <- file.path(results_path, model_type, rdata_file)

  if (!file.exists(rdata_path)) {
    stop("Workspace not found:\n", rdata_path, call. = FALSE)
  }

  if (verbose) message("Loading: ", rdata_path)

  ## ---- 2. Load workspace into its own environment --------------------------
  e <- new.env(parent = emptyenv())
  load(rdata_path, envir = e)

  ## ---- 3. Helper to compute vectors ----------------------------------------
  #' Computes annualized -cov(M,R) and E[R] for a set of assets
  #' @param asset_mat Matrix of asset returns (T x N)
  #' @param sdf Vector of SDF values (length T)
  #' @return List with minus_cov and meansR vectors
  build_vectors <- function(asset_mat, sdf) {
    # Annualize: (1 + monthly)^12 - 1
    list(
      minus_cov = (1 - cov(asset_mat, sdf))^12 - 1,
      meansR    = (1 + colMeans(asset_mat, na.rm = TRUE))^12 - 1
    )
  }

  ## ---- 4. Extract BMA SDF for chosen shrinkage level -----------------------
  idx <- match(sr_scale, c("20%", "40%", "60%", "80%"))
  if (is.na(idx)) {
    stop("`sr_scale` must be one of \"20%\", \"40%\", \"60%\", \"80%\".")
  }
  bma_sdf <- e$results[[idx]]$bma_sdf

  if (verbose) message("Using BMA SDF from shrinkage level: ", sr_scale)

  ## ---- 5. In-sample vectors ------------------------------------------------
  # Use R_matrix (test assets) and f2 (traded factors) if available
  # For treasury model, f2 may be NULL
  if (exists("R_matrix", envir = e)) {
    R_mat <- e$R_matrix
  } else if (exists("R", envir = e)) {
    R_mat <- e$R
  } else {
    stop("Neither R_matrix nor R found in loaded workspace.")
  }

  # Combine with f2 if available (for models with traded factors)
  if (!is.null(e$f2)) {
    in_sample_assets <- cbind(R_mat, e$f2)
  } else {
    in_sample_assets <- R_mat
  }

  vec_in <- build_vectors(in_sample_assets, bma_sdf)

  if (verbose) {
    message("In-sample: ", ncol(in_sample_assets), " assets")
  }

  ## ---- 6. Out-of-sample vectors --------------------------------------------
  os_pricing <- as.character(os_pricing)

  # Read OOS data (use first file if multiple provided)
  csv_path <- file.path(data_folder, os_pricing[1])
  if (!file.exists(csv_path)) {
    stop("OOS CSV not found:\n", csv_path, call. = FALSE)
  }

  # Read CSV and remove date column (first column)
  os_data <- read.csv(csv_path, stringsAsFactors = FALSE)
  os_mat <- as.matrix(os_data[, -1])

  vec_oos <- build_vectors(os_mat, bma_sdf)

  if (verbose) {
    message("Out-of-sample: ", ncol(os_mat), " assets")
    message("  File: ", os_pricing[1])
  }

  ## ---- 7. Plot factory -----------------------------------------------------
  make_plot <- function(v, title_suffix = "") {

    df <- data.frame(minus_cov = v$minus_cov, meansR = v$meansR)

    # 7.1 Always fit WITH-intercept line (this is what we draw)
    lm_free <- lm(meansR ~ minus_cov, df)
    slope   <- coef(lm_free)[2]

    # 7.2 Decide which R^2 to annotate
    if (constrained) {
      # Constrained R^2: slope forced to 1
      # R^2 = 1 - Var(residuals) / Var(meansR)
      # where residuals = meansR - minus_cov (when slope = 1)
      R2 <- 1 - var(df$meansR - df$minus_cov) / var(df$meansR)
    } else {
      R2 <- summary(lm_free)$r.squared
    }

    # 7.3 Build the ggplot
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
               x = quantile(v$minus_cov, 0.02),
               y = quantile(v$meansR,   0.35),
               label  = "45 degree line",
               colour = "tomato", hjust = 0, size = 3.3) +
      annotate("text",
               x = mean(v$minus_cov),
               y = max(v$meansR),
               vjust = 1,
               label = sprintf("Constrained R\u00b2: %.0f%%", 100 * R2),
               size  = 4.2) +
      annotate("text",
               x = mean(v$minus_cov),
               y = min(v$meansR),
               vjust  = -0.3,
               colour = "royalblue4",
               label  = sprintf("Fitted slope: %.2f", slope),
               size   = 4) +
      labs(x = expression(-cov(M, R)),
           y = expression(E(R)),
           subtitle = title_suffix) +
      theme_minimal(base_family = "sans") +
      theme(
        panel.grid.minor = element_blank(),
        panel.background = element_rect(fill = "white", colour = NA),
        plot.background  = element_rect(fill = "white", colour = NA)
      )
  }

  # Generate plots
  p_in  <- make_plot(vec_in,  title_suffix = "In-Sample")
  p_oos <- make_plot(vec_oos, title_suffix = "Out-of-Sample")

  ## ---- 8. Export PDFs ------------------------------------------------------
  if (!dir.exists(output_path)) {
    dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
  }

  export_plot <- function(pg, suffix) {
    fname <- paste0(figure_prefix, "_", suffix, ".pdf")
    fpath <- file.path(output_path, fname)
    ggsave(fpath,
           plot   = pg,
           device = cairo_pdf,
           width  = width, height = height, units = "in", bg = "white")
    if (verbose) message("Saved: ", fpath)
    fpath
  }

  # Export in-sample and out-of-sample plots
  path_is  <- export_plot(p_in,  suffix_is)
  path_oos <- export_plot(p_oos, suffix_os)

  ## ---- 9. Return results ---------------------------------------------------
  invisible(list(
    plot_is   = p_in,
    plot_oos  = p_oos,
    path_is   = path_is,
    path_oos  = path_oos,
    vec_in    = vec_in,
    vec_oos   = vec_oos,
    sr_scale  = sr_scale
  ))
}
