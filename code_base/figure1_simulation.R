###############################################################################
## figure1_simulation.R
## ---------------------------------------------------------------------------
##
## Purpose:
##   Build the paper's Figure 1 from tracked paper-calibration fixtures and
##   optionally regenerate the simulation outputs used by that figure.
##
## Paper role:
##   Figure 1: "Simulation evidence with useless factors and noisy proxies."
##
## Paper refs:
##   - Figure 1
##   - Section 2.4
##   - Internet Appendix IA.2
##
## Outputs:
##   - output/paper/figures/Fig_01_*.jpeg
##   - output/paper/latex/fig1_simulation.tex
##   - output/simulations/figure1/generated/*
###############################################################################

figure1_simulation_code_dir <- local({
  source_time_dir <- NULL
  for (idx in rev(seq_along(sys.frames()))) {
    candidate <- sys.frames()[[idx]]$ofile
    if (!is.null(candidate) && file.exists(candidate)) {
      source_time_dir <- dirname(normalizePath(candidate, winslash = "/", mustWork = TRUE))
      break
    }
  }

  cached_dir <- source_time_dir

  function() {
    if (!is.null(cached_dir) && dir.exists(cached_dir)) {
      return(cached_dir)
    }

    fallback <- normalizePath(file.path(getwd(), "code_base"), winslash = "/", mustWork = FALSE)
    if (dir.exists(fallback)) {
      cached_dir <<- fallback
      return(cached_dir)
    }

    stop("Could not determine the code_base directory for Figure 1 helpers.", call. = FALSE)
  }
})

figure1_repo_root <- function() {
  normalizePath(dirname(figure1_simulation_code_dir()), winslash = "/", mustWork = TRUE)
}

figure1_fixture_dir <- function(project_root = figure1_repo_root()) {
  normalizePath(
    file.path(project_root, "misc", "figure1_simulation"),
    winslash = "/",
    mustWork = FALSE
  )
}

figure1_runtime_root <- function(project_root = figure1_repo_root()) {
  normalizePath(
    file.path(project_root, "output", "simulations", "figure1"),
    winslash = "/",
    mustWork = FALSE
  )
}

figure1_generated_dir <- function(project_root = figure1_repo_root(), type = "OLS") {
  file.path(figure1_runtime_root(project_root), "generated", paste0(type, "_sim_output"))
}

figure1_panel_dir <- function(project_root = figure1_repo_root(), source_mode = "fixed") {
  file.path(figure1_runtime_root(project_root), "panels", source_mode)
}

figure1_paper_figures_dir <- function(project_root = figure1_repo_root()) {
  file.path(project_root, "output", "paper", "figures")
}

figure1_paper_latex_dir <- function(project_root = figure1_repo_root()) {
  file.path(project_root, "output", "paper", "latex")
}

figure1_required_fixture_paths <- function(project_root = figure1_repo_root()) {
  fixture_dir <- figure1_fixture_dir(project_root)
  list(
    pseudo_true = file.path(fixture_dir, "pseudo-true.RData"),
    simulation_400 = file.path(fixture_dir, "simulation400psi60.RData"),
    simulation_1600 = file.path(fixture_dir, "simulation1600psi60.RData"),
    monthly_return = file.path(fixture_dir, "monthly_return.csv"),
    legend = file.path(fixture_dir, "Fig_01_0_sim_legend.jpeg"),
    fig1_bma_400 = file.path(fixture_dir, "Fig_01_1_OLS_60_400_BMA_MPR.jpeg"),
    fig1_bma_1600 = file.path(fixture_dir, "Fig_01_2_OLS_60_1600_BMA_MPR.jpeg"),
    fig1_mprs_400 = file.path(fixture_dir, "Fig_01_3_OLS_60_400_factor_MPRs.jpeg"),
    fig1_mprs_1600 = file.path(fixture_dir, "Fig_01_4_OLS_60_1600_factor_MPRs.jpeg"),
    fig1_probs_400 = file.path(fixture_dir, "Fig_01_5_OLS_60_400_factor_probs.jpeg"),
    fig1_probs_1600 = file.path(fixture_dir, "Fig_01_6_OLS_60_1600_factor_probs.jpeg")
  )
}

validate_figure1_fixture_files <- function(project_root = figure1_repo_root()) {
  required_paths <- figure1_required_fixture_paths(project_root)
  missing_paths <- names(required_paths)[!file.exists(unlist(required_paths, use.names = FALSE))]

  list(
    ok = length(missing_paths) == 0L,
    missing = missing_paths,
    required_paths = required_paths
  )
}

assert_figure1_fixture_files <- function(project_root = figure1_repo_root()) {
  validation <- validate_figure1_fixture_files(project_root)
  if (!isTRUE(validation$ok)) {
    missing_labels <- paste(validation$missing, collapse = ", ")
    stop(
      "Figure 1 fixture files are missing from misc/figure1_simulation: ",
      missing_labels,
      call. = FALSE
    )
  }
  invisible(validation$required_paths)
}

load_figure1_pseudo_true_objects <- function(project_root = figure1_repo_root()) {
  fixture_paths <- assert_figure1_fixture_files(project_root)
  pseudo_true_env <- new.env(parent = emptyenv())
  load(fixture_paths$pseudo_true, envir = pseudo_true_env)

  list(
    HML = get("HML", envir = pseudo_true_env),
    lambda_gls = get("lambda_gls", envir = pseudo_true_env),
    results_gmm_gls = get("results_gmm_gls", envir = pseudo_true_env)
  )
}

