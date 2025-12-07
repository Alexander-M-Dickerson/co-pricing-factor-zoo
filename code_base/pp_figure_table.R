# =========================================================================
#  pp_figure_table()   ---  Posterior-probability Figure & Table
# =========================================================================
# Creates  (legend ordered high-->low) and returns the
# tidy probability table.  Saves the PDF under main_path/output_folder.
#
# Required
# --------
#   results          list returned by run_bayesian_mcmc()
#
# Optional (with sensible defaults)
# ---------------------------------
#   prior_labels     labels for priors            (default 20/40/60/80 %)
#   top_n            number of top factors to emphasise (default 5)
#   linetypes_top    vector of linetypes for those top_n factors
#   legend_cols      columns in the rectangle legend (default 8)
#   prob_thresh      y-intercept of dashed reference line (default .50)
#   legend_rows      rows in legend (if you prefer rows; default 4)
#   main_path        root folder (cross-platform)  (default current ".")
#   output_folder    sub-folder for figures        (default "figures")
#   fig_name         file name of PDF             (default "posterior_probs.pdf")
#   width, height    inches of saved figure       (default 12x7)
#   verbose          print “Plot exported ..."       (default TRUE)
#
# Returns
# -------
#   Invisible list(plot = <ggplot>, table = <tibble>, file = <path>)
# =========================================================================

