# Tracked File Inventory

This file is the authoritative list of every file intentionally tracked in this
repository. The CI validator (`tools/validate_repo_docs.R`) checks that
`git ls-files` matches this manifest on every push. Any tracked file not listed
here will fail CI; any entry here not tracked will also fail.

To update after adding or removing files: edit this manifest, then push.

---

## Root — Pipeline Entry Points and Documentation

```
_run_complete_replication.R           # Single-command full replication (main + IA)
_run_full_replication.R               # Main paper pipeline (Steps 1-6)
_run_all_unconditional.R              # Step 1: batch unconditional estimation (7 models)
_run_all_conditional.R                # Step 2: batch time-varying estimation
_run_conditional_direction.R          # Step 2 helper: single-direction conditional run
_run_paper_results.R                  # Step 3: generate all unconditional tables & figures
_run_paper_conditional_results.R      # Step 4: conditional outputs (Table 6B, Figure 7)
_create_djm_tabs_figs.R               # Step 5: LaTeX document assembly
base_document.txt                     # LaTeX master template for djm_main.tex
figures.txt                           # LaTeX figures template for document assembly
requirements.txt                      # Human-readable R package reference
README.md                             # Primary documentation
QUICKSTART.md                         # Detailed human setup guide
README_PAPER_PIPELINE.md              # Short human boundary map
IS_AP_README.md                       # IS_AP object specification
AGENTS.md                             # AI agent onboarding (Codex / Copilot)
CLAUDE.md                             # Claude-specific project context
LICENSE                                # CC-BY-NC-SA 3.0
MANIFEST.md                           # This file
.gitignore                             # Git ignore rules
.gitattributes                         # Line-ending normalization and binary markers
```

## .agents/ — Codex / Copilot Agent Skills

```
.agents/skills/explain-paper/SKILL.md
.agents/skills/explain-paper/agents/openai.yaml
.agents/skills/explain-paper/references/exhibit-routing.md
.agents/skills/replicate-paper/SKILL.md
.agents/skills/replicate-paper/agents/openai.yaml
.agents/skills/replicate-paper/references/main-text-flow.md
.agents/skills/replication-onboard/SKILL.md
.agents/skills/replication-onboard/agents/openai.yaml
.agents/skills/replication-onboard/references/bootstrap-sequence.md
```

## .claude/ — Claude Code Skills and Context

```
.claude/factors-reference.md
.claude/figures-guide.md
.claude/paper-context.md
.claude/settings.json                  # Shared permissions config (not machine-specific)
.claude/tables-guide.md
.claude/skills/explain-paper/SKILL.md
.claude/skills/onboard/SKILL.md
.claude/skills/replicate-paper/SKILL.md
```

## .codex/ — Codex Configuration

```
.codex/config.toml
```

## .github/ — CI Workflows and Copilot Config

```
.github/copilot-instructions.md
.github/workflows/latex-smoke.yml
.github/workflows/usability-smoke.yml
```

## BayesianFactorZoo/ — Local BHJ (2023) R Package

```
BayesianFactorZoo/AGENTS.override.md
BayesianFactorZoo/DESCRIPTION
BayesianFactorZoo/MD5
BayesianFactorZoo/NAMESPACE
BayesianFactorZoo/R/BayesianFamaMacBeth.R
BayesianFactorZoo/R/BayesianSDF.R
BayesianFactorZoo/R/FamaMacBeth.R
BayesianFactorZoo/R/SDF_GMM.R
BayesianFactorZoo/R/check_input.R
BayesianFactorZoo/R/continuous_ss_sdf.R
BayesianFactorZoo/R/continuous_ss_sdf_v2.R
BayesianFactorZoo/R/dirac_ss_sdf_pval.R
BayesianFactorZoo/R/import-packages.R
BayesianFactorZoo/R/psi_to_priorSR.R
BayesianFactorZoo/data/BFactor_zoo_example.rda
BayesianFactorZoo/inst/REFERENCES.bib
BayesianFactorZoo/man/BFactor_zoo_example.Rd
BayesianFactorZoo/man/BayesianFM.Rd
BayesianFactorZoo/man/BayesianSDF.Rd
BayesianFactorZoo/man/SDF_gmm.Rd
BayesianFactorZoo/man/Two_Pass_Regression.Rd
BayesianFactorZoo/man/continuous_ss_sdf.Rd
BayesianFactorZoo/man/continuous_ss_sdf_v2.Rd
BayesianFactorZoo/man/dirac_ss_sdf_pvalue.Rd
BayesianFactorZoo/man/psi_to_priorSR.Rd
```

## code_base/ — Reusable Analysis Modules

