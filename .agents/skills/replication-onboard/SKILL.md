---
name: "replication-onboard"
description: "Set up or verify this repo's R-based replication environment. Use when Codex needs to check R, compiler tools, required packages, data files, or fast backend readiness before running the paper."
---

# Replication Onboard

Read these sources in order:

1. `AGENTS.md`
2. `docs/agent-context/replication-onboarding.md`
3. `docs/manifests/data-files.csv`
4. `tools/bootstrap_packages.R`
5. `tools/doctor.R`

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
- required-data readiness summary
- fast-backend readiness summary
- exact next blocking dependency, if any

## Workflow

1. Resolve the full `Rscript` path before assuming `Rscript` is callable.
2. Use `tools/bootstrap_packages.R --check` or the PowerShell wrapper to determine package gaps.
3. Use `docs/manifests/data-files.csv` as the exact input checklist.
4. Run `tools/doctor.R` or `tools/doctor.ps1` to verify packages, data, toolchain visibility, and fast backend readiness.
5. Summarize whether the repo is ready for the main paper pipeline and whether optional LaTeX or IA-only inputs remain missing.

## Example Prompts

- "Set this repo up on a new Windows machine."
- "Why does this repo fail before estimation starts?"
- "Check whether my machine is ready to run the paper."

## Failure Boundaries

- stop if R itself is missing or cannot be resolved
- stop if the compiler toolchain is missing and backend compilation is blocked
- stop if required data files are missing rather than guessing substitutes
- do not hardcode machine-local paths into repo files
