# IS_AP Object Specification

This document describes the structure of the `IS_AP` object.

At a high level:

- It contains **in-sample** pricing information for a set of models (Bayesian, frequentist, PC-based, KNS, and optimal portfolios).
- All model-specific entries are organized in named lists keyed by **model identifiers** (e.g. `"BMA-20%"`, `"CAPM"`, `"RP-PCA"`, `"KNS"`, `"Tangency"`, etc.).
- It also stores **SDF time series**, **mimicking portfolio returns**, and **summary pricing metrics** across all models.

---

## 1. Top-Level Structure

`IS_AP` is an R `list` with the following elements:

1. `lambdas`  
2. `scaled_lambdas`  
3. `weights`  
4. `gammas`  
5. `date_end`  
6. `dates`  
7. `top_factors`  
8. `top_mpr_factors`  
9. `top_factors_all`  
10. `top_mpr_factors_all`  
11. `kns_pcs_weights`  
12. `knsf2_pc_weights`  
13. `rppca_pcs_weights`  
14. `rppcaf2_pc_weights`  
15. `pca_pcs_weights`  
16. `pcaf2_pc_weights`  
17. `is_pricing_result`  
18. `sdf_mat`  
19. `sdf_mim`  

Each element is documented below.

---

## 2. Lambda Objects

### 2.1 `lambdas`

**Type:** `list` of model-specific matrices  
**Purpose:** Raw market prices of risk (λ) for each model.

- `names(IS_AP$lambdas)` = set of model IDs (e.g. `"BMA-20%"`, `"FF5"`, `"RP-PCA"`, `"KNS"`, `"Tangency"`, etc.).
- Each entry is a `1 × P_m` numeric matrix:
  - **Row name:** `date_end` (e.g. `"unconditional"` or `"YYYY-MM-DD"`).
  - **Column names:** intercept (if present) + model-specific factor identifiers.
- For PC-based and KNS models, columns correspond to selected PCs; names may be generic (e.g. `"PC1"`, `"PC2"`, …) or re-labeled programmatically upstream.

Interpretation:

- Element `(1, j)` is the **price of risk** associated with factor `j` in that model, in the **scaled factor space used during estimation** (i.e., before any SD-descaling).

### 2.2 `scaled_lambdas`

**Type:** `list` of model-specific matrices  
**Purpose:** Market prices of risk in a common scale (descaled by factor standard deviations).

- Same keys as `lambdas`: `names(IS_AP$scaled_lambdas)` = model IDs.
- Each entry is a `1 × P_m` numeric matrix:
  - **Row name:** `date_end`.
  - **Column names:** same as corresponding `lambdas` entry.
- Construction:
  - For each model, non-intercept entries are divided by the **factor standard deviation** computed from the appropriate factor matrix:
    - Bayesian models: from `f_all`.
    - Frequentist models: from `fac_freq`.
    - PC-based models: from PC factor matrices.
    - KNS: raw and scaled lambdas coincide by construction.
- Intercept (if present) is left on its original scale.

Interpretation:

- `scaled_lambdas` can be used directly to construct **factor-mimicking portfolios**, as they are on the underlying factor scale.

---

## 3. Portfolio Weights

### 3.1 `weights`

**Type:** `list` of model-specific matrices  
**Purpose:** Weights of tradable portfolios that implement the SDF or factor-mimicking payoffs.

- `names(IS_AP$weights)` = subset of model IDs (those for which tradable portfolios are defined), including:
  - Bayesian models (e.g. `"BMA-20%"` …),
  - Frequentist models (e.g. `"CAPM"`, `"FF5"`),
  - PC-based models (e.g. `"RP-PCA"`, `"PCA"`),
  - KNS models (e.g. `"KNS"`, `"KNSf2"`),
  - Optimal portfolios (e.g. `"Tangency"`, `"MinVar"`, `"EqualWeight"`, and their variants using different factor sets).
- Each entry is a `1 × A_m` numeric matrix:
  - **Row name:** `date_end`.
  - **Column names:** tradable asset identifiers for that model.
    - For models built from a set of traded factors, columns correspond to those factors.
    - For PC-based and KNS models, columns correspond to the underlying test assets (or combined asset universe) used to build PCs.