resolve_figure1_simulation_path <- function(t2,
                                            prior_pct = 60L,
                                            type = "OLS",
                                            source_mode = c("fixed", "generated"),
                                            project_root = figure1_repo_root()) {
  source_mode <- match.arg(source_mode)
  type <- match.arg(toupper(type), c("OLS", "GLS"))

  if (identical(source_mode, "fixed")) {
    if (!identical(type, "OLS") || !identical(prior_pct, 60L) || !(t2 %in% c(400L, 1600L))) {
      stop(
        "Tracked Figure 1 fixtures only exist for the paper settings: ",
        "type = OLS, prior_pct = 60, t2 in {400, 1600}.",
        call. = FALSE
      )
    }

    fixture_paths <- assert_figure1_fixture_files(project_root)
    if (identical(as.integer(t2), 400L)) {
      return(fixture_paths$simulation_400)
    }
    return(fixture_paths$simulation_1600)
  }

  file.path(
    figure1_generated_dir(project_root, type),
    paste0("simulation", t2, "psi", prior_pct, ".RData")
  )
}

load_figure1_simulation_workspace <- function(simulation_path, t2) {
  if (!file.exists(simulation_path)) {
    stop("Figure 1 simulation file not found: ", simulation_path, call. = FALSE)
  }

  simulation_env <- new.env(parent = emptyenv())
  load(simulation_path, envir = simulation_env)
  object_name <- paste0("simulation", t2)

  if (!exists(object_name, envir = simulation_env, inherits = FALSE)) {
    stop(
      "Expected object ",
      object_name,
      " in ",
      simulation_path,
      ".",
      call. = FALSE
    )
  }

  get(object_name, envir = simulation_env, inherits = FALSE)
}

figure1_coalesce <- function(x, y) {
  if (!is.null(x)) {
    return(x)
  }
  y
}

Figure1GeomHalfViolin <- ggplot2::ggproto(
  "Figure1GeomHalfViolin",
  ggplot2::Geom,
  setup_data = function(data, params) {
    data$width <- figure1_coalesce(data$width, params$width)
    if (all(is.na(data$width))) {
      data$width <- ggplot2::resolution(data$x, FALSE) * 0.9
    }

    transform(
      data,
      ymin = y,
      ymax = y,
      xmin = x - width / 2,
      xmax = x + width / 2
    )
  },
  draw_group = function(data, panel_scales, coord, side = "l") {
    data <- transform(
      data,
      xminv = x - violinwidth * (x - xmin),
      xmaxv = x + violinwidth * (xmax - x)
    )

    if (identical(side, "l")) {
      left_idx <- order(data$y)
      right_idx <- order(data$y, decreasing = TRUE)
      newdata <- rbind(
        transform(data[left_idx, ], x = xminv[left_idx]),
        transform(data[right_idx, ], x = x[right_idx])
      )
    } else {
      left_idx <- order(data$y)
      right_idx <- order(data$y, decreasing = TRUE)
      newdata <- rbind(
        transform(data[left_idx, ], x = x[left_idx]),
        transform(data[right_idx, ], x = xmaxv[right_idx])
      )
    }

    newdata <- rbind(newdata, newdata[1, ])
    ggplot2::GeomPolygon$draw_panel(newdata, panel_scales, coord)
  },
  draw_key = ggplot2::draw_key_polygon,
  default_aes = ggplot2::aes(
    weight = 1,
    colour = "grey20",
    fill = "white",
    linewidth = 0.5,
    alpha = NA,
    linetype = "solid"
  ),
  required_aes = c("x", "y")
)

figure1_geom_half_violin <- function(mapping = NULL,
                                     data = NULL,
                                     stat = "ydensity",
                                     position = "identity",
                                     ...,
                                     side = "l",
                                     trim = TRUE,
                                     scale = "area",
                                     na.rm = FALSE,
                                     show.legend = NA,
                                     inherit.aes = TRUE) {
  ggplot2::layer(
    data = data,
    mapping = mapping,
    stat = stat,
    geom = Figure1GeomHalfViolin,
    position = position,
    show.legend = show.legend,
    inherit.aes = inherit.aes,
    params = list(
      side = side,
      trim = trim,
      scale = scale,
      na.rm = na.rm,
      ...
    )
  )
}

plot_figure1_sims <- function(sim_values,
                              ylim = c(0, 1),
                              benchmark = 0,
                              xlab = "x-lab",
                              ylab = "y-lab",
                              benchrange = c(-0.00001, 0.00001),
                              color_repeats = NULL,
                              custom_labels = NULL,
                              show_legend = FALSE,
                              bench_line_col = "red",
                              bench_line_type = "dashed",
                              label_cex = 1) {
  sim_values_df <- as.data.frame(sim_values)
  n_experiments <- ncol(sim_values_df)
  sim_values_long <- reshape2::melt(
    sim_values_df,
    measure.vars = colnames(sim_values_df),
    variable.name = "variable",
    value.name = "value"
  )

  percentiles <- dplyr::summarise(
    dplyr::group_by(sim_values_long, .data$variable),
    p025 = stats::quantile(.data$value, 0.025),
    p975 = stats::quantile(.data$value, 0.975),
    .groups = "drop"
  )

  sim_values_long <- dplyr::left_join(sim_values_long, percentiles, by = "variable")

  if (is.null(custom_labels)) {
    x_labels <- setNames(as.character(as.roman(seq_len(ncol(sim_values_df)))), colnames(sim_values_df))
  } else {
    x_labels <- setNames(custom_labels, colnames(sim_values_df))
  }

  if (is.null(color_repeats)) {
    fill_colors <- RColorBrewer::brewer.pal(n_experiments, "Pastel2")
  } else {
    palette_colors <- RColorBrewer::brewer.pal(length(color_repeats), "Pastel2")
    fill_colors <- rep(palette_colors, times = color_repeats)
  }

  base_plot <- ggplot2::ggplot(sim_values_long, ggplot2::aes(x = .data$variable, y = .data$value, fill = .data$variable)) +
    ggplot2::annotate(
      "rect",
      xmin = 0.5,
      xmax = n_experiments + 0.5,
      ymin = benchrange[1],
      ymax = benchrange[2],
      fill = "lightgrey",
      alpha = 0.3
    ) +
    figure1_geom_half_violin(trim = FALSE, scale = "width", side = "l") +
    ggplot2::geom_errorbar(
      ggplot2::aes(ymin = .data$p025, ymax = .data$p975),
      width = 0.2,
      color = "black",
      linewidth = 1
    ) +
    ggplot2::geom_hline(yintercept = benchmark, linetype = bench_line_type, color = bench_line_col) +
    ggplot2::stat_summary(
      fun = stats::median,
      geom = "point",
      shape = 21,
      size = 3,
      fill = "white",
      color = "black"
    ) +
    ggplot2::labs(x = xlab, y = ylab) +
    ggplot2::theme_minimal(base_size = 11 * label_cex) +
    ggplot2::scale_x_discrete(labels = x_labels) +
    ggplot2::coord_cartesian(ylim = ylim, xlim = c(1, n_experiments))

  if (isTRUE(show_legend)) {
    legend_labels <- paste("Experiment", as.roman(seq_len(length(unique(fill_colors)))))
    base_plot +
      ggplot2::scale_fill_manual(values = fill_colors, labels = legend_labels) +
      ggplot2::guides(fill = ggplot2::guide_legend(title = "")) +
      ggplot2::theme(
        legend.position = "top",
        legend.direction = "horizontal",
        legend.box = "horizontal"
      )
  } else {
    base_plot +
      ggplot2::scale_fill_manual(values = fill_colors) +
      ggplot2::theme(legend.position = "none")
  }
}

