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

## Quick Start

From the repo root:

```bash
# Full IA pipeline
Rscript ia/_run_ia_full.R

# Quick test with fewer draws
Rscript ia/_run_ia_full.R --ndraws=5000

# Skip estimation if IA results already exist
Rscript ia/_run_ia_full.R --skip-estim
```

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

## Output Structure

IA outputs are written under `ia/output/`:

- `unconditional/` for saved estimation results
- `logs/` for IA estimation logs
- `paper/tables/` for generated tables
- `paper/figures/` for generated figures
- `paper/latex/` for assembled LaTeX outputs

## Maintenance Note

If this README and `ia/_run_ia_estimation.R` ever disagree, update this README and follow the code until that happens.
