# AGENTS.md

Canonical repo guidance for coding agents working in this repository. Keep durable,
repo-specific instructions here. Tool-specific files such as `CLAUDE.md` or
`.github/copilot-instructions.md` should stay thin and defer to this document.

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

## High-Value File Map

- Root runner scripts:
  - `_run_full_replication.R`: end-to-end replication entrypoint
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
- `data/`: input data and cached intermediate data. Files here are gitignored.
- `output/` and `logs/`: generated results and runtime logs. These are gitignored.
- `README.md`, `QUICKSTART.md`, `README_PAPER_PIPELINE.md`: human-facing usage and
  pipeline documentation.

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

- `kappa = 0` or `NULL` with tradable factors present: use
  `BayesianFactorZoo::continuous_ss_sdf_v2`
- `kappa = 0` or `NULL` with no `f2`: use
  `BayesianFactorZoo::continuous_ss_sdf`
- nonzero `kappa` with tradable factors present: use the local multi-asset-weight
  extension in `code_base/`
- nonzero `kappa` with no `f2`: use the local no-self-pricing extension in
  `code_base/`
- Current default behavior is `kappa = 0`, which routes to the package
  implementation.

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
Rscript _run_full_replication.R --help
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_conditional.R --ndraws=5000
```

If a validation run is too expensive or blocked by missing data, say that plainly.

## Common Mistakes To Avoid

- confusing `model_type` names with human-readable labels
- assuming all changes belong in the upstream package copy
- hardcoding paths outside `data/` and `output/`
- inferring factor classifications from column names when the saved objects already
  contain the correct vectors
- silently dropping matrix dimensions during subsetting
- treating generated outputs as source files

## Maintainer Note

If repo guidance changes, update this file first. Keep tool-specific wrappers short
so this remains the single source of truth for agent context.