build_figure1_panel_plots <- function(simulation, pseudo_true) {
  sim_size <- length(simulation)
  factor_labels <- c(
    expression(u[f]), expression(f[true]),
    expression(u[f]), expression(f[true]), expression(f[1]),
    expression(u[f]), expression(f[true]), expression(f[1]), expression(f[2]),
    expression(u[f]), expression(f[1]),
    expression(u[f]), expression(f[1]), expression(f[2]),
    expression(u[f]), expression(f[1]), expression(f[2]), expression(f[3]), expression(f[4])
  )

  mpr_values <- matrix(NA_real_, nrow = sim_size, ncol = 6)
  mpr_values[, 1] <- vapply(simulation, function(x) x$MPR_uf_f, numeric(1))
  mpr_values[, 2] <- vapply(simulation, function(x) x$MPR_uf_f_f1, numeric(1))
  mpr_values[, 3] <- vapply(simulation, function(x) x$MPR_uf_f_f1_f2, numeric(1))
  mpr_values[, 4] <- vapply(simulation, function(x) x$MPR_uf_f1, numeric(1))
  mpr_values[, 5] <- vapply(simulation, function(x) x$MPR_uf_f1_f2, numeric(1))
  mpr_values[, 6] <- vapply(simulation, function(x) x$MPR_uf_f1_f2_f3_f4, numeric(1))

  bma_plot <- plot_figure1_sims(
    mpr_values,
    ylim = c(0, 0.35),
    benchmark = mean(pseudo_true$HML / stats::sd(pseudo_true$HML)),
    xlab = "Experiment",
    ylab = "BMA-SDF MPR",
    benchrange = c(
      (pseudo_true$lambda_gls[2] + 1.96 * sqrt(pseudo_true$results_gmm_gls$Avar_hat[2, 2])) * stats::sd(pseudo_true$HML),
      (pseudo_true$lambda_gls[2] - 1.96 * sqrt(pseudo_true$results_gmm_gls$Avar_hat[2, 2])) * stats::sd(pseudo_true$HML)
    ),
    color_repeats = c(1, 1, 1, 1, 1, 1),
    show_legend = TRUE,
    label_cex = 1.5
  )

  post_probs <- t(vapply(simulation, function(x) x$post_probs_uf_f, numeric(2)))
  post_probs <- cbind(post_probs, t(vapply(simulation, function(x) x$post_probs_uf_f_f1, numeric(3))))
  post_probs <- cbind(post_probs, t(vapply(simulation, function(x) x$post_probs_uf_f_f1_f2, numeric(4))))
  post_probs <- cbind(post_probs, t(vapply(simulation, function(x) x$post_probs_uf_f1, numeric(2))))
  post_probs <- cbind(post_probs, t(vapply(simulation, function(x) x$post_probs_uf_f1_f2, numeric(3))))
  post_probs <- cbind(post_probs, t(vapply(simulation, function(x) x$post_probs_uf_f1_f2_f3_f4, numeric(5))))

  prob_plot <- plot_figure1_sims(
    post_probs,
    ylim = c(0, 1),
    benchmark = 0.5,
    xlab = "Factors",
    ylab = "Posterior factor probabilities",
    benchrange = c(0, 0),
    color_repeats = c(2, 3, 4, 2, 3, 5),
    bench_line_col = "blue",
    bench_line_type = "dotdash",
    custom_labels = factor_labels,
    label_cex = 1.5
  )

  post_lambdas <- t(vapply(simulation, function(x) x$post_lambdas_uf_f, numeric(2)))
  post_lambdas <- cbind(post_lambdas, t(vapply(simulation, function(x) x$post_lambdas_uf_f_f1, numeric(3))))
  post_lambdas <- cbind(post_lambdas, t(vapply(simulation, function(x) x$post_lambdas_uf_f_f1_f2, numeric(4))))
  post_lambdas <- cbind(post_lambdas, t(vapply(simulation, function(x) x$post_lambdas_uf_f1, numeric(2))))
  post_lambdas <- cbind(post_lambdas, t(vapply(simulation, function(x) x$post_lambdas_uf_f1_f2, numeric(3))))
  post_lambdas <- cbind(post_lambdas, t(vapply(simulation, function(x) x$post_lambdas_uf_f1_f2_f3_f4, numeric(5))))

  lambda_plot <- plot_figure1_sims(
    post_lambdas,
    ylim = c(-0.05, 0.3),
    benchmark = mean(pseudo_true$HML / stats::sd(pseudo_true$HML)),
    xlab = "Factors",
    ylab = "Posterior factor MPRs",
    color_repeats = c(2, 3, 4, 2, 3, 5),
    custom_labels = factor_labels,
    benchrange = c(
      (pseudo_true$lambda_gls[2] + 1.96 * sqrt(pseudo_true$results_gmm_gls$Avar_hat[2, 2])) * stats::sd(pseudo_true$HML),
      (pseudo_true$lambda_gls[2] - 1.96 * sqrt(pseudo_true$results_gmm_gls$Avar_hat[2, 2])) * stats::sd(pseudo_true$HML)
    ),
    label_cex = 1.5
  )

  list(
    bma_mpr = bma_plot,
    factor_probs = prob_plot,
    factor_mprs = lambda_plot
  )
}

