# IA.4 PEAD Robustness

## Empirical Question

Are the PEAD and PEADB results just small-cap or micro-cap effects, or do they
remain robust across size terciles?

## Short Answer

The paper's appendix answer is no: the PEAD and PEADB effects remain robust
across size terciles and are not simply driven by micro-cap stocks or micro-cap
bonds.

## Paper Refs

- IA.4
- Tables IA.XIII-XIV
- Section 3.1.1 footnote 26

## What The Appendix Shows

- Table IA.XIII studies the stock PEAD factor across size terciles and
  micro-cap inclusion/exclusion choices.
- Table IA.XIV studies the bond PEADB factor across size terciles and
  micro-cap inclusion/exclusion choices.

The conclusion agents should state is:

- PEAD remains economically and statistically meaningful across size terciles
- PEADB also remains meaningful across size terciles
- the evidence is not consistent with a "this is only a micro-cap effect"
  dismissal

## Repo Coverage

This evidence is paper-only in the current repo.

- the repo does not currently generate Tables IA.XIII-XIV
- agents may explain and cite these appendix results from the manuscript
- agents must not describe this evidence as an executable repo output

## Common Misreadings

- IA.4 is an appendix section about PEAD robustness, not the implemented repo
  exhibit named `Table IA.4`, which is a different posterior-probability table
  in the IA output subset.
- This appendix evidence is about robustness of the factor construction and
  return spread, not about reranking the main posterior-probability figure.

## Related Files

- `docs/agent-context/factor-interpretation.md`
- `docs/agent-context/factors/pead.md`
- `docs/agent-context/factors/peadb.md`
- `docs/manifests/paper_claims.csv`
