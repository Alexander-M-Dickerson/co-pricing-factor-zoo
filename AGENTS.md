# AGENTS.md

Canonical repo guidance for coding agents working in this repository. Keep durable,
repo-specific instructions here. Tool-specific entrypoints such as `CLAUDE.md`
should remain aligned with this document and the shared docs under
`docs/agent-context/`.

## Repo Mission

This repository is the replication package for "The Co-Pricing Factor Zoo". It is
an R-first research codebase for Bayesian asset pricing estimation using the
Bryzgalova-Huang-Julliard (2023) spike-and-slab SDF framework, plus local
extensions for heterogeneous prior shrinkage (`kappa`) and downstream paper output.

Primary goals:

- run unconditional and conditional asset-pricing estimations
- generate paper tables and figures from saved estimation results
- preserve clear separation between upstream package code, local extensions, input
  data, and generated outputs

## Agent Surfaces

The repo is set up so Codex and Claude are both first-class entrypoints over the
same shared knowledge base.

Shared core:

- `AGENTS.md`: canonical repo rules, invariants, and routing
- `docs/agent-context/`: shared paper, pipeline, and output context
- `docs/acceptance/`: prompt acceptance rubric and manual agent acceptance templates
- `docs/validation/`: validated runtime/build ledgers and fresh-thread agent acceptance logs
- `docs/manifests/`: machine-readable data and exhibit maps
- `docs/paper/`: canonical full-paper source for deep equation and appendix lookup
- `code_review.md`: repo-specific review checklist for correctness and replication risks

Codex-native surfaces:

- `.codex/config.toml`
- `.agents/skills/`

Claude-native surfaces:

- `CLAUDE.md`
- `.claude/paper-context.md`
- `.claude/skills/`

Mirrored repo skills:

- Codex: `$replication-onboard`, `$replicate-paper`, `$explain-paper`
- Claude: `/onboard`, `/replicate-paper`, `/explain-paper`

Directory-specific overrides:

- `BayesianFactorZoo/AGENTS.override.md`
- `ia/AGENTS.md`
- `testing/AGENTS.md`

## Shared Context Map

High-value shared docs under `docs/agent-context/`:

- `replication-onboarding.md`
- `replication-pipeline.md`
- `prompt-recipes.md`
- `exhibits/`
- `paper-reading-guide.md`
- `paper-method.md`
- `paper-results-main.md`
- `paper-results-ia.md`
- `tables-guide.md`
- `figures-guide.md`
- `factor-interpretation.md`
- `factors-reference.md`
- `factors/`

Canonical full-paper source:

- `docs/paper/co-pricing-factor-zoo.ai-optimized.md`

Machine-readable manifests:

- `docs/manifests/data-files.csv`
- `docs/manifests/data-sources.csv`
- `docs/manifests/exhibits.csv`
- `docs/manifests/manuscript_exhibits.csv`
- `docs/manifests/paper_claims.csv`
- `docs/acceptance/prompt_harness.csv`
- `docs/validation/validated_runs.csv`
- `docs/validation/agent_acceptance_log.csv`

## High-Value File Map

- Root runner scripts:
  - `_run_full_replication.R`: main five-step replication entrypoint ending in LaTeX source assembly
  - `_run_all_unconditional.R`: batch unconditional estimation across model specs
  - `_run_all_conditional.R`: batch time-varying estimation
  - `_run_paper_results.R`: unconditional tables and figures
  - `_run_paper_conditional_results.R`: conditional paper outputs
  - `_create_djm_tabs_figs.R`: assembles final LaTeX outputs
- `code_base/`: reusable local implementation modules. Most substantive code changes
  should land here.
- `BayesianFactorZoo/`: local copy of the upstream BHJ package used as the base
  implementation. Treat this as upstream/reference code; prefer extending behavior
  in `code_base/` unless the change intentionally modifies package internals.
