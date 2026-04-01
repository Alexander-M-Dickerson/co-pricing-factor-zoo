# Table 6

## Empirical Question

Does the estimated SDF translate into economically meaningful trading
performance?

## Short Answer

Table 6 is the paper's trading summary. Panel A is the in-sample trading view
from the unconditional results. Panel B is the out-of-sample conditional trading
comparison built from the expanding-window estimation path.

## Panels

- Panel A: in-sample trading statistics
- Panel B: conditional out-of-sample trading statistics

## Paper Refs

- Table 6
- Section 3.4
- Figure 7
- `docs/manifests/paper_claims.csv`, Claim 4

## Code Path

- Panel A entry: `_run_paper_results.R`
- Panel A helper: `code_base/trading_table.R`
- Panel A output: `output/paper/tables/table_6_panel_a_trading.tex`
- Panel B entry: `_run_paper_conditional_results.R`
- Panel B helper: `code_base/evaluate_performance_paper.R`
- Panel B output: `output/paper/tables/table_6_panel_b_trading.tex`

## Saved Inputs

- Panel A: `IS_AP` trading summaries from unconditional saved results
- Panel B: conditional expanding-window `.rds` results

## Common Misreadings

- Panel B depends on the conditional pipeline; it is not just a reformatted unconditional table.
- Figure 7 is the graphical companion to Panel B, not Panel A.
