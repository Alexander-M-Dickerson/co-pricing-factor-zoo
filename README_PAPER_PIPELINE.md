# Paper Results Pipeline

This document describes the pipeline for generating tables and figures for the academic paper from Bayesian MCMC estimation results.

## Overview

The pipeline consists of:

1. **`_run_paper_results.R`** - Main runner script that loads results and generates all outputs
2. **`code_base/`** - Helper functions for table/figure generation
3. **`output/paper/`** - Generated tables and figures

## Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Run MCMC Estimation                                         │
│     _run_unconditional_model.R  →  output/{model}/*.Rdata       │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Generate Intermediate Data                                  │
│     run_sr_decomposition_multi()  →  data/sr_decomposition_results.rds │
│     run_pricing_multi()           →  data/pricing_results.rds          │
│     run_thousands_oos_tests()     →  data/thousands_oos_results.rds    │
│     run_thousands_oos_tests(duration_mode=TRUE)                        │
│                                   →  data/thousands_oos_results_duration.rds │
└─────────────────────────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Generate Paper Results                                      │
│     _run_paper_results.R  →  output/paper/tables/*.csv          │
│                           →  output/paper/figures/*.pdf         │
└─────────────────────────────────────────────────────────────────┘
```

## File Naming Convention

### Input .Rdata Files

Format: `{return_type}_{model_type}_alpha.w={alpha.w}_beta.w={beta.w}_kappa={kappa}_{tag}.Rdata`

Examples:
- `excess_bond_stock_with_sp_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata`
- `excess_stock_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata`
- `duration_bond_alpha.w=1_beta.w=1_kappa=0_baseline.Rdata`

### Output Files

Tables: `output/paper/tables/table_{N}_{description}.{csv,tex}`
Figures: `output/paper/figures/figure_{N}_{description}.{pdf,png}`

## Configuration Parameters

| Parameter | Description | Options |
|-----------|-------------|---------|
| `model_type` | Asset class model | `"bond"`, `"stock"`, `"bond_stock_with_sp"`, `"treasury"` |
| `return_type` | Return measure | `"excess"`, `"duration"` |
| `tag` | Run identifier | Any string (e.g., `"baseline"`) |
| `alpha.w` | Beta prior hyperparameter | Numeric (default: 1) |
| `beta.w` | Beta prior hyperparameter | Numeric (default: 1) |
| `kappa` | Factor tilt | Numeric (default: 0) |

## Adding New Tables/Figures

### Step 1: Create Helper Function (if needed)

Add reusable functions to `code_base/` with roxygen2 documentation:

```r
#' Generate summary statistics table
#'
#' @param IS_AP In-sample asset pricing results
#' @param ... Additional arguments
#' @return Data frame with summary statistics
generate_summary_table <- function(IS_AP, ...) {
  # Implementation
}
```

### Step 2: Add to Runner Script

In `_run_paper_results.R`, add a new section:

```r
#### Table N: Summary Statistics ----------------------------------------------
if (verbose) message("Table N: Summary Statistics")

# Generate table
table_n <- generate_summary_table(IS_AP)

# Save table
save_table(table_n, "table_N_summary_stats")
```

### Step 3: Update This README

Add the table/figure to the index below.

## Tables Index

| Table | Description | Status | Helper Function |
|-------|-------------|--------|-----------------|
| 1 | Top 5 factor contributions to SDF | **Implemented** | `generate_table_1()` |
| 2 | In-sample cross-sectional asset pricing | **Implemented** | `generate_table_2()` |
| 3 | Out-of-sample cross-sectional asset pricing | **Implemented** | `generate_table_3()` |
| 4 | BMA-SDF dimensionality & SR by factor type | **Implemented** | `generate_table_4()` |
| 5 | Discount rate vs cash-flow news | **Implemented** | `generate_table_5()` |
| A.2 | Posterior probabilities and risk prices | **Implemented** | `pp_figure_table()` |

## Figures Index

| Figure | Description | Status | Helper Function |
|--------|-------------|--------|-----------------|
| 1 | TBD | Not implemented | - |
| 2 | Posterior probability plot | **Implemented** | `pp_figure_table()` |
| 3 | Number of factors & Sharpe ratio distributions | **Implemented** | `plot_nfac_sr()` |
| 4 | Posterior probabilities & market prices of risk | **Implemented** | `pp_bar_plots()` |
| 5 | Thousands OOS pricing tests (excess) | **Implemented** | `plot_thousands_oos_densities()` |
| 8 | Thousands OOS pricing tests (duration) | **Implemented** | `plot_thousands_oos_densities()` |
| 9 | Mean vs Covariance diagnostic plots (Treasury) | **Implemented** | `plot_mean_vs_cov()` |

## Expected Objects in .Rdata

The following objects are expected when loading MCMC results:

| Object | Description | Used By |
|--------|-------------|---------|
| `results` | MCMC results list (gamma_path, lambda_path, sdf_path, bma_sdf per prior) | Figures 2-4, Tables 1/4/5, Table A.2 |
| `f1` | Non-traded factors matrix (T × N1) | Figures 2, 4, Tables 1/4/5, Table A.2 |
| `f2` | Traded factors matrix (T × N2), NULL for treasury | Figures 2, 4, Tables 1/4/5, Table A.2 |
| `intercept` | Whether intercept was included | Figures 2, 4, Tables 1/4/5, Table A.2 |
| `nontraded_names` | Character vector of non-traded factor names | Figure 4, Tables 1/4/5 |
| `bond_names` | Character vector of bond tradable factor names | Figure 4, Tables 1/4/5 |
| `stock_names` | Character vector of stock tradable factor names | Figure 4, Tables 1/4/5 |
| `IS_AP` | In-sample asset pricing results | Future tables |
| `kns_out` | Kozak-Nagel-Shanken results | Comparison tables |
| `rp_out` | RP-PCA results | Comparison tables |

### Results Structure Detail

The `results` object is a list with one element per prior shrinkage level (default: 20%, 40%, 60%, 80%).

Each element contains:

**`gamma_path`** - Posterior inclusion indicators (posterior probabilities)
- Dimensions: `ndraws × N` (N = number of factors)
- Binary 0/1 values for each MCMC draw
- `colMeans(gamma_path)` = posterior probability factor j is included
- Tables are sorted by **average** probability across all shrinkage levels

**`lambda_path`** - Market prices of risk
- Dimensions: `ndraws × (1+N)` when `intercept = TRUE`, else `ndraws × N`
- First column is the intercept/constant when included
- `colMeans(lambda_path) * sqrt(12)` = annualized risk prices (for monthly data)

**`sdf_path`** - Stochastic discount factor paths
- Dimensions: `ndraws × T` (T = number of time periods)
- Each row is one MCMC draw, each column is one time period

**`bma_sdf`** - Bayesian model-averaged SDF
- Vector of length T (one value per time period)

### Figure 3: Number of Factors & Sharpe Ratio

Figure 3 uses `gamma_path` and `sdf_path` to show:

**Panel (A): Posterior distribution of number of factors**
- Histogram of `rowSums(gamma_path)` - counts included factors per MCMC draw
- Shows posterior median and 95% credible interval
- Horizontal dashed line = prior distribution (uniform = 1/N)

**Panel (B): Posterior distribution of SDF-implied Sharpe ratio**
- Density of `sd(sdf_path) * sqrt(12)` - annualized SR from SDF volatility
- Shaded region = 90% credible interval (5th to 95th percentile)

By default, Figure 3 uses the highest shrinkage level (80% prior SR).

### Figure 4: Posterior Probabilities & Market Prices of Risk

Figure 4 uses `gamma_path` and `lambda_path` to show bar plots:

**Panel (A): Posterior probabilities**
- Bar chart of `colMeans(gamma_path)` for each factor
- Factors ordered by posterior probability (low to high)
- Dashed line at prior probability threshold (default: 0.50)
- Colors: Non-traded (dark blue), Bond (light blue), Equity (red)

**Panel (B): Posterior market prices of risk**
- Bar chart of `colMeans(lambda_path) * sqrt(12)` (annualized)
- Same factor ordering as Panel A
- Legend shows factor type categories

By default, Figure 4 uses the highest shrinkage level (80% prior SR).

**Output file:** `figure_4_posterior_bars_{return_type}_{model_type}_{tag}.pdf`

### SR Decomposition (Tables 1, 4, 5)

The `sr_decomposition()` function decomposes the SDF Sharpe ratio by factor groups.
This is the foundation for Tables 1, 4, and 5.

#### Mathematical Background

The stochastic discount factor (SDF) is constructed as:

```
m_t = 1 - (f_t - E[f])' · (λ / σ_f)
```

where:
- `f_t` = factor realizations at time t (T × K matrix)
- `λ` = market prices of risk from MCMC posterior
- `σ_f` = factor standard deviations

For a subset of factors S ⊆ {1, ..., K}, the **group-specific SDF** is:

```
m_S,t = 1 - (f_S,t - E[f_S])' · (λ_S / σ_S)
```

The **annualized Sharpe ratio** for group S is:

```
SR_S = √12 · σ(m_S)
```

The **squared SR contribution ratio** measures the fraction of total SDF variance
explained by factors in group S:

```
SR²_S / SR²_m = Var(m_S) / Var(m)
```

#### Output Metrics

For each factor group and shrinkage level, `sr_decomposition()` computes:

| Metric | Description | Formula |
|--------|-------------|---------|
| `Mean` | Expected number of included factors | E[|S|] |
| `5%`, `95%` | 90% credible interval for |S| | Quantiles of Σγ_j |
| `E[SR_f\|data]` | Posterior mean group Sharpe ratio | E[SR_S] |
| `E[SR²_f/SR²_m\|data]` | Posterior mean SR² contribution | E[Var(m_S)/Var(m)] |

#### Factor Groups

The decomposition analyzes these factor groups:

| Group | Description |
|-------|-------------|
| Nontraded factors | Factors in f1 (macro, sentiment, etc.) |
| Tradable factors | Factors in f2 (bond + stock) |
| Bond tradable factors | Bond-related tradable factors |
| Stock tradable factors | Stock-related tradable factors |
| DR factors | Discount rate news factors |
| CF factors | Cash-flow news factors |
| Top N Factors | Highest posterior probability factors |
| All factors | Complete factor set |

#### Wrapper Function: `run_sr_decomposition_multi()`

Runs `sr_decomposition()` across multiple model types and saves combined results:

```r
res_tbl_top <- run_sr_decomposition_multi(
  results_path = "output/unconditional",
  data_path    = "data",
  model_types  = c("bond_stock_with_sp", "stock", "bond"),
  top_factors  = 5
)
```

Output structure:
```r
res_tbl_top$bond_stock_with_sp  # tibble for combined model
res_tbl_top$stock               # tibble for stock-only model
res_tbl_top$bond                # tibble for bond-only model
```

Saved to: `data/sr_decomposition_results.rds`

### Table Generation: `sr_tables.R`

The `sr_tables.R` module generates LaTeX tables from SR decomposition results.

#### Main Functions

| Function | Description | Output File |
|----------|-------------|-------------|
| `generate_table_1()` | Top 5 factor contributions | `table_1_top5_factors.tex` |
| `generate_table_4()` | SR decomposition by factor type | `table_4_sr_by_factor_type.tex` |
| `generate_table_5()` | DR vs CF decomposition | `table_5_dr_vs_cf.tex` |
| `generate_sr_tables()` | Generate all tables at once | All above |

#### Usage

```r
# Generate all tables
sr_table_results <- generate_sr_tables(
  res_tbl_top  = res_tbl_top,
  output_path  = "output/paper/tables",
  tables       = c(1, 4, 5),
  verbose      = TRUE
)

# Or generate individual tables
generate_table_1(res_tbl_top, output_path = "output/paper/tables")
generate_table_4(res_tbl_top, output_path = "output/paper/tables")
generate_table_5(res_tbl_top, output_path = "output/paper/tables")
```

#### Helper Functions

- `extract_block()` - Extract and pivot a factor group block from sr_decomposition output
- `format_latex_value()` - Format numeric values for LaTeX (handles integers vs decimals)
- `build_latex_row()` - Build a single LaTeX table row with proper formatting

### Pricing Tables: `pricing_tables.R`

The `pricing_tables.R` module generates LaTeX tables for asset pricing performance.

#### Main Functions

| Function | Description | Output File |
|----------|-------------|-------------|
| `run_pricing_multi()` | Collect IS/OS pricing across model types | `pricing_results.rds` |
| `generate_table_2()` | In-sample pricing performance | `table_2_is_pricing.tex` |
| `generate_table_3()` | Out-of-sample pricing performance | `table_3_os_pricing.tex` |
| `generate_pricing_tables()` | Generate both Tables 2 & 3 | All above |

#### Usage

```r
# Step 1: Collect pricing results across model types
pricing_results <- run_pricing_multi(
  results_path = "output/unconditional",
  data_path    = "data",
  model_types  = c("bond_stock_with_sp", "stock", "bond"),
  run_oos      = TRUE
)

# Step 2: Generate tables
generate_pricing_tables(
  pricing_results = pricing_results,
  output_path     = "output/paper/tables",
  tables          = c(2, 3)
)
```

#### Models Included

Tables 2 and 3 include these models (in order):
- BMA-20%, BMA-40%, BMA-60%, BMA-80%
- CAPM, CAPMB, FF5, HKM
- TOP (Top-80%-All), KNS, RPPCA (RP-PCA)

#### Metrics

Both tables report four metrics per panel:
- **RMSE**: Root mean squared pricing error (demeaned)
- **MAPE**: Mean absolute pricing error (demeaned)
- **R²_OLS**: Cross-sectional R² under OLS weighting
- **R²_GLS**: Cross-sectional R² under GLS weighting

### Thousands OOS Tests: `thousands_outsample_tests.R`

The `thousands_outsample_tests.R` module runs OOS pricing across thousands of test asset subset combinations to assess robustness. This is used for Figure 5.

#### Main Functions

| Function | Description | Output File |
|----------|-------------|-------------|
| `run_thousands_oos_tests()` | Master function for all model types | `thousands_oos_results.rds` |
| `os_pricing_fast()` | Lightweight OOS pricing (no date handling) | - |
| `prepare_oos_inputs()` | Pre-compute shared objects for speed | - |
| `run_subset_combos()` | Run all subset combinations in parallel | - |

#### How It Works

1. **Test asset blocks**: OOS assets are divided into contiguous blocks:
   - Equity: 7 blocks (77 portfolios)
   - Bond: 7 blocks (77 portfolios)
   - Co-pricing: 14 blocks (154 portfolios = equity + bond)

2. **Subset combinations**: Every non-empty subset of blocks is tested:
   - Co-pricing: 2^14 - 1 = 16,383 combinations
   - Equity only: 2^7 - 1 = 127 combinations
   - Bond only: 2^7 - 1 = 127 combinations

3. **Parallel execution**: Uses `parallel::mclapply` (fork-based) for speed

4. **Output**: Pricing metrics (RMSE, MAPE, R²_OLS, R²_GLS) for each combination

#### Usage

```r
# Run thousands of OOS tests
thousands_oos_results <- run_thousands_oos_tests(
  results_path   = "output/unconditional",
  data_path      = "data",
  model_types    = c("bond_stock_with_sp", "stock", "bond"),
  n_cores        = parallel::detectCores() - 1,
  save_output    = TRUE,
  output_path    = "data",
  output_name    = "thousands_oos_results.rds"
)
```

#### Output Structure

```r
thousands_oos_results$bond_stock_with_sp  # List with:
  $co_pricing  # data.table: 16,383 rows × metrics
  $equity      # data.table: 127 rows × metrics
  $bond        # data.table: 127 rows × metrics

# Each data.table contains:
# - metric: RMSEdm, MAPEdm, R2OLS, R2GLS
# - Model columns: BMA-20%, BMA-40%, ..., KNS, RP-PCA
# - n_blocks: number of blocks in this subset
# - n_assets: number of assets in this subset
# - combo_id: block indices (e.g., "1-3-5")
```

#### Duration Mode

The function supports duration-adjusted analysis via `duration_mode = TRUE`:

```r
# Duration-adjusted mode
res_dur <- run_thousands_oos_tests(
  results_path = "output/unconditional",
  data_path = "data",
  model_types = c("bond_stock_with_sp", "stock", "bond"),
  duration_mode = TRUE,
  output_name = "thousands_oos_results_duration.rds"
)
```

In duration mode:
- **bond_stock_with_sp**: Loads `duration_bond_stock_with_sp_...Rdata`
- **bond**: Loads `duration_bond_...Rdata`
- **stock**: Loads `excess_stock_...Rdata` (unchanged)
- **Bond OOS file**: Uses `bond_oosample_all_duration_tmt.csv` instead of excess

#### Speed Optimizations

The function is optimized for speed:

1. **`os_pricing_fast()`**: Lightweight pricing without date handling overhead
2. **`prepare_oos_inputs()`**: Pre-compute factor matrices once per model type
3. **`parallel::mclapply`**: Fork-based parallelism on Linux/Mac
4. **`parallel::parLapply`**: PSOCK cluster on Windows
5. **Caching**: Results saved to RDS, loaded if file exists

Typical runtime: ~5-10 minutes per model type on 8+ cores.

### Density Plots: `plot_thousands_oos_densities.R`

The `plot_thousands_oos_densities.R` module generates density plots from thousands OOS results for Figures 5 and 8.

#### Main Functions

| Function | Description | Output Files |
|----------|-------------|--------------|
| `plot_thousands_oos_densities()` | Generate 4 density plots for one figure | `{prefix}_1_gls.pdf`, `{prefix}_2_ols.pdf`, etc. |
| `generate_figures_5_and_8()` | Convenience wrapper for both figures | All 8 plots |

#### Output Files

**Figure 5 (Excess Returns):**
- `fig5_1_gls.pdf` - R2GLS density distributions
- `fig5_2_ols.pdf` - R2OLS density distributions
- `fig5_3_rmse.pdf` - RMSEdm density distributions
- `fig5_4_mape.pdf` - MAPEdm density distributions

**Figure 8 (Duration-Adjusted):**
- `fig8_1_gls.pdf` - R2GLS density distributions
- `fig8_2_ols.pdf` - R2OLS density distributions
- `fig8_3_rmse.pdf` - RMSEdm density distributions
- `fig8_4_mape.pdf` - MAPEdm density distributions

#### What Each Plot Shows

Each density plot shows three overlapping distributions:
- **Co-pricing BMA** (red): IS model = `bond_stock_with_sp`, pricing co_pricing OOS
- **Bond BMA** (blue): IS model = `bond`, pricing co_pricing OOS
- **Stock BMA** (yellow): IS model = `stock`, pricing co_pricing OOS

Annotations show the mean value for each model.

#### Usage

```r
# Figure 5 (excess returns)
plot_thousands_oos_densities(
  thousands_oos_results = thousands_oos_results,
  model_col = "BMA-80%",
  os_estim = "co_pricing",
  output_path = "output/paper/figures",
  figure_prefix = "fig5"
)

# Figure 8 (duration-adjusted)
plot_thousands_oos_densities(
  thousands_oos_results = thousands_oos_results_duration,
  model_col = "BMA-80%",
  os_estim = "co_pricing",
  output_path = "output/paper/figures",
  figure_prefix = "fig8"
)
```

### Shrinkage Levels

The `SRscale` parameter (e.g., `c(0.20, 0.40, 0.60, 0.80)`) controls prior Sharpe ratio shrinkage:
- Values represent % of maximum attainable SR
- Lower = more conservative, Higher = more aggressive factor selection
- `results[[1]]` = 20%, `results[[2]]` = 40%, etc.

### Figure 9: Mean vs Covariance Diagnostic Plots

The `plot_mean_vs_cov.R` module generates diagnostic scatter plots of E[R] vs -cov(M,R) to visualize SDF pricing performance for treasury models.

#### Mathematical Background

The fundamental asset pricing equation states that expected excess returns equal the covariance between returns and the stochastic discount factor (SDF), scaled by the expected SDF:

```
E[R] = -cov(M, R) × (1 / E[M])
```

When the SDF is normalized such that E[M] ≈ 1, this simplifies to:

```
E[R] ≈ -cov(M, R)
```

**Interpretation:**
- Under the null hypothesis that the model is correctly specified, all assets should lie on the **45-degree line** (slope = 1, intercept = 0)
- Deviations from the 45-degree line indicate mispricing
- The **constrained R²** (forcing slope = 1) measures overall pricing fit

#### Computation Details

The function computes annualized values:

```
minus_cov = (1 - cov(R, M))^12 - 1
meansR    = (1 + mean(R))^12 - 1
```

Where:
- `R` = matrix of test asset returns (T × N)
- `M` = BMA SDF from specified shrinkage level (vector of length T)
- The ^12 exponentiation converts monthly to annual returns

#### Constrained vs Unconstrained R²

The plot reports the **constrained R²**, which imposes the theoretically-motivated restriction that the slope equals 1:

```
R²_constrained = 1 - Var(E[R] - (-cov(M,R))) / Var(E[R])
```

This differs from the unconstrained OLS R² which allows the slope to vary freely:

```
R²_OLS = 1 - Var(residuals) / Var(E[R])
```

The constrained R² is more appropriate because under the correct model, the slope should be exactly 1.

#### Output Files

Figure 9 generates 4 plots (2 for each treasury tag):

| File | Description | Treasury Tag |
|------|-------------|--------------|
| `fig9_1_bond_is.pdf` | Bond in-sample | `bond_treasury` |
| `fig9_2_bond_os.pdf` | Bond out-of-sample | `bond_treasury` |
| `fig9_3_stock_is.pdf` | Stock in-sample | `stock_treasury` |
| `fig9_4_stock_os.pdf` | Stock out-of-sample | `stock_treasury` |

#### Plot Elements

Each plot includes:
- **Black dots**: Individual assets (test portfolios)
- **Blue line + ribbon**: OLS fitted regression line with 95% confidence interval
- **Red dashed line**: 45-degree line (theoretical prediction under correct specification)
- **Annotations**: Constrained R² and fitted slope

#### Usage

```r
# Bond treasury (Figure 9.1-9.2)
plot_mean_vs_cov(
  results_path  = "output/unconditional",
  model_type    = "treasury",
  tag           = "bond_treasury",
  data_folder   = "paper.data.rr",
  os_pricing    = "treasury_oosample_all_excess.csv",
  sr_scale      = "80%",
  output_path   = "output/paper/figures",
  figure_prefix = "fig9",
  suffix_is     = "1_bond_is",
  suffix_os     = "2_bond_os"
)

# Stock treasury (Figure 9.3-9.4)
plot_mean_vs_cov(
  results_path  = "output/unconditional",
  model_type    = "treasury",
  tag           = "stock_treasury",
  data_folder   = "paper.data.rr",
  os_pricing    = "treasury_oosample_all_excess.csv",
  sr_scale      = "80%",
  output_path   = "output/paper/figures",
  figure_prefix = "fig9",
  suffix_is     = "3_stock_is",
  suffix_os     = "4_stock_os"
)
```

#### Required Data Files

- **Rdata files** (in `output/unconditional/treasury/`):
  - `excess_treasury_alpha.w=1_beta.w=1_kappa=0_bond_treasury.Rdata`
  - `excess_treasury_alpha.w=1_beta.w=1_kappa=0_stock_treasury.Rdata`

- **OOS data** (in `paper.data.rr/`):
  - `treasury_oosample_all_excess.csv`

## Troubleshooting

### File Not Found

If you get "Results file not found":

1. Check that `results_path` points to the correct directory
2. Verify the model configuration matches your MCMC run
3. Confirm the .Rdata file exists with the expected name

### Missing Objects

If objects are missing from loaded data:

1. The MCMC run may have used different settings
2. Re-run MCMC if needed with `save_flag = TRUE`

## Development Notes

### For Claude

When adding new tables/figures:

1. Follow the existing section pattern with `#### Table N:` comments
2. Use the `save_table()` and `save_figure()` utility functions
3. Update the Tables/Figures Index in this README
4. Add any new helper functions to `code_base/` with proper documentation
5. Test with `verbose = TRUE` to confirm generation

### Code Style

- Use descriptive variable names
- Follow roxygen2 documentation for functions
- Use `sprintf()` for filename construction
- Handle missing data gracefully with informative messages
