# Claude Paper Context

Claude routing hub for paper explanation tasks.

Read `AGENTS.md` first, then use the shared split docs under `docs/agent-context/`
selectively:

Canonical full paper:

- `docs/paper/co-pricing-factor-zoo.ai-optimized.md`

Machine-readable maps:

- `docs/manifests/exhibits.csv`
- `docs/manifests/manuscript_exhibits.csv`
- `docs/manifests/paper_claims.csv`

Exhibit dossiers:

- `docs/agent-context/exhibits/README.md`
- `docs/agent-context/exhibits/`

Prompt recipes:

- `docs/agent-context/prompt-recipes.md`

## If The User Wants Intuition

- `paper-reading-guide.md`
- `paper-results-main.md`

## If The User Wants Method Detail

- `paper-method.md`
- `paper-reading-guide.md`

## If The User Asks Why The SDF Is Dense Or About Noisy Proxies

- `noisy-proxy-guide.md`
- `factor-interpretation.md`

## If The User Asks About Treasury / Duration / Bond Redundancy

- `treasury-component-guide.md`

## If The User Asks About Time-Varying Results Or Expanding Windows

- `time-varying-guide.md`

## If The User Wants A Main Result

- `paper-results-main.md`
- `tables-guide.md`
- `figures-guide.md`

## If The User Wants IA Robustness

- `ia-robustness-guide.md`
- `paper-results-ia.md`

## If The User Wants A Table, Figure, Or Factor Walkthrough

- `docs/agent-context/exhibits/`
- `docs/manifests/exhibits.csv`
- `docs/manifests/manuscript_exhibits.csv`
- `tables-guide.md`
- `figures-guide.md`
- `factors-reference.md`

Prefer loading only the relevant shared doc instead of bulk-loading everything.
Use the exhibit dossier first when one exists. Use the manuscript manifest when
the user asks about paper-only or not-yet-implemented IA exhibits.
Load the full paper when exact equation, appendix, table, or figure wording matters.
