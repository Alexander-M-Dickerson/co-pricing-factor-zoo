# Table 1

## Empirical Question

Which five factors contribute most to the BMA-SDF Sharpe ratio in the co-pricing,
bond-only, and stock-only settings?

## Short Answer

The co-pricing SDF's recurring top five are `PEADB`, `IVOL`, `PEAD`, `CREDIT`,
and `YSP`. Table 1 shows that these top factors explain a large share of the
achievable SDF Sharpe ratio, but not all of it, which is why the paper still
argues the latent SDF is dense rather than literally five-factor sparse.

## Panels And Metrics

- Panel A: co-pricing SDF
- Panel B: bond-only SDF
- Panel C: stock-only SDF
- Metric 1: `E[SR_f | data]`
- Metric 2: `E[SR_f^2 / SR_m^2 | data]`

## Paper Refs

- Table 1
- Section 3.1.1
- Figure 2
- Figure 4
- `docs/manifests/paper_claims.csv`, Claim 1

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/sr_tables.R`
- Output: `output/paper/tables/table_1_top5_factors.tex`

## Saved Inputs

- unconditional saved estimation results
- SR decomposition summaries produced by `code_base/sr_decomposition.R`

## Common Misreadings

- Table 1 is about top Sharpe-ratio contributors, not just posterior probability rankings.
- The top five co-pricing factors are important, but the paper's broader claim is still that many factors act as noisy proxies for shared risks.
- Table 1 is not the same object as Table A.1, which is the appendix posterior-probability table.
