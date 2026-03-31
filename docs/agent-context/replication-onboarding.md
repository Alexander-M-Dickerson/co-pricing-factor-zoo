# Replication Onboarding

Use this runbook when setting up a new machine to run the replication package.

Public setup surfaces:

- `tools/bootstrap_packages.R`
- `tools/doctor.R`
- `docs/manifests/data-files.csv`

## Goal

Reach a state where the repo can:

- run unconditional and conditional estimation scripts
- generate paper tables and figures
- compile the final LaTeX outputs when `pdflatex` is available

## Platform Baseline

- R: prefer R 4.5 or newer
- Windows: install Rtools45 for package compilation and `Rcpp::sourceCpp()`
- macOS: install Xcode Command Line Tools and the matching `gfortran` package from CRAN's macOS tools page
- LaTeX: optional for estimation, recommended for final PDF assembly

Do not assume `Rscript` is on `PATH`. In automation, resolve it explicitly from `R.home("bin")` or probe the installed R location.

## Required Repo Inputs

The repo expects data files under `data/` and, for the weighted-treasury IA
branch, `ia/data/`.

Use `docs/manifests/data-files.csv` as the source of truth for exact filenames,
coverage, and optional versus required status.

If the data folders are missing or incomplete, use the repo's documented public
source and then rerun `tools/doctor.R`.

## R Packages

The canonical installable package set lives in `tools/bootstrap_packages.R`.
Do not duplicate long package vectors in new docs.

If `BayesianFactorZoo` is not available from the active library, install it from
the local `BayesianFactorZoo/` package copy rather than rewriting code around
the missing dependency.

## Compile Fast Backends

Both C++ samplers should load successfully before long estimation runs:

- `code_base/continuous_ss_sdf_v2_fast.R`
- `code_base/continuous_ss_sdf_fast.R`

Compile them by sourcing each file and calling the corresponding loader with `force_rebuild = TRUE` on first setup. Cached build artifacts belong under `.cache/`.

## Smoke Checks

Use the smallest checks that verify the environment without launching a full
replication:

1. Run `tools/doctor.R --check-only`.
2. Run `Rscript _run_full_replication.R --help`.

If a machine will be used for final PDF output, also confirm `pdflatex` is
callable or let `tools/doctor.R` report it as optional.

## Common Setup Failures

- missing build toolchain during `Rcpp::sourceCpp()`
- compile probes failing inside a restricted or sandboxed terminal despite visible Rtools paths
- missing `gfortran` on macOS
- missing `pdflatex` during final assembly
- wrong working directory for root scripts
- bare `Rscript` assumptions on Windows

## Recommended Agent Behavior

- Prefer the smallest setup or verification step that proves progress.
- If a toolchain dependency is missing, report the exact missing component and stop short of speculative fixes.
- Do not hardcode machine-local paths into repo-tracked files while onboarding.
