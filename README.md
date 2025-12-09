# Co-Pricing Factor Zoo

Bayesian Model Averaging (BMA) for asset pricing with bond and stock factors.

**Platform:** Works on Windows, macOS, and Linux

---

## Data Availability and Provenance

All portfolio data required for full replication is available for download from **Open Source Asset Pricing**:

📥 **Download URL:** https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip

### Data for Main Analyses

| Data File | Source | Provided | Description |
|-----------|--------|----------|-------------|
| `nontraded.csv` | Authors | Yes | 14 non-traded macro and sentiment factors |
| `traded_equity.csv` | Authors | Yes | 24 traded stock factors |
| `traded_bond_excess.csv` | Authors | Yes | 16 traded bond factors (excess returns) |
| `traded_bond_duration_tmt.csv` | Authors | Yes | Bond factors (duration-adjusted) |
| `equity_anomalies_composite_33.csv` | Authors | Yes | 33 stock test asset portfolios |
| `bond_insample_test_assets_50_excess.csv` | Authors | Yes | 50 bond test assets (excess returns) |
| `bond_insample_test_assets_50_duration_tmt.csv` | Authors | Yes | Bond test assets (duration-adjusted) |
| `bond_insample_test_assets_50_duration_tmt_tbond.csv` | Authors | Yes | Treasury test assets |
| `frequentist_factors.csv` | Authors | Yes | Factors for benchmark model comparisons |
| `treasury_oosample_all_excess.csv` | Authors | Yes | 29 out-of-sample U.S. Treasury returns |
| `variance_decomp_results_vuol.rds` | Authors | Yes | Discount rate (DR) vs cash-flow (CF) news decomposition |

All data files are provided in the download package. Monthly observations from January 1986 to December 2022.

---

## Quick Start: Step-by-Step Guide

### Prerequisites

1. **Install R** (version 4.0 or higher): https://cran.r-project.org/
2. **Install required packages** by running this in the R Console:

```r
install.packages(c(
  # Data manipulation
  "lubridate", "dplyr", "tidyr", "purrr", "tibble", "data.table", "rlang",
  # Visualization
  "ggplot2", "RColorBrewer", "scales", "patchwork",
  # Parallel processing
  "parallel", "doParallel", "foreach", "doRNG",
  # Statistics and linear algebra
  "MASS", "Matrix", "matrixStats", "Hmisc", "proxyC",
  # Bayesian estimation
  "BayesianFactorZoo",
  # Output formatting
  "xtable"
))
```

### Step 1: Download Data and Set Up

1. Download or clone this repository
2. Open RStudio and set your working directory to the project folder
3. **Download and extract the data** by running this in the RStudio **Terminal** tab:

```bash
# macOS/Linux:
curl -L -o djm_data.zip https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip
unzip djm_data.zip -d data
rm djm_data.zip

# Windows (PowerShell):
Invoke-WebRequest -Uri "https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip" -OutFile "djm_data.zip"
Expand-Archive -Path "djm_data.zip" -DestinationPath "data"
Remove-Item "djm_data.zip"
```

This will populate the `data/` folder with all required CSV files.

### Step 2: Run the Unconditional Models

**Recommended: Use the Terminal tab in RStudio** (works on all platforms without PATH issues)

1. Open RStudio and set your working directory to the project folder
2. Click on the **Terminal** tab (next to Console)
3. Run:

```bash
Rscript _run_all_unconditional.R
```

Or with options:
```bash
Rscript _run_all_unconditional.R --ndraws=5000 --parallel
```

**What this does:**
- Runs 7 different model specifications
- Each model takes ~6-20 minutes depending on your machine
- Creates `.Rdata` files in the `output/unconditional/` folder

**Expected runtime:**
| Model Type | Laptop | Server |
|------------|--------|--------|
| Joint (bond+stock) | ~20 min | ~6 min |
| Bond or Stock only | ~10 min | ~3 min |

### Step 3: Run the Conditional (Time-Varying) Models

