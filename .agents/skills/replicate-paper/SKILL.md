---
name: "replicate-paper"
description: "Run or debug the main paper and Internet Appendix replication pipeline. Use when Codex needs to choose the right script boundary, resume after a failure, or map a run request to the implemented main or IA output surface."
---

# Replicate Paper

Read these sources in order:

1. `AGENTS.md`
2. `docs/agent-context/replication-pipeline.md`
3. `docs/manifests/data-files.csv`
4. `docs/manifests/exhibits.csv`
5. `docs/agent-context/paper-results-ia.md`

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

1. Check the current environment with `tools/doctor.R --check-only` if readiness is uncertain.
2. Use `docs/manifests/exhibits.csv` to map user-facing exhibits to the smallest runnable boundary.
3. Prefer reduced-draw or help/list boundaries first when validating changes.
4. Stop at the first failing stage and report the exact rerun boundary instead of restarting everything.
5. Distinguish clearly between full main-paper coverage and the implemented IA subset.

## Example Prompts

- "Run the paper in quick mode and stop at the first failing step."
- "Which script generates Table 5?"
- "Resume the IA pipeline from the first missing output."

## Failure Boundaries

- do not claim a replication completed unless the relevant scripts actually finished
- do not describe every manuscript IA exhibit as implemented when the repo only generates a subset
- do not jump straight to the full pipeline when a narrower boundary will answer the question
