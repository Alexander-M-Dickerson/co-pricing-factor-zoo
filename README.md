# Co-Pricing Factor Zoo

Bayesian Model Averaging (BMA) for asset pricing with bond and stock factors. This repository implements the estimation and evaluation framework for identifying which factors from a large "zoo" of candidates are important for pricing both bond and stock returns.

## Overview

This project estimates Stochastic Discount Factor (SDF) models using Bayesian methods that:

- Handle large numbers of candidate factors (54 bond and stock factors)
- Provide posterior probabilities for factor inclusion
- Estimate market prices of risk with uncertainty quantification
- Compare against benchmark models (CAPM, FF5, HKM, KNS, RP-PCA)
- Evaluate pricing performance in-sample and out-of-sample

## Directory Structure

```
co-pricing-factor-zoo/
├── _run_*.R              # Runner scripts (entry points)
├── code_base/            # Core estimation and analysis functions
│   ├── run_*.R           # Main estimation routines
│   ├── *_helpers.R       # Utility functions
│   └── *.R               # Domain-specific functions
├── data/                 # Input data files (CSV format)
├── output/               # Results and figures
│   ├── *.Rdata           # Saved estimation results
│   ├── figures/          # Generated plots (PDF)
│   ├── tables/           # Generated tables (LaTeX)
│   └── paper/            # Paper compilation outputs
│       ├── latex/        # LaTeX document files
│       └── misc/         # Miscellaneous assets
├── CLAUDE.md             # Development guidelines
└── README.md             # This file
```

## Requirements

### R Packages

```r
install.packages(c(
  "lubridate",    # Date handling

  "dplyr",        # Data manipulation
  "tidyr",        # Data reshaping
  "ggplot2",      # Plotting
  "parallel",     # Parallel processing
  "doParallel",   # Parallel backends
  "MASS",         # Statistical functions
  "Matrix",       # Sparse matrices
  "Hmisc",        # Miscellaneous utilities
  "RColorBrewer"  # Color palettes
))
```

## Quick Start

### 1. Set Up Your Data

Place your CSV data files in the `data/` folder. Required files:

| File | Description |
|------|-------------|
| `nontraded.csv` | Non-traded factors (14 macro/sentiment factors) |
| `traded_equity.csv` | Traded stock factors (24 factors) |
| `traded_bond_excess.csv` | Traded bond factors - excess returns (16 factors) |
| `traded_bond_duration_tmt.csv` | Traded bond factors - duration-adjusted |
| `equity_anomalies_composite_33.csv` | Stock test assets (33 portfolios) |
| `bond_insample_test_assets_50_excess.csv` | Bond test assets - excess (50 portfolios) |
| `bond_insample_test_assets_50_duration_tmt.csv` | Bond test assets - duration-adjusted |
| `frequentist_factors.csv` | Factors for benchmark model comparison |

All CSV files must have `date` as the first column in `YYYY-MM-DD` format.

### 2. Run Unconditional Models

The unconditional models estimate factor importance over the full sample period.

**Run all 7 models:**
```bash
Rscript _run_all_unconditional.R
```

**List available models:**
```bash
Rscript _run_all_unconditional.R --list
```

**Run specific models:**
```bash
Rscript _run_all_unconditional.R --models=1,4,5
```

**Run in parallel (recommended for multi-core systems):**
```bash
# With 9 cores: runs 2 models at a time (4 cores each, 1 reserved)
Rscript _run_all_unconditional.R --parallel --cores=9

# With 17 cores: runs 4 models at a time
Rscript _run_all_unconditional.R --parallel --cores=17
```

#### Available Unconditional Models

| ID | Name | Description |
|----|------|-------------|
| 1 | `stock` | Stock factors pricing equity test assets |
| 2 | `bond_excess` | Bond factors pricing bond excess returns |
| 3 | `bond_duration` | Bond factors pricing duration-adjusted returns |
| 4 | `joint_excess` | Joint bond+stock factors with excess returns |
| 5 | `joint_duration` | Joint bond+stock factors with duration-adjusted returns |
| 6 | `treasury_stock` | Stock factors pricing Treasury component |
| 7 | `treasury_bond` | Bond factors pricing Treasury component |

### 3. Run Conditional (Time-Varying) Models

The conditional models estimate factor importance using expanding windows to track how factor relevance changes over time.

```bash
Rscript _run_all_conditional.R
```

### 4. Generate Paper Tables and Figures

After running the models, generate all tables and figures:

```bash
Rscript _run_paper_results.R
```

### 5. Compile LaTeX Document

Generate the LaTeX document with all tables and figures:

```bash
Rscript _create_djm_tabs_figs.R
```

Output files are created in `output/paper/latex/`.

## Model Configuration

### MCMC Parameters

Default settings in runner scripts:

```r
ndraws   <- 50000                      # MCMC iterations
SRscale  <- c(0.20, 0.40, 0.60, 0.80)  # Prior SR shrinkage levels
alpha.w  <- 1                          # Beta prior hyperparameter
beta.w   <- 1                          # Beta prior hyperparameter
kappa    <- 0                          # Factor tilt (0 = no tilt)
```