```
code_base/audit_helpers.R              # Post-run audit and manifest generation
code_base/conditional_run_helpers.R    # Conditional estimation utilities
code_base/continuous_ss_sdf_fast.R     # Fast C++ backend (no self-pricing)
code_base/continuous_ss_sdf_fast.cpp
code_base/continuous_ss_sdf_multi_asset_no_sp_weights.R
code_base/continuous_ss_sdf_multi_asset_weights.R
code_base/continuous_ss_sdf_v2_fast.R  # Fast C++ backend (self-pricing)
code_base/continuous_ss_sdf_v2_fast.cpp
code_base/data_loading_helpers.R       # Data loading and alignment
code_base/drop_factors.R
code_base/estim_rppca.R               # RP-PCA estimation
code_base/estimate_kns.R              # KNS benchmark estimation
code_base/evaluate_performance_paper.R # Table 6 Panel B + Figure 7
code_base/expanding_runs_plots.R       # Figures 6, IA.17
code_base/figure1_simulation.R         # Figure 1 simulation panels
code_base/fit_sdf_models.R            # Figures 10-12 (SDF dynamics)
code_base/get_factor_weights.R
code_base/gmm_estimation.R            # GMM SDF estimation
code_base/ia_run_helpers.R            # IA model configuration
code_base/insample_asset_pricing.R     # In-sample pricing
code_base/insample_asset_pricing_time_varying.R
code_base/logging_helpers.R
code_base/outsample_asset_pricing.R    # Out-of-sample pricing
code_base/parallel_helpers.R
code_base/plot_cumulative_sr.R         # Figure 13
code_base/plot_mean_vs_cov.R           # Figure 9
code_base/plot_nfac_sr.R              # Figure 3
code_base/plot_portfolio_analytics.R   # Portfolio analytics plots
code_base/plot_thousands_oos_densities.R  # Figures 5, 8
code_base/pp_bar_plots.R              # Figure 4
code_base/pp_figure_table.R           # Figure 2 + Table A.2
code_base/pricing_tables.R            # Tables 2, 3
code_base/psi_to_priorSR_multi_asset_weights.R
code_base/run_bayesian_mcmc.R          # Main MCMC orchestrator
code_base/run_bayesian_mcmc_time_varying.R
code_base/run_sr_decomposition_multi.R
code_base/run_time_varying_estimation.R
code_base/sr_decomposition.R           # SR decomposition logic
code_base/sr_tables.R                  # Tables 1, 4, 5
code_base/thousands_outsample_tests.R
code_base/trading_table.R             # Table 6 Panel A
code_base/unconditional_run_helpers.R
code_base/validate_and_align_dates.R
```

## docs/ — Manifests, Agent Context, Paper Text

```
docs/acceptance/README.md
docs/acceptance/agent_acceptance_template.md
docs/acceptance/prompt_harness.csv
docs/agent-context/exhibits/README.md
docs/agent-context/exhibits/figure-1.md
docs/agent-context/exhibits/figure-10.md
docs/agent-context/exhibits/figure-11.md
docs/agent-context/exhibits/figure-12.md
docs/agent-context/exhibits/figure-13.md
docs/agent-context/exhibits/figure-2.md
docs/agent-context/exhibits/figure-3.md
docs/agent-context/exhibits/figure-4.md
docs/agent-context/exhibits/figure-5.md
docs/agent-context/exhibits/figure-6.md
docs/agent-context/exhibits/figure-7.md
docs/agent-context/exhibits/figure-8.md
docs/agent-context/exhibits/figure-9.md
docs/agent-context/exhibits/figure-ia-17.md
docs/agent-context/exhibits/ia-implemented-subset.md
docs/agent-context/exhibits/ia-pead-robustness.md
docs/agent-context/exhibits/table-1.md
docs/agent-context/exhibits/table-2.md
docs/agent-context/exhibits/table-3.md
docs/agent-context/exhibits/table-4.md
docs/agent-context/exhibits/table-5.md
docs/agent-context/exhibits/table-6.md
docs/agent-context/exhibits/table-a1.md
docs/agent-context/exhibits/table-a2.md
docs/agent-context/factor-interpretation.md
docs/agent-context/factors-reference.md
docs/agent-context/factors/README.md
docs/agent-context/factors/credit.md
docs/agent-context/factors/ivol.md
docs/agent-context/factors/pead.md
docs/agent-context/factors/peadb.md
docs/agent-context/factors/ysp.md
docs/agent-context/figures-guide.md
docs/agent-context/ia-robustness-guide.md
docs/agent-context/noisy-proxy-guide.md
docs/agent-context/paper-method.md
docs/agent-context/paper-reading-guide.md
docs/agent-context/paper-results-ia.md
docs/agent-context/paper-results-main.md
docs/agent-context/prompt-recipes.md
docs/agent-context/replication-onboarding.md
docs/agent-context/replication-pipeline.md
docs/agent-context/tables-guide.md
docs/agent-context/time-varying-guide.md
docs/agent-context/treasury-component-guide.md
docs/manifests/README.md
docs/manifests/code-map.md
docs/manifests/data-files.csv
docs/manifests/data-sources.csv
docs/manifests/exhibits.csv
docs/manifests/manuscript_exhibits.csv
docs/manifests/paper_claims.csv
docs/paper/README.md
docs/paper/co-pricing-factor-zoo.ai-optimized.md
docs/validation/README.md
docs/validation/agent_acceptance_log.csv
docs/validation/validated_runs.csv
```

