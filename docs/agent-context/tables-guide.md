# Tables Guide

Quick reference for what each main paper table shows and where it is generated.

For a machine-readable exhibit map, use `docs/manifests/exhibits.csv`.

## Table 1

Top factor contributions to the SDF Sharpe ratio across the main model families and prior Sharpe-ratio settings.

- main takeaway: the recurring leaders are `PEADB`, `IVOL`, `PEAD`, `CREDIT`, and `YSP`
- helper path: `code_base/sr_tables.R`
- output family: `output/paper/tables/`

## Table 2

In-sample pricing performance across benchmark models and Bayesian model-averaged specifications.

- key metrics: `R2_gls`, `R2_ols`, `RMSE`, `MAPE`
- object source: `IS_AP` inside saved estimation results
- helper path: `code_base/pricing_tables.R`

## Table 3

Out-of-sample pricing performance using the same metric families as Table 2.

- emphasis: whether BMA performance survives beyond the estimation assets
- helper path: `code_base/pricing_tables.R`

## Table 4

Sharpe-ratio contribution breakdown by factor block.

- factor blocks: non-traded, bond tradable, stock tradable
- helper path: `code_base/sr_tables.R`

## Table 5

Discount-rate versus cash-flow news decomposition of factor contributions.

- supporting input: `data/variance_decomp_results_vuol.rds`
- helper path: `code_base/sr_tables.R`

## Table 6

Trading-performance summary.

- Panel A: in-sample trading statistics from the estimated SDF portfolios
- Panel B: conditional or expanding-window out-of-sample trading results
- helper paths: `code_base/trading_table.R` and `_run_paper_conditional_results.R`

## Table A.1

Full posterior inclusion probabilities across the factor zoo.

- helper path: `code_base/pp_figure_table.R`
- output basename: `table_a1_posterior_probs_*`
- manuscript numbering may differ across paper drafts; follow the output basename and manifest

## `IS_AP` Object Orientation

`IS_AP` is the main saved in-sample pricing summary object. It typically contains:

- `sdf_mim`
- `gamma_bma`
- `lambda_bma`
- `top5_gamma`
- `top5_lambda`
- `R2_gls`
- `R2_ols`
- `RMSE`
- `MAPE`
- benchmark model outputs such as KNS, PCA, or related objects

If a user asks how a table was built, start by locating the relevant saved result object and then the helper function above.
