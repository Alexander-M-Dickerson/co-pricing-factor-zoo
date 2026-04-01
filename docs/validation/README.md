# Validation Ledger

This folder is the source of truth for what has actually been validated.

Use it to answer:

- which execution boundaries are genuinely host-validated?
- which prompt behaviors have been manually acceptance-tested?
- what remains unvalidated even if docs already describe the workflow?

## Files

- `validated_runs.csv`: runtime and build boundaries that have been validated
- `agent_acceptance_log.csv`: fresh-thread Codex and Claude acceptance runs

## Rule

If README prose and these CSVs disagree, treat the CSVs as the validation source
of truth and update the prose.

## Logging Policy

- add a row to `validated_runs.csv` when a new host or CI validation boundary is
  completed
- add a row to `agent_acceptance_log.csv` after a manual fresh-thread agent
  acceptance drill
- do not mark a prompt or runtime boundary as validated just because the docs
  exist
