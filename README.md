# Co-Pricing Factor Zoo

Bayesian Model Averaging (BMA) for asset pricing with bond and stock factors.

**Platform:** Works on Windows, macOS, and Linux

---

## Quick Start: Step-by-Step Guide

### Prerequisites

1. **Install R** (version 4.0 or higher): https://cran.r-project.org/
2. **Install required packages** by running this in R:

```r
install.packages(c(
  "lubridate", "dplyr", "tidyr", "ggplot2",
  "parallel", "doParallel", "foreach",
  "MASS", "Matrix", "Hmisc", "RColorBrewer"
))
```

### Step 1: Download and Set Up

1. Download or clone this repository
2. Place your data files in the `data/` folder (see [Data Files](#data-files) below)

### Step 2: Run the Unconditional Models

Open a terminal/command prompt, navigate to the project folder, and run:

```bash
# On Windows (Command Prompt or PowerShell):
cd C:\path\to\co-pricing-factor-zoo
Rscript _run_all_unconditional.R

# On macOS/Linux:
cd /path/to/co-pricing-factor-zoo
Rscript _run_all_unconditional.R
```

**What this does:**
- Runs 7 different model specifications
- Each model takes ~6-20 minutes depending on your machine
- Creates `.Rdata` files in the `output/` folder

**Expected runtime:**
| Model Type | Laptop | Server |
|------------|--------|--------|
| Joint (bond+stock) | ~20 min | ~6 min |
| Bond or Stock only | ~10 min | ~3 min |

### Step 3: Run the Conditional (Time-Varying) Models

```bash
Rscript _run_all_conditional.R
```

**What this does:**
- Runs 2 models (forward and backward expanding windows) in parallel
- Uses 8 cores total (4 per model)
- Creates `.rds` files in `output/time_varying/`

**Expected runtime:** ~20-40 minutes total

### Step 4: Generate Paper Tables and Figures

```bash
Rscript _run_paper_results.R
```

**What this does:**
- Reads the estimation results
- Creates all tables (`.tex` files) in `output/tables/`
- Creates all figures (`.pdf` files) in `output/figures/`

### Step 5: Compile the LaTeX Document

```bash
Rscript _create_djm_tabs_figs.R
```

**What this does:**
- Generates the main LaTeX document
- Output files in `output/paper/latex/`

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
```

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

---

## Summary: Complete Replication in 5 Commands

```bash
# 1. Navigate to project folder
cd /path/to/co-pricing-factor-zoo

# 2. Run unconditional models (~1-2 hours total)
Rscript _run_all_unconditional.R

# 3. Run conditional models (~30-40 min)
Rscript _run_all_conditional.R

# 4. Generate tables and figures
Rscript _run_paper_results.R

# 5. Compile LaTeX document
Rscript _create_djm_tabs_figs.R
```

Done! Check `output/paper/latex/` for the final document.

---

## Project Structure

```
co-pricing-factor-zoo/
├── _run_all_unconditional.R   # Run all 7 unconditional models
├── _run_all_conditional.R     # Run 2 conditional models
├── _run_paper_results.R       # Generate tables and figures
├── _create_djm_tabs_figs.R    # Compile LaTeX document
├── code_base/                 # Core functions (don't modify)
├── data/                      # Your input data files (CSV)
├── output/                    # All results go here
├── CLAUDE.md                  # Development guidelines
└── README.md                  # This file
```

---

## Citation

If you use this code, please cite the associated paper.

## License

See LICENSE file for details.
