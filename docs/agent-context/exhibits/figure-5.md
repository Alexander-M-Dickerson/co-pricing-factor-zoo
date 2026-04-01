# Figure 5

## Empirical Question

How robust is excess-return out-of-sample pricing across many alternative
portfolio combinations?

## Short Answer

Figure 5 is the main thousands-of-tests robustness figure for excess-return
out-of-sample pricing. It uses the saved `thousands_oos_results.rds` object and
renders density plots for the paper's key pricing metrics.

## Paper Refs

- Figure 5
- Section 3.2

## Code Path

- Entry script: `_run_paper_results.R`
- Helpers: `code_base/thousands_outsample_tests.R`, `code_base/plot_thousands_oos_densities.R`
- Output family: `output/paper/figures/fig5_*.pdf`

## Saved Inputs

- `data/thousands_oos_results.rds`

## Common Misreadings

- Figure 5 is a robustness distribution, not a single cross-section result.
- The duration-adjusted analogue is Figure 8.
