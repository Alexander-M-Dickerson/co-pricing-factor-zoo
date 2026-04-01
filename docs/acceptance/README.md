# Acceptance Harness

This folder is the canonical trust layer for fresh-clone and fresh-thread
acceptance.

Use it when the question is not "can the code run?" but "can a human or agent
use this repo correctly and get the right behavior?"

## Files

- `prompt_harness.csv`: machine-readable prompt acceptance rubric
- `agent_acceptance_template.md`: manual run template for a fresh Codex or Claude
  thread

## Purpose

The prompt harness does not try to auto-grade full natural-language answers.
Instead, it records:

- the canonical prompts that matter most
- the routes, references, and outputs that must appear
- the statements the agent must not make
- whether the answer should rely on implemented repo outputs, paper-only
  evidence, or a mixed explanation

## Fresh-Clone Acceptance Drill

The minimum manual drill is:

1. fresh clone of the repo
2. open Codex or Claude from the repo root
3. run the canonical prompts below
4. record results in `docs/validation/agent_acceptance_log.csv`

Required prompts:

- `fresh_clone_setup`
- `replicate_main_text`
- `replicate_internet_appendix`
- `explain_table_1`
- `explain_factor_inclusion`
- `pead_microcap`

## Logging Rule

When a manual acceptance run is performed:

- copy `agent_acceptance_template.md`
- fill it in from the fresh-thread run
- summarize the result in `docs/validation/agent_acceptance_log.csv`

The source of truth for whether a prompt has been manually accepted is the CSV
log in `docs/validation/`, not scattered prose in README files.
