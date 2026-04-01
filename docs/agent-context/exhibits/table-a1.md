# Table A.1

## Empirical Question

What are the 54 bond, stock, and nontraded factors used for cross-sectional
asset pricing in the paper?

## Short Answer

Manuscript Table A.1 is the factor-list appendix table, not the posterior-
probability appendix table. In this repo, the canonical explanation surface for
Table A.1 is [factors-reference.md](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/docs/agent-context/factors-reference.md), which groups the 54 factors into 16 traded bond factors, 24 traded equity factors, and 14 nontraded factors and summarizes their construction.

## Paper Refs

- Table A.1
- Appendix A: The factor zoo list
- Figure 2 refers users to Table A.1 for factor descriptions

## Code Path

- Explanation surface: `docs/agent-context/factors-reference.md`
- Underlying factor files:
  - `data/nontraded_factors.csv`
  - `data/traded_bond_excess.csv`
  - `data/traded_equity.csv`
- Saved estimation outputs also expose:
  - `nontraded_names`
  - `bond_names`
  - `stock_names`

## Saved Inputs

- factor-list metadata from the manuscript
- repo factor CSV headers and saved factor-name vectors

## Common Misreadings

- Manuscript Table A.1 is the factor list, not the appendix posterior-
  probability table.
- The repo output basename `table_a1_posterior_probs_*` is a draft-numbering
  artifact and corresponds to the posterior-probability appendix table, not to
  manuscript Table A.1.
