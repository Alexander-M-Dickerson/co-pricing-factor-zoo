# Main Paper Results

Use this file for fast, high-signal answers about the headline findings in the main paper.

## Headline Results

- The joint bond-stock co-pricing model outperforms bond-only and stock-only models on important pricing metrics.
- The posterior implies a fairly dense SDF rather than a tiny winning subset of factors.
- A recurring top group includes `PEADB`, `IVOL`, `PEAD`, `CREDIT`, and `YSP`.
- Bayesian model averaging delivers the strongest pricing performance among the featured benchmark comparisons.

## Factor Importance

The key message is not just that a few factors rank highly. It is that the posterior keeps meaningful mass on many factors, consistent with the idea that the zoo contains multiple noisy measures of shared risks.

Factors that repeatedly matter in discussion and outputs:

- `PEADB`
- `IVOL`
- `PEAD`
- `CREDIT`
- `YSP`

## Pricing Performance

The BMA specification is the main winner in the paper's pricing comparisons:

- it dominates standard benchmark models in in-sample pricing tables
- it stays strong in out-of-sample pricing exercises
- the joint model benefits from combining information in bond and stock markets rather than treating them separately

For code mapping, the pricing tables are produced from saved estimation outputs through the paper result scripts and helpers summarized in [tables-guide.md](./tables-guide.md).

## Dimensionality Result

One of the paper's important conceptual findings is that the SDF is not sparse in the naive sense. Posterior dimensionality summaries show a nontrivial number of active factors, which supports the "noisy proxies for common risks" interpretation.

## Economic And Trading Results

The paper also argues that the estimated SDF has economically meaningful dynamics:

- the conditional exercises show time variation in top factors
- the trading results favor the BMA-based strategy against common alternatives
- the SDF contains predictive information about future returns and related objects

These claims are anchored by Table 6 and the later figures described in [figures-guide.md](./figures-guide.md).

## Treasury And Redundancy Angle

The treasury exercises help distinguish whether bond factors are merely standing in for broad rate exposure. The paper's interpretation is that treasury adjustments do not eliminate the broader co-pricing signal, which strengthens the case that the main findings are not a trivial duration story.

## How To Answer Result Questions

- If the question is about one table, use [tables-guide.md](./tables-guide.md).
- If the question is about one figure, use [figures-guide.md](./figures-guide.md).
- If the question is about one factor, use [factors-reference.md](./factors-reference.md).
- If the question is about why the model is dense, start with [paper-method.md](./paper-method.md) and then return here.
