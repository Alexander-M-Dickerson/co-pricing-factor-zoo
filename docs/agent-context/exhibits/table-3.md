# Table 3

## Empirical Question

Does the BMA-SDF retain pricing power out of sample on broader bond and stock
test assets?

## Short Answer

Yes. Table 3 is the main out-of-sample pricing comparison and is one of the core
pieces of evidence that the BMA-SDF remains strong beyond the estimation assets.

## Paper Refs

- Table 3
- Section 3.2
- `docs/manifests/paper_claims.csv`, Claim 3

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/pricing_tables.R`
- Output: `output/paper/tables/table_3_os_pricing.tex`

## Saved Inputs

- out-of-sample pricing objects from saved unconditional results
- `data/bond_oosample_all_excess.csv`
- `data/equity_os_77.csv`

## Common Misreadings

- Table 3 is the direct out-of-sample companion to Table 2.
- It is not the same as the conditional trading exercise in Table 6 Panel B or Figure 7.