pp_figure_table <- function(results,
                            prior_labels  = c("20%","40%","60%","80%"),
                            top_n         = 5,
                            linetypes_top = c("solid","dashed","dotted",
                                              "dotdash","longdash"),
                            legend_cols   = 8,
                            prob_thresh   = 0.50,
                            legend_rows   = 4,
                            main_path     = ".",
                            output_folder = "figures",
                            fig_name      = "posterior_probs.pdf",
                            width         = 12,
                            height        = 7,
                            legend_font   =12,
                            verbose       = TRUE) {
  
  ## ---- 0.  Factor names ---------------------------------------------------
  if (!exists("f1", inherits = TRUE))
    stop("`f1` (and optionally `f2`) must exist in the calling environment.")
  f1 <- get("f1", inherits = TRUE)
  f2 <- if (exists("f2", inherits = TRUE)) get("f2", inherits = TRUE) else NULL
  factor_names <- colnames(cbind(f1, f2))
  if (length(factor_names) != ncol(results[[1]]$gamma_path))
    stop("Mismatch between factor names and gamma_path columns.")
  
  ## ---- 1.  Posterior probabilities ---------------------------------------
  prob_mat <- sapply(results, \(r) colMeans(r$gamma_path))
  colnames(prob_mat) <- prior_labels
  rownames(prob_mat) <- factor_names
  
  risk_mat <- sapply(results, \(r) colMeans(r$lambda_path)) * sqrt(12)
  colnames(risk_mat) <- prior_labels
  
  if (nrow(risk_mat) == length(factor_names) + 1) {
    if (intercept) {
      rownames(risk_mat) <- c("Constant", factor_names)
      risk_mat <-risk_mat[c(2:nrow(risk_mat)),]
    } else {
      lam_mat  <- risk_mat[-1, , drop = FALSE]
      rownames(risk_mat) <- factor_names
    }
  } else rownames(risk_mat) <- factor_names
  
  
  library(dplyr); library(tidyr)
  tidy_tab <- as_tibble(prob_mat, rownames = "Factors") |>
    mutate(Ave = rowMeans(prob_mat)) |>
    arrange(desc(Ave))                 # high → low
  lvls <- tidy_tab$Factors
  
  fprob <- tidy_tab |>
    dplyr::select(Factors, all_of(prior_labels)) |>
    pivot_longer(-Factors, names_to = "priorSR", values_to = "value")
  fprob$Factors <- factor(fprob$Factors, levels = lvls)
  
  ## ---- 2.  Colours & linetypes -------------------------------------------
  library(RColorBrewer)
  qual <- brewer.pal.info[brewer.pal.info$category == "qual", ]
  col_vec <- adjustcolor(unlist(mapply(brewer.pal,
                                       qual$maxcolors,
                                       rownames(qual))),
                         alpha.f = .70)
  col_vec[1:top_n] <- c("#FF0000","#00007F","#007F00","#7F007F","#FFA500")
  names(col_vec) <- lvls
  
  lt_vec <- rep("solid", length(lvls))
  lt_vec[seq_len(min(top_n, length(linetypes_top)))] <- linetypes_top
  names(lt_vec) <- lvls
  
  ## ---- 3.  Annotation points ---------------------------------------------
  right_prior <- tail(prior_labels, 1)
  annot_df <- fprob |>
    filter(priorSR == right_prior) |>
    slice_max(value, n = top_n, with_ties = FALSE)
  
  ## ---- 4.  Build plot -----------------------------------------------------
  library(ggplot2)
  g <- ggplot(fprob,
              aes(x = factor(priorSR, levels = prior_labels),
                  y = value,
                  group = Factors,
                  colour = Factors,
                  linetype = Factors)) +
    geom_line() +
    geom_point(size = 2.5, shape = 21, fill = "white") +
    geom_hline(yintercept = prob_thresh,
               linetype = "dashed", colour = "red") +
    scale_colour_manual(values = col_vec, breaks = lvls) +
    scale_linetype_manual(values = lt_vec, breaks = lvls) +
    labs(x = "Prior SR", y = "Posterior probability") +
    theme_bw() +
    theme(text            = element_text(size = 12),
          axis.text       = element_text(size = 12),
          legend.position = "bottom",
          legend.title    = element_blank(),
          legend.key.width= unit(2.3, "lines"),
          legend.text     = element_text(size = legend_font)) +
    guides(colour   = guide_legend(ncol = legend_cols, byrow = FALSE),
           linetype = "none") +
    geom_text(data = annot_df,
              aes(label = Factors),
              hjust = -0.3, vjust = 0.5, show.legend = FALSE) +
    coord_cartesian(clip = "off")
  
  ## ---- 5.  Save -----------------------------------------------------------
  save_file <- file.path(main_path, output_folder, fig_name)
  dir.create(dirname(save_file), recursive = TRUE, showWarnings = FALSE)
  ggsave(save_file, g, width = width, height = height, units = "in")
  if (verbose) message("Plot exported → ", normalizePath(save_file))
  
  print(g)
  invisible(list(plot = g, table = tidy_tab, file = save_file))
  
  ## ---- 3.  merge & sort by 80 % -------------------------------------------
  risk_mat_renamed <- risk_mat
  colnames(risk_mat_renamed) <- paste0(colnames(risk_mat), " λ")   # unique names
  
  sort_idx <- order(prob_mat[, length(prior_labels)], decreasing = TRUE)
  
  tab_df <- cbind(prob_mat, " " = NA_real_, risk_mat_renamed)[sort_idx, ] |>
    tibble::as_tibble(rownames = "Factor", .name_repair = "minimal")
  
  ## ---- 4.  round numeric columns -------------------------------------------
  tab_df <- tab_df |>
    dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 3)))
  
  
  ## ---- 5.  LaTeX table ----------------------------------------------------
  
  # 1. merge & sort by highest-prob in last prior column
  sort_idx <- order(prob_mat[, length(prior_labels)], decreasing = TRUE)
  prob_mat <- prob_mat[sort_idx, ]
  risk_mat <- risk_mat[sort_idx, ]
  
  
  # --- 2.  format numbers (3-decimals; LaTeX minus) -------------------------
  fmt_ltx <- function(x) {
    y <- round(x, 3)
    ifelse(y < 0,
           paste0("$-$", formatC(abs(y), digits = 3, format = "f")),
           formatC(y,        digits = 3, format = "f"))
  }
  
  prob_fmt <- apply(prob_mat,  c(1, 2), fmt_ltx)   # probabilities (all ≥ 0)
  risk_fmt <- apply(risk_mat,  c(1, 2), fmt_ltx)   # risk prices (±)
  
  
  # 3. build LaTeX manually -----------------------------------------------
  library(Hmisc)
  nP <- length(prior_labels)                       # number of priors
  align_str <- paste0("l", strrep("r", nP), "c", strrep("r", nP))
  
  header1 <- sprintf("& \\multicolumn{%d}{c}{Factor prob., $\\mathbb{E}[\\gamma_j|\\text{data}]$} &  & "
                     , nP)
  header1 <- paste0(header1,
                    sprintf("\\multicolumn{%d}{c}{Price of risk,   $\\mathbb{E}[\\lambda_j|\\text{data}]$} \\\\",
                            nP))
  
  header2 <- paste0("& \\multicolumn{", nP,
                    "}{c}{Total prior Sharpe ratio} &  & \\multicolumn{",
                    nP,"}{c}{Total prior Sharpe ratio} \\\\")
  
  # escape "%" → "\%"  for LaTeX
  prior_lbl_tex <- gsub("%", "\\\\%", prior_labels)
  
  header3 <- paste("Factors &",                         
                   paste(prior_lbl_tex, collapse = " & "),
                   "&  &",
                   paste(prior_lbl_tex, collapse = " & "),
                   "\\\\ \\midrule")
  
  ## -- build each data row ---------------------------------------------------
  escape_tex <- \(x) gsub("_", "\\_", x, fixed = TRUE)
  
  
  rows_tex <- character(nrow(prob_mat))
  
  for (i in seq_len(nrow(prob_mat))) {
    rows_tex[i] <- paste(
      escape_tex(rownames(prob_mat)[i]), " &",     
      paste(prob_fmt[i, ], collapse = " & "),
      "&  &",
      paste(risk_fmt[i, ], collapse = " & "),
      "\\\\"
    )
  }
  
  
  latex_lines <- c(
    "\\begin{table}[tbp!]",
    "\\caption{Posterior factor probabilities and risk prices -- bond and stock factor zoo}\\label{tab:table-app-probs}",
    "\\vspace{-.6cm}",
    "\\begin{center}",
    "\\scalebox{0.65}{",
    sprintf("\\begin{tabular}{%s} \\toprule", align_str),
    header1,
    sprintf("\\cmidrule(lr){2-%d} \\cmidrule(lr){%d-%d}",
            nP + 1, nP + 3, 2 * nP + 2),
    header2,
    header3,
    rows_tex,
    "\\bottomrule",
    "\\end{tabular}",
    "}",
    "\\end{center}",
    "\\vspace{-0.2cm}",
    "\\begin{spacing}{0.8}",
    "{\\footnotesize",
    "Posterior probabilities $\\mathbb{E}[\\gamma_j|\\text{data}]$ and annualised risk prices $\\mathbb{E}[\\lambda_j|\\text{data}]$.",
    "}",
    "\\end{spacing}",
    "\\end{table}"
  )
  
  tex_path <- file.path(main_path, "tables",
                        sub("\\.pdf$", ".tex", fig_name))
  
  # ---- ensure target folder exists -----------------------------------------
  if (!dir.exists(dirname(tex_path))) {
    stop("Export failed: ‘", dirname(tex_path),
         "’ does not exist. Please create a “tables” folder inside ‘",
         normalizePath(main_path), "’.")
  }
  
  writeLines(latex_lines, tex_path)
  if (verbose) message("LaTeX table exported ---> ", normalizePath(tex_path))
  
  
}