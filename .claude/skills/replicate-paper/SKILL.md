---
name: replicate-paper
description: "Run or debug the main paper and Internet Appendix replication pipeline. Use when Claude needs to choose the right script boundary, resume after a failure, or map a run request to the implemented main or IA output surface."
argument-hint: "[--ndraws=50000] [--quick] [--skip-estimation] [--step=N]"
---

# Replicate Paper

Read these sources in order:

1. `AGENTS.md`
2. `docs/agent-context/replication-pipeline.md`
3. `docs/manifests/data-files.csv`
4. `docs/manifests/exhibits.csv`
5. `docs/manifests/manuscript_exhibits.csv`
6. `docs/agent-context/prompt-recipes.md`
7. `docs/agent-context/paper-results-ia.md`

## Use When

- the task is to run the main replication pipeline
- the task is to resume after a failed run
- the user wants the smallest script boundary for a table, figure, or IA subset
- the user wants to know what output a given runner script should produce

## Do Not Use When

- the task is environment setup or package installation only
- the task is explanation of the paper without running code
- the task is a code change unrelated to pipeline execution

## Inputs

- repo root access
- readiness information from `tools/doctor.R` when available
- user scope such as full run, quick run, specific step, or IA subset

## Outputs

- exact script boundary to run
- status of completed versus failed stages
- output folders or files produced so far
- precise rerun boundary after a failure

## Workflow

1. If readiness is uncertain, run `tools/doctor.R --check-only` first.
2. If packages are missing, use `tools/bootstrap_packages.*`; if bundle-managed required data are missing, use `tools/bootstrap_data.*` before launching replication.
3. Use `docs/manifests/exhibits.csv` to map user-facing exhibits to the smallest runnable boundary.
4. Use `docs/manifests/manuscript_exhibits.csv` when the user asks about the full paper inventory or about paper-only IA exhibits.
5. Prefer reduced-draw or help/list boundaries first when validating changes.
6. Stop at the first failing stage and report the exact rerun boundary instead of restarting everything.
7. Distinguish clearly between full main-paper coverage and the implemented IA subset.
8. For an IA replication prompt, use `tools/run_ia_smoke.*` or `ia/_run_ia_full.R --ndraws=500` as the first acceptance boundary before scaling up.

## Example Prompts

- "Run the paper in quick mode and stop at the first failing step."
- "Replicate the main text. If packages or data are missing, bootstrap them automatically first."
- "Replicate the Internet Appendix. Bootstrap what is needed, run the 500-draw IA smoke boundary first, and stop at the first failing model."
- "Which script generates Table 5?"
- "Resume the IA pipeline from the first missing output."

## Failure Boundaries

- do not claim a replication completed unless the relevant scripts actually finished
- do not describe every manuscript IA exhibit as implemented when the repo only generates a subset
- do not jump straight to the full pipeline when a narrower boundary will answer the question
- do not treat the weighted treasury IA model or `ia/data/w_all.rds` as optional
