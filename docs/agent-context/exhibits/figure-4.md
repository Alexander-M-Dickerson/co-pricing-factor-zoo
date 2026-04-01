# Figure 4

## Empirical Question

How do posterior inclusion probabilities line up with posterior market prices of
risk?

## Short Answer

Figure 4 is the joint posterior view: it pairs inclusion probabilities with
market prices of risk so the reader can see both which factors survive the model
selection layer and how large their priced exposure is.

## Paper Refs

- Figure 4
- Section 3.1
- Table 1
- Figure 2

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/pp_bar_plots.R`
- Output family: `output/paper/figures/figure_4_posterior_bars_*.pdf`

## Saved Inputs

- joint-model unconditional saved results

## Common Misreadings

- High posterior probability and high market price of risk are related but not identical concepts.
