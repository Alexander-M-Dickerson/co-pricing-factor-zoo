# Internet Appendix Results

Use this file when the question is about robustness checks, appendix outputs, or IA-specific model variants.

Use `docs/paper/co-pricing-factor-zoo.ai-optimized.md` for exact appendix equation or exhibit references.

## Purpose

The Internet Appendix extends the main paper with robustness checks and alternative specifications rather than replacing the paper's core conclusions.

## Source Of Truth

For IA estimation coverage, the source of truth is `ia/_run_ia_estimation.R`, not older prose docs.

The current IA estimation workflow includes nine models:

1. `bond_intercept`
2. `stock_intercept`
3. `bond_no_intercept`
4. `stock_no_intercept`
5. `joint_no_intercept`
6. `treasury_base`
7. `treasury_weighted`
8. `sparse_joint`
9. `isos_switch`

## Main Robustness Families

### Intercept sensitivity

The IA compares with-intercept and no-intercept specifications to show that the main co-pricing story is not simply an artifact of one intercept convention.

### Treasury weighting

The IA treasury models stress-test whether the bond-side findings are dominated by treasury-related exposure and how `kappa`-weighted emphasis changes the result.

The weighted treasury branch is part of the required IA baseline in this repo.
It relies on the tracked clone file `ia/data/w_all.rds`.

### Sparse-prior stress test

The `sparse_joint` model asks what happens when the prior is pushed toward a much smaller active set. This helps separate the paper's preferred dense posterior interpretation from an aggressively sparse alternative.

### IS versus OS asset switch

The `isos_switch` model swaps estimation emphasis toward out-of-sample style test assets as a robustness check on the reported pricing conclusions.

## Output Routing

IA estimation, tables, figures, and LaTeX outputs belong under `ia/output/`.

The repo currently implements some IA outputs, not the full manuscript IA exhibit set. Treat `ia/_run_ia_results.R` as the source of truth for which IA tables and figures are actually generated today.

When tracing a robustness result:

1. identify the IA model in `ia/_run_ia_estimation.R`
2. inspect `ia/_run_ia_results.R`
3. inspect the generated file in `ia/output/paper/`

## Explanation Guardrail

If IA documentation and IA code disagree, explain the discrepancy plainly and defer to the code. The repo has had stale IA prose describing only five models while the executable pipeline defines nine.
