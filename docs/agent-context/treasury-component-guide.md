# Treasury Component Guide

Use this file when the user asks about the duration-adjusted return
decomposition, why bond factors are "redundant", what Eq. (10) means, or how
Figures 8 and 9 support the paper's main conclusion.

## Core Question

Why does the paper conclude that the bond factor literature is "largely
redundant" for co-pricing bonds and stocks, and what role does the Treasury
component play?

## Short Answer

The paper decomposes corporate bond excess returns into a credit component and
a Treasury term-structure component using Eq. (10). It finds that once the
Treasury component is removed, equity and nontradable factors alone suffice
for pricing. Bond factors are needed only because they price the Treasury
component — a risk that stock factors do not capture.

## Paper Refs

- Section 3.3 (duration-adjusted return analysis)
- Eq. (10) (duration-adjusted return formula)
- Figure 8 (duration-adjusted pricing densities)
- Figure 9 (Treasury component mean-vs-covariance diagnostic)
- IA.6 (detailed Treasury component analysis, Tables IA.XVI-XX)

## Eq. (10): The Duration-Adjusted Return

The paper constructs the duration-adjusted return as:

    R_{bond i,t} - R^{Treasury}_{dur bond i,t}
    = (R_{bond i,t} - R_{f,t}) - (R^{Treasury}_{dur bond i,t} - R_{f,t})
      [excess return]            [Treasury component]

where:
- `R_{bond i,t}` is the return of corporate bond `i` at time `t`
- `R_{f,t}` is the short-term risk-free rate
- `R^{Treasury}_{dur bond i,t}` is the return on a portfolio of Treasury
  securities with the same duration as bond `i`

The duration-matched Treasury portfolio is constructed following van Binsbergen
et al. (2025). This decomposition isolates the credit risk premium from the
Treasury term-structure risk premium embedded in corporate bond returns.

## Figure 8: Bond Zoo Becomes Redundant

Figure 8 is the duration-adjusted analogue of Figure 5. It shows out-of-sample
pricing density plots for three BMA-SDFs applied to the joint cross-section of
stock and duration-adjusted bond returns:

- Co-pricing BMA (bond + stock + nontradable factors): R-squared(GLS) = 0.18,
  RMSE = 0.121
- Stock BMA (stock + nontradable factors only): R-squared(GLS) = 0.15,
  RMSE = 0.099
- Bond BMA (bond + nontradable factors only): R-squared(GLS) = 0.02,
  RMSE = 0.233

The key finding: the Stock BMA actually achieves lower RMSE and MAPE than the
Co-pricing BMA for duration-adjusted returns. Once the Treasury component is
removed, equity and nontradable information suffices.

## Figure 9: Why Bond Factors Are Still Needed

Figure 9 answers: what prices the Treasury component itself?

- Panels A-B (bond factors): constrained R-squared = 97% in-sample, 92%
  out-of-sample. Fitted slope near 1.
- Panels C-D (stock factors): constrained R-squared = 6% in-sample, 6%
  out-of-sample. Fitted slope far from 1.

Bond factors price the Treasury component nearly perfectly. Stock factors
cannot. This is why the bond factor zoo is necessary in the main co-pricing
results: it captures the Treasury term-structure risk premium that is
embedded in corporate bond returns.

## The Paper's Conclusion

From Section 3.3: "the bond factor zoo is necessary for co-pricing bonds and
stocks because the factors proposed in the corporate bond literature price well
the Treasury component implicit in corporate bond returns -- a component that
stock factors fail to price. However, once this component is accounted for --
as in the case of duration-adjusted bond returns -- co-pricing can effectively
be achieved using only equity information."

The paper also notes that the Treasury component is economically important:
the ex post annualized maximum Sharpe ratio of the duration-matched Treasury
portfolios is approximately 1.48.

From the conclusion: "Strikingly, decomposing bond excess returns into their
credit and Treasury components reveals that nontradable and tradable stock
factors are largely sufficient for pricing the credit component, making the
bond factor literature effectively redundant for this purpose. Conversely,
tradable bond factors (along with nontradable ones) remain necessary for
pricing the Treasury component -- a risk that stock factors do not seem to
capture."

## What Agents Should Say

- Corporate bond returns embed both credit risk and Treasury term-structure risk
- Eq. (10) separates these two components using duration-matched Treasury
  portfolios
- Once the Treasury component is removed, stock and nontradable factors alone
  can price the remaining credit component (Figure 8)
- Bond factors are needed only to price the Treasury component (Figure 9)
- This is the basis for the paper's "bond factor zoo is redundant" conclusion

## What Agents Should Not Say

- Do not say bond factors are useless in general; they price the Treasury
  component that stock factors cannot
- Do not say the Treasury component is negligible; its Sharpe ratio is
  approximately 1.48
- Do not describe Tables IA.XVI-XX as repo-generated; the detailed Treasury
  analysis in IA.6 is paper-only
- Do not add reasons for why stock factors fail to price the Treasury component
  beyond what the paper states

## Code Paths

| Exhibit | Entry Script | Helper |
|---------|-------------|--------|
| Figure 8 | `_run_paper_results.R` | `code_base/plot_thousands_oos_densities.R` |
| Figure 9 | `_run_paper_results.R` | `code_base/plot_mean_vs_cov.R` |

Both figures use the treasury-model unconditional saved results and the
duration-adjusted test asset files from `data/`.

## Related Files

- `docs/agent-context/exhibits/figure-8.md`
- `docs/agent-context/exhibits/figure-9.md`
- `docs/agent-context/paper-results-main.md`
- `docs/manifests/manuscript_exhibits.csv` (Tables IA.XVI-XX marked paper-only)