In the RStudio Terminal tab:
```bash
Rscript _run_all_conditional.R
```

Or for quick testing:
```bash
Rscript _run_all_conditional.R --ndraws=5000
```

**What this does:**
- Runs 2 models (forward and backward expanding windows) in parallel
- Uses 8 cores total (4 per model)
- Creates `.rds` files in `output/time_varying/`

**Expected runtime:** ~20-40 minutes total (per estimation window: ~20 min laptop, ~6 min server)

### Step 4: Generate Paper Tables and Figures (Unconditional)

In the RStudio Terminal tab:
```bash
Rscript _run_paper_results.R
```

**What this does:**
- Reads the unconditional estimation results
- Creates Tables 1-6 (Panel A) and Table A.2 (`.tex` files) in `output/paper/tables/`
- Creates Figures 2-6, 8-12 (`.pdf` files) in `output/paper/figures/`

### Step 5: Generate Paper Tables and Figures (Conditional)

In the RStudio Terminal tab:
```bash
Rscript _run_paper_conditional_results.R
```

**What this does:**
- Reads the time-varying estimation results
- Creates Figure 7 (cumulative returns) in `output/paper/figures/`
- Creates Table 6 Panel B (out-of-sample trading) in `output/paper/tables/`

### Step 6: Compile the LaTeX Document

In the RStudio Terminal tab:
```bash
Rscript _create_djm_tabs_figs.R
```

**What this does:**
- Generates the main LaTeX document
- Output files in `output/paper/latex/`

> **Note for Windows users:** If you get "'Rscript' is not recognized" in PowerShell or Command Prompt, use the RStudio Terminal instead. The RStudio Terminal automatically has R in the PATH.

---

## Output Files: Where to Find Everything

After running all scripts, your output folder will contain:

```
output/
├── *.Rdata                    # Unconditional model results
├── logs/                      # Timestamped log files
│   ├── log_model_*_YYYYMMDD_HHMMSS.txt    # Unconditional model logs
│   └── log_conditional_*_YYYYMMDD_HHMMSS.txt  # Conditional model logs
├── figures/                   # All PDF figures
│   ├── figure_2_*.pdf         # Posterior probabilities
│   ├── figure_3_*.pdf         # SDF dimensionality
│   ├── figure_4_*.pdf         # Factor bars
│   ├── fig5_*.pdf             # Pricing distributions
│   ├── fig6a_*.pdf, fig6b_*.pdf  # Time-varying heatmaps
│   ├── fig7_*.pdf             # Cumulative returns
│   └── ...
├── tables/                    # All LaTeX tables
│   ├── table_1_*.tex          # Top 5 factors
│   ├── table_2_*.tex          # In-sample pricing
│   ├── table_3_*.tex          # Out-of-sample pricing
│   └── ...
├── time_varying/              # Conditional model results
│   └── bond_stock_with_sp/
│       └── SS_*.rds           # Time-varying estimation results
└── paper/
    └── latex/                 # Final LaTeX document
        ├── djm_main.tex       # Main document
        ├── tables.tex         # Table includes
        ├── figures.tex        # Figure includes
        └── bibliography_*.bib # References
```

---

## List of Tables, Figures and Programs

### Tables (7 Total)

| Table | Description | Output File | Generated By |
|-------|-------------|-------------|--------------|
| Table 1 | Top 5 Factors by Posterior Probability | `table_1_top5_factors.tex` | `_run_paper_results.R` |
| Table 2 | In-Sample Cross-Sectional Pricing | `table_2_is_pricing.tex` | `_run_paper_results.R` |
| Table 3 | Out-of-Sample Cross-Sectional Pricing | `table_3_os_pricing.tex` | `_run_paper_results.R` |
| Table 4 | BMA-SDF Dimensionality & SR by Factor Type | `table_4_sr_by_factor_type.tex` | `_run_paper_results.R` |
| Table 5 | Discount Rate vs Cash-Flow News | `table_5_dr_vs_cf.tex` | `_run_paper_results.R` |
| Table 6 | Trading Performance (Panel A: IS, Panel B: OOS) | `table_6_trading.tex` | `_run_paper_results.R`, `_run_paper_conditional_results.R` |
| Table A.2 | Posterior Probabilities (Appendix) | `table_a2_posterior_probs.tex` | `_run_paper_results.R` |

