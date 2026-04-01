# Figures Guide

Quick reference for what each main paper figure shows and where it is generated.

For a machine-readable exhibit map, use `docs/manifests/exhibits.csv`.

## Figure 1

Simulation evidence about noisy proxies and Bayesian model averaging.

- helper path: `code_base/figure1_simulation.R`
- default build: tracked paper-calibration fixtures under `misc/figure1_simulation/`
- regeneration entrypoint: `tools/run_figure1_simulation.R`

## Figure 2

Posterior factor inclusion probabilities across the factor zoo.

- helper path: `code_base/pp_figure_table.R`
- output family: `output/paper/figures/`

## Figure 3

Posterior dimensionality and Sharpe-ratio distribution.

- interpretation: the SDF remains fairly dense
- helper path: `code_base/plot_nfac_sr.R`

## Figure 4

Joint view of posterior inclusion probabilities and market prices of risk.

- helper path: `code_base/pp_bar_plots.R`

## Figure 5

Large-scale out-of-sample pricing density plots for excess-return settings.

- helper paths: `code_base/thousands_outsample_tests.R`, `code_base/plot_thousands_oos_densities.R`

## Figure 6

Top factors over time in the expanding-window exercise.

- helper path: `code_base/expanding_runs_plots.R`
- input source: conditional `.rds` results

## Figure 7

Out-of-sample cumulative returns for the trading comparison.

- generated through `_run_paper_conditional_results.R`
- helper path: `code_base/evaluate_performance_paper.R`

## Figure 8

Thousands-of-tests pricing densities for duration-adjusted return settings.

## Figure 9

Treasury-model mean-versus-covariance comparison plots.

- helper path: `code_base/plot_mean_vs_cov.R`

## Figure 10

Time series of the BMA-SDF level and related fitted dynamics.

- helper path: `code_base/fit_sdf_models.R`

## Figure 11

Conditional volatility comparison for the BMA-SDF against benchmark SDFs.

- helper path: `code_base/fit_sdf_models.R`

## Figure 12

Predictability bar plots for future factor returns using lagged SDF information.

- helper path: `code_base/fit_sdf_models.R`

## Figure 13

Cumulative factor-implied Sharpe ratio as factors are added by posterior importance.

- helper path: `code_base/plot_cumulative_sr.R`

## IA Figures

Appendix figures generally live under `ia/output/paper/figures/` and are produced through `ia/_run_ia_results.R`. When answering an IA figure question, trace the exact figure section inside that script before summarizing.
