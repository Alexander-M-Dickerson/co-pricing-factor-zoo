# Figure 7

## Empirical Question

How does the conditional BMA trading strategy perform out of sample relative to
the comparison strategies?

## Short Answer

Figure 7 is the graphical trading result for the conditional pipeline. It plots
out-of-sample cumulative returns and is the visual companion to Table 6 Panel B.

## Paper Refs

- Figure 7
- Section 3.4
- Table 6 Panel B
- `docs/manifests/paper_claims.csv`, Claim 4

## Code Path

- Entry script: `_run_paper_conditional_results.R`
- Helper: `code_base/evaluate_performance_paper.R`
- Output: `output/paper/figures/fig7_oos_cumret.pdf`

## Saved Inputs

- conditional expanding-window `.rds` results

## Common Misreadings

- Figure 7 depends on the conditional estimation path, not just the unconditional BMA object.
- It is a cumulative-return trading figure, not a pricing-metric density plot.