## ia/ — Internet Appendix Pipeline

```
ia/AGENTS.md
ia/README.md
ia/_create_ia_latex.R                  # IA LaTeX assembly
ia/_run_ia_estimation.R                # IA estimation (9 models)
ia/_run_ia_full.R                      # IA unified pipeline
ia/_run_ia_model.R                     # Single IA model runner
ia/_run_ia_results.R                   # IA tables & figures
ia/data/w_all.rds                      # Tracked: DR-tilt kappa weights
```

## misc/ — Tracked Fixtures

```
misc/figure1_simulation/Fig_01_0_sim_legend.jpeg
misc/figure1_simulation/Fig_01_1_OLS_60_400_BMA_MPR.jpeg
misc/figure1_simulation/Fig_01_2_OLS_60_1600_BMA_MPR.jpeg
misc/figure1_simulation/Fig_01_3_OLS_60_400_factor_MPRs.jpeg
misc/figure1_simulation/Fig_01_4_OLS_60_1600_factor_MPRs.jpeg
misc/figure1_simulation/Fig_01_5_OLS_60_400_factor_probs.jpeg
misc/figure1_simulation/Fig_01_6_OLS_60_1600_factor_probs.jpeg
misc/figure1_simulation/monthly_return.csv
misc/figure1_simulation/pseudo-true.RData
misc/figure1_simulation/simulation1600psi60.RData
misc/figure1_simulation/simulation400psi60.RData
```

## testing/ — Validation and Benchmark Scripts

```
testing/AGENTS.md
testing/README_OPTIMIZATION_VALIDATION.md
testing/benchmark_continuous_ss_sdf_v2.R
testing/check_toolchain.R
testing/create_w_all.R
testing/latex_smoke/.gitignore
testing/latex_smoke/README.md
testing/latex_smoke/ia/ia_figures.tex
testing/latex_smoke/ia/ia_main.tex
testing/latex_smoke/ia/ia_tables.tex
testing/latex_smoke/main/app_tables.tex
testing/latex_smoke/main/djm_main.tex
testing/latex_smoke/main/figures.tex
testing/latex_smoke/main/smoke_refs.bib
testing/latex_smoke/main/tables.tex
testing/rebuild_both_cpp.R
testing/test_no_warnings.R
testing/test_unconditional_full_data_fast.R
testing/validate_continuous_ss_sdf_v2.R
testing/validate_unconditional_runner_fast.R
testing/validation_helpers.R
```

## tools/ — Setup, Bootstrap, and Maintenance Utilities

```
tools/audit_run.R                      # Post-run audit and manifest generation
tools/audit_run.cmd
tools/audit_run.ps1
tools/audit_run.sh
tools/bootstrap_data.R                 # Download canonical data bundle
tools/bootstrap_data.cmd
tools/bootstrap_data.ps1
tools/bootstrap_data.sh
tools/bootstrap_latex.R                # Install TinyTeX and LaTeX packages
tools/bootstrap_latex.cmd
tools/bootstrap_latex.ps1
tools/bootstrap_latex.sh
tools/bootstrap_packages.R             # Install all R dependencies
tools/bootstrap_packages.cmd
tools/bootstrap_packages.ps1
tools/bootstrap_packages.sh
tools/build_ia_paper.cmd               # Compile IA LaTeX to PDF
tools/build_ia_paper.ps1
tools/build_ia_paper.sh
tools/build_paper.cmd                  # Compile main LaTeX to PDF
tools/build_paper.ps1
tools/build_paper.sh
tools/doctor.R                         # Environment readiness check
tools/doctor.cmd
tools/doctor.ps1
tools/doctor.sh
tools/rebuild_fast_backends.cmd        # Compile C++ backends
tools/rebuild_fast_backends.ps1
tools/rebuild_fast_backends.sh
tools/run_complete_replication.cmd      # Full replication wrapper
tools/run_complete_replication.ps1
tools/run_complete_replication.sh
tools/run_conditional_smoke.cmd        # Conditional smoke test
tools/run_conditional_smoke.ps1
tools/run_conditional_smoke.sh
tools/run_figure1_simulation.R         # Regenerate Figure 1 from scratch
tools/run_figure1_simulation.cmd
tools/run_figure1_simulation.ps1
tools/run_figure1_simulation.sh
tools/run_full_replication.cmd         # Main paper pipeline wrapper
tools/run_full_replication.ps1
tools/run_full_replication.sh
tools/run_ia_full.cmd                  # IA pipeline wrapper
tools/run_ia_full.ps1
tools/run_ia_full.sh
tools/run_ia_smoke.cmd                 # IA smoke test
tools/run_ia_smoke.ps1
tools/run_ia_smoke.sh
tools/validate_repo_docs.R             # CI doc/manifest validator
```