### Figures (11 Total)

| Figure | Description | Output File | Generated By |
|--------|-------------|-------------|--------------|
| Figure 2 | Posterior Inclusion Probabilities | `figure_2_*.pdf` | `_run_paper_results.R` |
| Figure 3 | Number of Factors & Sharpe Ratio Distributions | `figure_3_*.pdf` | `_run_paper_results.R` |
| Figure 4 | Posterior Probabilities & Market Prices of Risk | `figure_4_*.pdf` | `_run_paper_results.R` |
| Figure 5 | OOS Pricing Distributions (Excess Returns) | `fig5_1_gls.pdf` ... `fig5_4_mape.pdf` | `_run_paper_results.R` |
| Figure 6 | Time-Varying Factor Heatmaps | `fig6a_*.pdf`, `fig6b_*.pdf` | `_run_paper_results.R` |
| Figure 7 | Out-of-Sample Cumulative Returns | `fig7_oos_cumret.pdf` | `_run_paper_conditional_results.R` |
| Figure 8 | OOS Pricing Distributions (Duration-Adjusted) | `fig8_1_gls.pdf` ... `fig8_4_mape.pdf` | `_run_paper_results.R` |
| Figure 9 | Mean vs Covariance Diagnostics (Treasury) | `fig9_1_bond_is.pdf` ... `fig9_4_stock_os.pdf` | `_run_paper_results.R` |
| Figure 10 | SDF Time Series | `fig10_sdf_time_series_bma.pdf` | `_run_paper_results.R` |
| Figure 11 | SDF Conditional Volatility | `fig11_sdf_volatility_bma_capmb_ff5.pdf` | `_run_paper_results.R` |
| Figure 12 | Return Predictability | `fig12a_predictability1m_bma.pdf`, `fig12b_predictability12m_bma.pdf` | `_run_paper_results.R` |

### Programs

| Program | Description | Inputs | Outputs |
|---------|-------------|--------|---------|
| `_run_full_replication.R` | **Single-command full replication** | `data/*.csv` | All outputs below |
| `_run_all_unconditional.R` | Run 7 unconditional BMA models | `data/*.csv` | `output/unconditional/*.Rdata` |
| `_run_all_conditional.R` | Run 2 conditional (time-varying) models | `data/*.csv` | `output/time_varying/**/*.rds` |
| `_run_paper_results.R` | Generate tables and figures (unconditional) | `output/unconditional/*.Rdata` | `output/paper/tables/*.tex`, `output/paper/figures/*.pdf` |
| `_run_paper_conditional_results.R` | Generate Figure 7 and Table 6 Panel B | `output/time_varying/**/*.rds` | `fig7_oos_cumret.pdf`, `table_6_trading.tex` |
| `_create_djm_tabs_figs.R` | Compile LaTeX document | `output/paper/tables/*.tex`, `output/paper/figures/*.pdf` | `output/paper/latex/*.tex` |

---

## Data Files

Place these CSV files in the `data/` folder. All files must have `date` as the first column in `YYYY-MM-DD` format.

### Required Files

| File | Description |
|------|-------------|
| `nontraded.csv` | 14 non-traded factors (macro, sentiment) |
| `traded_equity.csv` | 24 traded stock factors |
| `traded_bond_excess.csv` | 16 traded bond factors (excess returns) |
| `traded_bond_duration_tmt.csv` | Bond factors (duration-adjusted) |
| `equity_anomalies_composite_33.csv` | 33 stock test asset portfolios |
| `bond_insample_test_assets_50_excess.csv` | 50 bond test assets (excess) |
| `bond_insample_test_assets_50_duration_tmt.csv` | Bond test assets (duration-adjusted) |
| `bond_insample_test_assets_50_duration_tmt_tbond.csv` | Treasury test assets |
| `frequentist_factors.csv` | Factors for benchmark comparisons |
| `treasury_oosample_all_excess.csv` | 29 out-of-sample U.S. Treasury returns |