save_figure1_panel_plots <- function(plots, output_dir, file_stub) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  output_paths <- list(
    bma_mpr = file.path(output_dir, paste0(file_stub, "_BMA_MPR.jpeg")),
    factor_probs = file.path(output_dir, paste0(file_stub, "_factor_probs.jpeg")),
    factor_mprs = file.path(output_dir, paste0(file_stub, "_factor_MPRs.jpeg"))
  )

  strip_figure1_jfif_header <- function(path) {
    bytes <- readBin(path, what = "raw", n = file.info(path)$size)
    if (length(bytes) < 20L) {
      return(invisible(FALSE))
    }

    has_jfif <- identical(bytes[1:4], as.raw(c(0xFF, 0xD8, 0xFF, 0xE0))) &&
      rawToChar(bytes[7:10], multiple = FALSE) == "JFIF"
    if (!has_jfif) {
      return(invisible(FALSE))
    }

    segment_len <- sum(as.integer(bytes[5:6]) * c(256L, 1L))
    drop_to <- 4L + segment_len
    stripped <- c(bytes[1:2], bytes[(drop_to + 1L):length(bytes)])
    writeBin(stripped, path)
    invisible(TRUE)
  }

  # Match the historical Figure 1 contract from the original simulation
  # directory: the BMA panels were saved at 6 x 4 inches and the factor
  # panels at 6 x 3.5 inches. With dpi = 300 that yields the 1800 x 1200
  # and 1800 x 1050 JPEGs the manuscript TeX expects.
  ggplot2::ggsave(
    output_paths$bma_mpr,
    plot = plots$bma_mpr,
    width = 6,
    height = 4,
    units = "in",
    dpi = 300,
    device = "jpeg"
  )
  ggplot2::ggsave(
    output_paths$factor_probs,
    plot = plots$factor_probs,
    width = 6,
    height = 3.5,
    units = "in",
    dpi = 300,
    device = "jpeg"
  )
  ggplot2::ggsave(
    output_paths$factor_mprs,
    plot = plots$factor_mprs,
    width = 6,
    height = 3.5,
    units = "in",
    dpi = 300,
    device = "jpeg"
  )

  for (path in unlist(output_paths, use.names = FALSE)) {
    strip_figure1_jfif_header(path)
  }

  output_paths
}

generate_figure1_panels <- function(t2,
                                    prior_pct = 60L,
                                    type = "OLS",
                                    source_mode = c("fixed", "generated"),
                                    output_dir = NULL,
                                    project_root = figure1_repo_root()) {
  source_mode <- match.arg(source_mode)
  type <- match.arg(toupper(type), c("OLS", "GLS"))

  required_packages <- c("ggplot2", "reshape2", "dplyr", "RColorBrewer")
  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing_packages) > 0) {
    stop(
      "Figure 1 plotting requires additional packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  if (is.null(output_dir)) {
    output_dir <- figure1_panel_dir(project_root, source_mode)
  }

  pseudo_true <- load_figure1_pseudo_true_objects(project_root)
  simulation_path <- resolve_figure1_simulation_path(t2, prior_pct, type, source_mode, project_root)
  simulation <- load_figure1_simulation_workspace(simulation_path, t2)
  plots <- build_figure1_panel_plots(simulation, pseudo_true)
  file_stub <- paste(source_mode, type, prior_pct, t2, sep = "_")
  output_paths <- save_figure1_panel_plots(plots, output_dir, file_stub)

  list(
    plots = plots,
    paths = output_paths,
    simulation_path = simulation_path,
    file_stub = file_stub
  )
}