- `ia/`: Internet Appendix estimation and output pipeline.
- `testing/`: targeted validation and harness scripts.
- `tools/bootstrap_packages.R`: canonical installable R package set
- `tools/bootstrap_data.R`: canonical public data bootstrap entrypoint
- `tools/doctor.R`: public readiness check for packages, data, toolchain, and fast backends
- `tools/run_figure1_simulation.R`: explicit regeneration path for the paper Figure 1 simulation outputs
- `tools/*.ps1`, `tools/*.cmd`, `tools/*.sh`: public platform wrappers for setup, smoke runs, full replication, and paper build
- `tools/validate_repo_docs.R`: doc and context drift check
- `docs/manifests/`: source-of-truth CSV manifests for inputs and exhibits
- `data/`: input data and cached intermediate data. Files here are gitignored.
- `ia/data/w_all.rds`: required tracked IA input for the weighted treasury branch
- `misc/figure1_simulation/`: tracked Figure 1 paper-calibration fixtures used by the default build
- `output/` and `logs/`: generated results and runtime logs. These are gitignored.
- `README.md`, `QUICKSTART.md`, `README_PAPER_PIPELINE.md`: human-facing usage and
  pipeline documentation.

Replication coverage today:

- all main paper tables and figures
- all main Appendix tables and figures
- some Internet Appendix results

## Default Execution Flow

The core unconditional flow is:

`_run_unconditional_model.R`
-> `code_base/run_bayesian_mcmc.R`
-> data loading and date alignment
-> factor/test-asset matrix construction
-> prior calibration via `psi_to_priorSR*`
-> Gibbs sampling via `continuous_ss_sdf*`
-> benchmark models and in-sample pricing
-> save `.Rdata`

Paper-generation scripts consume those saved results and write `.tex`, `.pdf`, and
other derived outputs under `output/`.

When orienting in the codebase, start with `code_base/run_bayesian_mcmc.R` for
estimation behavior and the root `_run_*.R` scripts for orchestration.

For execution guidance, also read `docs/agent-context/replication-pipeline.md`.
For exact equation and appendix references, use `docs/paper/co-pricing-factor-zoo.ai-optimized.md`.
For exhibit explanation tasks, start with `docs/agent-context/exhibits/` and
the manifests before loading the full paper.

## Domain Invariants You Must Preserve

### Model configuration

- Valid `model_type` values are exactly:
  - `"bond"`
  - `"stock"`
  - `"bond_stock_with_sp"`
  - `"treasury"`
- Valid `return_type` values are:
  - `"excess"`
  - `"duration"`
- Do not invent derived `model_type` names such as `"bond_excess"` or
  `"joint_excess"`. Those are not valid configuration values.

### BHJ package function signatures

- `continuous_ss_sdf(f, R, ...)` means factors first, test assets second.
- `continuous_ss_sdf_v2(f1, f2, R, ...)` means non-traded factors, tradable
  factors, then test assets.
- Tradable factors in `f2` are self-pricing and must be handled accordingly.

### MCMC dispatch behavior

There are two distinct decisions in the current code:

- Prior calibration:
  - `kappa = NULL`: use `BayesianFactorZoo::psi_to_priorSR`
  - any supplied `kappa` object, including zero-valued numeric vectors: use the
    local `psi_to_priorSR_multi_asset*` helper path
- Sampler dispatch:
  - tradable factors present and any `kappa != 0`: use the local multi-asset-weight
    extension in `code_base/`
  - no `f2` and any `kappa != 0`: use the local no-self-pricing extension in
    `code_base/`
  - otherwise: use the baseline package sampler path
    (`BayesianFactorZoo::continuous_ss_sdf_v2` or
    `BayesianFactorZoo::continuous_ss_sdf`), with fast wrappers when enabled
- Treasury nuance:
  - `model_type = "treasury"` is treated as a no-self-pricing branch inside
    `run_bayesian_mcmc()`
  - the traded-bond file named in treasury configs is merged into the factor
    block and `f2` becomes `NULL` before sampler dispatch
  - do not classify treasury models as fast self-pricing `v2` runs

Most baseline runner scripts still pass `kappa = 0`, so the sampler remains on
the package path even though prior calibration may flow through the local helper
because `kappa` is not `NULL`.

### Data and naming invariants

- All CSV inputs should default to `data/`. Prefer `data_folder = "data"` rather
  than hardcoded machine-local paths.
