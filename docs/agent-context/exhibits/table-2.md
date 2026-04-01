# Table 2

## Empirical Question

How well does the BMA-SDF price the in-sample cross-section relative to benchmark
models?

## Short Answer

Table 2 is the main in-sample pricing comparison. It shows that the BMA-based
specifications outperform the benchmark models on the paper's pricing metrics for
the main model families.

## Metrics

- `R2_gls`
- `R2_ols`
- `RMSE`
- `MAPE`

## Paper Refs

- Table 2
- Section 3.2
- `docs/manifests/paper_claims.csv`, Claim 3

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/pricing_tables.R`
- Output: `output/paper/tables/table_2_is_pricing.tex`

## Saved Inputs

- `IS_AP` objects stored inside saved unconditional estimation results

## Common Misreadings

- Table 2 is in-sample only. The out-of-sample comparison is Table 3.
- The pricing table is assembled from saved objects; it does not re-estimate the model during table generation.
