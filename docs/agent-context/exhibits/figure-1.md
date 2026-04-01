# Figure 1

## Empirical Question

Can the Bayesian model-averaging SDF recover the correct pricing signal even
when the true factor is absent and only noisy proxies are observed?

## Short Answer

Figure 1 is the paper's simulation evidence for the noisy-proxy argument in
Section 2.4. The default paper build now republishes the tracked paper Figure 1
panel fixtures directly, which keeps the compiled PDF aligned with the original
published raster exports. The repo also exposes an explicit regeneration path
for the underlying Monte Carlo outputs, but that path is separate from the
default paper build.

## Paper Refs

- Figure 1
- Section 2.4
- Internet Appendix IA.2
- `docs/manifests/paper_claims.csv`, Claim 9

## Code Path

- Entry script: `_run_paper_results.R`
- Helper: `code_base/figure1_simulation.R`
- Optional regeneration: `tools/run_figure1_simulation.R`
- Output family: `output/paper/figures/Fig_01_*.jpeg`
- LaTeX snippet: `output/paper/latex/fig1_simulation.tex`

## Saved Inputs

- `misc/figure1_simulation/pseudo-true.RData`
- `misc/figure1_simulation/simulation400psi60.RData`
- `misc/figure1_simulation/simulation1600psi60.RData`
- `misc/figure1_simulation/monthly_return.csv`
- `misc/figure1_simulation/Fig_01_0_sim_legend.jpeg`
- `misc/figure1_simulation/Fig_01_1_OLS_60_400_BMA_MPR.jpeg`
- `misc/figure1_simulation/Fig_01_2_OLS_60_1600_BMA_MPR.jpeg`
- `misc/figure1_simulation/Fig_01_3_OLS_60_400_factor_MPRs.jpeg`
- `misc/figure1_simulation/Fig_01_4_OLS_60_1600_factor_MPRs.jpeg`
- `misc/figure1_simulation/Fig_01_5_OLS_60_400_factor_probs.jpeg`
- `misc/figure1_simulation/Fig_01_6_OLS_60_1600_factor_probs.jpeg`

## Common Misreadings

- The default Figure 1 build does not rerun the Monte Carlo simulation and does
  not regenerate the published raster panels; it republishes the tracked paper
  Figure 1 fixtures.
- The explicit regeneration path is separate from the normal paper pipeline and
  is best treated as a validation workflow, not the default production source
  of truth for the paper PDF.
- Figure 1 is simulation evidence, not an empirical unconditional or conditional
  asset-pricing output.
