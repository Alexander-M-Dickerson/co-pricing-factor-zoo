# Paper Method

This is the compact method briefing for explaining the econometric setup and mapping it to repo code.

## SDF Setup

The paper uses a linear stochastic discount factor built from factor returns. In words:

- the SDF loads on demeaned factors
- `lambda` are the market prices of risk
- expected returns are explained by factor covariances with the SDF plus optional pricing errors

The estimation problem is to determine which factors meaningfully enter the SDF and what prices of risk they carry.

## Bayesian Variable Selection

Each factor's price of risk receives a continuous spike-and-slab prior:

- `gamma_j = 1` means the factor is in the slab and meaningfully active
- `gamma_j = 0` means the factor is heavily shrunk toward zero
- `psi_j` scales the prior variance
- `omega_j` governs inclusion probability
- `sigma^2` captures residual variance in the pricing relation

The paper's variable-selection logic matters because the factor zoo is large enough that fixed benchmark models are not credible as the only specification.

## Gibbs Sampler Blocks

At a high level, each draw updates:

1. time-series moments of factors and returns
2. the vector of market prices of risk `lambda`
3. the inclusion indicators `gamma`
4. the inclusion probabilities and residual variance

The posterior distribution over these draws is then used for both factor-importance summaries and Bayesian model-averaged pricing objects.

## BMA-SDF Intuition

The Bayesian model-averaged SDF is not one hard-selected model. It averages over posterior draws, which lets many correlated factors contribute as noisy proxies for a smaller set of underlying risks. That is why the paper can rank standout factors while still finding a relatively dense effective SDF.

## Tradable Versus Non-Tradable Factors

This distinction is critical in the code:

- `continuous_ss_sdf(f, R, ...)` takes factors first and test assets second
- `continuous_ss_sdf_v2(f1, f2, R, ...)` takes non-traded factors, tradable factors, then test assets
- tradable factors in `f2` are self-pricing and must be handled as such

Do not swap argument order when explaining or editing the method implementation.

## `kappa` Extension In This Repo

The repo adds a local `kappa`-weighted shrinkage extension on top of the BHJ package base.

Prior calibration:

- `kappa = NULL`: use `BayesianFactorZoo::psi_to_priorSR`
- any supplied `kappa` object, including zero-valued numeric inputs: use the local
  `psi_to_priorSR_multi_asset*` helper path

Sampler dispatch:

- tradable factors present and any `kappa != 0`: use the local multi-asset-weight extension in `code_base/`
- no tradable factors and any `kappa != 0`: use the local no-self-pricing extension in `code_base/`
- otherwise: use the baseline package samplers (`BayesianFactorZoo::continuous_ss_sdf_v2` or `BayesianFactorZoo::continuous_ss_sdf`)

Most baseline runner scripts still pass `kappa = 0`, so the sampler remains on
the package path even though prior calibration may go through the local helper
because `kappa` is not `NULL`.

## What The Priors Mean Empirically

The prior Sharpe-ratio scaling choices control how much room the posterior gives the SDF to load on the factor zoo. In the results, stronger prior support for larger Sharpe ratios tends to elevate the joint model's already-strong pricing performance, but the factor rankings remain economically interpretable rather than arbitrary.

## Code Map

Use this map when translating the method into repo structure:

- `_run_all_unconditional.R`
- `code_base/run_bayesian_mcmc.R`
- `code_base/run_bayesian_mcmc_time_varying.R`
- `BayesianFactorZoo/R/continuous_ss_sdf.R`
- `BayesianFactorZoo/R/continuous_ss_sdf_v2.R`
- local `code_base/*continuous_ss_sdf*` extensions
- `code_base/insample_asset_pricing.R`

## Explanation Guardrails

- Do not describe the method as ordinary factor regression or simple lasso selection.
- Do not imply the joint model works by inventing new `model_type` values.
- When explaining saved results, rely on stored objects such as `nontraded_names`, `bond_names`, and `stock_names` rather than reconstructing classification from column names.
