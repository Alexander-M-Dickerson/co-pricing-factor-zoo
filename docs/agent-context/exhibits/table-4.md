# Table 4

## Empirical Question

How is the BMA-SDF Sharpe ratio distributed across non-traded, bond-tradable,
and stock-tradable factor blocks?

## Short Answer

Table 4 shows that the SDF's explanatory power is distributed across factor
blocks rather than collapsing entirely onto a single market segment. It is the
main block-level decomposition counterpart to the top-factor view in Table 1.

## Paper Refs

- Table 4
- Section 3.1
- Figure 3

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/sr_tables.R`
- Output: `output/paper/tables/table_4_sr_by_factor_type.tex`

## Saved Inputs

- SR decomposition summaries from saved unconditional results

## Common Misreadings

- Table 4 is a block decomposition, not a factor ranking.
- It complements Table 1 rather than replacing it.
