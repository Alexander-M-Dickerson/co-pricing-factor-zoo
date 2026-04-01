# Internet Appendix

This folder contains the Internet Appendix pipeline for "The Co-Pricing Factor Zoo".

## Models Estimated

The executable source of truth is `ia/_run_ia_estimation.R`. The current IA estimation surface contains nine models:

| # | Model | model_type | intercept | tag |
|---|-------|------------|-----------|-----|
| 1 | bond_intercept | bond | TRUE | ia_intercept |
| 2 | stock_intercept | stock | TRUE | ia_intercept |
| 3 | bond_no_intercept | bond | FALSE | ia_no_intercept |
| 4 | stock_no_intercept | stock | FALSE | ia_no_intercept |
| 5 | joint_no_intercept | bond_stock_with_sp | FALSE | ia_no_intercept |
| 6 | treasury_base | treasury | TRUE | bond_treasury |
| 7 | treasury_weighted | treasury | TRUE | bond_treasury |
| 8 | sparse_joint | bond_stock_with_sp | TRUE | ia_sparse |
| 9 | isos_switch | bond_stock_with_sp | TRUE | ia_isos_switch |

All IA models use `return_type = "excess"`.

Engine notes:

- Models `1-5`, `8`, and `9` are self-pricing IA runs and should use the fast
  C++ backend by default (`continuous_ss_sdf_v2_fast`).
- Models `6` and `7` are treasury runs. Even though their raw configs point to a
  traded-bond file, `run_bayesian_mcmc()` merges those bond factors into the
  no-self-pricing branch for `model_type = "treasury"`.
- `treasury_base` therefore uses `BayesianFactorZoo::continuous_ss_sdf`.
- `treasury_weighted` uses `continuous_ss_sdf_multi_asset_no_sp`.

## Quick Start

From the repo root:

```bash
# IA smoke boundary
Rscript ia/_run_ia_full.R --ndraws=500

# Full IA pipeline
Rscript ia/_run_ia_full.R --ndraws=5000

# Compile the IA PDF after assembly
bash tools/build_ia_paper.sh
```

Public wrappers:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

Validated Windows host path as of April 1, 2026:

- the 500-draw smoke wrapper completed all nine IA models fresh
- the 5,000-draw full wrapper completed estimation, results generation, and LaTeX assembly fresh
- the IA PDF wrapper compiled `ia/output/paper/latex/ia_main.pdf`

## Step-By-Step

### 1. Estimate IA Models

```bash
# Run all IA models
Rscript ia/_run_ia_estimation.R

# Run specific models
Rscript ia/_run_ia_estimation.R --models=1,2,5

# Run sequentially
Rscript ia/_run_ia_estimation.R --sequential

# List available models
Rscript ia/_run_ia_estimation.R --list
```

### 2. Generate IA Tables And Figures

```bash
Rscript ia/_run_ia_results.R
```

### 3. Compile IA LaTeX

```bash
Rscript ia/_create_ia_latex.R
```

To compile the PDF, use the public wrapper:

```bash
bash tools/build_ia_paper.sh
```

## Output Structure

IA outputs are written under `ia/output/`:

- `unconditional/` for saved estimation results
- `logs/` for IA estimation logs
- `paper/tables/` for generated tables
- `paper/figures/` for generated figures
- `paper/latex/` for assembled LaTeX outputs and the IA PDF after running the build wrapper

## Maintenance Note

If this README and `ia/_run_ia_estimation.R` ever disagree, update this README and follow the code until that happens.
