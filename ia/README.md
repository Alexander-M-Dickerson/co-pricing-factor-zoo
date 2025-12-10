# Internet Appendix

This folder contains scripts to generate the Internet Appendix for "The Co-Pricing Factor Zoo".

## Models Estimated

| Model | model_type | intercept | tag |
|-------|-----------|-----------|-----|
| 1. bond_intercept | bond | TRUE | ia_intercept |
| 2. stock_intercept | stock | TRUE | ia_intercept |
| 3. bond_no_intercept | bond | FALSE | ia_no_intercept |
| 4. stock_no_intercept | stock | FALSE | ia_no_intercept |
| 5. joint_no_intercept | bond_stock_with_sp | FALSE | ia_no_intercept |

All models use `return_type = "excess"`.

## Quick Start

From the project root (`co-pricing-factor-zoo/`):

```bash
# Full replication (estimation + results + LaTeX)
Rscript ia/_run_ia_full.R

# Quick test with fewer draws
Rscript ia/_run_ia_full.R --ndraws=5000

# Skip estimation (if .Rdata files exist)
Rscript ia/_run_ia_full.R --skip-estim
```

## Step-by-Step

### 1. Estimate Models

```bash
# Run all 5 models in parallel (default)
Rscript ia/_run_ia_estimation.R

# Run specific models
Rscript ia/_run_ia_estimation.R --models=1,2,5

# Run sequentially
Rscript ia/_run_ia_estimation.R --sequential

# List available models
Rscript ia/_run_ia_estimation.R --list
```

### 2. Generate Tables and Figures

```bash
Rscript ia/_run_ia_results.R
```

### 3. Compile LaTeX

```bash
Rscript ia/_create_ia_latex.R
```

## Output Structure

```
ia/
├── output/
│   ├── unconditional/           # MCMC results (.Rdata)
│   │   ├── bond/
│   │   ├── stock/
│   │   └── bond_stock_with_sp/
│   ├── logs/                    # Estimation logs
│   └── paper/
│       ├── tables/              # LaTeX tables (.tex)
│       ├── figures/             # PDF figures (.pdf)
│       └── latex/               # Compiled document
│           ├── ia_main.tex
│           ├── ia_tables.tex
│           └── ia_figures.tex
```

## Generated Outputs

### Tables

| Table | Description | Models |
|-------|-------------|--------|
| Posterior probabilities | Factor inclusion probs & risk prices | All 5 |
| IS pricing (Table IA.2) | In-sample pricing metrics | joint_no_intercept |
| OS pricing (Table IA.3) | Out-of-sample pricing metrics | joint_no_intercept |

### Figures

| Figure | Description | Models |
|--------|-------------|--------|
| Posterior probability plot | Factor probs across prior SR levels | All 5 |

## Adding New Tables/Figures

To add new outputs, edit `ia/_run_ia_results.R`:

1. Add a new section after Section 5.3
2. Load model results using `load_model_results()`
3. Generate output and save to `tables_dir` or `figures_dir`
4. The LaTeX compiler will automatically include new files

Example:

```r
###############################################################################
## SECTION 5.4: NEW TABLE/FIGURE
###############################################################################

if (verbose) message("\nGenerating new output...")

# Your code here
# Save to: file.path(tables_dir, "table_ia_new.tex")
# Or:      file.path(figures_dir, "figure_ia_new.pdf")
```