### Prior Sharpe Ratio Shrinkage

The `SRscale` parameter controls prior shrinkage toward zero:
- **20%**: Strong shrinkage (conservative factor selection)
- **40%**: Moderate-strong shrinkage
- **60%**: Moderate shrinkage
- **80%**: Light shrinkage (more aggressive factor selection)

Results are reported for all four levels.

## Output Files

### Estimation Results (`.Rdata`)

Each model estimation produces an `.Rdata` file containing:

| Object | Description |
|--------|-------------|
| `results` | List of MCMC output per shrinkage level |
| `f1`, `f2` | Factor matrices (non-traded, traded) |
| `R_matrix` | Test asset returns |
| `IS_AP` | In-sample asset pricing results |
| `kns_out` | Kozak-Nagel-Shanken OOS results |
| `rp_out` | RP-PCA results |

### Key Results Objects

**`results[[i]]$gamma_path`**: Binary inclusion indicators
- Dimensions: `ndraws × N_factors`
- `colMeans()` gives posterior inclusion probabilities

**`results[[i]]$lambda_path`**: Market prices of risk
- Dimensions: `ndraws × (1 + N_factors)` if intercept
- Multiply by `sqrt(12)` for annualization

**`IS_AP$is_pricing_result`**: Pricing metrics
- Rows: `RMSEdm`, `MAPEdm`, `R2OLS`, `R2GLS`
- Columns: Model names (BMA-20%, CAPM, FF5, KNS, etc.)

### Generated Figures

| Figure | Description |
|--------|-------------|
| `figure_2_posterior_probs_*.pdf` | Posterior factor probabilities |
| `figure_3_nfac_sr_*.pdf` | SDF dimensionality and Sharpe ratios |
| `figure_4_posterior_bars_*.pdf` | Factor probabilities and risk prices |
| `fig5_*.pdf`, `fig8_*.pdf` | BMA pricing performance distributions |
| `fig6a/b_top5_prob_*.pdf` | Time-varying factor importance |
| `fig7_oos_cumret.pdf` | Out-of-sample cumulative returns |
| `fig10_sdf_time_series_*.pdf` | SDF time series |
| `fig11_sdf_volatility_*.pdf` | SDF volatility dynamics |
| `fig12a/b_predictability_*.pdf` | Return predictability with SDF |

### Generated Tables

| Table | Description |
|-------|-------------|
| `table_1_top5_factors.tex` | Top 5 factors by posterior probability |
| `table_2_is_pricing.tex` | In-sample pricing performance |
| `table_3_os_pricing.tex` | Out-of-sample pricing performance |
| `table_4_sr_by_factor_type.tex` | Sharpe ratios by factor type |
| `table_5_dr_vs_cf.tex` | Discount rate vs. cash flow news |
| `table_6_trading.tex` | Trading strategy performance |
| `table_a1_posterior_probs_*.tex` | Full posterior probabilities (Appendix) |

## Benchmark Models

The framework compares BMA results against:

| Model | Factors |
|-------|---------|
| CAPM | MKTS (stock market) |
| CAPMB | MKTB (bond market) |
| FF5 | MKTS, HML, SMB, DEF, TERM |
| HKM | MKTS, CPTLT |
| KNS | Kozak-Nagel-Shanken latent factors |
| RP-PCA | Risk-premium PCA factors |
| TOP | Top factors by posterior probability |

## Advanced Usage

### Running a Single Model Manually

Edit `_run_unconditional_model.R` directly:

```r
# Set model configuration
model_type  <- "bond_stock_with_sp"
return_type <- "excess"
tag         <- "my_custom_run"

# Set data files
f1 <- "nontraded.csv"
f2 <- c("traded_bond_excess.csv", "traded_equity.csv")
R  <- c("bond_insample_test_assets_50_excess.csv",
        "equity_anomalies_composite_33.csv")

# Run
source("_run_unconditional_model.R")
```

### Customizing Frequentist Benchmarks

```r
frequentist_models <- list(
  CAPM  = "MKTS",
  FF3   = c("MKTS", "HML", "SMB"),
  MyModel = c("MKTS", "MOM", "BAB")
)
```

### Parallel Processing

Each model uses 4 cores by default for the 4 shrinkage levels. Adjust with:

```r
num_cores <- 4  # Cores per model
```

Or via command line:
```bash
Rscript _run_all_unconditional.R --cores-per-model=2
```

## Troubleshooting

### Memory Issues

For large datasets, run garbage collection between models:
```r
gc()
```

### Date Alignment Errors

Ensure all CSV files have:
- First column named `date`
- Format: `YYYY-MM-DD`
- Overlapping date ranges

### Missing Packages

Install all required packages:
```r
source("code_base/install_packages.R")  # If available
```

## Citation

If you use this code, please cite the associated paper.

## License

See LICENSE file for details.
