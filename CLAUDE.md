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

## Shared Context

The detailed shared docs live in `docs/agent-context/`:

- `replication-onboarding.md`
- `replication-pipeline.md`
- `paper-reading-guide.md`
- `paper-method.md`
- `paper-results-main.md`
- `paper-results-ia.md`
- `tables-guide.md`
- `figures-guide.md`
- `factors-reference.md`

The canonical full paper lives at:

- `docs/paper/co-pricing-factor-zoo.ai-optimized.md`

The machine-readable repo maps live at:

- `docs/manifests/data-files.csv`
- `docs/manifests/exhibits.csv`

Load the full paper only when exact equation, appendix, table, or figure wording matters.

## Task Routing

- Environment setup or machine verification: use `/onboard`
- Running or resuming replication: use `/replicate-paper`
- Explaining the paper or tracing outputs: use `/explain-paper`

## Repo Notes For Claude

- The main paper pipeline is the five-step root workflow under the repo root.
- The Internet Appendix pipeline is separate and the source of truth for IA model
  coverage is `ia/_run_ia_estimation.R`, which currently defines nine IA models.
- The repo currently reproduces all main paper tables and figures, all main
  Appendix tables and figures, and some IA results.
- For review work, use `code_review.md` in addition to `AGENTS.md`.