build_figure1_tex <- function(graphics_prefix = "../figures") {
  prefix <- function(filename) {
    if (identical(graphics_prefix, "")) {
      filename
    } else {
      paste0(graphics_prefix, "/", filename)
    }
  }

  c(
    "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%",
    "\\begin{figure}[tbp]",
    "\\begin{center}",
    paste0("\\includegraphics[scale=.16, trim = 0cm 0cm 0cm 0cm, clip]{", prefix("Fig_01_0_sim_legend.jpeg"), "}"),
    "\\vspace{.15cm}",
    "",
    "\\begin{subfigure}[b]{0.45\\textwidth}",
    paste0(" \\includegraphics[scale=.1,trim = 0cm 0cm 0cm 16cm, clip]{", prefix("Fig_01_1_OLS_60_400_BMA_MPR.jpeg"), "}\\caption{BMA-SDF market price of risk, $T=400$}"),
    "\\end{subfigure}",
    "\\hspace{.2cm}",
    "\\begin{subfigure}[b]{0.45\\textwidth}",
    paste0(" \\includegraphics[scale=.1,trim = 0cm 0cm 0cm 16cm, clip]{", prefix("Fig_01_2_OLS_60_1600_BMA_MPR.jpeg"), "}\\caption{BMA-SDF market price of risk, $T=1600$}"),
    "\\end{subfigure}",
    "",
    "\\begin{subfigure}[b]{0.45\\textwidth}",
    paste0(" \\includegraphics[scale=.1,trim = 0cm 0cm 0cm 0cm, clip]{", prefix("Fig_01_3_OLS_60_400_factor_MPRs.jpeg"), "}\\caption{Factors' market price of risk, $T=400$}"),
    "\\end{subfigure}",
    "\\hspace{.2cm}",
    "\\begin{subfigure}[b]{0.45\\textwidth}",
    paste0(" \\includegraphics[scale=.1,trim = 0cm 0cm 0cm 0cm, clip]{", prefix("Fig_01_4_OLS_60_1600_factor_MPRs.jpeg"), "}\\caption{Factors' market price of risk, $T=1600$}"),
    "\\end{subfigure}",
    "",
    "\\begin{subfigure}[b]{0.45\\textwidth}",
    paste0(" \\includegraphics[scale=.12,trim = 0cm 0cm 0cm 0cm, clip]{", prefix("Fig_01_5_OLS_60_400_factor_probs.jpeg"), "}\\caption{Factors' posterior probabilities, $T=400$}"),
    "\\end{subfigure}",
    "\\hspace{.2cm}",
    "\\begin{subfigure}[b]{0.45\\textwidth}",
    paste0(" \\includegraphics[scale=.1,trim = 0cm 0cm 0cm 0cm, clip]{", prefix("Fig_01_6_OLS_60_1600_factor_probs.jpeg"), "}\\caption{Factors' posterior probabilities, $T=1600$}"),
    "\\end{subfigure}",
    "\\end{center}",
    "\\vspace{-4mm}",
    "\\caption{Simulation evidence with useless factors and noisy proxies.}",
    "\\vspace{-2mm}",
    "\\begin{justify}",
    "\\begin{spacing}{1}",
    "\\footnotesize{",
    "Simulation results from applying our Bayesian methods to different sets of factors. Each experiment is repeated 1,000 times with the specified sample size ($T$). The data-generating process is calibrated to match the pricing ability of the HML factor (as a pseudo-true factor) for the Fama-French 25 size and book-to-market portfolios. Horizontal red dashed lines denote the market price of risk of HML, and the grey shaded area the frequentist 95\\% confidence region of its GMM estimate in the historical sample of 665 monthly observations. The prior is set to 60\\% of the ex post maximum Sharpe ratio. Simulation details are in Internet Appendix IA.2. Half-violin plots depict the distribution of the estimated quantities across the simulations, with black error bars denoting centered 95\\% coverage, and white circles denoting median values, across repeated samples. In all experiments we include a useless factor ($u_f$), while the pseudo-true factor ($f_{true}$) is included only in experiments I to III. In each experiment we include a variable number of noisy proxies $f_j$, $j=1,..., 4$ with correlations with the pseudo-true factor equal to, respectively, 0.4, 0.3, 0.2, and 0.1. The factors considered in the various experiments are: \\\\",
    "\\noindent \\begin{tabular}{@{}p{0.49\\linewidth}@{}p{0.49\\linewidth}@{}}",
    "\\textbf{Experiment I}: $u_f$ and $f_{true}$. & \\textbf{Experiment IV}: $u_f$ and $f_1$. \\\\",
    "\\textbf{Experiment II}: $u_f$, $f_{true}$ and $f_1$. & \\textbf{Experiment V}: $u_f$, $f_1$ and $f_2$. \\\\",
    "\\textbf{Experiment III}: $u_f$, $f_{true}$, $f_1$ and $f_2$. & \\textbf{Experiment VI}: $u_f$, $f_1$, $f_2$, $f_3$ and $f_4$.\\\\",
    "\\end{tabular}}",
    "\\end{spacing}",
    "\\end{justify}",
    "\\label{fig:simulation}",
    "\\end{figure}",
    "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
  )
}

publish_figure1_assets <- function(source_mode = c("fixed", "generated"),
                                   project_root = figure1_repo_root(),
                                   type = "OLS",
                                   prior_pct = 60L,
                                   left_t = 400L,
                                   right_t = 1600L) {
  source_mode <- match.arg(source_mode)
  type <- match.arg(toupper(type), c("OLS", "GLS"))

  if (!identical(type, "OLS") ||
      !identical(as.integer(prior_pct), 60L) ||
      !identical(as.integer(left_t), 400L) ||
      !identical(as.integer(right_t), 1600L)) {
    stop(
      "The production Figure 1 path is fixed to the paper settings: ",
      "type = OLS, prior_pct = 60, left_t = 400, right_t = 1600.",
      call. = FALSE
    )
  }

  fixture_paths <- assert_figure1_fixture_files(project_root)
  left_result <- NULL
  right_result <- NULL

  if (identical(source_mode, "generated")) {
    left_result <- generate_figure1_panels(
      t2 = left_t,
      prior_pct = prior_pct,
      type = type,
      source_mode = source_mode,
      output_dir = figure1_panel_dir(project_root, source_mode),
      project_root = project_root
    )
    right_result <- generate_figure1_panels(
      t2 = right_t,
      prior_pct = prior_pct,
      type = type,
      source_mode = source_mode,
      output_dir = figure1_panel_dir(project_root, source_mode),
      project_root = project_root
    )
  }

  figures_dir <- figure1_paper_figures_dir(project_root)
  latex_dir <- figure1_paper_latex_dir(project_root)
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(latex_dir, recursive = TRUE, showWarnings = FALSE)

  if (identical(source_mode, "fixed")) {
    published_sources <- c(
      fixture_paths$legend,
      fixture_paths$fig1_bma_400,
      fixture_paths$fig1_bma_1600,
      fixture_paths$fig1_mprs_400,
      fixture_paths$fig1_mprs_1600,
      fixture_paths$fig1_probs_400,
      fixture_paths$fig1_probs_1600
    )
  } else {
    published_sources <- c(
      fixture_paths$legend,
      left_result$paths$bma_mpr,
      right_result$paths$bma_mpr,
      left_result$paths$factor_mprs,
      right_result$paths$factor_mprs,
      left_result$paths$factor_probs,
      right_result$paths$factor_probs
    )
  }

  published_paths <- data.frame(
    source = published_sources,
    target = file.path(
      figures_dir,
      c(
        "Fig_01_0_sim_legend.jpeg",
        "Fig_01_1_OLS_60_400_BMA_MPR.jpeg",
        "Fig_01_2_OLS_60_1600_BMA_MPR.jpeg",
        "Fig_01_3_OLS_60_400_factor_MPRs.jpeg",
        "Fig_01_4_OLS_60_1600_factor_MPRs.jpeg",
        "Fig_01_5_OLS_60_400_factor_probs.jpeg",
        "Fig_01_6_OLS_60_1600_factor_probs.jpeg"
      )
    ),
    stringsAsFactors = FALSE
  )

  for (idx in seq_len(nrow(published_paths))) {
    if (!file.exists(published_paths$source[[idx]])) {
      stop("Required Figure 1 asset missing: ", published_paths$source[[idx]], call. = FALSE)
    }
    file.copy(published_paths$source[[idx]], published_paths$target[[idx]], overwrite = TRUE)
  }

  tex_path <- file.path(latex_dir, "fig1_simulation.tex")
  writeLines(build_figure1_tex(graphics_prefix = "../figures"), tex_path)

  list(
    figures_dir = figures_dir,
    latex_path = tex_path,
    published_paths = published_paths,
    left_source = if (identical(source_mode, "fixed")) fixture_paths$simulation_400 else left_result$simulation_path,
    right_source = if (identical(source_mode, "fixed")) fixture_paths$simulation_1600 else right_result$simulation_path
  )
}

