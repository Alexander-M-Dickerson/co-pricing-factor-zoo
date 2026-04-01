# Figure 2

## Empirical Question

Which factors have the highest posterior inclusion probabilities in the main
co-pricing SDF?

## Short Answer

Figure 2 is the main posterior-probability ranking figure. It visually supports
the headline result that only a handful of factors sit above the 50% prior line,
with `PEADB`, `IVOL`, `PEAD`, `CREDIT`, and `YSP` standing out.

## Paper Refs

- Figure 2
- Section 3.1
- Table A.1
- `docs/manifests/paper_claims.csv`, Claim 1

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/pp_figure_table.R`
- Output family: `output/paper/figures/figure_2_posterior_probs_*.pdf`

## Saved Inputs

- joint-model unconditional saved results

## Common Misreadings

- Figure 2 is about posterior probability, not Sharpe-ratio contribution.
- Table 1 and Figure 2 are related but not interchangeable.
