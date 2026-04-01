# Figure 6

## Empirical Question

Which factors remain important over time in the expanding-window conditional
exercise?

## Short Answer

Figure 6 is the time-variation view for top factors. Panel A uses the forward
expanding window and Panel B uses the backward expanding window. Together they
show that the importance ranking is not perfectly static through the sample.

## Paper Refs

- Figure 6 Panel A
- Figure 6 Panel B
- Section 3.4

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/expanding_runs_plots.R`
- Outputs:
  - `output/paper/figures/fig6a_top5_prob_psi80.pdf`
  - `output/paper/figures/fig6b_top5_prob_psi80.pdf`

## Saved Inputs

- conditional expanding-window `.rds` results under `output/time_varying/`

## Common Misreadings

- Figure 6 is conditional and time-varying; it does not come from the unconditional saved `.Rdata` files.
- The lambda-based appendix analogue is Figure IA.17.
