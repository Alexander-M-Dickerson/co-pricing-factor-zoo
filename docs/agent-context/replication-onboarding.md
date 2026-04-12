# Replication Onboarding

Use this runbook when setting up a new machine to run the replication package.

Public setup surfaces:

- `tools/bootstrap_packages.R`
- `tools/bootstrap_data.R`
- `tools/doctor.R`
- `tools/bootstrap_packages.ps1`, `tools/bootstrap_packages.cmd`, `tools/bootstrap_packages.sh`
- `tools/bootstrap_data.ps1`, `tools/bootstrap_data.cmd`, `tools/bootstrap_data.sh`
- `tools/doctor.ps1`, `tools/doctor.cmd`, `tools/doctor.sh`
- `docs/manifests/data-files.csv`
- `docs/manifests/data-sources.csv`

## Goal

Reach a state where the repo can:

- run unconditional and conditional estimation scripts
- generate paper tables and figures
- compile the final LaTeX outputs when `pdflatex` is available

## Platform Baseline

- R: prefer R 4.5 or newer
- Windows: install Rtools45 for package compilation and `Rcpp::sourceCpp()`
- macOS: install Xcode Command Line Tools plus the CRAN-recommended GNU Fortran that matches your installed CRAN R version
- LaTeX: optional for estimation, recommended for final PDF assembly

Official macOS toolchain references:

- <https://cran.r-project.org/bin/macosx/tools/>
- <https://mac.r-project.org/tools/>

Mac setup policy for this repo:

- tell users to install Xcode Command Line Tools with `xcode-select --install`
- tell users to install the `gfortran` release recommended for their specific CRAN R version rather than hard-coding a compiler version in repo docs
- avoid mixing CRAN R binaries with Homebrew or MacPorts compilers unless rebuilding the full toolchain consistently

Do not assume `Rscript` is on `PATH`. In automation, resolve it explicitly from `R.home("bin")` or probe the installed R location.

## Required Repo Inputs

The repo expects bundle-managed main files under `data/` and the tracked IA
weights file `ia/data/w_all.rds`.

Use `docs/manifests/data-files.csv` as the source of truth for exact filenames,
coverage, and optional versus required status.

Use `docs/manifests/data-sources.csv` as the source of truth for the canonical
public data bundle. The default onboarding path is:

1. `tools/bootstrap_packages.*`
2. `tools/bootstrap_data.*`
3. `tools/bootstrap_latex.*` (installs TinyTeX if no system LaTeX found)
4. `tools/doctor.*`
5. `tools/rebuild_fast_backends.*` if backend rebuild is required

`ia/data/w_all.rds` is required tracked clone data for the weighted-treasury IA
branch. It is not part of the canonical bundle because it ships with the repo.

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
3. Prefer `tools/rebuild_fast_backends.*` and `tools/run_conditional_smoke.*`
   for host-shell validation when wrappers are available.
4. Use `tools/run_ia_smoke.*` to validate the IA path once the main doctor passes.

If a machine will be used for final PDF output, also confirm `pdflatex` is
callable or let `tools/doctor.R` report it as optional.

## Common Setup Failures

- missing build toolchain during `Rcpp::sourceCpp()`
- compile probes failing inside a restricted or sandboxed terminal despite visible Rtools paths
- missing Xcode Command Line Tools on macOS
- missing `gfortran` on macOS
- missing `pdflatex` or `bibtex` during `tools/build_paper.*`
- wrong working directory for root scripts
- bare `Rscript` assumptions on Windows

## Recommended Agent Behavior

- Prefer the smallest setup or verification step that proves progress.
- On a fresh clone, bootstrap missing packages and bundle-managed main data before asking the user to place files manually.
- Treat `ia/data/w_all.rds` as required tracked clone data; if it is missing, report it as an incomplete checkout rather than as optional external data.
- If a toolchain dependency is missing, report the exact missing component and stop short of speculative fixes.
- Do not hardcode machine-local paths into repo-tracked files while onboarding.
