# Figure IA.17

## Role

Figure IA.17 is the lambda-based appendix companion to Figure 6.

## Panels

- Panel A: forward expanding window
- Panel B: backward expanding window

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/expanding_runs_plots.R`
- Outputs:
  - `output/paper/figures/fig_ia_17a_top5_lambda_psi80.pdf`
  - `output/paper/figures/fig_ia_17b_top5_lambda_psi80.pdf`

## Saved Inputs

- conditional expanding-window `.rds` results

## Common Misreadings

- Figure IA.17 ranks top factors by posterior lambda, not posterior inclusion probability.