---

## The 7 Unconditional Models

| # | Model | Description | Output File |
|---|-------|-------------|-------------|
| 1 | `stock` | Stock factors only | `excess_stock_*_baseline.Rdata` |
| 2 | `bond_excess` | Bond factors (excess returns) | `excess_bond_*_baseline.Rdata` |
| 3 | `bond_duration` | Bond factors (duration-adjusted) | `duration_bond_*_baseline.Rdata` |
| 4 | `joint_excess` | Joint bond+stock (excess) | `excess_bond_stock_with_sp_*_baseline.Rdata` |
| 5 | `joint_duration` | Joint bond+stock (duration) | `duration_bond_stock_with_sp_*_baseline.Rdata` |
| 6 | `treasury_stock` | Treasury with stock factors | `excess_treasury_*_stock_treasury.Rdata` |
| 7 | `treasury_bond` | Treasury with bond factors | `excess_treasury_*_bond_treasury.Rdata` |

### Run specific models only:

```bash
# Run only models 1 and 4
Rscript _run_all_unconditional.R --models=1,4

# List all available models
Rscript _run_all_unconditional.R --list
```

---

## The 2 Conditional Models

| Model | Direction | Output File |
|-------|-----------|-------------|
| `ExpandingForward` | 1986→2004, 1986→2005, ..., 1986→2022 | `SS_*_ExpandingForward_*_ALL_RESULTS.rds` |
| `ExpandingBackward` | 2004→2022, 2003→2022, ..., 1986→2022 | `SS_*_ExpandingBackward_*_ALL_RESULTS.rds` |

Both models run in parallel automatically (4 cores each, 8 total).

---

## Advanced Options

### Quick test run (fewer MCMC draws)

For testing purposes, you can run with fewer MCMC draws (faster but less accurate):

```bash
# Quick test with 5,000 draws (default is 50,000)
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_conditional.R --ndraws=5000
```

| Draws | Purpose | Runtime (per model) |
|-------|---------|---------------------|
| 50,000 | Full estimation (paper quality) | ~6-20 min |
| 5,000 | Quick test/debugging | ~1-2 min |

### Run models in parallel (faster on multi-core machines)

```bash
# Run unconditional models in parallel with 9 cores
# (2 models at a time, 4 cores each, 1 reserved)
Rscript _run_all_unconditional.R --parallel --cores=9
```

### Dry run (see what would happen without running)

```bash
Rscript _run_all_unconditional.R --dry-run
```

### Get help

```bash
Rscript _run_all_unconditional.R --help
Rscript _run_all_conditional.R --help
```

As a last resort, please email alexander.dickerson1@unsw.edu.au

---

## Replication Information

When scripts run, they automatically log:
- **R version** (e.g., R 4.3.1)
- **Platform** (Windows/macOS/Linux)
- **Package versions** for all required packages

This information appears in the console output and in timestamped log files for reproducibility.

### Log Files

Each model run creates a timestamped log file in `output/logs/`:

| Script | Log File Pattern |
|--------|-----------------|
| `_run_all_unconditional.R` | `log_model_{id}_{name}_YYYYMMDD_HHMMSS.txt` |
| `_run_all_conditional.R` | `log_conditional_{direction}_YYYYMMDD_HHMMSS.txt` |

Example log files:
```
output/logs/
├── log_model_1_stock_20241209_143052.txt
├── log_model_2_bond_excess_20241209_143052.txt
├── log_conditional_ExpandingForward_20241209_160000.txt
└── log_conditional_ExpandingBackward_20241209_160000.txt
```

---

## Troubleshooting

### "Package not found" error
Install the missing package:
```r
install.packages("package_name")
```

### "File not found" error
- Make sure you're running the script from the project root folder
- Check that all data files are in the `data/` folder

