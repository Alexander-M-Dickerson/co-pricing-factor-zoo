###############################################################################
## _debug_evaluate_performance.R
## 
## Debug script for testing evaluate_performance() independently
## This loads saved combined_results.rds and computes out-of-sample returns
###############################################################################

cat("\n")
cat("========================================\n")
cat("DEBUG: EVALUATE PERFORMANCE\n")
cat("========================================\n\n")

gc()

###############################################################################
## 1. CONFIGURATION
###############################################################################

#### 1.1 Results Location -----------------------------------------------------
# Root path where time-varying results are saved
output_root    <- file.path(getwd(), "output", "time_varying")

#### 1.2 Path Override --------------------------------------------------------
# When TRUE, use the paths below instead of those stored in the metadata.
# This is useful when running on a different machine than where estimation ran.
path_override  <- FALSE

# These paths are ONLY used when path_override = TRUE
override_main_path     <- getwd()
override_data_folder   <- file.path(getwd(), "data")
override_code_folder   <- file.path(getwd(), "code_base")
override_output_folder <- file.path(getwd(), "output")

#### 1.3 Model Specification --------------------------------------------------
# These parameters identify which results file to load
return_type    <- "excess"              # "excess" or "duration"
model_type     <- "bond_stock_with_sp"  # "bond", "stock", "bond_stock_with_sp"
tag            <- "ExpandingForward"    # Tag used during estimation
holding_period <- 12                    # Holding period in months
f1_flag        <- TRUE                 # TRUE if f1 was used, FALSE otherwise
alpha.w        <- 1                     # Alpha hyperparameter
beta.w         <- 1                     # Beta hyperparameter

#### 1.4 Performance Evaluation Options ---------------------------------------
# Volatility scaling: scale all portfolios to match this model's volatility
# Set to NULL for no scaling
vol_scale      <- "MKTS"                # "MKTS", "EqualWeight", or NULL

#### 1.5 Plot Options ---------------------------------------------------------
# Portfolios to include in plots (set to NULL to skip all plots)
factor_vec     <- c("BMA-80%", "KNS", "RP-PCA", "EqualWeight", "MKTB", "MKTS")

# Colors for each portfolio (must match factor_vec order, or NULL for defaults)
color_vec      <- c("red", "#66C2A5", "black", "lightblue", "royalblue4", "purple")

# Line types for each portfolio (must match factor_vec order, or NULL for defaults)
line_types_vec <- c("solid", "solid", "solid", "dashed", "dashed", "dashed")

# Legend position (x, y) where 0,0 is bottom-left and 1,1 is top-right
legend_position <- c(0.02, 0.98)

# Y-axis dollar spacing for cumulative return plot
dollar_step    <- 50

# Figure output settings
fig_width      <- 12
fig_height     <- 7

# Which plots to generate (set individual to FALSE to skip)
generate_plots <- list(
  cumret         = TRUE,   # Cumulative returns (wealth growth)
  drawdown       = TRUE,   # Drawdown over time
  rolling_sr     = TRUE,   # Rolling Sharpe ratio
  risk_return    = TRUE,   # Risk-return scatter
  annual_returns = TRUE,   # Annual returns bar chart
  annual_sr      = TRUE,   # Annual Sharpe ratio bar chart
  annual_sortino = TRUE,   # Annual Sortino ratio bar chart
  annual_ir      = TRUE,   # Annual Information ratio bar chart (vs EW)
  return_dist    = TRUE,   # Return distribution densities
  performance_bars = TRUE, # Performance metrics comparison
  underwater     = TRUE,   # Underwater (drawdown duration) by portfolio
  dashboard      = TRUE    # Multi-panel dashboard summary
)

# Benchmark for Information Ratio calculation
ir_benchmark   <- "EqualWeight"  # or "EW"

#### 1.6 Weight Analysis Options ----------------------------------------------
# Models for detailed weight analysis (heatmaps + stacked charts)
# These are the key models you want to showcase to investors
# Set to NULL to use all BMA models, or specify exact model names
weight_detail_models <- c("BMA-80%", "KNS", "RP-PCA")

