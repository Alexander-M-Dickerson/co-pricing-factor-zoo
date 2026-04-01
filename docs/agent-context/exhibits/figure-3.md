# Figure 3

## Empirical Question

Is the latent SDF sparse or dense once posterior uncertainty is taken seriously?

## Short Answer

Figure 3 is the main visual evidence for the paper's dense-SDF claim. The
posterior dimensionality does not collapse to five factors; instead it supports
a materially larger active set, which is why the paper emphasizes noisy proxies
for shared risks rather than one tiny winning subset.

## Paper Refs

- Figure 3
- Section 3.1
- `docs/manifests/paper_claims.csv`, Claim 2

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/plot_nfac_sr.R`
- Output family: `output/paper/figures/figure_3_nfac_sr_*.pdf`

## Saved Inputs

- joint-model unconditional saved results with `sdf_path`

## Common Misreadings

- Figure 3 is about posterior dimensionality, not just model fit.
- A dense latent SDF is compatible with only a few factors having the very highest posterior probabilities.