### Scripts seem to hang
- Unconditional models take 6-20 minutes each
- Conditional models take 20-40 minutes total
- Check log files in `output/logs/` for progress:
  ```bash
  # On macOS/Linux:
  tail -f output/logs/log_model_*.txt

  # On Windows:
  type output\logs\log_model_*.txt
  ```

### Memory issues
Close other applications. Each model uses ~2-4 GB RAM.

### "Rscript is not recognized" (Windows)
This happens when R is not in your system PATH. **Solution:** Use the RStudio Terminal tab instead of PowerShell or Command Prompt. The RStudio Terminal automatically has R in the PATH.

---

## Summary: Complete Replication

### Option 1: Single Command (Recommended)

Open RStudio, set your working directory to the project folder, then run in the **Terminal** tab:

```bash
Rscript _run_full_replication.R
```

This runs all 5 steps automatically (~2-3 hours total).

**Quick test mode** (~30 min with fewer MCMC draws):
```bash
Rscript _run_full_replication.R --quick
```

### Option 2: Step-by-Step (5 Commands)

```bash
# 1. Run unconditional models (~1-2 hours, parallel by default)
Rscript _run_all_unconditional.R

# 2. Run conditional models (~30-40 min, parallel by default)
Rscript _run_all_conditional.R

# 3. Generate tables and figures (unconditional)
Rscript _run_paper_results.R

# 4. Generate tables and figures (conditional)
Rscript _run_paper_conditional_results.R

# 5. Compile LaTeX document
Rscript _create_djm_tabs_figs.R
```

Done! Check `output/paper/latex/` for the final document.

---

## Project Structure

```
co-pricing-factor-zoo/
├── _run_full_replication.R         # Single-command full replication (recommended)
├── _run_all_unconditional.R        # Run all 7 unconditional models
├── _run_all_conditional.R          # Run 2 conditional models
├── _run_paper_results.R            # Generate tables/figures (unconditional)
├── _run_paper_conditional_results.R # Generate Figure 7 & Table 6B (conditional)
├── _create_djm_tabs_figs.R         # Compile LaTeX document
├── base_document.txt               # LaTeX skeleton for main document
├── figures.txt                     # LaTeX skeleton for figure includes
├── code_base/                      # Core functions (don't modify)
├── data/                           # Your input data files (CSV)
├── output/                         # All results go here
├── requirements.txt                # R version and package versions
├── QUICKSTART.md                   # Quick start guide
├── CLAUDE.md                       # Development guidelines
├── LICENSE                         # CC BY-NC-SA 3.0 license
└── README.md                       # This file
```

### LaTeX Template Files

| File | Description |
|------|-------------|
| `base_document.txt` | LaTeX document skeleton defining the main paper structure, preamble, and section organization |
| `figures.txt` | LaTeX skeleton with figure environments and captions for all paper figures |

These templates are used by `_create_djm_tabs_figs.R` to assemble the final LaTeX document in `output/paper/latex/`.

---

## Requirements

- **R version:** 4.4.2 or higher
- **Required packages:** See `requirements.txt` for exact versions

Install all required packages:
```r
install.packages(c(
  "lubridate", "dplyr", "tidyr", "purrr", "tibble", "data.table", "rlang",
  "ggplot2", "RColorBrewer", "scales", "patchwork",
  "parallel", "doParallel", "foreach", "doRNG",
  "MASS", "Matrix", "matrixStats", "Hmisc", "proxyC",
  "BayesianFactorZoo", "xtable"
))
```

---

## Citation

If you use this code, please cite:

**"The Co-Pricing Factor Zoo"** by Alexander Dickerson, Christian Julliard, and Philippe Mueller.

```bibtex
@article{dickerson2023corporate,
  title   = {The Co-Pricing Factor Zoo},
  author  = {Dickerson, Alexander and Julliard, Christian and Mueller, Philippe},
  journal = {Journal of Financial Economics},
  year    = {2025},
  note    = {Forthcoming}
}
```

## License

See LICENSE file for details.
