# Quick Start Guide

Replicate **["The Co-Pricing Factor Zoo"](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4589786)** (Dickerson, Julliard, Mueller, JFE 2025) in **1 command**.

> **Important:** All commands should be run from the **root folder** of the repository (`co-pricing-factor-zoo-jfe/`).

---

## 1. Install R and Packages

**R version:** 4.4.2 or higher ([download](https://cran.r-project.org/))

Open R and run:
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

## 2. Clone Repository and Download Data

**Clone the repository:**
```bash
git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo-jfe.git
cd co-pricing-factor-zoo-jfe
```

**Download the data:**

**macOS/Linux:**
```bash
curl -L -o djm_data.zip https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip
unzip djm_data.zip -d data
rm djm_data.zip
```

**Windows (Command Prompt):**
```cmd
curl -L -o djm_data.zip https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip
tar -xf djm_data.zip -C data
del djm_data.zip
```

---

## 3. Run Replication

### Option A: Single Command (Recommended)

```bash
mkdir -p logs
nohup Rscript _run_full_replication.R > logs/full_replication_$(date +%Y%m%d_%H%M%S).log 2>&1 & disown
```

This runs all 5 steps automatically. Runtime varies by hardware: ~1-2.5 hours (server with 24 cores), ~4-6 hours (laptop, with less optimized cores).

### Option B: Step-by-Step

From the project root folder (`co-pricing-factor-zoo-jfe/`):

```bash
# 1. Unconditional models (~15 minutes hours, parallel by default)
Rscript _run_all_unconditional.R

# 2. Conditional models (~1-2 hours, parallel by default)
Rscript _run_all_conditional.R

# 3. Tables & figures (unconditional,~15 minutes)
Rscript _run_paper_results.R

# 4. Tables & figures (conditional, instant)
Rscript _run_paper_conditional_results.R

# 5. Compile LaTeX (instant)
Rscript _create_djm_tabs_figs.R
```

---

## 4. Find Your Results

```
output/
├── paper/
│   ├── tables/     # LaTeX tables (.tex)
│   ├── figures/    # PDF figures (.pdf)
│   └── latex/      # Final LaTeX document
└── logs/           # Execution logs
```

---

## Quick Test Mode

Run with fewer MCMC draws for testing (runtime varies, up to ~45 minutes max on server with many cores):

```bash
mkdir -p logs
nohup Rscript _run_full_replication.R --quick > logs/full_replication_quick_$(date +%Y%m%d_%H%M%S).log 2>&1 & disown
```

Or step-by-step:
```bash
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_conditional.R --ndraws=5000
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Rscript not recognized` | Use RStudio Terminal instead of PowerShell |
| Package not found | Run `install.packages("package_name")` |
| Memory issues | Close other applications (needs ~4 GB RAM) |

**Help:** `Rscript _run_full_replication.R --help`

**Contact:** alexander.dickerson1@unsw.edu.au

---

## Citation

```bibtex
@article{dickerson2023corporate,
  title   = {The Co-Pricing Factor Zoo},
  author  = {Dickerson, Alexander and Julliard, Christian and Mueller, Philippe},
  journal = {Journal of Financial Economics},
  year    = {2025},
  note    = {Forthcoming}
}
```