# Number of top factors to show in weight time-series plots (per model)
weight_n_top <- 5

# Number of top factors for heatmaps
weight_heatmap_n_top <- 15

# Number of top factors for stacked charts (remainder grouped as "Other")
weight_stacked_n_top <- 8

#### 1.7 Tail Risk Options ----------------------------------------------------
# Benchmark for capture ratio and tail risk comparisons
# Options: "MKTS", "MKTB", "EqualWeight", or any portfolio in factor_vec
tail_risk_benchmark <- "EqualWeight"

# Number of worst months to show in comparison
n_worst_months <- 10

# Number of worst drawdowns to analyze
n_drawdowns <- 5

###############################################################################
## 2. BUILD RESULTS FILE PATH
###############################################################################

# Construct filename: SS_{return_type}_{model_type}_alpha.w={}_beta.w={}_SRscale={tag}_holding_period={}_f1={}_ALL_RESULTS.rds
results_filename <- sprintf(
  "SS_%s_%s_alpha.w=%g_beta.w=%g_SRscale=%s_holding_period=%d_f1=%s_ALL_RESULTS.rds",
  return_type,
  model_type,
  trunc(alpha.w),
  trunc(beta.w),
  tag,
  holding_period,
  toupper(as.character(f1_flag))
)

# Full path: output_root / model_type / filename
results_file <- file.path(output_root, model_type, results_filename)

cat("Looking for results file:\n")
cat("  ", results_file, "\n\n")

###############################################################################
## 3. LOAD COMBINED RESULTS
###############################################################################

cat("Loading combined results...\n")

if (!file.exists(results_file)) {
  stop("Combined results file not found: ", results_file, "\n",
       "Please check your configuration parameters.")
}

combined_results <- readRDS(results_file)

cat("Combined results loaded successfully.\n\n")

###############################################################################
## 4. EXTRACT CONFIGURATION FROM METADATA
###############################################################################

cat("Extracting configuration from metadata...\n")

# Extract paths: use override if enabled, otherwise use metadata
if (path_override) {
  cat("  [PATH OVERRIDE ENABLED]\n")
  # Modify combined_results$metadata$paths directly so evaluate_performance() sees overridden values
  combined_results$metadata$paths$main_path     <- override_main_path
  combined_results$metadata$paths$data_folder   <- override_data_folder
  combined_results$metadata$paths$code_folder   <- override_code_folder
  combined_results$metadata$paths$output_folder <- override_output_folder
}

# Extract metadata (now with overridden paths if path_override = TRUE)
metadata <- combined_results$metadata

# Now extract from (possibly modified) metadata
main_path     <- metadata$paths$main_path
data_folder   <- metadata$paths$data_folder
code_folder   <- metadata$paths$code_folder
output_folder <- metadata$paths$output_folder

# Extract data file names from metadata (these are filenames, not paths)
f2       <- metadata$data_files$f2
R        <- metadata$data_files$R
fac_freq <- metadata$data_files$fac_freq

cat("  Main path:    ", main_path, "\n")
cat("  Data folder:  ", data_folder, "\n")
cat("  Code folder:  ", code_folder, "\n")
cat("  Output folder:", output_folder, "\n")
cat("  f2 files:     ", paste(f2, collapse = ", "), "\n")
cat("  R files:      ", paste(R, collapse = ", "), "\n")
cat("  fac_freq:     ", fac_freq, "\n")
cat("  Window type:  ", metadata$window_type, "\n")
cat("  Holding period: ", metadata$holding_period, " months\n")
cat("  Date range:   ", metadata$date_start, " to ", metadata$date_end, "\n")
cat("  Number of windows: ", metadata$n_windows_success, "\n")
cat("  Vol scale:    ", ifelse(is.null(vol_scale), "None", vol_scale), "\n\n")