Invariants:

- For all multi-asset entries, weights are **normalized to sum to 1** (budget-1 portfolios).
- For single-factor frequentist models (e.g. one-factor CAPM), the sole weight is exactly `1.0`.

Interpretation:

- These weights can be applied to the underlying return matrix used in estimation (e.g. `R`, `f2`, or `cbind(R, f2)`) to obtain the model’s **tradable return** that corresponds to its SDF component or factor-mimicking portfolio.

---

## 4. Bayesian Inclusion Probabilities

### 4.1 `gammas`

**Type:** `list` of matrices, one per Bayesian prior scale  
**Purpose:** Posterior inclusion probabilities (average γ) for the Bayesian models.

- `names(IS_AP$gammas)` = `c("BMA-20%", "BMA-40%", "BMA-60%", "BMA-80%")`.
- Each entry is a `1 × F` numeric matrix:
  - **Row name:** `date_end`.
  - **Column names:** factor identifiers in `f_all` (excluding intercept).
- Values lie in `[0, 1]`, representing the posterior probability that each factor is included in the SDF for the corresponding prior scale.

Interpretation:

- These probabilities are used to:
  - Rank factors by **importance** for each prior scale.
  - Construct lists of top probability factors (`top_factors`, `top_factors_all`).

---

## 5. Date Information

### 5.1 `date_end`

**Type:** scalar `character` or `Date`  
**Purpose:** Label of the last date of the estimation window used to construct `IS_AP`.

- Example: `"unconditional"` for full-sample estimation, or `"YYYY-MM-DD"` for time-varying windows.

### 5.2 `dates`

**Type:** `Date` vector (length `T`)  
**Purpose:** Full set of time indices used in the estimation window.

- Typically monthly end-of-month dates spanning the in-sample period for this `IS_AP` instance.
- Used as the time index for `sdf_mat` and `sdf_mim`.

---

## 6. Factor Ranking Objects

These objects summarize which factors are most relevant according to either inclusion probabilities or absolute risk prices.

### Common Conventions

- Each of the following lists has **exactly 4 entries**, corresponding to the four Bayesian prior scales (aligned with `"BMA-20%"`, `"BMA-40%"`, `"BMA-60%"`, `"BMA-80%"`).
- Within each entry, factors are ordered by **descending importance** for that criterion.
- Each entry contains **up to 5 factor identifiers** (fewer if fewer than 5 candidates are available).

### 6.1 `top_factors`

**Type:** `list` of length 4; each element: `character` vector  
**Purpose:** Top factors among **traded factors only** (e.g. those in the tradable block), ranked by posterior inclusion probability.

- Entry `[[k]]` corresponds to prior scale `k` (e.g. 20%, 40%, 60%, 80%).
- Values: factor identifiers belonging to the traded-factor subset.

### 6.2 `top_mpr_factors`

**Type:** `list` of length 4; each element: `character` vector  
**Purpose:** Top factors among **traded factors only**, ranked by **absolute market price of risk** (|λ|).

### 6.3 `top_factors_all`

**Type:** `list` of length 4; each element: `character` vector  
**Purpose:** Top factors among **all factors** (non-traded + traded), ranked by posterior inclusion probability.

### 6.4 `top_mpr_factors_all`

**Type:** `list` of length 4; each element: `character` vector  
**Purpose:** Top factors among **all factors**, ranked by |λ|.

Interpretation:

- These lists are used to define **“Top”** and **“Top-MPR”** models, both for traded-factor-only and all-factor specifications (e.g. model names containing `Top-...` and `Top-MPR-...`).

---

## 7. PC Weight Matrices

These matrices describe how principal components (PCs) are constructed from underlying assets, for multiple PC methodologies.

All PC weight matrices are **budget-normalized PC constructions**: each column corresponds to a PC and sums to 1 across assets after normalization. They are not necessarily the exact raw PC eigenvectors; they are often scaled to be interpretable as portfolios.

Dimensions below use:

- `N` = number of combined test assets (e.g. `R` and `f2` together).
- `M` = number of traded factors (`f2`).

