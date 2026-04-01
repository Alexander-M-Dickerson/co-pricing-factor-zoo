# CREDIT

## Factor Group

Nontraded factor.

## High-Level Meaning

`CREDIT` is the credit-spread factor, typically measured as the BAA minus AAA
yield spread. It proxies for changing credit conditions in the economy.

## Why It Matters In The Paper

`CREDIT` is one of the recurring top factors in the co-pricing SDF and helps
explain why nontraded risk measures remain central even in a factor zoo with
many tradable bond and equity factors.

## Gamma Interpretation

High posterior inclusion probability means the posterior frequently places
`CREDIT` inside the latent SDF, making it a likely common component of priced
risk across bonds and stocks.

## Lambda Interpretation

A meaningful posterior expected market price of risk means changes in credit
conditions carry economically important priced exposure in the joint
cross-section.

## Main Paper Refs

- Section 3.1.1
- Figure 2
- Figure 4
- Table 1
- Eq. (8)

## Common Misreadings

- `CREDIT` being important does not mean tradable bond factors are irrelevant in
  every exercise; the Treasury-component analysis still assigns a special role to
  bond factors.
- `CREDIT` is not a statement that one macro spread alone spans the full SDF.

## Repo Routing

- factor list: `docs/agent-context/factors-reference.md`
- interpretation layer: `docs/agent-context/factor-interpretation.md`
- top-factor evidence: `docs/agent-context/exhibits/figure-2.md`
- probability-plus-MPR evidence: `docs/agent-context/exhibits/figure-4.md`
- Sharpe-ratio contribution evidence: `docs/agent-context/exhibits/table-1.md`
