# Noisy-Proxy Guide

Use this file when the user asks why the SDF is dense, how BMA recovers pricing
when factors are "just noisy proxies", or what Eq. (9) and Section 2.4 mean.

## Core Question

How can a dense SDF (posterior median 22 factors) be interpretable and useful
rather than overfitted, and why does BMA work when observed factors are imperfect
proxies for latent risks?

## Short Answer

The paper argues in Section 2.4 that observable factors are noisy proxies for a
smaller set of true latent risk sources. Eq. (9) shows that even a single noisy
proxy prices test assets perfectly in population but yields an inflated market
price of risk. Because many observed factors proxy the same underlying risks,
the BMA-SDF aggregates across them to recover a well-calibrated pricing kernel.
The SDF is dense in the space of observables but parsimonious in the space of
latent risks.

## Paper Refs

- Section 2.4 (theoretical framework)
- Eq. (9) (noisy proxy pricing result)
- Figure 1 (simulation validation)
- Section 3.1.1 (empirical connection to standout factors)
- Figure 3 (posterior dimensionality)
- IA.2 (simulation design details)
- Figures IA.9-IA.10 (additional simulation experiments)

## The Theory (Section 2.4)

The paper defines a noisy proxy as an observed factor whose return is a mixture
of the true latent risk factor and idiosyncratic noise:

    f_{j,t} = delta_j * f_{true,t} + sqrt(1 - delta_j^2) * w_{j,t}

where `delta_j` captures both the correlation with the true factor and the
signal-to-noise ratio. The key result is Eq. (9): a misspecified SDF built from
a single noisy proxy prices all test assets perfectly in population. The catch
is that the estimated market price of risk is inflated by `1/delta_j` compared
to the true value.

This means:

- any noisy proxy can appear to be a valid pricing factor
- its standalone lambda will overstate the true price of risk
- removing one noisy proxy and replacing it with another still gives correct
  pricing
- no single noisy proxy is uniquely necessary

## Why BMA Solves This

The paper shows that BMA handles this by averaging over the model space rather
than selecting one sparse model. Because BMA assigns posterior weight to many
models, each potentially using different combinations of noisy proxies, the
weighted average SDF recovers the correct pricing kernel.

From the paper (Section 2.4): "the BMA-SDF estimator accurately recovers the
market price of risk of the SDF not only when the pseudo-true factor is included
among the candidate pricing factors, but also when only noisy proxies of the
true source of risk are included."

## Figure 1: Simulation Validation

Figure 1 provides the simulation evidence for this claim. It presents six
experiments with T=400 and T=1600 observations:

- Experiments I-III: the pseudo-true factor is among the candidates
- Experiments IV-VI: only noisy proxies are available (the true factor is absent)

The key results from Figure 1:

- Panels A-B: BMA-SDF market prices of risk are accurately recovered in all six
  experiments, even when the true factor is absent
- Panels C-D: individual factor MPRs are inflated (as Eq. (9) predicts), but
  BMA averages them correctly
- Panels E-F: posterior inclusion probabilities spread across the noisy proxies
  rather than concentrating on one factor

The paper notes that "the estimates are sharp -- the distributions of the
BMA-MPRs across simulation runs have 95% coverage areas very similar to the ones
obtained (without accounting for model uncertainty) in the much longer true
sample."

## Connection To The Dense SDF Result

The empirical results in Section 3.1 show that the posterior median number of
factors in the SDF is 22 (95% CI: 15-29, from Figure 3 Panel A). The paper
interprets this through the noisy-proxy lens:

- the true latent SDF is dense in the space of 54 observable factors
- this density arises because many observed factors are correlated proxies for
  common underlying risks
- the BMA-SDF is not overfitting; it is aggregating across redundant signals
- the resulting maximum Sharpe ratio "is not extreme because the many factors
  necessary for an accurate characterization of the latent SDF are multiple
  noisy proxies for common underlying sources of risk" (paper conclusion)

## Connection To The Standout Factors

The five standout factors (PEADB, IVOL, PEAD, CREDIT, YSP) are the only ones
with posterior inclusion probabilities above the 50% prior threshold. The paper
does not interpret this as meaning the true SDF is literally five-dimensional.
Instead, these are the factors whose signal-to-noise ratio is high enough to
stand out individually, while the remaining factors contribute collectively as
noisy proxies.

## What Agents Should Say

When explaining the dense SDF:

1. The SDF is dense in observables but parsimonious in latent risks
2. Many observed factors proxy common underlying risk sources
3. BMA aggregates across these proxies rather than picking one sparse model
4. This is why the BMA-SDF outperforms all low-dimensional benchmark models
5. The out-of-sample Sharpe ratio (1.5-1.8) is achievable because BMA exploits
   the redundancy structure rather than overfitting to noise

## What Agents Should Not Say

- Do not say the true SDF is literally a 22-factor model
- Do not say the five standout factors are the only ones that matter
- Do not say BMA is just model selection with more models
- Do not say the dense SDF implies all factors are equally important
- Do not add explanations for why specific factors matter beyond what the paper
  states

## Related Files

- `docs/agent-context/factor-interpretation.md`: gamma vs. lambda interpretation
- `docs/agent-context/exhibits/figure-1.md`: Figure 1 dossier
- `docs/agent-context/exhibits/figure-3.md`: Figure 3 dossier (dimensionality)
- `docs/agent-context/factors-reference.md`: full 54-factor list
