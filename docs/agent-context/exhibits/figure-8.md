# Figure 8

## Empirical Question

What happens to out-of-sample pricing when bond returns are adjusted for the
Treasury component?

## Short Answer

Figure 8 is the duration-adjusted analogue of Figure 5. It is one of the main
pieces of evidence behind the paper's Treasury-component argument: once the
Treasury term-structure component is separated out, equity and non-traded
factors do much more of the work.

## Paper Refs

- Figure 8
- Section 3.3
- Eq. (10)
- `docs/manifests/paper_claims.csv`, Claim 5

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/plot_thousands_oos_densities.R`
- Output family: `output/paper/figures/fig8_*.pdf`

## Saved Inputs

- `data/thousands_oos_results_duration.rds`

## Common Misreadings

- Figure 8 is not the Treasury diagnostic itself; that is Figure 9.
- Eq. (10) belongs to the duration-adjusted return decomposition that motivates this exercise.
