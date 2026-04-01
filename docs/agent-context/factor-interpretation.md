# Factor Interpretation

Use this file when the user is asking what it means for a factor to be "in the
SDF", why posterior probabilities and market prices of risk are different, or
how the paper can emphasize a few standout factors while still arguing that the
latent SDF is dense.

## Core Question

What does the paper mean when it says a factor is included in the SDF, and how
should agents interpret `gamma` versus `lambda`?

## Short Answer

- `gamma_j` is the latent inclusion indicator for factor `j`.
- `Pr(gamma_j = 1 | data)` is the posterior probability that factor `j` belongs
  in the latent SDF.
- `lambda_j` is the factor's market price of risk.
- `E[lambda_j | data]` measures how strongly that factor is priced in the
  cross-section on average.

The paper's main message is that both objects matter. A factor can look
important because it is often included, because it carries a large market price
of risk, or because it acts as a noisy proxy for a common latent risk that is
shared across several observable factors.

## Paper Refs

- Section 2.2
- Section 2.4
- Section 3.1.1
- Figure 2
- Figure 3
- Figure 4
- Table 1
- Eq. (3)
- Eq. (4)
- Eq. (7)
- Eq. (8)
- Eq. (9)

## What Inclusion Means

The paper does not use inclusion in the naive "selected by one sparse model"
sense. Instead:

- `gamma_j = 1` means factor `j` is in the slab and actively participates in a
  given posterior draw.
- `gamma_j = 0` means factor `j` is strongly shrunk toward zero in that draw.
- `Pr(gamma_j = 1 | data)` is therefore a posterior frequency statement:
  how often the factor appears as a component of the latent SDF across posterior
  draws.

So when the paper says a factor is "likely in the SDF", it means the posterior
assigns substantial probability to that factor entering the pricing kernel,
rather than the factor being the unique or exhaustive source of priced risk.

## Why Market Price Of Risk Also Matters

The paper explicitly argues that posterior inclusion probabilities are not the
whole story. Eq. (7) and Eq. (8) imply that the BMA-SDF depends on posterior
expected prices of risk across all factors, not only on the factors with the
highest inclusion probabilities.

Interpretation:

- high `gamma`, high `|lambda|`: the factor is both a robust recurring SDF
  component and a quantitatively important priced exposure
- high `gamma`, modest `|lambda|`: the factor is consistently present, but its
  standalone price of risk is not the only driver of SDF performance
- lower `gamma`, meaningful `|lambda|`: the factor may still matter for
  portfolio construction because it helps proxy a priced latent risk when it is
  selected

This is why Figure 2, Figure 4, and Table 1 should be read together, not in
isolation.

## How The Main Exhibits Fit Together

- Figure 2 answers: which factors have high posterior inclusion probability?
- Figure 4 answers: how do posterior inclusion probabilities line up with
  posterior market prices of risk?
- Table 1 answers: which factors contribute most to the SDF Sharpe ratio?
- Figure 3 answers: does the posterior collapse to a sparse model or remain
  dense?

Together they support the paper's claim that only a few factors stand above the
50% prior threshold, while the effective latent SDF still uses a materially
larger set of factors.

## Dense SDF Versus Standout Factors

This is the main conceptual guardrail for agents:

- the standout factors are `PEADB`, `IVOL`, `PEAD`, `CREDIT`, and `YSP`
- but the paper does not conclude the true SDF is literally a five-factor model
- instead, the posterior dimensionality evidence implies many factors act as
  noisy proxies for common underlying risks

So the correct explanation is:

1. a few factors stand out as especially likely and economically important
2. the latent SDF is still dense
3. BMA works well because it aggregates many correlated proxies rather than hard
   selecting one tiny model

## Noisy-Proxy Interpretation

Section 2.4 and Eq. (9) provide the theoretical intuition: even if the observed
factor is only a noisy proxy for the true latent risk, the BMA-SDF can still
recover the relevant pricing information. This is why:

- the paper cares about `E[lambda_j | data]` for all factors
- removing a few top factors does not destroy performance
- density and noisy-proxy structure are central, not secondary

## PEAD And PEADB

`PEAD` and `PEADB` are especially important because they are among the most
likely factors for inclusion and also carry meaningful prices of risk. But the
paper is careful not to treat them as narrow micro-cap artifacts.

For PEAD-specific robustness:

- use `docs/agent-context/factors/pead.md`
- use `docs/agent-context/factors/peadb.md`
- use `docs/agent-context/exhibits/ia-pead-robustness.md`

The appendix conclusion to state is:

- the PEAD and PEADB factors remain robust across size terciles
- the effect is not just concentrated in micro-cap stocks or micro-cap bonds
- this evidence is discussed in IA.4 and Tables IA.XIII-XIV, which are paper-only
  in the current repo

## Answering Strategy

When the user asks a factor question:

1. use `factors-reference.md` for the factor list and group membership
2. use this file for `gamma` / `lambda` / dense-SDF interpretation
3. use the relevant factor dossier for the economic intuition
4. use Figure 2, Figure 4, Table 1, and Figure 3 dossiers to anchor the claim
5. use the full paper only when exact equation or appendix wording is needed
