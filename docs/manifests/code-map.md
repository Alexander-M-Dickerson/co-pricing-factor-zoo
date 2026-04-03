# Code Map

Complete call graph for the main paper and Internet Appendix replication pipelines.

## Combined Entry Point

`_run_complete_replication.R` — runs both pipelines end-to-end.
Sources: `code_base/audit_helpers.R`.
Calls: `_run_full_replication.R`, then `ia/_run_ia_full.R`.

---

## Main Paper Pipeline

Entry point: `_run_full_replication.R`
Sources: `code_base/conditional_run_helpers.R`, `code_base/unconditional_run_helpers.R`, `code_base/audit_helpers.R`

### Step 1 — Unconditional Estimation

`_run_all_unconditional.R` — estimates 7 unconditional models (parallel or sequential)

Each model dynamically generates a temp script that sources:
- `code_base/logging_helpers.R`
- `code_base/validate_and_align_dates.R`
- `code_base/data_loading_helpers.R`
- `code_base/run_bayesian_mcmc.R` → **main MCMC workhorse**

`run_bayesian_mcmc()` bulk-sources all `code_base/*.R` files, then calls:
- `code_base/psi_to_priorSR_multi_asset_weights.R` — prior SR calibration
- `code_base/parallel_helpers.R` — cluster setup
- `code_base/continuous_ss_sdf_v2_fast.R` + `.cpp` — fast C++ self-pricing kernel
- `code_base/continuous_ss_sdf_fast.R` + `.cpp` — fast C++ no-self-pricing kernel
- `code_base/continuous_ss_sdf_multi_asset_weights.R` — kappa extension (self-pricing)
- `code_base/continuous_ss_sdf_multi_asset_no_sp_weights.R` — kappa extension (no-SP)
- `BayesianFactorZoo/R/continuous_ss_sdf_v2.R` — reference sampler (v2, fallback)
- `BayesianFactorZoo/R/continuous_ss_sdf.R` — reference sampler (v1, fallback)
- `BayesianFactorZoo/R/psi_to_priorSR.R` — upstream prior calibration
- `code_base/insample_asset_pricing.R` — in-sample pricing diagnostics
- `code_base/outsample_asset_pricing.R` — out-of-sample pricing
- `code_base/gmm_estimation.R` — GMM comparison
- `code_base/estim_rppca.R` — RP-PCA comparison
- `code_base/estimate_kns.R` — KNS elastic net comparison
- `code_base/fit_sdf_models.R` — SDF model fitting
- `code_base/get_factor_weights.R` — factor weight extraction
- `code_base/drop_factors.R` — factor dropping utility

### Step 2 — Conditional (Time-Varying) Estimation

`_run_all_conditional.R` → spawns `_run_conditional_direction.R` (forward + backward)

Each direction sources:
- `code_base/conditional_run_helpers.R`
- `code_base/logging_helpers.R`
- `code_base/validate_and_align_dates.R`
- `code_base/data_loading_helpers.R`
- `code_base/run_bayesian_mcmc.R`
- `code_base/run_bayesian_mcmc_time_varying.R` → **conditional MCMC workhorse**
- `code_base/run_time_varying_estimation.R` → expanding-window scheduler

`run_bayesian_mcmc_time_varying()` additionally calls:
- `code_base/insample_asset_pricing_time_varying.R`

### Step 3 — Unconditional Tables and Figures

`_run_paper_results.R`

Sources: `code_base/unconditional_run_helpers.R`, then dynamically:
- `code_base/figure1_simulation.R` — Figure 1 panels
- `code_base/pp_figure_table.R` — posterior probability table/figure
- `code_base/plot_nfac_sr.R` — Figure 2 (nfac vs SR)
- `code_base/pp_bar_plots.R` — Figure 3 (bar plots)
- `code_base/sr_decomposition.R` — SR decomposition
- `code_base/run_sr_decomposition_multi.R` — multi-model SR decomposition
- `code_base/sr_tables.R` — Tables 1, 4, 5
- `code_base/validate_and_align_dates.R`
- `code_base/outsample_asset_pricing.R`
- `code_base/pricing_tables.R` — Tables 2, 3
- `code_base/thousands_outsample_tests.R` — robustness OOS tests
- `code_base/plot_thousands_oos_densities.R` — Figures 5, 8
- `code_base/plot_mean_vs_cov.R` — Figure 4
- `code_base/fit_sdf_models.R`
- `code_base/trading_table.R` — Table 6 Panel A
- `code_base/expanding_runs_plots.R` — Figure 6
- `code_base/plot_cumulative_sr.R` — Figure 9

