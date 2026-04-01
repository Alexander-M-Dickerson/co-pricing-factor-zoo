# Figure 10

## Empirical Question

What does the BMA-SDF look like as a time series?

## Short Answer

Figure 10 plots the BMA-SDF level over time. It supports the paper's claim that
the estimated SDF is economically meaningful as a time-series object and not
just a static cross-sectional pricing device.

## Paper Refs

- Figure 10
- Section 3.4
- Eq. (7)
- `docs/manifests/paper_claims.csv`, Claim 7

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/fit_sdf_models.R`
- Output: `output/paper/figures/fig10_sdf_time_series_bma.pdf`

## Saved Inputs

- joint-model unconditional saved results
