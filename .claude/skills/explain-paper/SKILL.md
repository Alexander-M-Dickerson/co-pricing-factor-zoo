---
name: explain-paper
description: "Explain the paper, methods, factors, tables, figures, and code paths for this repo. Use when Claude needs to answer a paper question, trace an exhibit back to code, or connect saved results to equations and manuscript claims."
argument-hint: ""
---

# Explain Paper

Read only the docs needed for the question:

- `AGENTS.md`
- `docs/manifests/exhibits.csv`
- `.claude/paper-context.md`
- `docs/paper/co-pricing-factor-zoo.ai-optimized.md`
- `docs/agent-context/paper-reading-guide.md`
- `docs/agent-context/paper-method.md`
- `docs/agent-context/paper-results-main.md`
- `docs/agent-context/paper-results-ia.md`
- `docs/agent-context/tables-guide.md`
- `docs/agent-context/figures-guide.md`
- `docs/agent-context/factors-reference.md`

## Use When

- the user asks what the paper finds or how the method works
- the user wants a table, figure, factor, or equation traced back to code
- the user wants to understand which saved objects feed a result
- the user wants to compare manuscript claims with executable repo coverage

## Do Not Use When

- the task is to set up dependencies or diagnose the runtime environment
- the task is to execute the replication pipeline rather than explain it
- the question is a general coding task unrelated to the paper or outputs

## Inputs

- the paper question, exhibit id, factor name, or code path of interest
- optional request for high-level intuition versus exact equation-level tracing

## Outputs

- concise explanation of the requested method or result
- exact exhibit-to-code path when relevant
- saved-object names or generated output paths when relevant
- explicit note when manuscript prose and executable coverage diverge

## Workflow

1. Start from the empirical question or exhibit, not from sampler internals.
2. Use `docs/manifests/exhibits.csv` to locate the entry script and helper before reading source deeply.
3. Load the full paper only when exact equation, appendix, table, or figure references matter.
4. Prefer stored saved-object metadata such as `nontraded_names`, `bond_names`, and `stock_names` over reconstruction.

## Example Prompts

- "Explain Table 5 and show the code path."
- "Why does the paper say the SDF is dense?"
- "Which equation is the treasury decomposition using?"

## Failure Boundaries

- do not invent factor classifications or unsupported model configurations
- do not treat stale prose as authoritative when code and docs disagree
- do not bulk-load the full paper when a smaller shared doc answers the question
