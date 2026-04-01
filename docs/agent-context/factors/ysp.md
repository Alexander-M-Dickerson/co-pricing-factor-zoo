# YSP

## Factor Group

Nontraded factor.

## High-Level Meaning

`YSP` is the yield-slope factor, typically the difference between the 5-year and
1-year Treasury yield. It proxies for the slope of the Treasury yield curve and
term-structure conditions.

## Why It Matters In The Paper

`YSP` is one of the recurring top nontraded factors and is central to the
paper's interpretation that Treasury term-structure risk matters for corporate
bond pricing. It also helps connect the main co-pricing results to the
duration-adjusted and Treasury-component exercises.

## Gamma Interpretation

High posterior inclusion probability means the posterior frequently includes
`YSP` as a component of the latent SDF, making it one of the most likely
nontraded sources of priced risk.

## Lambda Interpretation

A meaningful posterior expected market price of risk means term-structure
conditions carry quantitatively important priced exposure, not just a symbolic
selection role.

## Main Paper Refs

- Section 3.1.1
- Figure 2
- Figure 4
- Table 1
- Figure 8
- Figure 9
- Eq. (8)
- Eq. (10)

## Common Misreadings

- `YSP` is not itself the full Treasury-component story, but it is one of the
  clearest nontraded proxies for term-structure risk.
- `YSP` being important does not mean the bond factor zoo is entirely redundant
  in Treasury-component pricing exercises.

## Repo Routing

- factor list: `docs/agent-context/factors-reference.md`
- interpretation layer: `docs/agent-context/factor-interpretation.md`
- top-factor evidence: `docs/agent-context/exhibits/figure-2.md`
- probability-plus-MPR evidence: `docs/agent-context/exhibits/figure-4.md`
- Sharpe-ratio contribution evidence: `docs/agent-context/exhibits/table-1.md`
- Treasury interpretation: `docs/agent-context/exhibits/figure-9.md`