### 7.1 `kns_pcs_weights`

**Type:** `matrix` (`N × N`)  
**Purpose:** PC construction weights for the KNS model on the **combined** asset universe.

- Column `j`: portfolio weights that implement PC `j` in KNS combined estimation.

### 7.2 `knsf2_pc_weights`

**Type:** `matrix` (`M × M`)  
**Purpose:** PC construction weights for the KNS model on the **traded-factor subset** only.

### 7.3 `rppca_pcs_weights`

**Type:** `matrix` (`N × N`)  
**Purpose:** PC construction weights for the RP-PCA model on the **combined** asset universe.

### 7.4 `rppcaf2_pc_weights`

**Type:** `matrix` (`M × M`)  
**Purpose:** PC construction weights for the RP-PCA model on the **traded-factor subset** only.

### 7.5 `pca_pcs_weights`

**Type:** `matrix` (`N × N`)  
**Purpose:** PC construction weights for standard PCA on the **combined** asset universe.

### 7.6 `pcaf2_pc_weights`

**Type:** `matrix` (`M × M`)  
**Purpose:** PC construction weights for standard PCA on the **traded-factor subset** only.

Interpretation:

- To obtain the payoff of PC `j`, multiply the corresponding column of the appropriate matrix by the underlying asset return matrix for the relevant universe.
- These matrices can be used to:
  - Inspect diversification properties of PCs,
  - Translate PC factors back to asset portfolios,
  - Build alternative PC-based strategies.

---

## 8. In-Sample Pricing Summary

### 8.1 `is_pricing_result`

**Type:** `data.frame` with 4 rows and `N_models` columns  

**Purpose:** Summary in-sample pricing performance metrics for each model.

- Rows (`metric` column):
  1. `RMSEdm` – Root mean squared pricing error (demeaned) across test assets.
  2. `MAPEdm` – Mean absolute pricing error (demeaned).
  3. `R2OLS` – Cross-sectional R² under OLS weighting.
  4. `R2GLS` – Cross-sectional R² under GLS weighting.

- Columns:
  - `metric` (character) – row label.
  - One column per model (same naming convention as `lambdas` / `weights`, e.g. `"BMA-20%"`, `"CAPM"`, `"RP-PCA"`, `"KNS"`, `"Tangency"`, etc.).

Interpretation:

- These metrics are computed **within the current estimation window** using each model’s SDF and the test assets’ returns. They allow quick comparison of model fit in terms of pricing errors and R².

---

## 9. Stochastic Discount Factors and Mimicking Portfolios

The following two objects provide **time-series representations** of the SDF and its tradable mimicking portfolio for each model.

### 9.1 `sdf_mat`

**Type:** `data.frame` with `T` rows and `1 + N_models` columns  

**Purpose:** Time series of SDF values for each model.

- Columns:
  - `date` – same as `IS_AP$dates`.
  - One column per model (e.g. `"CAPM"`, `"Top-20%"`, `"RP-PCA"`, `"KNS"`, `"Tangency"`, etc.) containing SDF values at each time point.
- Each model column is the SDF process implied by that model’s λ and factor returns, transformed and normalized so it has a meaningful scale (typically mean near 1).

Interpretation:

- For each model, `sdf_mat[[model_id]][t]` is the discount factor applied to payoffs at time `t+1`. This object is useful for:
  - Comparing SDF volatility and dynamics across models,
  - Computing correlations between model SDFs,
  - Building SDF-based diagnostics.

### 9.2 `sdf_mim`

**Type:** `data.frame` with `T` rows and `1 + N_models` columns  

**Purpose:** Time series of returns on factor-mimicking portfolios that replicate each model’s SDF payoff.

- Columns:
  - `date` – same as `IS_AP$dates`.
  - One column per model (e.g. `"BMA-20%"`, `"CAPM"`, `"RP-PCA"`, `"KNS"`, `"Tangencyf2"`, etc.) containing **portfolio returns** at each date.
- Each model column is constructed by applying the corresponding `weights` entry to the appropriate asset return matrix, yielding a tradable portfolio whose payoff matches (or closely approximates) the SDF component for that model.