### Step 4 — Conditional Tables and Figures

`_run_paper_conditional_results.R`

Sources: `code_base/conditional_run_helpers.R`, then dynamically:
- `code_base/validate_and_align_dates.R`
- `code_base/data_loading_helpers.R`
- `code_base/evaluate_performance_paper.R` — portfolio metrics
- `code_base/plot_portfolio_analytics.R` — Figure 7, dashboard plots

### Step 5 — LaTeX Assembly

`_create_djm_tabs_figs.R` — assembles `output/paper/latex/` tree (no code_base sources)

### Step 6 — PDF Compilation

`pdflatex` + `bibtex` (called directly by `_run_full_replication.R`)

---

## Internet Appendix Pipeline

Entry point: `ia/_run_ia_full.R`
Sources: `code_base/audit_helpers.R`

### IA Step 1 — Estimation

`ia/_run_ia_estimation.R` → spawns `ia/_run_ia_model.R` per model (9 models)

Each model sources:
- `code_base/ia_run_helpers.R` — IA model registry (9 configs)
- `code_base/logging_helpers.R`
- `code_base/validate_and_align_dates.R`
- `code_base/data_loading_helpers.R`
- `code_base/run_bayesian_mcmc.R` (same call graph as main Step 1)

### IA Step 2 — Tables and Figures

`ia/_run_ia_results.R`

Sources:
- `code_base/ia_run_helpers.R`
- `code_base/pp_figure_table.R`
- `code_base/pricing_tables.R`
- `code_base/validate_and_align_dates.R`
- `code_base/insample_asset_pricing.R`
- `code_base/outsample_asset_pricing.R`
- `code_base/plot_cumulative_sr.R`
- `code_base/plot_nfac_sr.R`
- `code_base/pp_bar_plots.R`
- `code_base/sr_decomposition.R`
- `code_base/sr_tables.R`

### IA Step 3 — LaTeX Assembly

`ia/_create_ia_latex.R`
Sources: `code_base/ia_run_helpers.R`

### IA Step 4 — PDF Compilation

`pdflatex` + `bibtex` (called by `ia/_run_ia_full.R`)

---

## Setup and Maintenance Tools (not part of replication)

| Script | Purpose |
|--------|---------|
| `tools/bootstrap_packages.R` | Install required R packages |
| `tools/bootstrap_data.R` | Download canonical public data bundle |
| `tools/doctor.R` | System readiness check |
| `tools/audit_run.R` | Post-run manifest generation |
| `tools/validate_repo_docs.R` | Documentation drift check |
| `tools/run_figure1_simulation.R` | Regenerate Figure 1 Monte Carlo (optional) |
| `tools/*.ps1`, `*.cmd`, `*.sh` | Platform wrappers for setup and replication |

## Testing Scripts (not part of replication)

| Script | Purpose |
|--------|---------|
| `testing/validation_helpers.R` | Shared test setup |
| `testing/check_toolchain.R` | C++ compiler diagnostics |
| `testing/validate_continuous_ss_sdf_v2.R` | Fast kernel correctness tests |
| `testing/validate_unconditional_runner_fast.R` | Unconditional runner tests |
| `testing/test_unconditional_full_data_fast.R` | Full-data integration test |
| `testing/benchmark_continuous_ss_sdf_v2.R` | Performance benchmarks |
| `testing/rebuild_both_cpp.R` | Force recompile C++ kernels |
| `testing/test_no_warnings.R` | Warning regression test |
| `testing/create_w_all.R` | Generate IA kappa weights |

## BayesianFactorZoo Package (upstream reference)

| File | Used by pipeline? |
|------|-------------------|
| `R/continuous_ss_sdf.R` | Yes — v1 reference sampler (fallback) |
| `R/continuous_ss_sdf_v2.R` | Yes — v2 reference sampler (fallback) |
| `R/psi_to_priorSR.R` | Yes — prior SR calibration |
| `R/check_input.R` | Yes — input validation |
| `R/import-packages.R` | Yes — package imports |
| `R/BayesianFamaMacBeth.R` | No — unused package export |
| `R/BayesianSDF.R` | No — unused package export |
| `R/FamaMacBeth.R` | No — unused package export |
| `R/SDF_GMM.R` | No — unused package export |
| `R/dirac_ss_sdf_pval.R` | No — unused package function |
