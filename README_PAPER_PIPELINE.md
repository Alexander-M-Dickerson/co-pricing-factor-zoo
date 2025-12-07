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
│  2. Generate Paper Results                                      │
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
| 1 | TBD | Not implemented | - |
| A.2 | Posterior probabilities and risk prices | **Implemented** | `pp_figure_table()` |
| 3 | TBD | Not implemented | - |

## Figures Index

| Figure | Description | Status | Helper Function |
|--------|-------------|--------|-----------------|
| 1 | TBD | Not implemented | - |
| 2 | Posterior probability plot | **Implemented** | `pp_figure_table()` |
| 3 | Number of factors & Sharpe ratio distributions | **Implemented** | `plot_nfac_sr()` |

## Expected Objects in .Rdata

The following objects are expected when loading MCMC results:

| Object | Description | Used By |
|--------|-------------|---------|
| `results` | MCMC results list (gamma_path, lambda_path, sdf_path, bma_sdf per prior) | Figure 2, Figure 3, Table A.2 |
| `f1` | Non-traded factors matrix (T × N1) | Figure 2, Table A.2 |
| `f2` | Traded factors matrix (T × N2), NULL for treasury | Figure 2, Table A.2 |
| `intercept` | Whether intercept was included | Figure 2, Table A.2 |
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

### Shrinkage Levels

The `SRscale` parameter (e.g., `c(0.20, 0.40, 0.60, 0.80)`) controls prior Sharpe ratio shrinkage:
- Values represent % of maximum attainable SR
- Lower = more conservative, Higher = more aggressive factor selection
- `results[[1]]` = 20%, `results[[2]]` = 40%, etc.

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
