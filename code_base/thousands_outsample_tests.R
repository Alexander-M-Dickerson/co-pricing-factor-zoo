#' thousands_outsample_tests
#'
#' **Big-bang OS diagnostics** for three universes of test assets  
#' 1. *co_pricing*  – all 154 assets (77 equities + 77 bonds)  
#' 2. *equity*      – the 77 equity assets only  
#' 3. *bond*        – the 77 bond assets only  
#'
#' Each universe is sliced into contiguous blocks (7 for equity, 7 for bond,
#' 14 for co-pricing) and every **non-empty** subset of blocks is priced
#' out-of-sample (16 383 subsets for co-pricing, 2 047 for equity, 2 047 for
#' bond).  Computations are run in parallel via **`furrr`**.
#'
#' The result is a nested list  
#' `res[[model_type]][[universe]]` → `data.table` of metrics.
#'
#' @inheritParams create_pricing_tables
#' @param workers integer.  Parallel workers (default 14).
#' @return list(model_type → list(co_pricing, equity, bond)).
#' @export
thousands_outsample_tests <- function(
    main_path,
    data_folder   = "paper.data.rr",
    output_folder = "output",
    code_folder   = "code_base",
    return_type   = c("excess"),
    tag           = "baseline",
    alpha.w       = 1,
    beta.w        = 1,
    kappa         = 0,
    intercept     = TRUE,
    model_types   = c("bond_stock_with_sp", "bond", "stock"),
    equity_os_file   = "equity_os_77.csv",
    bond_os_file_fmt = "bond_oosample_all_%s.csv",
    workers          = 14,
    dur_adj          = TRUE
) {
  library(future)
  # ---------------------------------------------------------------------------
  # helpers
  # ---------------------------------------------------------------------------
  build_fname <- function(model)
    sprintf("%s_%s_alpha.w=%g_beta.w=%g_kappa=%g%s%s.RData",
            return_type, model, alpha.w, beta.w, kappa,
            if (!intercept) "_no_intercept" else "",
            if (nzchar(tag)) paste0("_", tag) else "")
  
  # run_combos(R_oss,  cols_from_CP, cols_to_CP,
  #            env_objs, pkg_w, workers)
  
  run_combos <- function(mat, from, to, env_objects, pkg, workers) {
    splits <- Map(\(s, e) mat[, s:e], from, to)
    combs  <- unlist(
      lapply(seq_along(splits),
             \(k) combn(seq_along(splits), k, simplify = FALSE)),
      recursive = FALSE
    )
    
    future::plan(multisession, workers = workers)
    on.exit(future::plan(sequential), add = TRUE)
    
    system.time({
      out <- furrr::future_map(
        combs,
        \(idx) {
          R_sub <- do.call(cbind, splits[idx])
          do.call(os_asset_pricing,
                  c(list(R_sub), env_objects))        # pass through …
        },
        .options = furrr::furrr_options(seed = TRUE, packages = pkg)
      )
    }) -> tm
    
    message(sprintf("      finished %d combos in %.1f min",
                    length(combs), tm[3] / 60))
    
    data.table::rbindlist(out, use.names = TRUE)
  }
  
  # ── source **every** *.R script in `code_folder` ─────────────────────────────
  code_dir <- file.path(main_path, code_folder)
  R_files  <- list.files(code_dir, pattern = "\\.R$", full.names = TRUE)
  
  if (length(R_files) == 0L)
    stop("No .R scripts found in: ", code_dir,
         "\nCheck the 'code_folder' argument.", call. = FALSE)
  
  message("Sourcing ", length(R_files), " helper script(s) from ", code_dir, " …")
  invisible(lapply(R_files, source, local = FALSE))
  
  
  # ---------------------------------------------------------------------------
  # load test assets once
  # ---------------------------------------------------------------------------
  eq_path   <- file.path(main_path, data_folder, equity_os_file)
  bond_path <- file.path(main_path, data_folder,
                         if (grepl("%s", bond_os_file_fmt, fixed = TRUE))
                           sprintf(bond_os_file_fmt, return_type)
                         else bond_os_file_fmt)
  
  if (!file.exists(eq_path))   stop("Missing file: ", eq_path)
  if (!file.exists(bond_path)) stop("Missing file: ", bond_path)
  
  R_ossE <- as.matrix(read.csv(eq_path)[-1])
  R_ossB <- as.matrix(read.csv(bond_path)[-1])
  R_oss  <- cbind(R_ossE, R_ossB)                  # 154 columns
  
  # index ranges
  cols_from_CP <- c(1, 11, 21, 38, 48, 58, 68, 78, 88, 98, 108, 118, 128, 138)
  cols_to_CP   <- c(10, 20, 37, 47, 57, 67, 77, 87, 97, 107, 117, 127, 137, 154)
  
  cols_from_E  <- c(1, 11, 21, 38, 48, 58, 68)
  cols_to_E    <- c(10, 20, 37, 47, 57, 67, 77)
  
  offset       <- ncol(R_ossE)                     # 77
  cols_from_B  <- c(78, 88, 98, 108, 118, 128, 138) - offset
  cols_to_B    <- c(87, 97, 107, 117, 127, 137, 154) - offset
  
  # packages required in workers
  pkg_w <- c("data.table", "dplyr", "tibble", "matrixStats")
  
  # master output
  out_all <- vector("list", length(model_types))
  names(out_all) <- model_types
  
  for (model in model_types) {
    message("\n▸ Model: ", model)
    
    # ---- load workspace (IS_AP, f1, f2, …) ----------------------------------
    wspace <- file.path(main_path, output_folder, build_fname(model))
    if (!file.exists(wspace))
      stop("Workspace not found: ", wspace)
    load(wspace)                     # defines IS_AP, f1, f2, f_all_raw, …
    
    env_objs <- list(
      IS_AP     = IS_AP,
      f1        = f1,
      f2        = f2,
      f_all_raw = f_all_raw,
      intercept = intercept,
      kns_out   = kns_out,
      rp_out    = rp_out
    )
    
    # ---- three universes ----------------------------------------------------
    res_cp <- run_combos(R_oss,  cols_from_CP, cols_to_CP,
                         env_objs, pkg_w, workers)
    res_eq <- run_combos(R_ossE, cols_from_E,  cols_to_E,
                         env_objs, pkg_w, workers)
    res_bd <- run_combos(R_ossB, cols_from_B, cols_to_B,
                         env_objs, pkg_w, workers)
    
    out_all[[model]] <- list(co_pricing = res_cp,
                             equity      = res_eq,
                             bond        = res_bd)
  }
  
  # ──────────────────────────────────────────────────────────────────────────────
  #  Optional duration-adjusted diagnostics (co-pricing / equity / bond universes)
  # ──────────────────────────────────────────────────────────────────────────────
  if (isTRUE(dur_adj)) {
    
    message("\n⚑  Computing duration-adjusted diagnostics for all models …")
    
    # --- load duration-based bond returns once ---------------------------------
    dur_bond_file <- if (grepl("%s", bond_os_file_fmt, fixed = TRUE))
      sprintf(bond_os_file_fmt, "duration_tmt")
    else bond_os_file_fmt
    dur_bond_path <- file.path(main_path, data_folder, dur_bond_file)
    if (!file.exists(dur_bond_path))
      stop("Duration bond OS file not found: ", dur_bond_path)
    
    R_ossB_dur <- as.matrix(read.csv(dur_bond_path)[-1])
    R_oss_dur  <- cbind(R_ossE, R_ossB_dur)   # equity (excess) + bond (duration)
    
    # helper to compose workspace filename -------------------------------------
    ws_name <- function(rt, model)
      sprintf("%s_%s_alpha.w=%g_beta.w=%g_kappa=%g%s%s.RData",
              rt, model, alpha.w, beta.w, kappa,
              if (!intercept) "_no_intercept" else "",
              if (nzchar(tag)) paste0("_", tag) else "")
    
    env_base <- list(intercept = intercept)
    pkg_w    <- c("data.table", "dplyr", "tibble", "matrixStats")
    
    for (model in model_types) {
      
      rt_ws <- if (model == "stock") "excess" else "duration"
      ws_fp <- file.path(main_path, output_folder, ws_name(rt_ws, model))
      
      if (!file.exists(ws_fp))
        stop("Workspace not found for ", model, ": ", ws_fp)
      
      message("   → model: ", model, "  (workspace: ", rt_ws, ")")
      load(ws_fp)  # supplies IS_AP, f1, f2, f_all_raw, kns_out, rp_out
      
      env_objs <- c(env_base,
                    list(IS_AP     = IS_AP,
                         f1        = f1,
                         f2        = f2,
                         f_all_raw = f_all_raw,
                         kns_out   = kns_out,
                         rp_out    = rp_out))
      
      out_all[[model]][["duration_adj"]] <- list(
        co_pricing = run_combos(R_oss_dur,  cols_from_CP, cols_to_CP,
                                env_objs, pkg_w, workers),
        equity     = run_combos(R_ossE,     cols_from_E,  cols_to_E,
                                env_objs, pkg_w, workers),
        bond       = run_combos(R_ossB_dur, cols_from_B,  cols_to_B,
                                env_objs, pkg_w, workers)
      )
    }
    
    message("✓  Duration-adjusted diagnostics added for all models.")
  }
  
  # ---- save the nested results object -----------------------------------------
  msg <- sprintf("\n✓  Exporting results to file (tag = \"%s\") …", tag)
  message(msg)
  
  saveRDS(
    out_all,
    file = file.path(
      main_path, output_folder,
      sprintf("OS_metrics_%s%s.rds",
              if (nzchar(tag)) tag else "default",
              if (!intercept) "_no_intercept" else "")
    )
  )
  
  
  invisible(out_all)
}