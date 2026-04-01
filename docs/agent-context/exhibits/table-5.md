# Table 5

## Empirical Question

Are the important factors primarily discount-rate-news factors or cash-flow-news
factors?

## Short Answer

Table 5 summarizes the discount-rate versus cash-flow decomposition for the
factor groups that matter in the main paper. The repo uses a precomputed
variance-decomposition input to map factors into the DR/CF framework and then
renders the table from the SR decomposition summaries.

## Interpretation

- bond factors lean more toward discount-rate news
- stock factors lean more toward cash-flow news
- the decomposition supports the paper's view that both channels matter, but in
  different ways across markets

## Paper Refs

- Table 5
- Section 3.1.1
- IA.5
- `docs/manifests/paper_claims.csv`, Claim 12

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/sr_tables.R`
- Output: `output/paper/tables/table_5_dr_vs_cf.tex`

## Saved Inputs

- SR decomposition summaries
- `data/variance_decomp_results_vuol.rds`

## Common Misreadings

- Table 5 is not the duration-adjusted Treasury decomposition of Eq. (10); that equation belongs to the Treasury-component exercises behind Figures 8 and 9.
- The repo does not recompute the DR/CF classification from scratch during paper assembly; it uses the saved decomposition input.
