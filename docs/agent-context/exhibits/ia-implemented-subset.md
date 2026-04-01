# IA Implemented Subset

Use this file when the user asks about the Internet Appendix implementation
surface in this repo.

## What Is Implemented

- posterior-probability tables for the intercept and no-intercept IA models
- IA pricing tables for the no-intercept models
- duration-adjusted pricing robustness output
- treasury-branch posterior probability, SR decomposition, and figure analogues
- sparse-joint posterior probability and pricing outputs
- IS/OS-switch posterior probability and pricing outputs
- weighted-treasury output using the tracked `ia/data/w_all.rds` file that ships with the clone

## What Is Not Implemented As A Public Repo Surface

- the full manuscript IA exhibit set
- the broader kappa-tilt, factor-exclusion, and sample-split appendix tables and figures
- the manuscript's deeper simulation and robustness appendices

## Routing Rule

- for implemented IA outputs: use `docs/manifests/exhibits.csv`
- for manuscript IA coverage questions: use `docs/manifests/manuscript_exhibits.csv`
- for exact paper wording: use `docs/paper/co-pricing-factor-zoo.ai-optimized.md`
