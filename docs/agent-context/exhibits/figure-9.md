# Figure 9

## Empirical Question

Is the bond factor zoo mainly pricing the Treasury component of corporate bond
returns rather than the credit component?

## Short Answer

Figure 9 is the paper's sharp Treasury-component diagnostic. It compares the
mean-versus-covariance relationship for Treasury returns and shows why bond
factors matter for the Treasury piece that stock factors do not price well.

## Paper Refs

- Figure 9
- Section 3.3
- Eq. (10)
- `docs/manifests/paper_claims.csv`, Claims 5 and 6

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/plot_mean_vs_cov.R`
- Output family: `output/paper/figures/fig9_*.pdf`

## Saved Inputs

- treasury-model unconditional saved results
- `data/treasury_oosample_all_excess.csv`

## Common Misreadings

- Figure 9 is the Treasury decomposition diagnostic, not the DR-versus-CF decomposition.
- The key comparison is about the Treasury component, not generic out-of-sample bond pricing.
