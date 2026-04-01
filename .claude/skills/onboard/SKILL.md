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
2. Resolve the full `Rscript` path before assuming `Rscript` is callable.
3. Use `tools/bootstrap_packages.R --check` or the platform wrapper to determine package gaps, and install them when the task is setup rather than audit-only.
4. Use `docs/manifests/data-files.csv` and `docs/manifests/data-sources.csv` to determine whether missing required files are covered by the canonical public bundle.
5. If bundle-managed required files are missing, run `tools/bootstrap_data.R` or the platform wrapper instead of telling the user to place files manually.
6. Treat `ia/data/w_all.rds` as required tracked clone data; if it is missing, report an incomplete checkout rather than optional external data.
7. Run `tools/doctor.R` or `tools/doctor.ps1` to verify packages, data, toolchain visibility, and fast backend readiness.
8. Rebuild the fast backends when the doctor reports a backend problem or when this is the first setup on a new machine.
9. Use `docs/validation/validated_runs.csv` to distinguish maintainer-validated boundaries from commands that are merely documented.
10. Summarize whether the repo is ready for the main paper pipeline, the IA smoke boundary, and final PDF builds.

## Example Prompts

- "Set this repo up on a new Windows machine."
- "Set this repo up from a fresh clone. Install packages, download the canonical public data bundle, validate readiness, and rebuild the fast backends if needed."
- "Why does this repo fail before estimation starts?"
- "Check whether my machine is ready to run the paper."

## Failure Boundaries

- stop if R itself is missing or cannot be resolved
- stop if the compiler toolchain is missing and backend compilation is blocked
- stop if required data files are missing rather than guessing substitutes
- stop if tracked required clone data such as `ia/data/w_all.rds` is missing
- do not hardcode machine-local paths into repo files
