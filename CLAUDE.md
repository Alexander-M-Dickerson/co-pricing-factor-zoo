# CLAUDE.md

Claude-first entrypoint for this repository.

Read `AGENTS.md` first for repo invariants, valid model configurations, sampler
argument ordering, output conventions, and validation expectations.

Then use the Claude context surfaces below to route the task quickly without
loading unnecessary material.

## Claude Surfaces

- `.claude/paper-context.md`: Claude paper and results routing hub
- `.claude/skills/onboard/`: environment and dependency setup
- `.claude/skills/replicate-paper/`: replication pipeline execution and resume
- `.claude/skills/explain-paper/`: paper, method, table, figure, and factor explanation
- `docs/manifests/`: machine-readable data and exhibit maps shared with Codex
- `docs/acceptance/`: prompt acceptance rubric and manual fresh-thread templates
- `docs/validation/`: validated runtime/build ledgers and agent acceptance logs

## Shared Context

The detailed shared docs live in `docs/agent-context/`:

- `replication-onboarding.md`
- `replication-pipeline.md`
- `prompt-recipes.md`
- `exhibits/`
- `paper-reading-guide.md`
- `paper-method.md`
- `paper-results-main.md`
- `paper-results-ia.md`
- `tables-guide.md`
- `figures-guide.md`
- `factor-interpretation.md`
- `factors-reference.md`
- `factors/`
- `noisy-proxy-guide.md`
- `treasury-component-guide.md`
- `time-varying-guide.md`
- `ia-robustness-guide.md`

The canonical full paper lives at:

- `docs/paper/co-pricing-factor-zoo.ai-optimized.md`

The machine-readable repo maps live at:

- `docs/manifests/data-files.csv`
- `docs/manifests/data-sources.csv`
- `docs/manifests/exhibits.csv`
- `docs/manifests/manuscript_exhibits.csv`
- `docs/manifests/paper_claims.csv`
- `docs/manifests/code-map.md`
- `docs/acceptance/prompt_harness.csv`
- `docs/validation/validated_runs.csv`
- `docs/validation/agent_acceptance_log.csv`

Load the full paper only when exact equation, appendix, table, or figure wording matters.

## Task Routing

- Environment setup or machine verification: use `/onboard`
- Running or resuming replication: use `/replicate-paper`
- Explaining the paper or tracing outputs: use `/explain-paper`

## Repo Notes For Claude

- The main paper pipeline is the six-step root workflow under the repo root (including automatic PDF compilation).
- On a fresh clone, Claude should bootstrap packages and the canonical public data bundle before telling the user to place files manually.
- `ia/data/w_all.rds` is tracked required clone data for the weighted treasury IA branch and should not be treated as optional.
- The Internet Appendix pipeline is separate and the source of truth for IA model
  coverage is `ia/_run_ia_estimation.R`, which currently defines nine IA models.
- The repo currently reproduces all main paper tables and figures, all main
  Appendix tables and figures, and some IA results.
- For review work, use `code_review.md` in addition to `AGENTS.md`.
