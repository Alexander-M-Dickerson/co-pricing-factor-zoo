# IVOL

## Factor Group

Nontraded factor.

## High-Level Meaning

`IVOL` is the idiosyncratic equity-volatility factor. In the paper it proxies
for equity risk conditions that matter for the cross-section of bond and stock
returns.

## Why It Matters In The Paper

`IVOL` is one of the recurring nontraded factors that stands out alongside
`PEADB`, `PEAD`, `CREDIT`, and `YSP`. Its importance supports the paper's claim
that nontraded macro-financial risks help explain the joint cross-section.

## Gamma Interpretation

High posterior inclusion probability means the posterior repeatedly includes
`IVOL` in the latent SDF. This makes it one of the most likely nontraded
components of the pricing kernel.

## Lambda Interpretation

A meaningful posterior expected market price of risk means `IVOL` is not only
frequently selected, but also economically important for the priced exposure of
the joint SDF.

## Main Paper Refs

- Section 3.1.1
- Figure 2
- Figure 4
- Table 1
- Eq. (8)

## Common Misreadings

- `IVOL` is nontraded, so its importance does not mean it directly forms a
  tradable standalone strategy inside the BMA-SDF.
- `IVOL` matters because it helps proxy priced latent risks, not because the
  paper is making a one-factor idiosyncratic-volatility claim.

## Repo Routing

- factor list: `docs/agent-context/factors-reference.md`
- interpretation layer: `docs/agent-context/factor-interpretation.md`
- top-factor evidence: `docs/agent-context/exhibits/figure-2.md`
- probability-plus-MPR evidence: `docs/agent-context/exhibits/figure-4.md`
- Sharpe-ratio contribution evidence: `docs/agent-context/exhibits/table-1.md`
