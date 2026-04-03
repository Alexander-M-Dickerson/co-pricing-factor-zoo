# README for "The Co-Pricing Factor Zoo"

(Dickerson, Julliard, and Mueller, *Journal of Financial Economics*, Forthcoming)

Replication repository for [The Co-Pricing Factor Zoo](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4589786).

## Overview

### AI-Assisted Workflows

This repository is fully augmented for AI coding agents (Claude Code,
Codex). Instead of reading docs and running scripts manually, you can
drive the entire workflow conversationally:

1. **Clone** the repo
2. **`/onboard`** — the agent verifies R, compilers, packages, and data; fixes anything missing
3. **`/replicate-paper`** — the agent runs the full pipeline, resumes on failure, and reports results
4. **`/explain-paper`** — ask the agent to explain any table, figure, factor, or method in the paper

No prior knowledge of the codebase is required. See
[Additional Resources](#additional-resources) for full agent setup details.

### Replication Summary

The code in this replication package constructs all tables and figures in the
main paper, Appendix, and Internet Appendix. Data are downloaded from a single public bundle hosted at
[openbondassetpricing.com](https://openbondassetpricing.com). Two main scripts
run all of the code: `_run_full_replication.R` (main paper, ~65 minutes) and
`ia/_run_ia_full.R` (Internet Appendix, ~16 minutes), or the combined wrapper
`_run_complete_replication.R` (~81 minutes total). Runtimes are representative
of a 24-core desktop at 50,000 MCMC draws.

Current coverage:

- all main paper tables and figures
- all main Appendix tables and figures
- Internet Appendix results

## Data Availability and Provenance Statements

### Statement about Rights

- [x] I certify that the author(s) of the manuscript have legitimate access to and permission to use the data used in this manuscript.
- [x] I certify that the author(s) of the manuscript have documented permission to redistribute/publish the data contained within this replication package. Appropriate permissions are documented in the [LICENSE](LICENSE) file.

### License for Data

The data are licensed under a Creative Commons Attribution-NonCommercial-ShareAlike
3.0 Unported License. See [LICENSE](LICENSE) for details.

### Summary of Availability

- [x] All data **are** publicly available.

### Data Availability Summary

| Data Name | Data Files | Location | Provided | Citation |
|-----------|-----------|----------|----------|----------|
| Non-traded factors | `nontraded.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Traded bond factors (excess) | `traded_bond_excess.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Traded bond factors (duration) | `traded_bond_duration_tmt.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Traded equity factors | `traded_equity.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Bond test assets (excess) | `bond_insample_test_assets_50_excess.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Bond test assets (duration) | `bond_insample_test_assets_50_duration_tmt.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Treasury test assets | `bond_insample_test_assets_50_duration_tmt_tbond.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Equity test assets | `equity_anomalies_composite_33.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Frequentist benchmark factors | `frequentist_factors.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Bond OOS test assets (excess) | `bond_oosample_all_excess.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Bond OOS test assets (duration) | `bond_oosample_all_duration_tmt.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Equity OOS test assets | `equity_os_77.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Treasury OOS test assets | `treasury_oosample_all_excess.csv` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| Variance decomposition inputs | `variance_decomp_results_vuol.rds` | `data/` | YES (via bundle) | Dickerson, Julliard, Mueller (2025) |
| IA DR-tilt kappa weights | `w_all.rds` | `ia/data/` | YES (tracked) | Dickerson, Julliard, Mueller (2025) |
| Figure 1 simulation fixtures | `*.RData`, `*.csv`, `*.jpeg` | `misc/figure1_simulation/` | YES (tracked) | Dickerson, Julliard, Mueller (2025) |

### Details on each Data Source

**Canonical public data bundle.** All CSV input files are downloaded from a
single public ZIP archive hosted by the authors at
<https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip>.
The bootstrap script `tools/bootstrap_data.R` downloads and extracts this
bundle into `data/`. No registration, login, or payment is required. Data files
are flat CSV with the first column as a date column (YYYY-MM-DD). A full
inventory of every file, its purpose, and its source is provided in
[docs/manifests/data-files.csv](docs/manifests/data-files.csv).

**Tracked repo files.** The IA kappa-weight file `ia/data/w_all.rds` and the
Figure 1 simulation fixtures under `misc/figure1_simulation/` are tracked in
the repository and ship with the clone. No separate download is needed for
these files.

## Computational Requirements

### Software Requirements

- [x] The replication package contains programs to install all dependencies and set up the necessary directory structure.

- R >= 4.5.0 (code was last run with R 4.5.2)
  - `BayesianFactorZoo` (local package, installed from `BayesianFactorZoo/`)
  - `Rcpp`, `RcppArmadillo` (C++ compilation)
  - `pkgbuild` (build tooling)
  - `MASS` (statistical distributions)
  - `MCMCpack` (MCMC utilities)
  - `matrixStats` (fast matrix operations)
  - `doParallel`, `foreach`, `doRNG` (parallel computation)
  - `processx` (subprocess management)
  - `ggplot2`, `ggtext`, `patchwork`, `RColorBrewer`, `scales` (plotting)
  - `reshape2`, `dplyr`, `tidyr`, `purrr`, `tibble`, `data.table` (data manipulation)
  - `rlang`, `lubridate` (tidyverse utilities)
  - `Hmisc` (statistical utilities)
  - `xtable` (LaTeX table export)
  - `proxyC` (sparse similarity)
  - `PerformanceAnalytics` (return analytics)
  - `rugarch`, `rmgarch` (GARCH modeling)
  - `forecast` (time-series forecasting)
  - The script `tools/bootstrap_packages.R` will install all dependencies and should be run once prior to running other programs.

- C++ toolchain required for Rcpp compilation:
  - Windows: [Rtools](https://cran.r-project.org/bin/windows/Rtools/) (tested with Rtools 4.5)
  - macOS: Xcode Command Line Tools plus the CRAN-recommended GNU Fortran matching the installed R version (see <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>)

- LaTeX distribution (for PDF compilation):
  - Any TeX Live, MiKTeX, or TinyTeX installation with `pdflatex` and `bibtex` on the system PATH
  - If LaTeX is not installed, pass `--skip-pdf` to skip PDF compilation; all tables and figures are still generated

- Portions of the code use PowerShell scripting (Windows) or bash scripting (macOS/Linux).

### Controlled Randomness

- [x] Random seed is set at line 404 of program `_run_all_unconditional.R` (seed = 234)

All MCMC estimation uses a deterministic seed (234) passed through
`run_bayesian_mcmc()`. Within each Gibbs sampler chain, `set.seed(i)` is
called at the start of each prior-shrinkage iteration to ensure
reproducibility across runs. The conditional (time-varying) pipeline uses
the same seed (line 204 of `_run_conditional_direction.R`). The IA pipeline
also uses seed 234 (line 221 of `ia/_run_ia_model.R`). Results are
reproducible to at least 4 decimal places across repeated runs on the same
hardware.

### Memory, Runtime, and Storage Requirements

#### Summary

Approximate time needed to reproduce the analyses on a standard 2024 desktop machine:

- [x] 1-2 hours

Approximate storage space needed:

- [x] 250 MB - 2 GB

#### Computational Details

The code was last run on a **24-core Intel Core Ultra 9 275HX desktop with
128 GB RAM running Windows 11**. The complete replication (main paper + Internet
Appendix) took approximately **81 minutes**.

| Pipeline step | Description | Runtime | Cores used |
|---------------|-------------|---------|------------|
| Main Step 1 | Unconditional estimation (7 models) | ~8 min | 24 |
| Main Step 2 | Conditional estimation (2 directions) | ~46 min | 24 |
| Main Step 3 | Tables & figures (unconditional) | ~10 min | 1 |
| Main Step 4 | Tables & figures (conditional) | <1 min | 1 |
| Main Step 5 | LaTeX assembly | <1 min | 1 |
| Main Step 6 | PDF compilation | <1 min | 1 |
| IA Step 1 | IA estimation (9 models) | ~12 min | 24 |
| IA Step 2 | IA tables & figures | ~4 min | 1 |
| IA Step 3 | IA LaTeX assembly | <1 min | 1 |
| IA Step 4 | IA PDF compilation | <1 min | 1 |

Minimum recommended hardware: 4 cores, 16 GB RAM. Runtime scales
approximately linearly with available cores for estimation steps. With 4
cores, expect approximately 4-6 hours for complete replication.

Storage requirements: the data bundle is ~15 MB. Generated estimation
outputs consume ~500 MB. Total working storage (input + output + temporary
files) is under 1 GB.

## Description of Programs/Code

- `_run_complete_replication.R`: unified entry point that runs both main and IA pipelines
- `_run_full_replication.R`: main six-step replication (estimation, tables/figures, LaTeX, PDF)
- `_run_all_unconditional.R`: batch unconditional estimation across 7 model specifications
- `_run_all_conditional.R`: batch time-varying estimation (forward and backward directions)
- `_run_paper_results.R`: generates all unconditional tables and figures
- `_run_paper_conditional_results.R`: generates conditional paper outputs (Table 6 Panel B, Figure 7)
- `_create_djm_tabs_figs.R`: assembles final LaTeX document tree
- `ia/_run_ia_full.R`: unified IA pipeline (estimation, outputs, LaTeX, PDF)
- `ia/_run_ia_estimation.R`: estimates 9 IA robustness models
- `ia/_run_ia_results.R`: generates IA tables and figures
- `ia/_create_ia_latex.R`: assembles IA LaTeX document tree
- `code_base/`: reusable local implementation modules (MCMC estimation, pricing, plotting)
- `BayesianFactorZoo/`: local copy of the upstream BHJ (2023) R package
- `tools/`: setup, bootstrap, and maintenance utilities
- `testing/`: targeted validation and benchmark scripts

A complete call graph mapping every script to its sourced dependencies is
provided in [docs/manifests/code-map.md](docs/manifests/code-map.md).

### License for Code

The code is licensed under a Creative Commons Attribution-NonCommercial-ShareAlike
3.0 Unported License. See [LICENSE](LICENSE) for details.

## Instructions to Replicators

1. Clone the repository: `git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git`
2. Run `tools/bootstrap_data.*` to download and extract the public data bundle into `data/`.
3. Run `tools/bootstrap_packages.*` to install all required R packages.
4. Run `tools/doctor.*` to verify the environment is ready.
5. Run `tools/run_complete_replication.*` to replicate both the main paper and Internet Appendix.

Platform wrappers are provided for Windows PowerShell (`.ps1`), Windows Command
Prompt (`.cmd`), and macOS/Linux bash (`.sh`). For example, on Windows
PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_data.ps1
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
powershell -ExecutionPolicy Bypass -File tools\run_complete_replication.ps1
```

On macOS Terminal:

```bash
bash tools/bootstrap_data.sh
bash tools/bootstrap_packages.sh
bash tools/doctor.sh --check-only
bash tools/run_complete_replication.sh
```

Expected output:
- main PDF: [djm_main.pdf](output/paper/latex/djm_main.pdf)
- IA PDF: [ia_main.pdf](ia/output/paper/latex/ia_main.pdf)
- replication manifest: `output/replication_manifest_both_<timestamp>.json`

For detailed step-by-step instructions, reduced-draw smoke paths, and
troubleshooting, see [QUICKSTART.md](QUICKSTART.md).

### Details on Various Programs

- `tools/bootstrap_data.*`: downloads the canonical public data bundle and extracts CSV files into `data/`. No registration or authentication required.
- `tools/bootstrap_packages.*`: installs all R package dependencies listed in `tools/bootstrap_packages.R`. Should be run once on a new system.
- `tools/doctor.*`: verifies that all packages, data files, C++ toolchain, and LaTeX are available. Reports any missing components.
- `tools/run_full_replication.*`: runs the main paper pipeline end-to-end (Steps 1-6). Accepts `--quick` for a 5,000-draw setup validation.
- `tools/run_ia_full.*`: runs the IA pipeline end-to-end (Steps 1-4). Accepts `-Draws N` to override the default 50,000 draws.
- `tools/build_paper.*`: compiles the main LaTeX document to PDF (only needed if `--skip-pdf` was passed).
- `tools/build_ia_paper.*`: compiles the IA LaTeX document to PDF.
- `tools/audit_run.R`: post-run audit that validates all expected outputs and generates a replication manifest.
- `tools/run_figure1_simulation.*`: optional script to regenerate the Figure 1 Monte Carlo simulation from scratch (not required for replication; tracked fixtures are used by default).

## List of Tables and Programs

The provided code reproduces:

- [x] All tables and figures in the paper
- [x] Selected Internet Appendix tables and figures, as listed below

The complete exhibit-to-program mapping is in
[docs/manifests/exhibits.csv](docs/manifests/exhibits.csv). Summary:

| Figure/Table | Program | Generator | Output |
|---|---|---|---|
| Table 1 | `_run_paper_results.R` | `code_base/sr_tables.R` | `output/paper/tables/table_1_top5_factors.tex` |
| Table 2 | `_run_paper_results.R` | `code_base/pricing_tables.R` | `output/paper/tables/table_2_is_pricing.tex` |
| Table 3 | `_run_paper_results.R` | `code_base/pricing_tables.R` | `output/paper/tables/table_3_os_pricing.tex` |
| Table 4 | `_run_paper_results.R` | `code_base/sr_tables.R` | `output/paper/tables/table_4_sr_by_factor_type.tex` |
| Table 5 | `_run_paper_results.R` | `code_base/sr_tables.R` | `output/paper/tables/table_5_dr_vs_cf.tex` |
| Table 6 | `_run_paper_results.R` + `_run_paper_conditional_results.R` | `code_base/trading_table.R` + `code_base/evaluate_performance_paper.R` | `output/paper/tables/table_6_trading.tex` |
| Figure 1 | `_run_paper_results.R` | `code_base/figure1_simulation.R` | `output/paper/figures/Fig_01_*.jpeg` |
| Figure 2 | `_run_paper_results.R` | `code_base/pp_figure_table.R` | `output/paper/figures/figure_2_posterior_probs_*.pdf` |
| Figure 3 | `_run_paper_results.R` | `code_base/plot_nfac_sr.R` | `output/paper/figures/figure_3_nfac_sr_*.pdf` |
| Figure 4 | `_run_paper_results.R` | `code_base/pp_bar_plots.R` | `output/paper/figures/figure_4_posterior_bars_*.pdf` |
| Figure 5 | `_run_paper_results.R` | `code_base/plot_thousands_oos_densities.R` | `output/paper/figures/fig5_*.pdf` |
| Figure 6 | `_run_paper_results.R` | `code_base/expanding_runs_plots.R` | `output/paper/figures/fig6a_*.pdf`, `fig6b_*.pdf` |
| Figure 7 | `_run_paper_conditional_results.R` | `code_base/evaluate_performance_paper.R` | `output/paper/figures/fig7_oos_cumret.pdf` |
| Figure 8 | `_run_paper_results.R` | `code_base/plot_thousands_oos_densities.R` | `output/paper/figures/fig8_*.pdf` |
| Figure 9 | `_run_paper_results.R` | `code_base/plot_mean_vs_cov.R` | `output/paper/figures/fig9_*.pdf` |
| Figure 10 | `_run_paper_results.R` | `code_base/fit_sdf_models.R` | `output/paper/figures/fig10_sdf_time_series_bma.pdf` |
| Figure 11 | `_run_paper_results.R` | `code_base/fit_sdf_models.R` | `output/paper/figures/fig11_sdf_volatility_*.pdf` |
| Figure 12 | `_run_paper_results.R` | `code_base/fit_sdf_models.R` | `output/paper/figures/fig12a_*.pdf`, `fig12b_*.pdf` |
| Figure 13 | `_run_paper_results.R` | `code_base/plot_cumulative_sr.R` | `output/paper/figures/fig13_cum_sr_80pct.pdf` |
| Table A.2 | `_run_paper_results.R` | `code_base/pp_figure_table.R` | `output/paper/tables/table_a1_posterior_probs_*.tex` |
| IA Tables 1-7 | `ia/_run_ia_results.R` | Various `code_base/` helpers | `ia/output/paper/tables/table_ia_*.tex` |
| IA Figures | `ia/_run_ia_results.R` | Various `code_base/` helpers | `ia/output/paper/figures/*.pdf` |

## References

Dickerson, Alexander, Christian Julliard, and Philippe Mueller. 2025. "The Co-Pricing
Factor Zoo." *Journal of Financial Economics* (Forthcoming).
<https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4589786>

Bryzgalova, Svetlana, Jiantao Huang, and Christian Julliard. 2023. "Bayesian
Solutions for the Factor Zoo: We Just Ran Two Quadrillion Models." *Journal of
Finance* 78(1): 487-557. <https://doi.org/10.1111/jofi.13197>

Data bundle: Dickerson, Alexander, Christian Julliard, and Philippe Mueller. 2025.
"Co-Pricing Factor Zoo Replication Data [dataset]." Open Source Bond Asset Pricing.
<https://openbondassetpricing.com/wp-content/uploads/2025/12/djm_data.zip>
(accessed March 31, 2026).

---

## Additional Resources

### Use Claude Code or Codex

If you want an agent to drive setup or replication for you, open Claude Code or
Codex in the repo root and use the repo skills below. These are prompts you
type inside the agent session, not shell commands you run in a terminal.

Claude Code:
- `/onboard` to set up a fresh clone
- `/replicate-paper` to run or resume the replication pipeline
- `/explain-paper` to explain tables, figures, factors, and code paths

Codex:
- `$replication-onboard` to set up a fresh clone
- `$replicate-paper` to run or resume the replication pipeline
- `$explain-paper` to explain tables, figures, factors, and code paths

Example prompt for either agent:

`Replicate the main text. If packages or data are missing, bootstrap them automatically first. Use the smallest validated boundary before scaling up, and stop at the first failing step with the exact rerun boundary.`

More agent prompts:
- [docs/agent-context/prompt-recipes.md](docs/agent-context/prompt-recipes.md)

### Supplementary Human References

- [QUICKSTART.md](QUICKSTART.md): full human setup and run guide
- [README_PAPER_PIPELINE.md](README_PAPER_PIPELINE.md): short human boundary map
- [docs/validation/validated_runs.csv](docs/validation/validated_runs.csv): validated runtime and build boundaries
- [docs/manifests/data-files.csv](docs/manifests/data-files.csv): required input checklist
- [docs/manifests/data-sources.csv](docs/manifests/data-sources.csv): canonical public data bundle source
- [docs/manifests/exhibits.csv](docs/manifests/exhibits.csv): table, figure, and IA output map
- [docs/manifests/code-map.md](docs/manifests/code-map.md): complete code call graph
- [docs/manifests/manuscript_exhibits.csv](docs/manifests/manuscript_exhibits.csv): full manuscript exhibit inventory
- [docs/manifests/paper_claims.csv](docs/manifests/paper_claims.csv): claim-to-evidence map
- [docs/acceptance/prompt_harness.csv](docs/acceptance/prompt_harness.csv): acceptance rubric for agent checks
- [docs/validation/agent_acceptance_log.csv](docs/validation/agent_acceptance_log.csv): fresh-thread agent acceptance log

### For Codex / Claude

This repo is also designed for coding agents. Shared surfaces:
- [AGENTS.md](AGENTS.md)
- [docs/agent-context/](docs/agent-context/)
- [docs/manifests/](docs/manifests/)
- [docs/paper/](docs/paper/)

Codex-native: `.codex/config.toml`, `.agents/skills/`
Claude-native: [CLAUDE.md](CLAUDE.md), `.claude/paper-context.md`, `.claude/skills/`
