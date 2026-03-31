# Code Review Focus

Use this repo's review mode to find correctness and replication risks first, not style issues.

## Prioritize These Findings

1. Invalid domain configuration:
   - invented `model_type` values
   - invalid `return_type` values
2. Broken sampler usage:
   - swapped argument order for `continuous_ss_sdf()` or `continuous_ss_sdf_v2()`
   - incorrect dispatch between package samplers and local `kappa` extensions
3. Data integrity bugs:
   - missing `validate_and_align_dates()` when joining series
   - silent dimension drops from matrix subsetting without `drop = FALSE`
   - hardcoded machine-local paths instead of `data/` or explicit parameters
4. Saved-object misuse:
   - recreating factor-name vectors that already exist in saved `.Rdata`
   - assuming factor classes from column-name heuristics
5. Source/layout regressions:
   - edits in `BayesianFactorZoo/` that should live in `code_base/`
   - generated outputs written into source directories
6. Replication-surface drift:
   - docs or wrappers that describe a pipeline different from the executable code
   - stale IA model-count or script guidance

## Expected Review Output

- Findings first, ordered by severity.
- Cite exact files and lines where possible.
- Treat documentation bugs that would mislead a replication user as real findings, not polish.

## Residual Risks To Note

- expensive runs that were not executed
- missing data that blocks validation
- numerical behavior that was not rechecked after sampler changes
