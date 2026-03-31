# BayesianFactorZoo Override

This directory is the local upstream package copy. Treat it as upstream/reference code unless the task explicitly requires changing package internals.

## Default Behavior

- Prefer implementing repo-specific behavior in `code_base/` instead of here.
- Preserve exported function signatures unless the task is explicitly about changing the package API.
- Avoid cleanup-only edits, style churn, or broad refactors in this directory.

## When Edits Here Are Justified

- a bug is genuinely inside the upstream package copy
- local extensions cannot be implemented cleanly in `code_base/`
- the task is to sync or deliberately modify the package internals

## Guardrails

- Preserve factor and test-asset argument ordering for sampler functions.
- Be careful with namespace-sensitive package code and source file structure.
- If you change behavior here, check the downstream callers in `code_base/` and root scripts.
