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
| 3 | TBD | Not implemented | - |

## Expected Objects in .Rdata

The following objects are expected when loading MCMC results:

| Object | Description | Used By |
|--------|-------------|---------|
| `results` | MCMC results list (gamma_path, lambda_path per prior) | Figure 2, Table A.2 |
| `f1` | Non-traded factors matrix | Figure 2, Table A.2 |
| `f2` | Traded factors matrix | Figure 2, Table A.2 |
| `intercept` | Whether intercept was included | Figure 2, Table A.2 |
| `IS_AP` | In-sample asset pricing results | Future tables |
| `metadata` | Run configuration and metadata | Header info |
| `kns_out` | Kozak-Nagel-Shanken results | Comparison tables |
| `rp_out` | RP-PCA results | Comparison tables |

## Troubleshooting

### File Not Found

If you get "Results file not found":

1. Check that `results_path` points to the correct directory
2. Verify the model configuration matches your MCMC run
3. Confirm the .Rdata file exists with the expected name

### Missing Objects

If objects are missing from loaded data:

1. The MCMC run may have used different settings
2. Check `metadata` object for run configuration
3. Re-run MCMC if needed with `save_flag = TRUE`

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