figure1_sdf_gmm <- function(R, f, W) {
  t1 <- nrow(R)
  n_assets <- ncol(R)
  n_factors <- ncol(f)
  cov_rf <- stats::cov(R, f)
  one_n <- matrix(1, ncol = 1, nrow = n_assets)
  one_t <- matrix(1, ncol = 1, nrow = t1)
  design_matrix <- cbind(one_n, cov_rf)
  mu_r <- matrix(colMeans(R), ncol = 1)
  mu_f <- matrix(colMeans(f), ncol = 1)

  w1 <- W[1:n_assets, 1:n_assets]
  lambda_gmm <- solve(t(design_matrix) %*% w1 %*% design_matrix) %*% t(design_matrix) %*% w1 %*% mu_r
  lambda_c <- lambda_gmm[1]
  lambda_f <- lambda_gmm[2:(1 + n_factors), , drop = FALSE]

  f_demean <- f - one_t %*% t(mu_f)
  moments <- matrix(0, ncol = n_assets + n_factors, nrow = t1)
  moments[, (1 + n_assets):(n_assets + n_factors)] <- f_demean

  for (t_idx in seq_len(t1)) {
    r_t <- matrix(R[t_idx, ], ncol = 1)
    f_t <- matrix(f[t_idx, ], ncol = 1)
    moments[t_idx, 1:n_assets] <- t(r_t - lambda_c * one_n - r_t %*% t(f_t - mu_f) %*% lambda_f)
  }

  s_hat <- stats::cov(moments)

  g_hat <- matrix(0, ncol = 2 * n_factors + 1, nrow = n_assets + n_factors)
  g_hat[1:n_assets, 1] <- -1
  g_hat[1:n_assets, 2:(1 + n_factors)] <- -cov_rf
  g_hat[1:n_assets, (n_factors + 2):(1 + 2 * n_factors)] <- mu_r %*% t(lambda_f)
  g_hat[(n_assets + 1):(n_assets + n_factors), (n_factors + 2):(1 + 2 * n_factors)] <- -diag(n_factors)

  avar_hat <- (1 / t1) * (
    solve(t(g_hat) %*% W %*% g_hat) %*%
      t(g_hat) %*% W %*% s_hat %*% W %*% g_hat %*%
      solve(t(g_hat) %*% W %*% g_hat)
  )

  r2 <- 1 - t(mu_r - design_matrix %*% lambda_gmm) %*% w1 %*% (mu_r - design_matrix %*% lambda_gmm) /
    (t(mu_r - mean(mu_r)) %*% w1 %*% (mu_r - mean(mu_r)))
  r2_adj <- 1 - (1 - r2) * (n_assets - 1) / (n_assets - 1 - n_factors)

  list(
    lambda_gmm = lambda_gmm,
    mu_f = mu_f,
    Avar_hat = avar_hat,
    R2_adj = r2_adj,
    S_hat = s_hat
  )
}

figure1_simulated_data <- function(sim_size, mu_y, sigma_y_half, n_assets, n_factors) {
  sim_y <- (mu_y %*% matrix(1, nrow = 1, ncol = sim_size) +
              t(sigma_y_half) %*% matrix(stats::rnorm((n_assets + n_factors) * sim_size), ncol = sim_size))
  sim_y <- t(sim_y)
  useless_factor <- matrix(stats::rnorm(sim_size), ncol = 1)

  list(sim_y = sim_y, uf = useless_factor)
}