- Expect the first column of input CSVs to be the date column.
- Use `validate_and_align_dates()` when combining multiple input series.
- When loading saved estimation `.Rdata` files, use the precomputed factor name
  vectors already stored in the file:
  - `nontraded_names`
  - `bond_names`
  - `stock_names`
- Do not recreate or infer those vectors if they are already present.

## Editing Guidance

- Prefer changes in `code_base/` over changes in `BayesianFactorZoo/`.
- Avoid `setwd()` in functions or reusable code. Use `file.path()` and explicit
  parameters.
- Do not hardcode user-specific absolute paths into repo-tracked files.
- Treat `data/`, `output/`, and `logs/` as environment-specific runtime state, not
  source code.
- Preserve the existing split between:
  - configuration near the top of runner scripts
  - reusable implementation in sourced files under `code_base/`
- For new reusable functions:
  - use `snake_case`
  - validate inputs early with informative errors
  - prefer explicit parameters and sensible defaults
  - avoid hidden global side effects
  - prefer `requireNamespace()` or explicit `pkg::fn` over `library()` inside
    functions
- Keep date handling explicit and preserve matrix dimensions carefully. In R,
  include `drop = FALSE` where a one-column subset must remain matrix-like.

## Output Conventions

- Generated estimation results belong under `output/`.
- For post-estimation analysis, follow the existing convention:
  `output/results/{return_type}_{model_type}_{ndraws}draws_{tag}/`
- If code writes additional derived figures or tables, keep them inside generated
  output folders rather than mixing them into source directories.
- Do not commit generated `.Rdata`, `.rds`, `.csv`, `.pdf`, or log artifacts unless
  the task explicitly requires tracked fixture data.
- Use `docs/manifests/exhibits.csv` when you need the paper-to-output mapping
  before reading helper code in depth.

## Validation Expectations

There is no lightweight unit-test suite in this repo today. Validation is usually a
targeted script run plus log inspection.

Prefer one of these levels of verification:

- Documentation-only changes: no runtime verification required.
- Narrow code changes: run the smallest relevant `Rscript` entrypoint or analysis
  path you can justify.
- Pipeline changes: use a reduced-draw or quick-mode run when available before
  recommending a full replication run.

Useful commands from the repo root:

```bash
Rscript tools/bootstrap_data.R --help
Rscript tools/validate_repo_docs.R
Rscript _run_full_replication.R --help
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_conditional.R --direction=both --ndraws=500
Rscript _run_all_conditional.R --direction=forward --ndraws=500
Rscript ia/_run_ia_results.R --help
Rscript ia/_create_ia_latex.R --help
Rscript ia/_run_ia_full.R --help
```

Validated Windows host commands as of March 31, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Important nuance from that validated run:

- the full wrapper completed end-to-end on the maintainer Windows host
- if packages or bundle-managed main data are missing in a fresh clone, use
  `tools/bootstrap_packages.*`, then `tools/bootstrap_data.*`, then
  `tools/doctor.*` before running estimation
- `tools/build_paper.*` is the public wrapper for final PDF compilation
- strict unconditional freshness now exists in `_run_paper_results.R`; for
  publication-grade reruns, prefer the top-level wrapper or
  `_run_paper_results.R --strict-freshness`

Validated IA Windows host commands as of April 1, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

Important IA nuance from that validated host path:

- the 500-draw smoke boundary completed all nine IA models
- the 5,000-draw full IA wrapper completed estimation, outputs, LaTeX assembly,
  and IA PDF compilation
- eligible fast IA models (`1-5`, `8`, `9`) ran on `continuous_ss_sdf_v2_fast`
- treasury IA models remained on their intended no-self-pricing paths

If a validation run is too expensive or blocked by missing data, say that plainly.

For review-specific expectations, also read `code_review.md`.

## Common Mistakes To Avoid

- confusing `model_type` names with human-readable labels
- assuming all changes belong in the upstream package copy
- hardcoding paths outside `data/` and `output/`
- inferring factor classifications from column names when the saved objects already
  contain the correct vectors
- silently dropping matrix dimensions during subsetting
- treating generated outputs as source files
- describing the IA pipeline from stale prose instead of `ia/_run_ia_estimation.R`

## Maintainer Note

If repo guidance changes, update this file first. Keep tool-specific wrappers short
so this remains the single source of truth for agent context.