Interpretation:

- These are **testable portfolios** corresponding to each model’s SDF:
  - Can be used to compute Sharpe ratios, drawdowns, and other performance metrics.
  - Enable comparison between models in terms of investable performance, not just pricing errors.

---

## 10. Usage Patterns (for Downstream Code / AI)

Below are generic usage patterns that do *not* rely on specific factor names.

### 10.1 Enumerate Models and Types

```r
models_lambda  <- names(IS_AP$lambdas)
models_weights <- names(IS_AP$weights)
models_bma     <- intersect(names(IS_AP$gammas), models_lambda)
```

### 10.2 Extract Raw and Scaled Lambdas for a Given Model

```r
model_id <- "BMA-40%"  # example, can loop over models_lambda

lambda_raw   <- IS_AP$lambdas[[model_id]]        # 1 × P_m matrix
lambda_scaled <- IS_AP$scaled_lambdas[[model_id]] # 1 × P_m matrix

# Drop intercept if present
cols <- colnames(lambda_raw)
keep_idx <- cols != "(Intercept)"
lambda_raw_no_int    <- as.numeric(lambda_raw[, keep_idx, drop = TRUE])
lambda_scaled_no_int <- as.numeric(lambda_scaled[, keep_idx, drop = TRUE])
factor_ids           <- cols[keep_idx]
```

### 10.3 Get Portfolio Weights and Build Returns

```r
# For models that have tradable portfolios
if (model_id %in% names(IS_AP$weights)) {
  w <- as.numeric(IS_AP$weights[[model_id]][1, , drop = TRUE])
  assets <- colnames(IS_AP$weights[[model_id]])

  # Suppose `R_mat` is a T × A matrix of returns with columns matching `assets`
  # r_port_t <- R_mat %*% w
}
```

### 10.4 Use Top Factor Lists to Define New Models

```r
# Example: build a custom f2-only model based on top 3 factors for psi = 0.6
psi_index <- 3  # corresponds to 60%
top_f2_factors <- IS_AP$top_factors[[psi_index]][1:3]
# Use `top_f2_factors` to select columns from your traded factor matrix
```

### 10.5 Access SDF and Mimicking Portfolio Time Series

```r
# SDF time series for a given model
sdf_series <- IS_AP$sdf_mat[ , model_id]

# Mimicking portfolio return series for same model
mim_series <- IS_AP$sdf_mim[ , model_id]
```

---

## 11. Extensibility Guidelines

To keep `IS_AP` extensible and AI-friendly:

1. **Model Names as Keys**  
   - Treat model names (e.g. `"BMA-20%"`, `"CAPM"`, `"RP-PCA"`, `"KNS"`) purely as *labels*.  
   - Do not hard-code logic on specific names; instead, infer model type by simple patterns (e.g. `"BMA-"`, `"Top-"`, `"-All"`, `"KNS"`, etc.) when necessary.

2. **Shape Consistency**  
   - All `lambdas` and `scaled_lambdas` entries must be `1 × P_m` matrices with **consistent column naming** for a given model.
   - All `weights` entries must be `1 × A_m` matrices with asset identifiers as column names and sum to 1 where applicable.

3. **Date Handling**  
   - For time-varying estimation, multiple `IS_AP` objects (one per `date_end`) can be stacked vertically by:
     - Using `rowbind` on the `lambdas`/`weights` matrices by model,
     - Using `IS_AP$dates` / `sdf_mat$date` / `sdf_mim$date` as time indices.

4. **Adding New Models**  
   - To add a new model, create:
     - A new entry in `lambdas` and `scaled_lambdas`,
     - Optionally a `weights` entry (if it corresponds to a tradable portfolio),
     - A column in `is_pricing_result`, `sdf_mat`, and `sdf_mim`.
   - No other structural changes are required.

5. **No Assumption on Factor Names**  
   - Downstream code should treat factor identifiers purely as strings and should **never rely on specific factor labels**; instead, it should use only **relative ordering** (top lists, probabilities, magnitudes) and matching between factor sets and factor matrices.

---

