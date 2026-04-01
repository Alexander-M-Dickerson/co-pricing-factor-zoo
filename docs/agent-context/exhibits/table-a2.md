# Table A.2

## Empirical Question

What are the full posterior inclusion probabilities and posterior market prices
of risk across all 54 factors?

## Short Answer

Table A.2 is the appendix companion to Figure 2. It gives the full posterior
probability and posterior market-price-of-risk surface rather than only the
visual ranking.

## Paper Refs

- Table A.2
- Figure 2
- Section 3.1

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/pp_figure_table.R`
- Output family: `output/paper/tables/table_a1_posterior_probs_*.tex`

## Saved Inputs

- joint-model unconditional saved results

## Common Misreadings

- The repo basename still starts with `table_a1_`, but the manuscript appendix
  table with posterior probabilities is Table A.2.
- Table A.2 is about posterior probabilities and market prices of risk, not the
  factor descriptions themselves. For the factor list, use `table-a1.md` and
  `factors-reference.md`.