###############################################################################
## 5. LOAD DEPENDENCIES
###############################################################################

cat("Loading dependencies...\n")

library(dplyr)
library(lubridate)
library(tidyr)
library(zoo)          # For rolling statistics
library(moments)      # For skewness/kurtosis
library(ggrepel)      # For label repelling in scatter plots
library(patchwork)    # For multi-panel layouts

# Source helper functions (in correct order - validate_and_align_dates first)
source(file.path(code_folder, "validate_and_align_dates.R"))
source(file.path(code_folder, "data_loading_helpers.R"))

# Source evaluate_performance function
source(file.path(code_folder, "evaluate_performance.R"))

# Source plotting library (comprehensive)
source(file.path(code_folder, "plot_portfolio_analytics.R"))

cat("Dependencies loaded.\n\n")

###############################################################################
## 6. INSPECT WEIGHTS PANEL
###############################################################################

cat("Inspecting weights panel...\n")

df_weights <- combined_results$weights_panel

cat("  Dimensions: ", nrow(df_weights), " rows x ", ncol(df_weights), " cols\n")
cat("  Date range: ", min(df_weights$date), " to ", max(df_weights$date), "\n")
cat("  Unique models: ", length(unique(df_weights$model)), "\n")

cat("\nFirst few rows:\n")
print(head(df_weights, 10))

cat("\nUnique models:\n")
print(unique(df_weights$model))

cat("\n")

###############################################################################
## 7. RUN EVALUATE PERFORMANCE
###############################################################################

cat("Running evaluate_performance()...\n\n")

t_start <- Sys.time()

