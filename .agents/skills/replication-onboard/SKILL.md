---
name: "replication-onboard"
description: "Set up or verify this repo's R-based replication environment. Use when Codex needs to check R, compiler tools, required packages, data files, or fast backend readiness before running the paper."
---

# Replication Onboard

Read these sources in order:

1. `AGENTS.md`
2. `docs/agent-context/replication-onboarding.md`
3. `docs/manifests/data-files.csv`
4. `docs/manifests/data-sources.csv`
5. `docs/validation/validated_runs.csv`
6. `tools/bootstrap_system.sh` (installs R, build tools, system libraries)
7. `tools/bootstrap_packages.R`
8. `tools/bootstrap_data.R`
9. `tools/bootstrap_latex.R`
10. `tools/doctor.R`
11. `tools/rebuild_fast_backends.*` (platform wrappers that compile the C++ backends)

## Critical Principle

**Never tell the user to install something manually if it can be installed automatically.** The onboarding flow must exhaust all automated options before asking the user to act. The user approving a sudo prompt is acceptable; the user copy-pasting install commands is not.

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

Steps must be executed in order. Each step depends on the previous one completing successfully. Do not skip ahead — for example, do not attempt `Rscript` commands before step 2 confirms R is installed.

**Audit-only shortcut:** If the user only wants to verify readiness (not install), skip to step 8 and run `tools/doctor.R --check-only`.

1. Print `Scanning your environment...` before starting.
2. Check whether `Rscript` is on PATH. **If R is not found, install it automatically** — do NOT stop and tell the user to install it manually. On Linux/macOS, run `bash tools/bootstrap_system.sh` which installs R, build tools, and system libraries via the native package manager. On Windows, run `powershell -ExecutionPolicy Bypass -File tools/bootstrap_system.ps1` which installs R and Rtools via `winget`. After the script completes, run `hash -r` (bash) to refresh PATH, then verify `Rscript --version` works before proceeding. On macOS, if the script exits with status 1 mentioning Xcode Command Line Tools, wait for the user to accept the GUI dialog, then re-run the script.
3. Use `tools/bootstrap_packages.R` or the platform wrapper to determine package gaps and install them. The bootstrap script prints per-package progress with `[N/total]` format — read stdout directly for progress updates. Do NOT spawn monitor agents or background watchers. Wait for the script to complete.
4. Use `docs/manifests/data-files.csv` and `docs/manifests/data-sources.csv` to determine whether missing required files are covered by the canonical public bundle.
5. If bundle-managed required files are missing, run `tools/bootstrap_data.R` or the platform wrapper instead of telling the user to place files manually.
6. Treat `ia/data/w_all.rds` as required tracked clone data; if it is missing, report an incomplete checkout rather than optional external data.
7. If the task is full setup (not audit-only), run `tools/bootstrap_latex.R` to ensure LaTeX is available for PDF compilation. The script installs TinyTeX automatically if no system LaTeX is found.
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

- if R is missing: run `bash tools/bootstrap_system.sh` (Linux/macOS) or `tools/bootstrap_system.ps1` (Windows) to install it automatically
- if R is missing AND the bootstrap script fails: report the exact error from the script output
- if the compiler toolchain is missing on Linux: `bootstrap_system.sh` installs build-essential, gfortran, and system libraries automatically
- if no writable R library is available: `bootstrap_packages.R` creates one automatically
- stop if required data files are missing rather than guessing substitutes
- stop if tracked required clone data such as `ia/data/w_all.rds` is missing
- on Windows: if `winget` is not available AND R cannot be found, inform the user to download from CRAN as a last resort
- do not hardcode machine-local paths into repo files
