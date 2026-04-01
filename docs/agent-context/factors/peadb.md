# PEADB

## Factor Group

Traded bond factor.

## High-Level Meaning

`PEADB` is the bond post-earnings-announcement drift factor. It captures the
bond-market analogue of post-earnings-announcement drift, sorting bonds by the
earnings-surprise information of the issuing firm.

## Why It Matters In The Paper

`PEADB` is repeatedly one of the most important factors in the paper. It is a
key reason the paper argues that behavioral information tied to earnings news
shows up in both corporate bond and stock risk premia.

## Gamma Interpretation

High posterior inclusion probability for `PEADB` means the posterior often
assigns the bond PEAD factor to the latent SDF. This is why `PEADB` sits among
the most likely SDF components in the co-pricing results.

## Lambda Interpretation

A meaningful posterior expected market price of risk means `PEADB` also matters
quantitatively for the cross-sectional pricing relation and for the BMA-SDF's
Sharpe-ratio contribution, not only for binary selection.

## Main Paper Refs

- Section 3.1.1
- Figure 2
- Figure 4
- Table 1
- Eq. (8)

## Robustness Refs

- IA.4
- Tables IA.XIII-XIV

## Common Misreadings

- `PEADB` is not just a bond-market curiosity; it is one of the most likely
  co-pricing factors in the joint bond-stock analysis.
- `PEADB` being important does not contradict the dense-SDF result.
- The paper does not say `PEADB` is driven only by tiny bonds. The appendix
  robustness evidence says PEADB remains robust across size terciles and is not
  simply a micro-cap bond effect.

## Repo Routing

- factor list: `docs/agent-context/factors-reference.md`
- interpretation layer: `docs/agent-context/factor-interpretation.md`
- top-factor evidence: `docs/agent-context/exhibits/figure-2.md`
- probability-plus-MPR evidence: `docs/agent-context/exhibits/figure-4.md`
- Sharpe-ratio contribution evidence: `docs/agent-context/exhibits/table-1.md`
- PEAD robustness evidence: `docs/agent-context/exhibits/ia-pead-robustness.md`