tryCatch({
  
  results <- evaluate_performance(
    combined_results = combined_results,
    main_path        = main_path,
    data_folder      = data_folder,
    f2               = f2,
    R                = R,
    fac_freq         = fac_freq,
    vol_scale        = vol_scale,
    # Plot parameters (for backward compatibility, but now we use plotting library)
    factor_vec       = factor_vec,
    color_vec        = color_vec,
    line_types_vec   = line_types_vec,
    legend_position  = legend_position,
    dollar_step      = dollar_step,
    fig_name         = "oos_cumret.pdf",
    fig_width        = fig_width,
    fig_height       = fig_height,
    verbose          = TRUE
  )
  
  t_end <- Sys.time()
  
  cat("\n")
  cat("========================================\n")
  cat("SUCCESS!\n")
  cat("========================================\n\n")
  cat("Computation time: ", round(difftime(t_end, t_start, units = "secs"), 2), " seconds\n\n")
  
  ###############################################################################
  ## 8. INSPECT RESULTS
  ###############################################################################
  
  # Extract returns (now a list with multiple elements)
  oos_returns_raw <- results$oos_returns_raw
  oos_returns_scaled <- results$oos_returns_scaled
  perf_df <- results$performance
  
  cat("Out-of-sample returns computed:\n")
  cat("  Raw returns dimensions: ", nrow(oos_returns_raw), " rows x ", ncol(oos_returns_raw), " cols\n")
  cat("  Scaled returns dimensions: ", nrow(oos_returns_scaled), " rows x ", ncol(oos_returns_scaled), " cols\n")
  cat("  Date range: ", min(oos_returns_raw$date), " to ", max(oos_returns_raw$date), "\n")
  cat("  Number of models: ", ncol(oos_returns_raw) - 1, "\n")
  cat("  Vol scale applied: ", results$vol_scale, "\n")
  if (!is.na(results$target_vol)) {
    cat("  Target monthly vol: ", round(results$target_vol * 100, 2), "%\n")
  }
  cat("\n")
  
  cat("Column names:\n")
  print(colnames(oos_returns_raw))
  
  cat("\nFirst 10 rows (scaled returns):\n")
  print(head(oos_returns_scaled, 10))
  
  cat("\nLast 10 rows (scaled returns):\n")
  print(tail(oos_returns_scaled, 10))
  
  ###############################################################################
  ## 9. DIAGNOSTIC CHECKS
  ###############################################################################
  
  cat("\n")
  cat("========================================\n")
  cat("DIAGNOSTIC CHECKS\n")
  cat("========================================\n\n")
  
  # Check for missing values
  na_counts <- colSums(is.na(oos_returns_scaled))
  if (any(na_counts > 0)) {
    cat("WARNING: Missing values detected:\n")
    print(na_counts[na_counts > 0])
  } else {
    cat("✓ No missing values\n")
  }
  
  # Check for infinite values
  inf_counts <- colSums(sapply(oos_returns_scaled[, -1], is.infinite))
  if (any(inf_counts > 0)) {
    cat("WARNING: Infinite values detected:\n")
    print(inf_counts[inf_counts > 0])
  } else {
    cat("✓ No infinite values\n")
  }
  
  # Check date continuity
  date_diffs <- diff(as.numeric(oos_returns_scaled$date))
  expected_diff <- 30  # Approximate monthly difference
  gaps <- which(date_diffs > 35)  # More than ~35 days suggests gap
  if (length(gaps) > 0) {
    cat("\nWARNING: Date gaps detected at positions:\n")
    print(gaps)
    cat("Dates with gaps:\n")
    print(oos_returns_scaled$date[gaps])
  } else {
    cat("✓ No significant date gaps\n")
  }
  
  # Sample statistics for first model
  first_model <- colnames(oos_returns_scaled)[2]
  cat("\nSample statistics for ", first_model, " (scaled):\n")
  cat("  Mean return: ", round(mean(oos_returns_scaled[[first_model]], na.rm = TRUE) * 100, 4), "%\n")
  cat("  Std dev: ", round(sd(oos_returns_scaled[[first_model]], na.rm = TRUE) * 100, 4), "%\n")
  cat("  Min return: ", round(min(oos_returns_scaled[[first_model]], na.rm = TRUE) * 100, 4), "%\n")
  cat("  Max return: ", round(max(oos_returns_scaled[[first_model]], na.rm = TRUE) * 100, 4), "%\n")
  
  ###############################################################################
  ## 10. DISPLAY PERFORMANCE TABLES
  ###############################################################################
  
  cat("\n")
  cat("========================================\n")
  cat("PERFORMANCE SUMMARY\n")
  cat("========================================\n\n")
  
  # Round numeric columns only for display
  perf_display <- perf_df
  numeric_cols <- sapply(perf_display, is.numeric)
  perf_display[, numeric_cols] <- round(perf_display[, numeric_cols], 2)
  
  cat("Performance metrics (all models):\n")
  print(perf_display)
  
  # Round numeric columns only for short display
  perf_short_display <- results$performance_short
  if (nrow(perf_short_display) > 0) {
    numeric_cols_short <- sapply(perf_short_display, is.numeric)
    perf_short_display[, numeric_cols_short] <- round(perf_short_display[, numeric_cols_short], 2)
    cat("\nPerformance metrics (short list):\n")
    print(perf_short_display)
  }
  
  ###############################################################################
  ## 11. LATEX TABLE LOCATIONS
  ###############################################################################
  
  cat("\n")
  cat("========================================\n")
  cat("LATEX TABLES SAVED\n")
  cat("========================================\n\n")
  
  tables_dir <- file.path(output_folder, "time_varying", model_type, "tables")
  cat("Tables saved to: ", tables_dir, "\n")
  cat("  - oos_performance_short.tex\n")
  cat("  - oos_performance_full.tex\n")
  
  ###############################################################################
  ## 12. GENERATE PORTFOLIO ANALYTICS PLOTS
  ###############################################################################
  
  if (!is.null(factor_vec) && length(factor_vec) > 0) {
    cat("\n")
    cat("========================================\n")
    cat("GENERATING PORTFOLIO ANALYTICS PLOTS\n")
    cat("========================================\n\n")
    
    # Determine output directory for figures
    figures_base <- file.path(output_folder, "time_varying", model_type)
    
    # Generate plots based on user selections
    all_plots <- list()
    
    if (generate_plots$cumret) {
      all_plots$cumret <- plot_cumret(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        line_types_vec = line_types_vec,
        legend_position = legend_position,
        dollar_step    = dollar_step,
        output_dir     = figures_base,
        fig_name       = "oos_cumret.pdf",
        width          = fig_width,
        height         = fig_height,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$drawdown) {
      all_plots$drawdown <- plot_drawdown(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        line_types_vec = line_types_vec,
        output_dir     = figures_base,
        fig_name       = "oos_drawdown.pdf",
        width          = fig_width,
        height         = 6,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$rolling_sr) {
      all_plots$rolling_sr <- plot_rolling_sr(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        line_types_vec = line_types_vec,
        window         = 36,  # 3-year rolling window
        output_dir     = figures_base,
        fig_name       = "oos_rolling_sr.pdf",
        width          = fig_width,
        height         = 6,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$risk_return) {
      all_plots$risk_return <- plot_risk_return(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_risk_return.pdf",
        width          = 10,
        height         = 8,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$annual_returns) {
      all_plots$annual_returns <- plot_annual_returns(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_annual_returns.pdf",
        width          = 14,
        height         = 7,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$annual_sr) {
      all_plots$annual_sr <- plot_annual_sr(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_annual_sr.pdf",
        width          = 14,
        height         = 7,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$annual_sortino) {
      all_plots$annual_sortino <- plot_annual_sortino(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_annual_sortino.pdf",
        width          = 14,
        height         = 7,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$annual_ir) {
      all_plots$annual_ir <- plot_annual_ir(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        benchmark      = ir_benchmark,
        output_dir     = figures_base,
        fig_name       = "oos_annual_ir.pdf",
        width          = 14,
        height         = 7,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$return_dist) {
      all_plots$return_dist <- plot_return_distribution(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_return_dist.pdf",
        width          = fig_width,
        height         = 7,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$performance_bars) {
      all_plots$performance_bars <- plot_performance_bars(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_performance_bars.pdf",
        width          = 10,
        height         = 8,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$underwater) {
      all_plots$underwater <- plot_underwater(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        output_dir     = figures_base,
        fig_name       = "oos_underwater.pdf",
        width          = 12,
        height         = 8,
        verbose        = TRUE
      )
    }
    
    if (generate_plots$dashboard) {
      all_plots$dashboard <- plot_dashboard(
        df_scaled      = oos_returns_scaled,
        factor_vec     = factor_vec,
        color_vec      = color_vec,
        line_types_vec = line_types_vec,
        output_dir     = figures_base,
        fig_name       = "oos_dashboard.pdf",
        width          = 16,
        height         = 12,
        verbose        = TRUE
      )
    }
    
    cat("\n")
    cat("========================================\n")
    cat("PERFORMANCE FIGURES SAVED\n")
    cat("========================================\n\n")
    
    figures_dir <- file.path(figures_base, "figures")
    cat("Figures saved to: ", figures_dir, "\n")
    n_plots <- sum(unlist(generate_plots))
    cat("Total performance plots generated: ", n_plots, "\n")
  } else {
    cat("\nSkipping performance plots (no factor_vec specified)\n")
  }
  
  ###############################################################################
  ## 13. GENERATE WEIGHT ANALYSIS PLOTS
  ###############################################################################
  
  if (!is.null(factor_vec) && length(factor_vec) > 0) {
    cat("\n")
    cat("========================================\n")
    cat("GENERATING WEIGHT ANALYSIS PLOTS\n")
    cat("========================================\n\n")
    
    # Get weights panel from combined_results
    weights_panel <- combined_results$weights_panel
    
    # Generate weight plots for the models in factor_vec
    # (filter to models that exist in weights_panel)
    weight_models <- intersect(factor_vec, unique(weights_panel$model))
    
    cat("Models in factor_vec: ", paste(factor_vec, collapse = ", "), "\n")
    cat("Models in weights_panel: ", paste(unique(weights_panel$model), collapse = ", "), "\n")
    cat("Intersection (weight_models): ", paste(weight_models, collapse = ", "), "\n\n")
    
    if (length(weight_models) > 0) {
      
      # Create color/linetype vectors for weight_models
      # Match from original vectors if possible, else use defaults
      weight_colors <- sapply(weight_models, function(m) {
        idx <- match(m, factor_vec)
        if (!is.na(idx) && idx <= length(color_vec)) {
          color_vec[idx]
        } else {
          # Use default colors for unmatched models
          get_default_colors(1)
        }
      })
      
      weight_linetypes <- sapply(weight_models, function(m) {
        idx <- match(m, factor_vec)
        if (!is.na(idx) && idx <= length(line_types_vec)) {
          line_types_vec[idx]
        } else {
          "solid"
        }
      })
      
      # 1. Weight time series (top 5 factors per model)
      cat("Generating weight time-series plots...\n")
      weight_ts_plots <- plot_weight_timeseries(
        weights_panel  = weights_panel,
        model_vec      = weight_models,
        n_top          = weight_n_top,
        output_dir     = figures_base,
        verbose        = TRUE
      )
      
      # 2. Weight concentration (HHI) over time
      cat("Generating concentration plot...\n")
      plot_weight_concentration(
        weights_panel  = weights_panel,
        model_vec      = weight_models,
        color_vec      = weight_colors,
        line_types_vec = weight_linetypes,
        output_dir     = figures_base,
        verbose        = TRUE
      )
      
      # 3. Average weight distribution (bar chart)
      cat("Generating weight distribution plot...\n")
      plot_weight_distribution(
        weights_panel  = weights_panel,
        model_vec      = weight_models,
        n_top          = 10,
        output_dir     = figures_base,
        verbose        = TRUE
      )
      
      # 4. Turnover over time
      cat("Generating turnover plot...\n")
      plot_weight_turnover(
        weights_panel  = weights_panel,
        model_vec      = weight_models,
        color_vec      = weight_colors,
        line_types_vec = weight_linetypes,
        output_dir     = figures_base,
        verbose        = TRUE
      )
      
      # 5. Weight summary table
      cat("Generating weight summary...\n")
      plot_weight_summary(
        weights_panel  = weights_panel,
        model_vec      = weight_models,
        output_dir     = figures_base,
        verbose        = TRUE
      )
      
      # 6. Heatmaps for specified models (or BMA models if not specified)
      # Determine which models to generate detailed plots for
      if (!is.null(weight_detail_models) && length(weight_detail_models) > 0) {
        detail_models <- intersect(weight_detail_models, unique(weights_panel$model))
      } else {
        # Default: all BMA models
        detail_models <- weight_models[grepl("^BMA-", weight_models)]
      }
      
      if (length(detail_models) > 0) {
        cat("Generating weight heatmaps for: ", paste(detail_models, collapse = ", "), "...\n")
        for (m in detail_models) {
          plot_weight_heatmap(
            weights_panel  = weights_panel,
            model_name     = m,
            n_top          = weight_heatmap_n_top,
            output_dir     = figures_base,
            verbose        = TRUE
          )
        }
      }
      
      # 7. Stacked charts for specified models
      if (length(detail_models) > 0) {
        cat("Generating stacked weight charts for: ", paste(detail_models, collapse = ", "), "...\n")
        for (m in detail_models) {
          plot_weight_stacked(
            weights_panel  = weights_panel,
            model_name     = m,
            n_top          = weight_stacked_n_top,
            output_dir     = figures_base,
            verbose        = TRUE
          )
        }
      }
      
      cat("\n")
      cat("========================================\n")
      cat("WEIGHT ANALYSIS FIGURES SAVED\n")
      cat("========================================\n\n")
      cat("Weight analysis plots saved to: ", figures_dir, "\n")
      
    } else {
      cat("No models from factor_vec found in weights_panel. Skipping weight plots.\n")
    }
  }
  
  ###############################################################################
  ## 14. GENERATE TAIL RISK PLOTS
  ###############################################################################
  
  if (!is.null(factor_vec) && length(factor_vec) > 0) {
    cat("\n")
    cat("========================================\n")
    cat("GENERATING TAIL RISK PLOTS\n")
    cat("========================================\n\n")
    cat("Tail risk benchmark: ", tail_risk_benchmark, "\n\n")
    
    # 1. VaR comparison
    cat("Generating VaR comparison...\n")
    plot_var_comparison(
      df_scaled  = oos_returns_scaled,
      factor_vec = factor_vec,
      color_vec  = color_vec,
      output_dir = figures_base,
      verbose    = TRUE
    )
    
    # 2. CVaR (Expected Shortfall) comparison
    cat("Generating CVaR comparison...\n")
    plot_cvar_comparison(
      df_scaled  = oos_returns_scaled,
      factor_vec = factor_vec,
      color_vec  = color_vec,
      output_dir = figures_base,
      verbose    = TRUE
    )
    
    # 3. Upside/Downside Capture Ratio
    cat("Generating capture ratio plot...\n")
    plot_capture_ratio(
      df_scaled  = oos_returns_scaled,
      factor_vec = factor_vec,
      benchmark  = tail_risk_benchmark,
      color_vec  = color_vec,
      output_dir = figures_base,
      verbose    = TRUE
    )
    
    # 4. Rolling Win Rate
    cat("Generating rolling win rate...\n")
    plot_rolling_winrate(
      df_scaled      = oos_returns_scaled,
      factor_vec     = factor_vec,
      window         = 36,
      color_vec      = color_vec,
      line_types_vec = line_types_vec,
      output_dir     = figures_base,
      verbose        = TRUE
    )
    
    # 5. Tail Risk Summary Table
    cat("Generating tail risk summary...\n")
    plot_tail_risk_summary(
      df_scaled  = oos_returns_scaled,
      factor_vec = factor_vec,
      benchmark  = tail_risk_benchmark,
      output_dir = figures_base,
      verbose    = TRUE
    )
    
    # 6. Worst Months Comparison
    cat("Generating worst months comparison...\n")
    plot_worst_months(
      df_scaled  = oos_returns_scaled,
      factor_vec = factor_vec,
      n_worst    = n_worst_months,
      color_vec  = color_vec,
      output_dir = figures_base,
      verbose    = TRUE
    )
    
    # 7. Drawdown Recovery Analysis
    cat("Generating drawdown recovery analysis...\n")
    plot_drawdown_recovery(
      df_scaled   = oos_returns_scaled,
      factor_vec  = factor_vec,
      n_drawdowns = n_drawdowns,
      color_vec   = color_vec,
      output_dir  = figures_base,
      verbose     = TRUE
    )
    
    cat("\n")
    cat("========================================\n")
    cat("TAIL RISK FIGURES SAVED\n")
    cat("========================================\n\n")
    cat("Tail risk plots saved to: ", file.path(figures_base, "figures"), "\n")
  }
  
  ###############################################################################
  ## 15. SAVE RESULTS (OPTIONAL)
  ###############################################################################
  
  # Uncomment to save returns to CSV
  # output_file <- file.path(tables_dir, "oos_returns_scaled.csv")
  # write.csv(oos_returns_scaled, file = output_file, row.names = FALSE)
  # cat("\nScaled returns saved to: ", output_file, "\n")
  
}, error = function(e) {
  cat("\n")
  cat("========================================\n")
  cat("ERROR OCCURRED\n")
  cat("========================================\n\n")
  cat("Error message:\n")
  cat(e$message, "\n\n")
  cat("Stack trace:\n")
  print(traceback())
  stop(e)
})

cat("\n")
cat("========================================\n")
cat("DEBUG COMPLETE\n")
cat("========================================\n\n")