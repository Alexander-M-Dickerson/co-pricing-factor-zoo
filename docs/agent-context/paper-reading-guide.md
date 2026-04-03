# Paper Reading Guide

Use this file when the task is to explain the paper quickly and accurately without rereading the full manuscript every time.

The canonical full manuscript is `docs/paper/co-pricing-factor-zoo.ai-optimized.md`.

## Core Question

Can equity and nontradable factors explain corporate bond risk premia once Treasury term-structure risk is accounted for, and what does the joint factor zoo imply for the pricing of bond and stock returns?

## Short Answer

The paper argues that the bond factor zoo becomes much less special once Treasury risk is separated out. Equity and nontradable factors explain the corporate bond component well, while the full Bayesian model-averaged SDF remains fairly dense because many observed factors are noisy proxies for shared risks.

## Dataset and Setting

- Monthly sample: January 1986 to December 2022.
- Cross-sections: bond portfolios, stock portfolios, and joint bond-stock test assets.
- Factor blocks:
  - non-traded macro and intermediary factors
  - traded bond factors
  - traded equity factors

## Claims To Keep Straight

- Joint co-pricing beats bond-only and stock-only views on several pricing metrics.
- The posterior does not collapse to a tiny factor set; the SDF is fairly dense.
- A recurring top set includes `PEADB`, `IVOL`, `PEAD`, `CREDIT`, and `YSP`.
- Bayesian model averaging improves in-sample pricing and remains strong out of sample.
- Conditional and trading exercises show economically meaningful variation over time.

## Suggested Reading Paths

### If the user wants intuition

1. abstract and introduction
2. [paper-method.md](./paper-method.md)
3. [paper-results-main.md](./paper-results-main.md)

### If the user wants code-to-paper mapping

1. [replication-pipeline.md](./replication-pipeline.md)
2. [tables-guide.md](./tables-guide.md)
3. [figures-guide.md](./figures-guide.md)

### If the user wants factor-specific context

1. [factors-reference.md](./factors-reference.md)
2. [factor-interpretation.md](./factor-interpretation.md)
3. [factors/README.md](./factors/README.md)
4. [paper-results-main.md](./paper-results-main.md)
5. saved factor-name vectors in estimation outputs

## Minimal Notation Cheat Sheet

- `f`: factor returns
- `R`: test-asset returns
- `lambda`: market prices of risk
- `gamma`: latent inclusion indicator
- `omega`: inclusion probability parameter
- `psi`: prior scaling for factor risk prices
- `kappa`: local shrinkage-weight extension used in this repo
- `BMA-SDF`: posterior average of sampled SDF realizations

## Code Orientation

When explaining how the paper maps to the repo:

- estimation logic starts in `code_base/run_bayesian_mcmc.R`
- unconditional orchestration starts in `_run_all_unconditional.R`
- conditional orchestration starts in `_run_all_conditional.R`
- table and figure generation starts in `_run_paper_results.R` and `_run_paper_conditional_results.R`

## Answering Strategy

- Start from the empirical question, not the sampler internals.
- Use the shared table and figure guides to anchor claims to actual outputs.
- If a result depends on a saved estimation file, prefer the stored objects and factor-name vectors over reconstructed guesses.
