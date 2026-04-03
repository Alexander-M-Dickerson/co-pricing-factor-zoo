# Time-Varying Results Guide

Use this file when the user asks about the expanding-window estimation, how
factor importance changes over time, or how the paper validates time-varying
SDF behavior.

## Core Question

Does the set of important pricing factors remain stable over time, and does the
BMA-SDF exhibit economically meaningful dynamics?

## Short Answer

The paper uses an expanding-window design (Section 3.1.3) to show that the
relevant factors remain "remarkably stable" over time. The BMA-SDF itself is
persistent, tracks the business cycle, exhibits countercyclical conditional
volatility (Section 3.4, Figures 10-11), and predicts future asset returns with
median monthly R-squared of 1.7% and median annual R-squared of 9.7%
(Figure 12).

## Paper Refs

- Section 3.1.3 (time-varying factor importance)
- Section 3.4 (SDF dynamics and predictability)
- Figure 6 (top factors over time)
- Figure 7 (out-of-sample cumulative returns)
- Figure 10 (BMA-SDF time series)
- Figure 11 (conditional volatility comparison)
- Figure 12 (return predictability)
- Figure 13 (cumulative Sharpe ratio)
- Table 6 Panel B (out-of-sample trading performance)
- IA.3.3 (expanding-window design details)
- IA.8 (ACFs, GARCH analysis, Table IA.XXI)

## The Expanding-Window Design

The paper splits the sample in half (222 monthly observations each) and
estimates the model in two directions:

**Forward expanding window:**
- starts with the first subsample (July 1986 to June 2004)
- re-estimates every year, adding 12 new observations at each step
- continues forward through December 2022

**Backward expanding window:**
- starts with the second subsample (July 2004 to December 2022)
- re-estimates every year, adding 12 earlier observations at each step
- continues backward through January 1986

Throughout, the prior shrinkage is fixed at 80% of the corresponding ex post
maximum Sharpe ratio for each window. This design tests whether factor
importance is driven by a specific sub-period or is robust to the direction
of sample accumulation.

## Figure 6: Factor Stability Over Time

Figure 6 shows heatmaps of the top five factors ordered by posterior
probabilities at each expanding-window step.

- Panel A (forward): IVOL, PEAD, PEADB, YSP, CREDIT feature prominently
  throughout
- Panel B (backward): IVOL, YSP, CREDIT, PEADB remain stable

The paper's conclusion: the relevant factors remain remarkably stable regardless
of the direction of sample accumulation or the specific sub-period used.

Figure IA.17 provides the companion view using market prices of risk (lambda)
rather than posterior probabilities (gamma).

## Figure 7 and Table 6 Panel B: Out-of-Sample Trading

The conditional expanding-window results also generate out-of-sample trading
performance. At each window step, the BMA-SDF constructs a tradable portfolio
from the estimated posterior weights, and its out-of-sample returns are measured
in the held-out period.

Table 6 Panel B reports the annualized out-of-sample Sharpe ratios:
- BMA-SDF achieves OS Sharpe ratios of 1.5-1.8
- This outperforms all benchmark factor models (CAPM, FF5, etc.)

Figure 7 plots the cumulative out-of-sample returns over the full sample,
showing the BMA-SDF's sustained outperformance relative to benchmark models.

## Figures 10-11: SDF Dynamics

Figure 10 plots the BMA-SDF level over time (Eq. 7). The paper finds that:
- the SDF is persistent
- it tracks the business cycle
- it increases during recessions and periods of economic uncertainty

Figure 11 compares the conditional volatility of the BMA-SDF against benchmark
SDFs (CAPMB, FF5). The paper finds that:
- BMA-SDF conditional volatility is countercyclical
- it increases sharply during recessions
- this suggests time variation in conditional risk premia

## Figure 12: Return Predictability

Figure 12 tests whether lagged BMA-SDF information predicts future tradable
factor returns.

- Panel A (monthly horizon): median R-squared of 1.71%; significant at 5% in
  62% of cases and at 10% in 75% of cases
- Panel B (twelve-month horizon): median R-squared of 9.71%; significant at 5%
  in 45% of cases and at 10% in 57% of cases

The paper describes this predictability as "economically large."

## Figure 13: Cumulative Sharpe Ratio

Figure 13 shows how the SDF-implied maximum Sharpe ratio grows as factors are
added one at a time, ordered by their posterior probability. This illustrates
the dense-SDF finding: the Sharpe ratio continues to grow well beyond the first
five factors, confirming that many factors contribute to the SDF's pricing power.

## What Agents Should Say

- The expanding-window design tests factor stability by accumulating data from
  both ends of the sample
- The top factors (IVOL, PEAD, PEADB, YSP, CREDIT) remain stable over time
- The BMA-SDF is persistent and tracks the business cycle
- Out-of-sample trading performance (SR 1.5-1.8) demonstrates that the in-sample
  results are not overfitting
- Lagged SDF information predicts future returns

## What Agents Should Not Say

- Do not claim the expanding window is a rolling window (it expands, not rolls)
- Do not confuse the conditional estimation (expanding window) with time-varying
  parameters (the model parameters are re-estimated from scratch at each step)
- Do not describe the SDF dynamics results (Table IA.XXI, GARCH analysis) as
  repo-generated; they are paper-only

## Code Paths

| Exhibit | Entry Script | Helper |
|---------|-------------|--------|
| Figure 6 | `_run_paper_results.R` | `code_base/expanding_runs_plots.R` |
| Figure 7 | `_run_paper_conditional_results.R` | `code_base/evaluate_performance_paper.R` |
| Table 6 Panel B | `_run_paper_conditional_results.R` | `code_base/evaluate_performance_paper.R` |
| Figure 10-11 | `_run_paper_results.R` | `code_base/fit_sdf_models.R` |
| Figure 12 | `_run_paper_results.R` | `code_base/fit_sdf_models.R` |
| Figure 13 | `_run_paper_results.R` | `code_base/plot_cumulative_sr.R` |
| Figure IA.17 | `_run_paper_results.R` | `code_base/expanding_runs_plots.R` |

## Related Files

- `docs/agent-context/exhibits/figure-6.md`
- `docs/agent-context/exhibits/figure-7.md`
- `docs/agent-context/exhibits/table-6.md`
- `docs/agent-context/exhibits/figure-10.md`
- `docs/agent-context/exhibits/figure-12.md`
- `docs/agent-context/exhibits/figure-13.md`
