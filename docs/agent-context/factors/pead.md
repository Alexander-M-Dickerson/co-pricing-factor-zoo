# PEAD

## Factor Group

Traded equity factor.

## High-Level Meaning

`PEAD` is the stock post-earnings-announcement drift factor. It captures the
well-known cross-sectional return pattern in which firms with stronger earnings
surprises continue to earn higher returns after the announcement.

## Why It Matters In The Paper

`PEAD` is one of the recurring top factors in the joint co-pricing results. The
paper treats it as one of the most likely observable proxies for priced risk in
the combined bond-stock cross-section.

## Gamma Interpretation

High posterior inclusion probability for `PEAD` means the posterior frequently
places the stock PEAD factor inside the latent SDF. In the paper's language,
this makes `PEAD` a likely component of the pricing kernel rather than merely a
factor with a strong standalone sample mean.

## Lambda Interpretation

A large posterior expected market price of risk for `PEAD` means the factor is
not only selected often, but also carries meaningful priced exposure when the
cross-section is summarized through the BMA-SDF. This is why Figure 4 and Table
1 matter alongside Figure 2.

## Main Paper Refs

- Section 3.1.1
- Figure 2
- Figure 4
- Table 1
- Eq. (8)

## Robustness Refs

- IA.4
- Tables IA.XIII-XIV
- Section 3.1.1 footnote 26

## Common Misreadings

- `PEAD` is not the same factor as `PEADB`; the former is the stock factor and
  the latter is the bond factor.
- High `gamma` for `PEAD` does not mean the whole SDF is sparse or reduced to
  one behavioral factor.
- The paper does not say `PEAD` is only a small-cap effect. The appendix
  robustness evidence says the PEAD result remains robust across size terciles
  and is not simply a micro-cap artifact.

## Repo Routing

- factor list: `docs/agent-context/factors-reference.md`
- interpretation layer: `docs/agent-context/factor-interpretation.md`
- top-factor evidence: `docs/agent-context/exhibits/figure-2.md`
- probability-plus-MPR evidence: `docs/agent-context/exhibits/figure-4.md`
- Sharpe-ratio contribution evidence: `docs/agent-context/exhibits/table-1.md`
- PEAD robustness evidence: `docs/agent-context/exhibits/ia-pead-robustness.md`
