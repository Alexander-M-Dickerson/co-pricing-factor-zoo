# Figure 13

## Empirical Question

How does the SDF-implied Sharpe ratio accumulate as factors are added by
posterior importance?

## Short Answer

Figure 13 is the cumulative-Sharpe interpretation figure. It shows how much
additional Sharpe ratio is gained as factors are added in posterior-importance
order, which helps explain why the latent SDF can be dense even when a few
factors stand out.

## Paper Refs

- Figure 13
- Section 3.4
- Eq. (7)

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/plot_cumulative_sr.R`
- Output: `output/paper/figures/fig13_cum_sr_80pct.pdf`

## Saved Inputs

- joint-model unconditional saved results
