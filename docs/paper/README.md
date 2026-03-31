# Paper Docs

This directory contains the canonical tracked manuscript source for this repo.

## Canonical Full Paper

- `co-pricing-factor-zoo.ai-optimized.md`

This is the full AI-optimized manuscript used for deep paper-aware tracing, equation lookup, and paper-to-code annotation.

## When To Read It

Use the full manuscript when a task needs:

- exact equation references
- detailed section or appendix language
- precise table or figure numbering
- cross-checking claims against the manuscript rather than the smaller repo summaries

For normal repo use, start with the lighter shared docs in `docs/agent-context/` and only load the full paper when needed.

## Tagging Standard

Repo paper-traceability comments should stay compact and precise.

- File headers:
  - `Paper role:` short statement of why the file exists in the paper workflow
  - `Paper refs:` exact `Sec.`, `Eq.`, `Table`, `Figure`, or appendix references
  - `Outputs:` only when the file produces saved artifacts
- Public functions:
  - add a short `Paper refs:` note in roxygen where it materially improves traceability
- Internal code blocks:
  - use `Paper:` comments for non-obvious logic and implementation choices
- C++ and upstream package files:
  - prefer light file-level or block-level references, not dense line-by-line comments

## Style Guardrails

- Prefer comments that explain `why`, not comments that restate obvious code.
- Use exact manuscript references when available.
- Keep comments accurate when code changes.