ensure_figure1_fast_backend <- function(project_root = figure1_repo_root(), force_rebuild = FALSE) {
  fast_helper <- file.path(project_root, "code_base", "continuous_ss_sdf_fast.R")
  if (!exists("continuous_ss_sdf_fast", mode = "function") ||
      !exists("load_continuous_ss_sdf_fast_cpp", mode = "function")) {
    source(fast_helper)
  }

  backend_ready <- load_continuous_ss_sdf_fast_cpp(force_rebuild = force_rebuild)
  if (!isTRUE(backend_ready)) {
    stop(
      "Requested the fast Figure 1 simulation engine, but the backend did not load: ",
      continuous_ss_sdf_fast_cpp_error(),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

run_single_figure1_shrinkage <- function(factors,
                                         sim_R,
                                         ndraws,
                                         psi1,
                                         aw,
                                         bw,
                                         type,
                                         engine,
                                         project_root) {
  if (identical(engine, "fast_cpp")) {
    continuous_ss_sdf_fast(
      f = factors,
      R = sim_R,
      sim_length = ndraws,
      psi0 = psi1,
      r = 0.001,
      aw = aw,
      bw = bw,
      type = type,
      intercept = TRUE,
      backend = "cpp"
    )
  } else {
    BayesianFactorZoo::continuous_ss_sdf(
      f = factors,
      R = sim_R,
      sim_length = ndraws,
      psi0 = psi1,
      r = 0.001,
      aw = aw,
      bw = bw,
      type = type
    )
  }
}

prepare_figure1_calibration <- function(project_root = figure1_repo_root()) {
  fixture_paths <- assert_figure1_fixture_files(project_root)
  monthly_return <- utils::read.csv(fixture_paths$monthly_return, header = TRUE)

  rf <- as.matrix(monthly_return[, 62, drop = FALSE])
  ff3 <- as.matrix(monthly_return[, 57:59, drop = FALSE])
  R <- as.matrix(monthly_return[, 2:26, drop = FALSE] - monthly_return[, 62])
  HML <- ff3[, 3, drop = FALSE]

  n_assets <- ncol(R)
  sigma_r <- stats::cov(R)
  mu_f <- matrix(colMeans(HML), ncol = 1)
  Y <- cbind(R, HML)
  sigma_y <- stats::cov(Y)
  sigma_y_half <- chol(sigma_y)

  kappa <- 10000000000
  w_ols <- matrix(0, ncol = n_assets + 1, nrow = n_assets + 1)
  w_ols[1:n_assets, 1:n_assets] <- diag(n_assets)
  w_ols[(n_assets + 1):(n_assets + 1), (n_assets + 1):(n_assets + 1)] <- kappa * diag(1)
  results_gmm_ols <- figure1_sdf_gmm(R, HML, w_ols)
  lambda_ols <- results_gmm_ols$lambda_gmm

  w_gls <- matrix(0, ncol = n_assets + 1, nrow = n_assets + 1)
  w_gls[1:n_assets, 1:n_assets] <- solve(sigma_r)
  w_gls[(n_assets + 1):(n_assets + 1), (n_assets + 1):(n_assets + 1)] <- kappa * diag(1)
  results_gmm_gls <- figure1_sdf_gmm(R, HML, w_gls)
  lambda_gls <- results_gmm_gls$lambda_gmm

  er_mis <- matrix(colMeans(R), nrow = n_assets, ncol = 1)
  sr_25ff <- as.vector(sqrt(t(er_mis) %*% solve(stats::cov(R)) %*% er_mis))

  list(
    monthly_return = monthly_return,
    rf = rf,
    ff3 = ff3,
    R = R,
    HML = HML,
    n_assets = n_assets,
    mu_f = mu_f,
    sigma_y_half = sigma_y_half,
    lambda_ols = lambda_ols,
    results_gmm_ols = results_gmm_ols,
    lambda_gls = lambda_gls,
    results_gmm_gls = results_gmm_gls,
    er_mis = er_mis,
    sr_25ff = sr_25ff
  )
}

run_figure1_simulation_batch <- function(sim_size,
                                         t2,
                                         psi1,
                                         calibration,
                                         ndraws,
                                         aw = 1,
                                         bw = 1,
                                         type = "OLS",
                                         engine = "fast_cpp",
                                         num_cores = 1L,
                                         project_root = figure1_repo_root()) {
  worker_count <- max(1L, min(as.integer(num_cores), parallel::detectCores()))
  mean_y <- rbind(calibration$er_mis, calibration$mu_f)

  cl <- parallel::makeCluster(worker_count)
  on.exit(parallel::stopCluster(cl), add = TRUE)

  parallel::clusterExport(
    cl,
    c(
      "figure1_simulated_data",
      "run_single_figure1_shrinkage",
      "project_root",
      "mean_y",
      "calibration",
      "t2",
      "psi1",
      "aw",
      "bw",
      "type",
      "ndraws",
      "engine"
    ),
    envir = environment()
  )

  parallel::clusterEvalQ(cl, {
    library(BayesianFactorZoo)
    library(matrixStats)
    if (identical(engine, "fast_cpp")) {
      source(file.path(project_root, "code_base", "continuous_ss_sdf_fast.R"))
      ok <- load_continuous_ss_sdf_fast_cpp(force_rebuild = FALSE)
      if (!isTRUE(ok)) {
        stop(
          "Fast C++ backend failed to load on Figure 1 simulation worker: ",
          continuous_ss_sdf_fast_cpp_error(),
          call. = FALSE
        )
      }
    }
    NULL
  })

  post_start <- max(2L, floor(ndraws * 0.2))

  parallel::parLapply(cl, seq_len(sim_size), function(i) {
    set.seed(i)
    sample_sim <- figure1_simulated_data(
      sim_size = t2,
      mu_y = mean_y,
      sigma_y_half = calibration$sigma_y_half,
      n_assets = calibration$n_assets,
      n_factors = 1
    )
    sim_y <- sample_sim$sim_y
    sim_R <- sim_y[, 1:calibration$n_assets, drop = FALSE]
    sim_f <- sim_y[, (1 + calibration$n_assets):(calibration$n_assets + 1), drop = FALSE]
    uf <- sample_sim$uf

    rho <- c(0.4, 0.3, 0.2, 0.1)
    sim_f1 <- rho[1] * sim_f + sqrt(1 - rho[1]^2) * stats::rnorm(length(sim_f), sd = stats::sd(sim_f))
    sim_f2 <- rho[2] * sim_f + sqrt(1 - rho[2]^2) * stats::rnorm(length(sim_f), sd = stats::sd(sim_f))
    sim_f3 <- rho[3] * sim_f + sqrt(1 - rho[3]^2) * stats::rnorm(length(sim_f), sd = stats::sd(sim_f))
    sim_f4 <- rho[4] * sim_f + sqrt(1 - rho[4]^2) * stats::rnorm(length(sim_f), sd = stats::sd(sim_f))

    model_factors <- list(
      uf_f = cbind(uf, sim_f),
      uf_f_f1 = cbind(uf, sim_f, sim_f1),
      uf_f_f1_f2 = cbind(uf, sim_f, sim_f1, sim_f2),
      uf_f1 = cbind(uf, sim_f1),
      uf_f1_f2 = cbind(uf, sim_f1, sim_f2),
      uf_f1_f2_f3_f4 = cbind(uf, sim_f1, sim_f2, sim_f3, sim_f4)
    )

    output <- list()
    for (model_name in names(model_factors)) {
      shrinkage <- run_single_figure1_shrinkage(
        factors = model_factors[[model_name]],
        sim_R = sim_R,
        ndraws = ndraws,
        psi1 = psi1,
        aw = aw,
        bw = bw,
        type = type,
        engine = engine,
        project_root = project_root
      )

      output[[paste0("MPR_", model_name)]] <- mean(
        matrixStats::colSds(t(shrinkage$sdf_path[post_start:ndraws, , drop = FALSE]))
      )
      output[[paste0("post_probs_", model_name)]] <- colMeans(
        shrinkage$gamma_path[post_start:ndraws, , drop = FALSE]
      )
      output[[paste0("post_lambdas_", model_name)]] <- colMeans(
        shrinkage$lambda_path[post_start:ndraws, -1, drop = FALSE]
      )
      output[[paste0("backend_", model_name)]] <- if (!is.null(attr(shrinkage, "backend_used"))) {
        attr(shrinkage, "backend_used")
      } else {
        engine
      }
    }

    output
  })
}

run_figure1_simulation <- function(sim_size = 1000L,
                                   sample_sizes = c(400L, 1600L),
                                   prior_pcts = 60L,
                                   type = "OLS",
                                   ndraws = 5000L,
                                   engine = "fast_cpp",
                                   num_cores = max(1L, parallel::detectCores() - 1L),
                                   project_root = figure1_repo_root(),
                                   publish = FALSE) {
  type <- match.arg(toupper(type), c("OLS", "GLS"))
  engine <- match.arg(engine, c("fast_cpp", "reference"))

  if (length(sample_sizes) == 0L || any(is.na(sample_sizes)) || any(sample_sizes < 1L)) {
    stop("sample_sizes must be a non-empty vector of positive integers.", call. = FALSE)
  }
  if (length(prior_pcts) == 0L || any(is.na(prior_pcts)) || any(prior_pcts < 1L)) {
    stop("prior_pcts must be a non-empty vector of positive integers.", call. = FALSE)
  }
  if (is.na(sim_size) || sim_size < 1L) {
    stop("sim_size must be a positive integer.", call. = FALSE)
  }
  if (is.na(ndraws) || ndraws < 100L) {
    stop("ndraws must be at least 100.", call. = FALSE)
  }
  if (is.na(num_cores) || num_cores < 1L) {
    stop("num_cores must be at least 1.", call. = FALSE)
  }
  if (isTRUE(publish) &&
      (!identical(type, "OLS") ||
       !all(c(400L, 1600L) %in% as.integer(sample_sizes)) ||
       !identical(as.integer(prior_pcts), 60L))) {
    stop(
      "publish = TRUE requires the full paper Figure 1 settings: ",
      "type = OLS, prior_pcts = 60, sample_sizes including 400 and 1600.",
      call. = FALSE
    )
  }

  calibration <- prepare_figure1_calibration(project_root)
  if (identical(engine, "fast_cpp")) {
    ensure_figure1_fast_backend(project_root = project_root, force_rebuild = FALSE)
  }

  generated_root <- file.path(figure1_runtime_root(project_root), "generated")
  generated_dir <- figure1_generated_dir(project_root, type)
  dir.create(generated_root, recursive = TRUE, showWarnings = FALSE)
  dir.create(generated_dir, recursive = TRUE, showWarnings = FALSE)

  lambda_ols <- calibration$lambda_ols
  results_gmm_ols <- calibration$results_gmm_ols
  lambda_gls <- calibration$lambda_gls
  results_gmm_gls <- calibration$results_gmm_gls
  HML <- calibration$HML
  ER.mis <- calibration$er_mis
  SR.25FF <- calibration$sr_25ff
  save(
    lambda_ols,
    results_gmm_ols,
    lambda_gls,
    results_gmm_gls,
    HML,
    ER.mis,
    SR.25FF,
    file = file.path(generated_root, "pseudo-true.RData")
  )

  run_log <- list()
  for (prior_pct in prior_pcts) {
    psi1 <- BayesianFactorZoo::psi_to_priorSR(
      calibration$R,
      calibration$HML,
      priorSR = (prior_pct / 100) * calibration$sr_25ff
    )

    for (sample_size in sample_sizes) {
      started_at <- Sys.time()
      simulation_out <- run_figure1_simulation_batch(
        sim_size = sim_size,
        t2 = sample_size,
        psi1 = psi1,
        calibration = calibration,
        ndraws = ndraws,
        aw = 1,
        bw = 1,
        type = type,
        engine = engine,
        num_cores = num_cores,
        project_root = project_root
      )
      finished_at <- Sys.time()

      object_name <- paste0("simulation", sample_size)
      assign(object_name, simulation_out)
      output_file <- file.path(generated_dir, paste0(object_name, "psi", prior_pct, ".RData"))
      save(list = object_name, file = output_file)

      run_log[[paste0("T", sample_size, "_psi", prior_pct)]] <- list(
        sample_size = sample_size,
        prior_pct = prior_pct,
        started_at = started_at,
        finished_at = finished_at,
        engine = engine,
        type = type,
        ndraws = ndraws,
        sim_size = sim_size,
        output_file = output_file
      )
    }
  }

  metadata <- list(
    generated_at = Sys.time(),
    engine = engine,
    type = type,
    sim_size = sim_size,
    sample_sizes = as.integer(sample_sizes),
    prior_pcts = as.integer(prior_pcts),
    ndraws = as.integer(ndraws),
    num_cores = as.integer(num_cores),
    output_dir = generated_dir,
    runs = run_log
  )
  saveRDS(metadata, file.path(generated_root, "run_metadata.rds"))

  published <- NULL
  if (isTRUE(publish)) {
    published <- publish_figure1_assets(
      source_mode = "generated",
      project_root = project_root,
      type = type,
      prior_pct = 60L,
      left_t = 400L,
      right_t = 1600L
    )
  }

  list(
    metadata = metadata,
    published = published
  )
}
