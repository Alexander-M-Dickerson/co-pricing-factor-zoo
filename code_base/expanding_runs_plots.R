expanding_runs_plots <- function(
    main_path     = "/Users/ASUS/Dropbox/DJM_Bayesian_RR",
    data_folder   = "paper.data.rr",
    output_folder = "output",
    code_folder   = "code_base",
    model_type    = "bond_stock_with_sp",
    return_type   = "excess",
    tag           = "baseline",
    alpha.w       = 1,
    beta.w        = 1,
    kappa         = 0,
    intercept     = TRUE,
    prior_labels  = c("20%","40%","60%","80%"),
    run_dir       = "expanding_output/forward",
    verbose       = TRUE
) {
  
  ## ── packages & helper ─────────────────────────────────────────────────
  library(stringr)
  library(purrr)
  library(dplyr)
  library(lubridate)
  library(tibble)
  
  talk <- function(...) if (isTRUE(verbose)) message(...)
  
  ## ── 1  baseline file: load & harvest factor info ──────────────────────
  int_flag <- if (intercept) "" else "no_intercept_"
  base_file <- file.path(
    main_path, output_folder,
    sprintf(
      "%s_%s_alpha.w=%s_beta.w=%s_kappa=%s_%s%s.Rdata",
      return_type, model_type, alpha.w, beta.w, kappa, int_flag, tag
    )
  )
  if (!file.exists(base_file))
    stop("Baseline file not found: ", base_file, call. = FALSE)
  
  e_base <- new.env(parent = emptyenv())
  load(base_file, envir = e_base)   # loads fac, posterior draws, etc.
  
  if (!exists("fac", envir = e_base))
    stop("`fac` object missing in baseline file.", call. = FALSE)
  
  factor_names <- colnames(e_base$fac$f_all_raw)   # matrix or data-frame OK
  lambda_names <- c("CONST", factor_names)
  f2_raw       <- e_base$fac$f2                    # benchmark factor panel
  
  risk_mat <- sapply(e_base$results, function(r) colMeans(r$lambda_path))
  colnames(risk_mat) <- prior_labels
  if (nrow(risk_mat) == length(factor_names) + 1) {
    rownames(risk_mat) <- c("Constant", factor_names)
    ## strip intercept row (always dropped in your example)
    risk_mat <- risk_mat[-1, , drop = FALSE]
  } else {
    rownames(risk_mat) <- factor_names
  }
  
  
  talk("Baseline loaded (K = ", length(factor_names), " factors).")
  
  ## ── 2  find Forward expanding-window files ────────────────────────────
  dir_path  <- file.path(main_path, run_dir)
  run_files <- list.files(dir_path, "^SS_.*\\.Rdata$", full.names = TRUE) |>
    keep(~ str_detect(.x, "Forward"))
  
  if (!length(run_files))
    stop("No Forward run files found in ", dir_path, call. = FALSE)
  
  run_dates <- str_extract(run_files, "\\d{4}-\\d{2}-\\d{2}") |>
    as.Date()
  o          <- order(run_dates)
  run_files  <- run_files[o]
  date_chr   <- format(run_dates[o], "%Y-%m-%d")
  
  talk("Found ", length(run_files), " expanding runs.")
  
  ## ── 3  extractor for a single run file (γ / λ only) ───────────────────
  extract_one <- function(file, idx) {
    
    env <- new.env(parent = emptyenv())
    load(file, envir = env)                       # must expose `results`
    stopifnot("results" %in% ls(env))
    
    ## γ: posterior inclusion probs ----------------------------------------
    gamma_mat <- sapply(1:4, \(i) colMeans(env$results[[i]]$gamma_path))
    colnames(gamma_mat) <- paste0("gam", 1:4)
    rownames(gamma_mat) <- factor_names
    
    gam4_row <- as.data.frame(t(gamma_mat[, "gam4", drop = FALSE]))
    rownames(gam4_row) <- date_chr[idx]
    
    ## λ: risk prices -------------------------------------------------------
    lambda_mat <- sapply(1:4, \(i) colMeans(env$results[[i]]$lambda_path))
    colnames(lambda_mat) <- paste0("lam", 1:4)
    rownames(lambda_mat) <- lambda_names          # "CONST", factors …
    
    lam4_row <- as.data.frame(t(lambda_mat[, "lam4", drop = FALSE]))
    rownames(lam4_row) <- date_chr[idx]
    
    ## top/bottom 5 lists ---------------------------------------------------
    gam_tbl <- tibble(factor = factor_names, gam4 = gamma_mat[, "gam4"])
    lam_tbl <- tibble(
      factor = factor_names,                      # exclude CONST
      lam4   = lambda_mat[-1, "lam4"]             # drop first row (CONST)
    )
    
    list(
      prob_row      = gam4_row,
      risk_row      = lam4_row,
      top5prob      = gam_tbl |> arrange(desc(gam4)) |> slice_head(n = 5) |> pull(factor),
      bottom5prob   = gam_tbl |> arrange(gam4)       |> slice_head(n = 5) |> pull(factor),
      top5risk      = lam_tbl |> arrange(desc(lam4)) |> slice_head(n = 5) |> pull(factor),
      bottom5risk   = lam_tbl |> arrange(lam4)       |> slice_head(n = 5) |> pull(factor)
    )
  }
  
  
  ## ── 4  loop over all run files ─────────────────────────────────────────
  all_res <- map2(run_files, seq_along(run_files), extract_one)
  
  time_series_prob <- bind_rows(map(all_res, "prob_row"))
  time_series_risk <- bind_rows(map(all_res, "risk_row")) |> select(-CONST)
  
  top_factors_prob    <- set_names(map(all_res, "top5prob"),    date_chr)
  bottom_factors_prob <- set_names(map(all_res, "bottom5prob"), date_chr)
  top_factors_risk    <- set_names(map(all_res, "top5risk"),    date_chr)
  bottom_factors_risk <- set_names(map(all_res, "bottom5risk"), date_chr)
  
  # NEW CODE: PLOT #
  
  ## ── 5  heat-maps for top/bottom prob & risk ────────────────────────────
  library(ggplot2)
  
  ## plotting parameters ---------------------------------------------------
  x_tick_size      <- 14
  legend_text_size <- 14
  y_label_size     <- 14
  plot_width       <- 12
  plot_height      <- 7
  plot_units       <- "in"
  
  ## ensure <main_path>/figures exists -------------------------------------
  fig_dir <- file.path(main_path, "figures")
  if (!dir.exists(fig_dir)) dir.create(fig_dir, recursive = TRUE)
  
  ## helper to reshape → heat-map → pdf ------------------------------------
  build_heatmap <- function(factor_list, label) {
    
    ## 1) normalise list names → 1 Jan of each year
    dates_dt  <- as.Date(names(factor_list))
    years_chr <- format(dates_dt, "%Y")
    names(factor_list) <- paste0(years_chr, "-01-01")
    
    ## 2) long data frame with Rank 1-5
    df_long <- purrr::map_df(
      names(factor_list),
      \(d) tibble(
        date   = as.Date(d),
        factor = factor_list[[d]],
        Rank   = seq_along(factor_list[[d]])
      )
    )
    
    ## 3) order factors by frequency, then by how often they are Rank 1
    ordering <- df_long %>% 
      dplyr::group_by(factor) %>% 
      dplyr::summarise(
        total_n = dplyr::n(),
        rank1   = sum(Rank == 1),
        .groups = "drop"
      ) %>% 
      dplyr::arrange(dplyr::desc(total_n), dplyr::desc(rank1)) %>% 
      dplyr::pull(factor)
    
    df_long <- df_long %>%
      mutate(factor = factor(factor, levels = rev(ordering)))
    
    ## 4) build heat-map
    p <- ggplot(df_long, aes(x = date, y = factor, fill = Rank)) +
      geom_tile(colour = "white") +
      scale_x_date(
        date_breaks = "1 year",
        labels = function(x) {
          labs <- format(x, "%Y")
          labs[x == as.Date("2003-01-01")] <- ""
          labs[x == as.Date("2023-01-01")] <- ""
          labs
        }
      ) +
      labs(x = "", y = "", title = "") +
      theme_minimal() +
      theme(
        panel.border    = element_rect(colour = "black", fill = NA, linewidth = 1),
        axis.text.x     = element_text(angle = 45, hjust = 1, size = x_tick_size),
        axis.text.y     = element_text(size = y_label_size),
        axis.title.y    = element_text(size = y_label_size),
        legend.position = "right",
        legend.text     = element_text(size = legend_text_size),
        legend.title    = element_text(size = legend_text_size),
        legend.background      = element_rect(colour = "black", fill = "white"),
        legend.box.background = element_rect(colour = "white", fill = "white")
      ) +
      guides(fill = guide_legend(reverse = FALSE))
    
    ## 5) export to pdf
    outfile <- file.path(fig_dir, paste0(label, ".pdf"))
    ggsave(outfile, plot = p,
           width = plot_width, height = plot_height, units = plot_units)
    
    talk("Saved ", basename(outfile))
    p
    print(p)
  }
  
  ## run for all four objects ----------------------------------------------
  heatmaps <- list(
    top_factors_prob    = top_factors_prob,
    bottom_factors_prob = bottom_factors_prob,
    top_factors_risk    = top_factors_risk,
    bottom_factors_risk = bottom_factors_risk
  )
  
  plot_objects <- purrr::imap(heatmaps, build_heatmap)
  
  invisible(plot_objects)   # return invisibly so you can inspect if desired
}