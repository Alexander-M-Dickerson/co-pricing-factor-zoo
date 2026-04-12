---
name: onboard
description: "Set up or verify this repo's R-based replication environment. Use when Claude needs to check R, compiler tools, required packages, data files, or fast backend readiness before running the paper."
argument-hint: ""
---

# Environment Onboarding

Read these sources in order:

1. `AGENTS.md`
2. `docs/agent-context/replication-onboarding.md`
3. `docs/manifests/data-files.csv`
4. `docs/manifests/data-sources.csv`
5. `docs/validation/validated_runs.csv`
6. `tools/bootstrap_packages.R`
7. `tools/bootstrap_data.R`
8. `tools/doctor.R`
9. `tools/rebuild_fast_backends.*` (platform wrappers that compile the C++ backends)

## Use When

- a new machine needs to be prepared for the repo
- R, build tools, packages, or data readiness is unclear
- the fast C++ backends may be missing or broken
- a run fails before estimation because the environment is incomplete

## Do Not Use When

- the task is to explain the paper or trace a table or figure
- the environment is already ready and the task is to run or debug a pipeline step
- the task is a code edit unrelated to environment setup

## Inputs

- repo root access
- current platform and shell context
- optional user preference for install versus check-only behavior

## Outputs

- resolved `Rscript` path
- package readiness summary
- canonical data bootstrap status
- required-data readiness summary, including tracked IA clone data
- fast-backend readiness summary
- exact next blocking dependency, if any

## Workflow

1. Print `Scanning your environment...` before starting.
2. Resolve the full `Rscript` path before assuming `Rscript` is callable. On Windows, prefer the platform wrappers (`tools/*.ps1`, `tools/*.cmd`); on macOS/Linux, ensure `Rscript` is on the shell PATH. Run `Rscript --version` to confirm it works. If Rscript cannot be found or `--version` fails, **stop immediately** with an actionable error — do NOT proceed to package bootstrap.
3. Use `tools/bootstrap_packages.R --check` or the platform wrapper to determine package gaps, and install them when the task is setup rather than audit-only. The bootstrap script prints per-package progress with `[N/total]` format — read stdout directly for progress updates. Do NOT spawn monitor agents, background watchers, or Monitor tool calls. The script outputs one structured line per package and a summary at the end. Wait for the script to complete. On Linux, the script auto-detects Posit Package Manager (PPM) for pre-compiled binaries — if PPM is unreachable, packages compile from source (slower but functional if build tools are present).
4. Use `docs/manifests/data-files.csv` and `docs/manifests/data-sources.csv` to determine whether missing required files are covered by the canonical public bundle.
5. If bundle-managed required files are missing, run `tools/bootstrap_data.R` or the platform wrapper instead of telling the user to place files manually.
6. Treat `ia/data/w_all.rds` as required tracked clone data; if it is missing, report an incomplete checkout rather than optional external data.
7. If the task is full setup (not audit-only), run `tools/bootstrap_latex.R` to ensure LaTeX is available for PDF compilation. If the user indicates they don't need PDF output, skip this step. The script installs TinyTeX automatically if no system LaTeX is found, and pre-installs all required LaTeX packages.
8. Run `tools/doctor.R` or `tools/doctor.ps1` to verify packages, data, toolchain visibility, and fast backend readiness.
9. Rebuild the fast backends when the doctor reports a backend problem or when this is the first setup on a new machine.
10. Use `docs/validation/validated_runs.csv` to distinguish maintainer-validated boundaries from commands that are merely documented.
11. Summarize whether the repo is ready for the main paper pipeline, the IA smoke boundary, and final PDF builds.

## Example Prompts

- "Set this repo up on a new Windows machine."
- "Set this repo up from a fresh clone. Install packages, download the canonical public data bundle, validate readiness, and rebuild the fast backends if needed."
- "Why does this repo fail before estimation starts?"
- "Check whether my machine is ready to run the paper."

## Failure Boundaries

- stop if R itself is missing or cannot be resolved
- stop if Rscript `--version` fails after resolution
- stop if no writable R library is available
- stop if the compiler toolchain is missing and backend compilation is blocked
- stop if required data files are missing rather than guessing substitutes
- stop if tracked required clone data such as `ia/data/w_all.rds` is missing
- if multiple packages fail with compilation errors on Linux, the user likely needs system development packages: `sudo apt install build-essential gfortran libcurl4-openssl-dev libssl-dev libxml2-dev libfontconfig1-dev libharfbuzz-dev libfribidi-dev libfreetype-dev libpng-dev libtiff-dev libjpeg-dev`
- do not hardcode machine-local paths into repo files
