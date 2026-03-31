# The Co-Pricing Factor Zoo

<!-- @document-metadata
  @title: The Co-Pricing Factor Zoo
  @type: academic-paper (empirical finance, asset pricing)
  @core-question: Can equity and nontradable factors alone explain corporate bond risk premia, rendering the bond factor literature redundant?
  @core-answer: Yes — once Treasury term structure risk is accounted for, equity and nontradable factors suffice; a dense BMA-SDF aggregating dozens of noisy factor proxies achieves out-of-sample Sharpe ratios of 1.5–1.8
  @datasets: BAML/ICE corporate bonds (1997–2022), Lehman Brothers Fixed Income (1986–1998), TRACE (2002–2022), CRSP/Compustat equities
  @n-signals: 54 factors (16 bond tradable + 24 stock tradable + 14 nontradable)
  @key-equations: (1)–(10) plus IA equations
  @key-tables: Tables 1–6, IA Tables I–XXXIV
  @key-figures: Figures 1–12, IA Figures 1–50
-->

---

## AI Reading Guide

### I. Notation Glossary

| Symbol | Type | Meaning | Defined |
|--------|------|---------|---------|
| $\boldsymbol{R}_t$ | Vector ($N \times 1$) | Returns of $N$ long-short test asset portfolios at time $t$ | Section 2.1 |
| $\boldsymbol{f}_t$ | Vector ($K \times 1$) | Factor returns at time $t$ ($K_1$ tradable + $K_2$ nontradable) | Section 2.1 |
| $\boldsymbol{\lambda}_f$ | Vector ($K \times 1$) | Market prices of risk (MPRs) for all factors | Eq. (1) |
| $\lambda_c$ | Scalar | Average mispricing (cross-sectional intercept) | Eq. (1) |
| $\boldsymbol{C}_f$ | Matrix ($N \times K$) | Covariance matrix between test asset returns and factors | Eq. (1) |
| $\boldsymbol{C}$ | Matrix ($N \times (K+1)$) | Augmented covariance matrix $(\boldsymbol{1}_N, \boldsymbol{C}_f)$ | Eq. (1) |
| $\boldsymbol{\alpha}$ | Vector ($N \times 1$) | Pricing errors in excess of $\lambda_c$ | Eq. (1) |
| $\sigma^2$ | Scalar | Cross-sectional variance scale parameter | Eq. (2) |
| $\boldsymbol{\gamma}$ | Vector ($K+1$) binary | Factor inclusion indicators ($\gamma_j \in \{0,1\}$) | Section 2.2 |
| $r(\gamma_j)$ | Scalar | Spike-and-slab scaling: $r(\gamma_j=1)=1$, $r(\gamma_j=0)=r\ll 1$ | Eq. (3) |
| $\psi_j$ | Scalar | Factor-specific prior precision, function of factor-asset correlations | Eq. (5) |
| $\tilde{\boldsymbol{\rho}}_j$ | Vector ($N \times 1$) | Cross-sectionally demeaned correlations between factor $j$ and test assets | Eq. (5) |
| $\omega_j$ | Scalar $\in [0,1]$ | Prior probability of factor $j$ inclusion | Eq. (4) |
| $\kappa$ | Scalar $\in (-1,1)$ | Heterogeneous class prior tilt parameter (bond vs. stock factor weight) | Eq. (6) |
| $\boldsymbol{D}$ | Matrix (diagonal) | Prior precision matrix for risk prices incorporating $\kappa$ | Eq. (6) |
| $M_t^{BMA}$ | Scalar | Bayesian Model Averaging SDF at time $t$ | Eq. (7) |
| $\Pr(\gamma_j=1\|\text{data})$ | Scalar | Posterior probability of factor $j$ being in the SDF | Eq. (8) |
| $\mathbb{E}[\lambda_j\|\text{data}]$ | Scalar | Posterior expected market price of risk for factor $j$ | Eq. (8) |
| $\delta_j$ | Scalar | Correlation between noisy proxy $j$ and true factor | Eq. (9) |
| $R^{\text{Treasury}}_{\text{dur bond } i,t}$ | Scalar | Return on duration-matched Treasury portfolio for bond $i$ | Eq. (10) |
| $\boldsymbol{\mu}_Y, \boldsymbol{\Sigma}_Y$ | Vector/Matrix | Time-series mean and covariance of $\boldsymbol{Y}_t = \boldsymbol{f}_t \cup \boldsymbol{R}_t$ | Eqs. (A.1)-(A.2) |
| $N_{dr,t+1}$ | Scalar | Discount rate news component from VAR decomposition | Eq. (IA.1) |

### II. Equation Quick-Reference

| Eq. | Name | What it defines | Where used empirically |
|-----|------|-----------------|----------------------|
| (1) | Cross-sectional regression | Maps factor covariances to expected returns via MPRs | All IS/OS pricing tests (Tables 2-3) |
| (2) | Cross-sectional likelihood | Gaussian likelihood for Bayesian estimation of MPRs | Posterior sampling (Appendix B) |
| (3) | Spike-and-slab prior | Continuous mixture prior for factor inclusion/exclusion | All Bayesian estimation |
| (4) | Beta-Bernoulli prior | Prior on factor inclusion probability $\omega_j$ | Model dimensionality (Figure 3) |
| (5) | Weak factor correction | Prior precision $\psi_j$ from demeaned factor-asset correlations | Regularization of weak/useless factors |
| (6) | Heterogeneous class prior | Generalized prior with $\kappa$ tilt across factor classes | Robustness to bond/stock factor tilting (Section 4, IA.9) |
| (7) | BMA-SDF (model-space) | Posterior-weighted average over all $2^{54}$ model SDFs | All pricing and trading results |
| (8) | BMA-SDF (factor-space) | Equivalent factor-weighted form of the BMA-SDF | Factor MPR interpretation, portfolio construction |
| (9) | Noisy proxy pricing | Shows misspecified SDF with noisy proxy prices assets perfectly | Theoretical motivation (Section 2.4) |
| (10) | Duration-adjusted return | Decomposes bond return into credit and Treasury components | Section 3.3, IA.6 |
| (A.1)-(A.2) | Time-series posteriors | Normal-inverse-Wishart posteriors for $(\boldsymbol{\mu}_Y, \boldsymbol{\Sigma}_Y)$ | Gibbs sampler step 1 |
| (A.3)-(A.6) | Cross-sectional posteriors | Conditional posteriors for $\boldsymbol{\lambda}, \boldsymbol{\gamma}, \boldsymbol{\omega}, \sigma^2$ | Gibbs sampler steps 2-5 |
| (IA.1) | DR/CF news decomposition | VAR-based discount rate news for factor decomposition | IA.5 (Figure IA.21, Table IA.XV) |

### III. Core Claims to Evidence Map

| # | Claim | Primary evidence | Supporting evidence |
|---|-------|-----------------|---------------------|
| 1 | **Only 5 factors (PEADB, IVOL, PEAD, CREDIT, YSP) have posterior probabilities above the 50% prior for the co-pricing SDF** | Figure 2, Table 1 Panel A | Table A.2 (across prior SR levels) |
| 2 | **The true latent SDF is dense: posterior median of 22 factors (95% CI: 15-29)** | Figure 3 Panel A | Figure IA.22 (Treasury component) |
| 3 | **BMA-SDF outperforms all benchmark models in- and out-of-sample for co-pricing bonds and stocks** | Tables 2-3 (all panels) | Tables IA.III-IA.XII (additional tests) |
| 4 | **BMA-SDF tradable portfolio achieves OS annualized Sharpe ratio of 1.5-1.8** | Table 6 Panel B, Figure 7 | Table IA.XXVII (by data source) |
| 5 | **Equity and nontradable factors alone suffice for co-pricing once Treasury term structure risk is removed** | Figure 8, Table IA.XVI | Figure 9 (Treasury component pricing) |
| 6 | **Bond factor zoo is necessary only because it prices the Treasury component that stock factors cannot** | Figure 9 Panels C-D ($R^2$ = 6% with stock factors vs. 97% with bond factors) | IA.6 (detailed Treasury analysis) |
| 7 | **The BMA-SDF is persistent, tracks the business cycle, and its conditional volatility is countercyclical** | Figures 10-11, Table IA.XXI | IA.8 (ACFs, GARCH analysis) |
| 8 | **Lagged SDF information predicts future factor returns with median monthly $R^2$ of 1.7% and annual $R^2$ of 9.7%** | Figure 12 | Section 3.4 |
| 9 | **BMA-SDF correctly recovers market prices of risk even when only noisy proxies are available** | Figure 1 (simulation), Section 2.4 theory | Figure IA.9-IA.10 (additional simulations) |
| 10 | **Results robust to factor tilting ($\kappa$), imposed sparsity, top-factor exclusion, data source variation, and sample splits** | Section 4, Tables IA.XXII-XXXIII | Figures IA.32-IA.39 |
| 11 | **PEAD factors (bond and stock) remain robust across size terciles and are not driven by micro-cap stocks** | IA.4, Table IA.XIII-XIV | Section 3.1.1 footnote 26 |
| 12 | **62% of bond factors are driven by discount rate news vs. 53% of stock factors by cash-flow news** | Figure IA.21, Table IA.XV | Section 3.1.1 (DR/CF decomposition) |

### IV. Dataset Divergence Log

| Dimension | BAML/ICE (1997-2022) | LBFI (1986-1998) | TRACE (2002-2022) |
|-----------|---------------------|------------------|-------------------|
| Coverage | ~5,000 bonds/month | ~3,000 bonds/month | Transaction-level |
| Price type | Matrix + quotes | Matrix prices | Transaction prices |
| Combined sample | 1986:01-2022:12 (T=444 months) | Pre-1997 only | Post-2002 only |
| Matched firms | 2,211 bond-stock matched firms | -- | -- |
| IS test assets | 83 portfolios (50 bond + 33 stock) + 40 tradable factors = 123 | -- | -- |
| OS test assets | 154 portfolios (77 bond + 77 stock) | -- | -- |
| Factor zoo | 54 total: 16 bond tradable + 24 stock tradable + 14 nontradable | -- | -- |

### V. Suggested Reading Paths

**Path A: "What does this paper find?" (5 minutes)**
1. Abstract (Page 1) → filter `@importance: core` claims map above
2. Figure 2 (posterior factor probabilities) → Figure 3 (SDF dimensionality) → Table 6 Panel B (OS trading)
3. Figure 8 (duration-adjusted pricing: bond zoo redundancy)

**Path B: "Is the methodology sound?" (20 minutes)**
1. Section 2.1-2.2 (frequentist problems → Bayesian solution) → Eqs. (1)-(6)
2. Section 2.3 (heterogeneous class prior, $\kappa$ parameter) → Section 2.4 (noisy proxy theory + simulation)
3. Appendix B (Gibbs sampler) → IA.2 (simulation design details)

**Path C: "Should I believe the magnitudes?" (15 minutes)**
1. Table 6 Panel B (OS SR = 1.79; is this too high?) → Figure 7 (cumulative returns)
2. Table 3 (OS $R^2_{OLS}$, $R^2_{GLS}$, MAPE across all panels)
3. Section 4 (robustness: tilting, sparsity, factor exclusion) → Tables IA.XXII-XXVI

**Path D: "Why are bond factors redundant?" (10 minutes)**
1. Eq. (10) (duration-adjusted return decomposition)
2. Figure 8 (stock-only BMA prices duration-adjusted bonds) → Figure 9 (Treasury component: bond factors needed, stock factors fail)
3. IA.6 (full Treasury component analysis, Tables IA.XVI-XX)

**Path E: "Which factors matter and why?" (10 minutes)**
1. Figure 2 (all 54 posterior probabilities) → Figure 4 (probabilities + MPRs side by side)
2. Table 1 (top-5 contributions to SDF SR) → Section 3.1.1 (interpretation of PEADB, IVOL, PEAD, CREDIT, YSP)
3. IA.5 (DR/CF decomposition of factors) → IA.4 (PEAD robustness across size)

**Path F: "How robust are the results?" (10 minutes)**
1. Section 4 (factor tilting, sparsity, factor exclusion, varying data/cross-sections)
2. Tables IA.XXVII-XXXIII (Sharpe ratios by data, sample splits, millions of OS tests)
3. IA.11 (CREDIT factor construction robustness)

---


*(Page 1)*

<!-- @section-type: introduction
  @key-claim: Equity and nontradable factors alone suffice to explain corporate bond risk premia once Treasury term structure risk is accounted for, rendering the bond factor literature largely redundant.
  @importance: core
  @data-source: BAML/ICE corporate bonds, CRSP equities, LBFI, FISD, TRACE
  @depends-on: none
  @equations: none
-->

## Abstract

We analyze 18 quadrillion models for the joint pricing of corporate bond and stock returns. Strikingly, we find that equity and nontradable factors alone suffice to explain corporate bond risk premia once their Treasury term structure risk is accounted for, rendering the extensive bond factor literature largely redundant for this purpose. While only a handful of factors, behavioral and nontradable, are likely robust sources of priced risk, the true latent stochastic discount factor is *dense* in the space of observable factors. Consequently, a Bayesian Model Averaging Stochastic Discount Factor explains risk premia better than all low-dimensional models, in- and out-of-sample, by optimally aggregating dozens of factors that serve as noisy proxies for common underlying risks, yielding an out-of-sample Sharpe ratio of 1.5 to 1.8. This SDF, as well as its conditional mean and volatility, are persistent, track the business cycle and times of heightened economic uncertainty, and predict future asset returns.

**Keywords:** Bond-stock co-pricing, Corporate bonds, Factor zoo, Factor models, Bayesian methods, Macro-finance, Asset pricing.

**JEL:** G10, G12, G40, C12, C13, C52.

> *Wherever there is risk, it must be compensated to the lender by a higher premium or interest.*
> -- J. R. McCullough (1830, pp. 508-9)

In their seminal paper, Fama and French (1993) set themselves to "examine whether variables that are important in bond returns help to explain stock returns, and vice versa." Thirty years later, the equity literature has produced its own, independent, 'factor zoo' (Cochrane (2011)), while the corporate bond literature has effectively returned to square one with Dickerson, Mueller and Robotti (2023) showing that there is no satisfactory (observable) factor model for that asset class.[^1] Hence, to date, a model for the *joint* pricing of corporate bonds and stocks has escaped discovery -- we fill this gap.

[^1]: More precisely, they document that all low dimensional linear factor models in the previous literature add little spanning to a simple *bond* version of the Capital Asset Pricing Model, the CAPM_B. At the same time, they show that the CAPM_B is in itself an unsatisfactory pricing model.

Generalizing recent methodological advances in Bayesian econometrics (Bryzgalova, Huang and Julliard (2023)) to handle heterogeneous asset classes, we comprehensively analyze all observable factors and models proposed to date in the bond and equity literature. Our method allows us to not only study models or factors in isolation, but also consider all of their possible combinations, resulting in over 18 quadrillion models stemming from the joint zoo of corporate bond and stock factors. And we do so while relaxing the cornerstone assumptions of previous studies: the existence of a unique, low-dimensional, correctly specified and well-identified factor model.

Ultimately, this allows us to pinpoint the robust sources of priced risk in both markets, and a novel benchmark Stochastic Discount Factor (SDF) that prices both asset classes, significantly better than all existing models, both in- and out-of-sample. Remarkably, our analysis reveals that once corporate bonds' Treasury term structure risk

*(Page 2)*

is accounted for, stock and nontradable factors alone suffice to explain corporate bond risk premia -- rendering the extensive bond factor literature largely redundant for this purpose.

First, we find that the 'true' latent SDF of bonds and stocks is *dense* in the space of observable bond and stock factors -- literally dozens of factors, both tradable and nontradable, are necessary to span the risks driving asset prices. Yet, the SDF-implied maximum Sharpe ratio is not excessive, indicating that, as we confirm in our analysis, multiple bond and stock factors proxy for common sources of fundamental risk. Importantly, density of the SDF implies that the sparse models considered in the previous literature are affected by severe misspecification and, as we show, rejected by the data and outperformed by the most likely SDF components that we identify.

Second, a Bayesian Model Averaging Stochastic Discount Factor (BMA-SDF) over the space of all possible models (including bond, stock, and nontradable factors) explains (jointly and separately) corporate bond and equity risk premia better than all existing models and most likely factors, both in- and out-of-sample. Moreover, the BMA-SDF's conditional mean and volatility -- hence, the implied conditional Sharpe ratio achievable in the economy -- have clear business cycle patterns. In particular, the volatility of the SDF increases sharply at the onset of recessions and at times of heightened economic uncertainty. That is, the estimated SDF behaves as one would expect from the intertemporal marginal rate of substitution of an agent exposed to the risks arising from general economic conditions and market turmoil.

Third, the predictability of the first and second moments of the SDF suggests time-varying risk premia in the economy and predictability of asset returns with lagged SDF information. We verify this by running predictive regressions of future asset returns on the conditional variance of the BMA-SDF, alone and interacted with the conditional mean of the SDF, as implied by the Hansen and Jagannathan (1991) representation of the conditional SDF. We not only find that lagged SDF information is highly significant in predicting future asset returns, but also that the amount of explained time series variation in monthly and annual returns is much larger than what is achievable with canonical predictors. This result is remarkable for two reasons. First, the BMA-SDF is *not* by construction geared toward predicting future returns: it is instead identified only under the restriction that a valid SDF should explain the cross-section of risk premia -- not the time series of returns. Second, it offers an important validation of our estimation of the SDF: if risk premia are time-varying, future returns should be predictable with lagged SDF information, and that is exactly what our BMA-SDF delivers.

Fourth, we show theoretically that, to construct a tradable portfolio that captures the SDF-implied maximum Sharpe ratio achievable in the economy, one should focus on the posterior expectation of the market prices of risk of *all* factors, rather than on the factors' posterior probabilities (or some ancillary selection statistic), which have been the focus of the previous literature. Such an approach can correctly recover the pricing of risk even if the observed factors are only noisy proxies of the true, yet latent, sources of risk priced in the market. *In the data*, this yields a trading strategy with a time-series out-of-sample annualized Sharpe ratio of 1.5 to 1.8 (despite only yearly rebalancing) in an evaluation period (July 2004 to December 2022) that spans both the Global Financial Crisis and the COVID pandemic.

Fifth, we shed light on which factors, and which types of risk, are reflected in the cross-section of bond and equity risk premia. We find that only a handful of factors should be in the SDF with high probability. In particular, two factors meant to capture the bond and stock post-earnings announcement drift anomalies, PEAD_B and PEAD, respectively, are very likely sources of priced risk in the joint cross-section of bond and stock returns.[^2] In addition to these two behavioral sources of risk, the other most likely components of the SDF are all nontradable in nature, and are a proxy for the slope of the Treasury yield curve (YSP), the AAA/BAA yield spread (CREDIT), and the idiosyncratic equity volatility (the IVOL of Campbell and Taksler (2003)). As we show, these factors alone are enough to price the cross-section of bonds and stocks better than canonical observable factor models. Nevertheless, the importance of *individual* factors should not be overstated. Even excluding the most likely factors when constructing it, the BMA-SDF strongly outperforms these individual factors and *all* low dimensional factor models -- from the celebrated Fama and French (1993) model to the latest arrival in the zoo (Dick-Nielsen et al. (2025)). This superior performance occurs because the true latent SDF is dense and demands large compensations for risks that are not fully spanned by just a handful of individual observable factors. Furthermore, we find that both discount rate and cash-flow news are sources of priced risk, and yield sizeable contributions (albeit larger for the former) to the Sharpe ratio of the latent SDF.

[^2]: The post-earnings announcement drift phenomenon is the observation, first documented in equity markets, whereby firms experiencing positive earnings surprises subsequently earn higher returns than those with negative earnings surprises. See, e.g., Hirshleifer and Teoh (2003), Della Vigna and Pollet (2009), Hirshleifer et al. (2011) and Nozawa et al. (2025) for the microfoundations of this phenomenon.

Sixth, we demonstrate that a portion of corporate bond risk premia serves as compensation for their implicit Treasury term structure risk. Once this component is removed, the factors proposed in the tradable bond factor zoo have very little residual information content for characterizing the SDF: in this case, a BMA-SDF constructed only with stock and nontradable factors can explain the joint cross-section of bonds and stocks as well as our full BMA-SDF. This finding extends and explains the result in van Binsbergen et al. (2025), who show that once corporate bond returns are adjusted for duration risk, the equity CAPM has higher explanatory power for bond risk premia than benchmark bond models. Furthermore, we show that the empirical success of the bond factor zoo

*(Page 3)*

in the previous literature is largely driven by its ability to price the Treasury term structure risk -- a component of bond risk premia that tradable stock factors do not capture.

Finally, we conduct extensive robustness checks. Most notably, we show that: (i) altering the priors regarding the relative importance of bond versus stock factors, or equivalently a potential 'alpha mismeasurement' phenomenon in bond market data, has only a limited effect on the posterior probabilities of the factors and the pricing performance of the BMA-SDF; (ii) a BMA-SDF estimated with a prior that imposes sparsity -- overwhelmingly the focus of the previous literature -- performs worse than our baseline BMA-SDF, yet still improves upon competing models; (iii) as our theoretical results imply, *removing* the most likely factors from the estimation -- a challenging test for the method -- leads to only minor deterioration in the performance of the BMA-SDF in- and out-of-sample; (iv) all findings remain materially unchanged across *hundreds* of sets of corporate bond and stock in-sample test assets -- we identify a similar set of most likely factors, consistent market prices of risk, and stable in-sample asset pricing performance; (v) out-of-sample, the pricing performance of the BMA-SDF is superior across *millions* of alternative cross-sections of stocks and bonds; (vi) lastly, the results are robust to extending, by dozens of factors, both the stock and bond factor zoos that we consider in our baseline estimation (to maximize the time-series sample size), to varying sample and subsample estimations, and to using a multiplicity of different corporate bond datasets.

The remainder of the paper is organized as follows. Below, we review the most closely related literature and our contribution to it. Section 1 describes the data used in our analysis, while Section 2 outlines our Bayesian SDF method and its properties for inference, selection, and aggregation. Section 3 presents our empirical findings, and Section 4 contains extensive robustness checks. Section 5 concludes. Additional details and results are reported in the Appendix and the Internet Appendix.

<!-- @section-type: introduction
  @key-claim: The paper contributes to the literature on Bayesian model averaging, co-pricing of bonds and stocks, and factor zoo taming.
  @importance: supporting
  @data-source: none
  @depends-on: none
  @equations: none
-->

### Closely related literature

Our research contributes to the active and growing body of work that critically reevaluates existing findings in the empirical asset pricing literature using robust inference methods. Following Harvey et al. (2016), a large literature has tried to understand which existing factors (or their combinations) drive the cross-section of returns. In particular, Gospodinov et al. (2014) develop a general method for misspecification-robust inference, while Giglio and Xiu (2021) exploit the invariance principle of PCA and recover the risk premium of a given factor from the projection on the span of latent factors driving a cross-section of returns. Similarly, Dello Preite et al. (2025) recover latent factors from the residuals of an asset pricing model, effectively completing the span of the SDF. Feng et al. (2020) combine cross-sectional asset pricing regressions with the double-selection LASSO of Belloni et al. (2014) to provide valid inference on the selected sources of risk when the true SDF is sparse. Kozak et al. (2020) use a ridge-based approach to approximate the SDF and compare sparse models based on principal components of returns. Our approach instead identifies a dominant pricing model -- if such a model exists -- or a BMA across the space of all models, even if the true model is not sparse in nature, hence cannot be proxied by a small number of factors. Furthermore, and importantly, our work focuses on the *co-pricing* of corporate bond and stock returns, hence shedding light on both the common, as well as the market specific, sources of risk.

As Harvey (2017) stresses in his American Finance Association presidential address, the factor zoo naturally calls for a Bayesian solution -- and we adopt one. In particular, we generalize the Bayesian method of model estimation, selection, and averaging developed in Bryzgalova, Huang and Julliard (2023) to handle heterogeneous asset classes.

Numerous strands of the literature rely on Bayesian tools for asset allocation, model selection, and performance evaluation. Our approach is most closely linked to Pastor and Stambaugh (2000) and Pastor (2000) in that we assign a prior distribution to the vector of pricing errors, and this maps into a natural and transparent prior for the maximal Sharpe ratio achievable in the economy. Barillas and Shanken (2018) also extend the prior formulation of Pastor and Stambaugh (2000) and provide a closed-form solution for the Bayes factors when all factors are tradable in nature. Chib et al. (2020) show that the improper prior formulation of Barillas and Shanken (2018) is problematic, and provide a new class of priors that leads to valid comparisons for tradable factor models. As in these papers, our model and factor selection is based on posterior probabilities, but our method is designed to work with both tradable and *nontradable* factors -- as we show, the latter are a first-order source of priced risk in the joint space of corporate bonds and stock returns.

Our work is closely related to the literature that stresses the optimality of Bayesian model averaging for a very wide set of optimality criteria (see, e.g., Schervish (1995) and Raftery and Zheng (2003)).[^3] We highlight that Bayesian model averaging *over the space of models* can be expressed as model averaging *over the space of factors*. This allows us to show that posterior factor probabilities (which the previous Bayesian asset pricing literature has overwhelmingly focused on) and posterior market prices of risk (across the space of models) have very different information content. In particular, as we demonstrate, it is the latter, not the former, that tells us how to construct

[^3]: In particular, BMA is "optimal on average," i.e., no alternative method can outperform the BMA for all values of the true unknown parameters. Furthermore, a BMA-SDF can be microfounded thanks to the equivalence between an economy populated by agents with heterogeneous beliefs and a Bayesian representative agent setting (Heyerdahl-Larsen et al. (2023)).

*(Page 4)*

tradable portfolios that achieve the BMA-SDF-implied maximum Sharpe ratio. In the data, this yields a trading strategy with an (annualized) out-of-sample Sharpe ratio of 1.5 to 1.8. Most importantly, our approach can deal with a very large factor space, is not affected by the common identification failures that invalidate inference in asset pricing (see, e.g., Kan and Zhang (1999a,b), Kleibergen (2009), and Gospodinov et al. (2019)), and provides an optimal method for aggregating the pricing information stemming from the joint zoo of corporate bond and equity factors even if only noisy proxies of the true fundamental risks are available.

In the complete market benchmark, the pricing measure should be consistent across asset classes, and equilibrium models normally yield nontradable state variables. Therefore, we focus on the co-pricing of corporate bonds and stocks, and consider jointly a very broad collection of potential sources of risk that extends well beyond the set of bond and stock tradable factors that have been studied in isolation in the previous literature. Hence, our paper speaks to the large literature on co-pricing, originated with the seminal work of Fama and French (1993), and market segmentation of bonds and stocks (see, e.g., Chordia et al. (2017), Choi and Kim (2018), or Sandulescu (2022)). In particular, our paper is related to the body of work that explores whether equity market risk proxies (see, e.g., Blume and Keim (1987) and Elton et al. (2001)), equity volatilities (see, e.g., Campbell and Taksler (2003) and Chung et al. (2019)), and equity-based characteristics (see, e.g., Fisher (1959), Giesecke et al. (2011), and Gebhardt et al. (2001)) are likely drivers of corporate bond returns, and on the commonality of risks across markets (see, e.g., He et al. (2017), Lettau et al. (2014), and Chen et al. (2024)).

Overall, we find that factors in both the corporate bond and equity zoos are needed for the joint pricing of both asset classes, and stock factors do carry relevant information to explain bond returns. Yet, there is substantial overlap between the risks spanned by these two markets. That is, multiple bond and stock factors are noisy proxies for common underlying sources of risk. Nevertheless, as we show, corporate bond risk premia include an implicit compensation for Treasury term structure risk -- a risk that the bond factor zoo, and nontradable factors proposed therein, price very well, while equity factors do not. And once this term structure risk component is removed, tradable bond factors become largely unnecessary for the joint pricing of bonds and stocks.

Several theoretical contributions stress that real economic activity and the business cycle should be among the drivers of bond risk premia (see, e.g., Bhamra et al. (2010), Khan and Thomas (2013), Chen et al. (2018), and Favilukis et al. (2020)). Echoing both the general equilibrium model predictions of Gomes and Schmid (2021) and the empirical findings of Elton et al. (1995) and Elkamhi et al. (2023), we show that the BMA-SDF conditional first and second moments have a clear business cycle pattern and peak during recessions and at times of heightened economic uncertainty, and that nontradable factors (especially proxies of the economic cycle such as the slope of the yield curve), are salient components of the pricing measure.[^4] Furthermore, we show that the business cycle properties of the BMA-SDF and its volatility are predictable, and predict -- as theory implies in this case -- future asset returns, generating a substantial degree of time variation in conditional risk premia.

[^4]: Elton et al. (1995) show that adding fundamental macro-risk variables (such as GNP, inflation and term spread measures) significantly improves pricing performance relative to equity and bond market index models. Elkamhi et al. (2023) show that the long-run consumption risk measure of Parker and Julliard (2003) yields a one-factor model with significant explanatory power for corporate bonds, and such an SDF, as documented in Parker and Julliard (2005), has a very strong business cycle pattern.

Our work also relates to behavioral biases and market frictions in asset pricing. In particular, complementing the evidence of Daniel et al. (2020a) and Bryzgalova et al. (2023) for the equity market, we show that the post-earnings announcement drifts of both bonds (see Nozawa et al. (2025)) and stocks are extremely likely drivers of corporate bond and stock risk premia. Furthermore, we show that cash-flow and discount rate news (see, e.g., Vuolteenaho (2002), Cohen et al. (2002), Zviadadze (2021), and Delao et al. (2025)) are both important drivers of risk premia in the joint cross-section of bonds and stocks, but the latter are responsible for a larger share of the volatility of the co-pricing SDF.

---

*(Page 4)*

<!-- @section-type: data
  @key-claim: The analysis uses BAML/LBFI corporate bond data merged with FISD (1986-2022), 54 factors (40 tradable, 14 nontradable) yielding 2^54 ~ 18 quadrillion models.
  @importance: core
  @data-source: BAML ICE (H0A0, C0A0), LBFI, FISD, CRSP, Kenneth French, Chen-Zimmermann, Jensen et al. (2023)
  @depends-on: none
  @equations: none
-->

## 1. Data

Our analysis relies on a combination of corporate bond and stock data, which we present below and in more detail in Internet Appendix IA.1. As academic research relies on various sources for corporate bond data, we are careful to estimate our model across *all* datasets available to us to ensure that our results are neither driven by the data source nor the choice of bond or stock test assets (see the discussion in Section 4.4).

### 1.1. Corporate bond data and corporate bond returns

Our baseline results in the main text are based on the constituents of the corporate bond data set from the Bank of America Merrill Lynch (BAML) High Yield (H0A0) and Investment Grade (C0A0) indices made available via the Intercontinental Exchange (ICE) from January 1997 to December 2022. For the period from January 1986 to December 1996, we augment the data using the Lehman Brothers Fixed Income (LBFI) database.[^5] These data are then merged with the Mergent Fixed Income Securities Database (FISD) to obtain additional bond characteristics.

[^5]: We follow van Binsbergen et al. (2025) and begin the LBFI sample in 1986. Prior to 1986, bonds in the LBFI database are predominantly investment grade (91% of bonds) with 67% of all bonds priced with matrix pricing (i.e., the prices are not actual dealer quotes).

*(Page 5)*

After merging the two datasets and applying the standard filters, our bond-level data spans 37 years, resulting in a total of 444 monthly observations. Our corporate bond sample is representative of the U.S. market and, once merged with CRSP equity data, covers 75% of the total stock market capitalisation of all listed firms on average (see Figure IA.3 of the Internet Appendix).[^6]

[^6]: See Internet Appendix IA.1 for a detailed description of the databases and associated cleaning procedures. Therein, we also discuss the additional datasets used for robustness tests.

In the baseline analysis, we use *excess* bond returns defined as the total bond return minus the one-month risk-free rate of return.[^7] In addition, we follow van Binsbergen et al. (2025) and repeat our analysis with *duration-adjusted* returns, whereby we subtract the return on a portfolio of duration-matched U.S. Treasury bonds from the total bond return. We do not further winsorize, trim, or augment the underlying bond return data in any way, avoiding the biases that such procedures normally induce (Duarte et al. (2025) and Dickerson et al. (2024)).

[^7]: We use the one-month risk-free rate from Kenneth French's website.

### 1.2. The joint factor zoo

We use all factors in published papers for which a monthly time series matching our sample is publicly available. Our bond-specific factor zoo includes 16 tradable bond factors. From the equity literature, we include an additional 24 tradable factors. This set is smaller than the tradable equity factor zoo in Bryzgalova et al. (2023) as for several of their 34 tradable factors, an updated series is not publicly available. Moreover, we exclude factors for which authors did not provide sufficient information for exact replication.[^8] Our nontradable zoo comprises 14 factors, many of which have previously been used to study stock returns.

[^8]: The excluded factors are all among the *least* likely components of the equity SDF in Bryzgalova et al. (2023). Nevertheless, we consider *all* of their factors in our robustness analysis.

Overall, in our baseline analysis, we consider 54 factors -- 40 tradable and 14 nontradable -- yielding $2^{54} \approx 18$ quadrillion models. In Section 4.4.3, we extend this to include dozens of additional factors available over varying subsamples, for a grand total of 91 candidate pricing factors. All factors are described in Table A.1 of Appendix A.[^9] Internet Appendix IA.1.3 analyzes the robustness of bond factors with respect to data source and calculation method.

[^9]: All factors are publicly available from the authors' personal websites and public repositories, listed therein. We make our 16 tradable bond factors available on the companion website: openbondassetpricing.com

### 1.3. In-sample bond and stock test assets

For our in-sample (IS) estimation of the BMA-SDF, we construct a set of 50 bond portfolios that are sorted on various bond characteristics to ensure a sufficiently broad cross-section. The first 25 portfolios are double-sorted on credit spreads and bond size, while the remaining 25 portfolios are double-sorted on bond rating and time-to-maturity. All portfolios are value-weighted based on the market capitalization of the bond issue, defined as the bond dollar value multiplied by the number of outstanding units of the bond. For the stock test assets, we rely on a set of 33 portfolios and anomalies very similar to those used in Kozak et al. (2020) and Bryzgalova et al. (2023).[^10]

[^10]: These are publicly available from Chen and Zimmermann (2022) and Jensen et al. (2023), and replicable using CRSP and Compustat. See jkpfactors.com.

In addition, we include the 40 tradable factors as Barillas and Shanken (2017) emphasize that factors included in a model should price any factor excluded from the model. This, along with the use of a nonspherical pricing error formulation (i.e., GLS) also imposes (asymptotically) the restriction of factors pricing themselves. For the estimation of the co-pricing BMA-SDF, we naturally include both bond and stock tradable factors, while we only include the respective bond and stock tradable factors to estimate the bond- and stock-specific BMA-SDFs.

In summary, our baseline cross-section comprises a wide array of 50 bond and 33 stock portfolios, as well as the underlying 40 tradable factors, for a total of 123 IS test assets.

### 1.4. Out-of-sample bond and stock test assets

To test the out-of-sample (OS) asset pricing efficacy of the BMA-SDF estimated on the IS test assets, we employ a broad cross-section of additional corporate bond, stock, and U.S. Treasury bond portfolios. For bonds, we use decile-sorted portfolios on: (i) bond historical 95% value-at-risk, (ii) duration, (iii) bond value (Houweling and Van Zundert (2017)), (iv) bond book-to-market (Bartram et al. (2025)), (v) long-term reversals (Bali et al. (2021a)), (vi) momentum (Gebhardt et al. (2005b)), as well as the bond version of the 17 Fama-French industry portfolios -- totaling 77 bond-based portfolios.

For stocks, we include decile-sorted portfolios on: (i) earnings-to-price, (ii) momentum, (iii) long-term reversal, (iv) accruals, (v) size (measured by market capitalization), (vi) equity variance, in addition to the equity version of the 17 Fama-French industry portfolios (following Lewellen et al. (2010)), also resulting in 77 stock-based portfolios.

For U.S. Treasury bonds, we use monthly annualized continuously compounded zero-coupon yields from Liu and Wu (2021). We price the U.S. Treasury bonds each month using the yield curve data and then compute

*(Page 6)*

monthly discrete excess returns across the term structure as the total return in excess of the one-month Treasury Bill rate. Our set of OS U.S. Treasury portfolios consists of 29 portfolios, ranging from 2-year Treasury notes up to 30-year Treasury bonds in increments of one year.

In summary, our baseline OS test assets comprise 154 bond and stock portfolios (77 each) from the 14 distinct cross-sections discussed above.[^11] We not only use the joint cross-section, but we also construct $2^{14} - 1 = 16,383$ possible unique combinations of OS cross-sections.[^12] For robustness, we conduct OS pricing tests with the Jensen et al. (2023) and the Dick-Nielsen et al. (2025) bond and stock anomaly data.

[^11]: All are available from Kenneth French's webpage and Cynthia Wu's webpage.
[^12]: Further details about factors and in- and out-of-sample test assets, as well as links to the data sources, can be found in Table IA.II of the Internet Appendix.

---

<!-- @section-type: methodology
  @key-claim: The Bayesian hierarchical method with a continuous spike-and-slab prior solves the weak identification problem and enables model averaging over 18 quadrillion models.
  @importance: core
  @data-source: none
  @depends-on: Section 1
  @equations: 1,2,3,4,5,6,7,8,9
-->

## 2. Econometric method

This section introduces the notation and summarizes the methods employed in our empirical analysis. We consider linear factor models for the SDF and focus on the SDF representation since we aim to identify the factors that have pricing ability for the joint cross-section of corporate bond and stock returns.[^13]

[^13]: Recall that a factor might have a significant risk premium even if it is not part of the SDF, just because it has non-zero correlation with the true latent SDF. Hence, in order to identify the pricing measure, focusing on the SDF representation is the natural choice.

We first review the frequentist estimation and the inference problems that arise therein in the presence of weak identification caused by weak and useless factors. We then summarize the Bayesian method proposed by Bryzgalova, Huang and Julliard (2023) to address the weak identification problem, present our extension of the approach to handle different asset classes, and introduce a more flexible prior structure. Finally, we establish a set of important new properties for the Bayesian model averaging of the SDF, and illustrate its mechanics in finite samples with a simulation study.

### 2.1. Frequentist estimation of linear factor models

We begin by introducing the notation used throughout the paper. The returns of $N$ test assets, which are long-short portfolios, are denoted by $\boldsymbol{R}_t = (R_{1t} \ldots R_{Nt})^\top$, $t = 1, \ldots T$. We consider $K$ factors, $\boldsymbol{f}_t = (f_{1t} \ldots f_{Kt})^\top$, $t = 1, \ldots T$, that can be either tradable or nontradable. A linear SDF takes the form $M_t = 1 - (\boldsymbol{f}_t - \mathbb{E}[\boldsymbol{f}_t])^\top \boldsymbol{\lambda}_f$, where $\boldsymbol{\lambda}_f \in \mathbb{R}^K$ is the vector containing the market prices of risk (MPRs) associated with the individual factors. Throughout the paper, $\mathbb{E}[X]$ or $\mu_X$ denote the unconditional expectation of an arbitrary random variable $X$.

In the absence of arbitrage opportunities, we have that $\mathbb{E}[M_t \boldsymbol{R}_t] = \boldsymbol{0}_N$; hence, expected returns are given by $\boldsymbol{\mu_R} \equiv \mathbb{E}[\boldsymbol{R}_t] = \boldsymbol{C}_f \boldsymbol{\lambda}_f$, where $\boldsymbol{C}_f$ is the covariance matrix between $\boldsymbol{R}_t$ and $\boldsymbol{f}_t$, and prices of risk, $\boldsymbol{\lambda}_f$, are commonly estimated via the cross-sectional regression

$$\boldsymbol{\mu_R} = \lambda_c \boldsymbol{1}_N + \boldsymbol{C}_f \boldsymbol{\lambda}_f + \boldsymbol{\alpha} = \boldsymbol{C}\boldsymbol{\lambda} + \boldsymbol{\alpha}, \tag{1}$$

where $\boldsymbol{C} = (\boldsymbol{1}_N, \boldsymbol{C}_f)$, $\boldsymbol{\lambda}^\top = (\lambda_c, \boldsymbol{\lambda}_f^\top)$, $\lambda_c$ is a scalar average mispricing (equal to zero under the null of the model being correctly specified), $\boldsymbol{1}_N$ is an $N$-dimensional vector of ones, and $\boldsymbol{\alpha} \in \mathbb{R}^N$ is the vector of pricing errors in excess of $\lambda_c$ (equal to zero under the null of the model).

Such models are usually estimated via GMM, MLE or two-pass regression methods (see, e.g., Hansen (1982), Cochrane (2005)). Nevertheless, as pointed out in a substantial body of literature, the underlying assumptions for the validity of these methods (see, e.g., Newey and McFadden (1994)), are often violated (see, e.g., Kleibergen and Zhan (2020) and Gospodinov and Robotti (2021)), and identification problems arise in the presence of a *weak* factor (i.e., a factor that does not exhibit sufficient comovement with any of the assets, or has very little cross-sectional dispersion in this comovement, but is nonetheless considered a part of the SDF). These issues, in turn, lead to incorrect inferences for both weak and strong factors, erroneous model selection, and inflate the canonical measures of model fit.[^14]

[^14]: These problems are common to GMM (Kan and Zhang (1999a)), MLE (Gospodinov et al. (2019)), Fama-MacBeth regressions (Kan and Zhang (1999b), Kleibergen (2009)), and even Bayesian approaches with flat priors for risk prices (Bryzgalova et al. (2023)).

### 2.2. The Bayesian solution

Albeit robust frequentist inference methods have been suggested in the literature for specific settings, our task is complicated by the fact that we want to parse the entire zoo of bond and stock factors, rather than estimate and test an individual model. Furthermore, we aim to identify the best specification -- if a dominant model exists -- or aggregate the information in the factor zoo into a single SDF if no clear best model arises. Therefore, we extend the Bayesian method proposed in Bryzgalova, Huang and Julliard (2023) (BHJ), since it is applicable to both tradable and nontradable factors, can handle the entire factor zoo, is valid under misspecification, and is robust to weak inference problems. This Bayesian approach is conceptually simple, since it leverages the naturally hierarchical

*(Page 7)*

structure of cross-sectional asset pricing, and restores the validity of inference using transparent and economically motivated priors.

Consider first the time-series layer of the estimation problem. Without loss of generality, we order the $K_1$ tradable factors first, $\boldsymbol{f}_t^{(1)}$, followed by $K_2$ nontradable factors, $\boldsymbol{f}_t^{(2)}$; hence $\boldsymbol{f}_t \equiv (\boldsymbol{f}_t^{(1),\top}, \boldsymbol{f}_t^{(2),\top})^\top$ and $K_1 + K_2 = K$. Denote by $\boldsymbol{Y}_t \equiv \boldsymbol{f}_t \cup \boldsymbol{R}_t$ the union of factors and returns, where $\boldsymbol{Y}_t$ is a $p$-dimensional vector.[^15] Modelling $\{\boldsymbol{Y}_t\}_{t=1}^T$ as multivariate Gaussian with mean $\boldsymbol{\mu}_Y$ and variance matrix $\boldsymbol{\Sigma}_Y$, and adopting the conventional diffuse prior $\pi(\boldsymbol{\mu}_Y, \boldsymbol{\Sigma}_Y) \propto |\boldsymbol{\Sigma}_Y|^{-\frac{p+1}{2}}$, yields the canonical Normal-inverse-Wishart posterior for the time series parameters $(\boldsymbol{\mu}_Y, \boldsymbol{\Sigma}_Y)$ in equations (A.1) and (A.2) of Appendix B.

[^15]: If one requires the tradable factors to price themselves, then $\boldsymbol{Y}_t \equiv (\boldsymbol{R}_t^\top, \boldsymbol{f}_t^{(2),\top})^\top$ and $p = N + K_2$.

The cross-sectional layer of the inference problem allows for misspecification of the factor model via the average pricing errors $\boldsymbol{\alpha}$ in equation (1). We model these pricing errors, as in the previous literature (e.g., Pastor and Stambaugh (2000) and Pastor (2000)), as $\boldsymbol{\alpha} \sim \mathcal{N}(\boldsymbol{0}_N, \sigma^2 \boldsymbol{\Sigma_R})$, yielding the cross-sectional likelihood (conditional on the time series parameters)

$$p(\text{data}|\boldsymbol{\lambda}, \sigma^2) = (2\pi\sigma^2)^{-\frac{N}{2}} |\boldsymbol{\Sigma_R}|^{-\frac{1}{2}} \exp\left\{-\frac{1}{2\sigma^2}(\boldsymbol{\mu_R} - \boldsymbol{C}\boldsymbol{\lambda})^\top \boldsymbol{\Sigma_R}^{-1} (\boldsymbol{\mu_R} - \boldsymbol{C}\boldsymbol{\lambda})\right\}, \tag{2}$$

where, in the cross-sectional regression, the 'data' are the expected risk premia, $\boldsymbol{\mu_R}$, and the factor loadings, $\boldsymbol{C} \equiv (\boldsymbol{1}_N, \boldsymbol{C}_f)$. The above likelihood can then be combined with a prior for risk prices (presented below) to obtain a posterior distribution that informs inference and model selection.

Note that the assumption of a Gaussian conditional cross-sectional likelihood in equation (2) is not strictly necessary, and we could, in principle, use an alternative formulation (albeit, in most cases, this would cause us to lose many of the closed-form results that make our method able to handle such high-dimensional models and parameter spaces). Nevertheless, there are two key reasons why Gaussianity is the most preferable assumption. First, the canonical quasi-maximum likelihood estimation property applies (Bollerslev and Wooldridge (1992)): that is, the likelihood in equation (2) yields consistent estimates even if the true distribution is not Gaussian. Instead, different distributional assumptions would yield consistency only if we "guess" the right distribution. Hence, Gaussianity is the robust choice. Second, consider estimating the model $\boldsymbol{R}_t = \boldsymbol{C}\boldsymbol{\lambda} + \boldsymbol{\varepsilon}_t$. Denoting with $\mathbb{E}_T$ the sample analogue of the unconditional expectation operator, we have $\mathbb{E}_T[\boldsymbol{R}_t] = \boldsymbol{C}\boldsymbol{\lambda} + \mathbb{E}_T[\boldsymbol{\varepsilon}_t]$. This implies that the pricing error $\boldsymbol{\alpha}$ should be equal to $\mathbb{E}_T[\boldsymbol{\varepsilon}_t]$. But the latter, under very general central limit theorem conditions (see, e.g., Hayashi (2000)), follows (under the null of the model) the limiting distribution $\boldsymbol{\alpha}|\boldsymbol{\Sigma_R} \sim \mathcal{N}(\boldsymbol{0}_N, \frac{1}{T}\boldsymbol{\Sigma_R})$. Hence, the Gaussian likelihood encoding in equation (2) not only ensures consistent estimates but is also a natural choice that guarantees compatibility of our hierarchical Bayesian modeling with frequentist asymptotic theory.

To handle model and factor selection, we introduce a vector of binary latent variables $\boldsymbol{\gamma}^\top = (\gamma_0, \gamma_1, \ldots, \gamma_K)$, where $\gamma_j \in \{0, 1\}$. When $\gamma_j = 1$, the $j$-th factor (with associated loadings $\boldsymbol{C}_j$) should be included in the SDF, and should be excluded otherwise.[^16] In the presence of potentially weak factors and, hence, unidentified prices of risk, the posterior probabilities of models and factors are not well defined under flat priors.

[^16]: In the baseline analysis, we always include the common intercept in the cross-sectional layer, that is, $\gamma_0 = 1$. Nevertheless, we also consider $\gamma_0 = 0$, i.e., no common intercept, in the robustness analysis.

To solve this issue, BHJ introduce an (economically motivated) prior that, albeit not informative, restores the validity of posterior inference. In particular, the uncertainty underlying the estimation and model selection problem is encoded via a (continuous spike-and-slab) mixture prior, $\pi(\boldsymbol{\lambda}, \sigma^2, \boldsymbol{\gamma}, \boldsymbol{\omega}) = \pi(\boldsymbol{\lambda} | \sigma^2, \boldsymbol{\gamma})\pi(\sigma^2)\pi(\boldsymbol{\gamma} | \boldsymbol{\omega})\pi(\boldsymbol{\omega})$, where

$$\lambda_j | \gamma_j, \sigma^2 \sim \mathcal{N}\left(0, r(\gamma_j)\psi_j \sigma^2\right). \tag{3}$$

Note the presence of three new elements, $r(\gamma_j)$, $\pi(\boldsymbol{\omega})$ and $\psi_j$, in the prior formulation.

First, $r(\gamma_j)$ captures the 'spike-and-slab' nature of the prior formulation. When the factor should be included, we have $r(\gamma_j = 1) = 1$, and the prior, the 'slab,' is just a diffuse distribution centred at zero. When instead the factor should not be in the model, $r(\gamma_j = 0) = r \ll 1$, the prior is extremely concentrated -- a 'spike' at zero. As $r \to 0$, the prior spike is just a Dirac distribution at zero, hence it removes the factor from the SDF.[^17]

[^17]: We set $r = 0.001$ in our empirical analysis.

Second, the prior $\pi(\boldsymbol{\omega})$ not only gives us a way to sample from the space of potential models, but also encodes belief about the sparsity of the true model using the prior distribution $\pi(\gamma_j = 1|\omega_j) = \omega_j$. Following the literature on predictor selection, we set

$$\pi(\gamma_j = 1|\omega_j) = \omega_j, \quad \omega_j \sim \text{Beta}(a_\omega, b_\omega). \tag{4}$$

Different hyperparameters $a_\omega$ and $b_\omega$ determine whether one a priori favors more parsimonious models or not. The prior expected probability of selecting a factor is $\frac{a_\omega}{a_\omega + b_\omega}$ and we set $a_\omega = b_\omega = 1$ in the benchmark case, that is, we have a uniform (flat) prior for the model dimensionality and each factor has an ex ante expected probability of being selected equal to 50%.[^18]

[^18]: However, we could set for instance, $a_\omega = 1$ and $b_\omega >> 1$ to favor sparser models.

*(Page 8)*

Third, the Bayesian solution to the weak factor problem in BHJ is to set

$$\psi_j = \psi \times \tilde{\boldsymbol{\rho}}_j^\top \tilde{\boldsymbol{\rho}}_j, \tag{5}$$

where $\tilde{\boldsymbol{\rho}}_j \equiv \boldsymbol{\rho}_j - \left(\frac{1}{N}\sum_{i=1}^N \rho_{j,i}\right) \times \boldsymbol{1}_N$, $\boldsymbol{\rho}_j$ is an $N \times 1$ vector of correlation coefficients between factor $j$ and the test assets, and $\psi \in \mathbb{R}_+$ is a tuning parameter that controls the degree of shrinkage across all factors. That is, factors that have vanishing correlation with asset returns, or extremely low cross-sectional dispersion in their correlations (hence cannot help in explaining cross-sectional differences in returns), have a low value of $\psi_j$ and are therefore endogenously shrunk toward zero. Instead, such a prior has no effect on the estimation of strong factors since these have large and dispersed correlations with the test assets, yielding a large $\psi_j$ and consequently a diffuse prior.

Finally, for the cross-sectional variance scale parameter, $\sigma^2$, estimation and inference can be based on the canonical diffuse prior $\pi(\sigma^2) \propto \sigma^{-2}$. As per Proposition 1 of Chib et al. (2020), since the parameter $\sigma$ is common across models and has the same support in each model, the marginal likelihoods obtained under this improper prior are valid and comparable.

The above hierarchical system yields a well-defined posterior distribution from which all the unknown parameters and quantities of interest can be sampled. Nevertheless, the prior formulation of BHJ might be overly restrictive when applied, as in our empirical analysis, to different asset classes jointly. To illustrate this, consider the case in which (as in our empirical application) all factors are standardized, and note that equations (3) to (5) then yield the following (squared) prior Sharpe ratio (SR) for each factor $f_{k,t}$:

$$\mathbb{E}_\pi[SR^2_{f_k} | \sigma^2] = \frac{a_\omega}{a_\omega + b_\omega} \psi \sigma^2 \tilde{\boldsymbol{\rho}}_k^\top \tilde{\boldsymbol{\rho}}_k, \quad \text{as } r \to 0.$$

This implies that two factors with the same (sum of squared) demeaned correlations with asset returns will have exactly identical prior Sharpe ratios. This feature is unsatisfactory when considering factors proposed for pricing different asset classes, as the maximum Sharpe ratio achievable in different market segments might actually be quite different. We relax this constraint in the next subsection by introducing a new, more flexible prior formulation that preserves the robustness of the estimator to weak and spurious factors.

### 2.3. A spike-and-slab prior for heterogeneous classes of factors

We now generalize the prior specification in equation (3). As in BHJ, we formalize a continuous spike-and-slab prior that, using the correlation between factors and asset returns, endogenously solves the problems arising from weak factor identification. However, unlike them, we introduce an additional hyperparameter that researchers can use to encode their prior belief about how much of the SDF Sharpe ratio in the data can be captured with factors coming from, respectively, the bond and stock factor zoos. Specifically, we formulate a spike-and-slab prior for the vector of all factors' market prices of risk as[^19]

[^19]: More precisely, the first element of $\boldsymbol{\lambda}$ is the coefficient associated with the common cross-sectional intercept, while the remaining elements are the market prices of risks of the factors under consideration.

$$\boldsymbol{\lambda}|\sigma^2, \boldsymbol{\gamma} \sim \mathcal{N}(\boldsymbol{0}, \sigma^2 \boldsymbol{D}^{-1}). \tag{6}$$

For illustrative purposes, consider first the case in which we have only two types of factors under consideration: $K_1$ bond-market-based factors (ordered first) and $K - K_1$ stock-market-based factors (ordered last). In this case we can encode our prior beliefs about which factors are more likely drivers of observed risk premia by setting $\boldsymbol{D}$ as a diagonal matrix with elements $c$ (the prior precision for the intercept), $[(1+\kappa)r(\gamma_1)\psi_1)]^{-1}$, ..., $[(1+\kappa)r(\gamma_{K_1})\psi_{K_1}]^{-1}$, $[(1-\kappa)r(\gamma_{K_1+1})\psi_{K_1+1}]^{-1}$, ..., $[(1-\kappa)r(\gamma_K)\psi_K]^{-1}$. The $\psi_j$ elements are defined as in equation (5) and endogenously solve the problems arising from weak factors. Similarly, $r(\gamma_j)$, as before, captures the spike-and-slab nature of the prior formulation.

The new hyperparameter $\kappa \in (-1, 1)$ encodes the prior belief about which class of factors is more likely to explain the Sharpe ratio of asset returns. To see this, consider the case in which both factors and returns are standardized (as in our empirical implementation). In this case:

$$\frac{\mathbb{E}_\pi\left[SR^2_f|\boldsymbol{\gamma}, \sigma^2\right]}{\mathbb{E}_\pi\left[SR^2_\alpha|\sigma^2\right]} = \frac{\psi}{N}\left[(1+\kappa)\sum_{k=1}^{K_1} r(\gamma_k)\tilde{\boldsymbol{\rho}}_k^\top \tilde{\boldsymbol{\rho}}_k + (1-\kappa)\sum_{k=K_1+1}^{K} r(\gamma_k)\tilde{\boldsymbol{\rho}}_k^\top \tilde{\boldsymbol{\rho}}_k\right],$$

where $SR_f$ and $SR^2_\alpha$ denote, respectively, the Sharpe ratios achievable with all factors and the Sharpe ratio of the pricing errors.

The above implies that the only free 'tuning' parameters in our setting, $\psi$ and $\kappa$, have straightforward economic interpretations and can be transparently set. To see this, first consider $\kappa = 0$ (the homogeneous prior specification). In this case (with a uniform prior of factor inclusion), the expected prior Sharpe ratio achievable with the factors

*(Page 9)*

is just $\mathbb{E}_\pi[SR^2_f | \sigma^2] = \frac{1}{2}\psi\sigma^2 \sum_{k=1}^K \tilde{\boldsymbol{\rho}}_k^\top \tilde{\boldsymbol{\rho}}_k$ as $r \to 0$. Hence, prior beliefs about the achievable Sharpe ratio with the factors fully pin down $\psi$.[^20] When instead $\kappa \neq 0$, the prior is heterogeneous across types of factors, and this parameter encodes our prior expectation about which type of factors explains a larger share of the Sharpe ratio of the asset returns. As $\kappa \to 1^-$ ($\kappa \to -1^+$), the prior becomes concentrated on only bond (stock) factors being able to explain the Sharpe ratio of asset returns. For example, setting $\kappa = 0.5$ encodes the prior belief that, ceteris paribus, bond factors explain a $\frac{1+\kappa}{1-\kappa} = 3$ times as large a share of the squared Sharpe ratio than equity factors.

[^20]: Without a uniform prior for the SDF dimensionality, the prior Sharpe ratio value becomes $\mathbb{E}_\pi[SR^2_f | \sigma^2] = \frac{a_\omega}{a_\omega + b_\omega}\psi\sigma^2 \sum_{k=1}^K \tilde{\boldsymbol{\rho}}_k^\top \tilde{\boldsymbol{\rho}}_k$ as $r \to 0$. Hence, beliefs about the prior Sharpe ratio and model dimensionality fully pin down the hyperparameters.

More generally, we can flexibly encode prior beliefs about the saliency of more than two categories of factors by setting $\boldsymbol{D} = \tilde{\boldsymbol{D}} \times \boldsymbol{\kappa}$, where $\tilde{\boldsymbol{D}}$ is a diagonal matrix with elements $c$, $(r(\gamma_1)\psi_1)^{-1}$, ..., $(r(\gamma_K)\psi_K)^{-1}$ and $\boldsymbol{\kappa}$ is a conformable column vector with elements $1, 1 + \kappa_1, \ldots, 1 + \kappa_K$ such that $\sum_{k=1}^K \kappa_j = 0$ and $0 < |\kappa_j| < 1 \; \forall j$.

Note that this general prior encoding maintains the same assumption of exponential tails for all factors (given the Gaussian formulation in equation (6)). And there is a very good reason for this: useless factors generate heavy-tailed cross-sectional likelihoods (in the limit, the likelihood is an improper "uniform" on $\mathbb{R}$), with peaks for the market prices of risk that deviate toward infinity. But, as first pointed out by Jeffreys (1961), as the peak of a thick-tailed likelihood moves away from the exponential-tail prior, the posterior distribution eventually *reverts back to the prior*. Hence, in our setting, the exponential tails of the prior play an important role: they shrink the price of risk of useless factors toward zero.

The transparency and interpretability of our prior formulation allows us, in the empirical analysis, to report results for various prior expectations of the Sharpe ratio achievable in the economy,[^21] prior probability of factor inclusion, shares of the prior Sharpe ratio achievable with the different types of factors that we consider, and account for a potential "mismeasurement alpha" in the corporate bond data.

[^21]: More precisely, we report results for different prior values of $\sqrt{\mathbb{E}_\pi[SR^2_f | \sigma^2]}$.

Furthermore, note that pure 'level' factors -- i.e., factors that have no explanatory power for cross-sectional differences in asset returns but capture the average level of risk premia across assets -- can be accommodated by removing the free intercept in the SDF (since it would be collinear with a pure level factor) and using simple correlations (instead of cross-sectionally demeaned ones) in equation (5), i.e. setting $\psi_j = \psi \times \boldsymbol{\rho}_j^\top \boldsymbol{\rho}_j$. We consider this particular case among our robustness exercises, and it leaves our main findings virtually unchanged.

### 2.4. Model and factor selection and aggregation

Our Bayesian hierarchical system defined in the previous subsections yields a well-defined posterior distribution from which all the unknown parameters and quantities of interest (e.g., $R^2$, SDF-implied Sharpe ratio, and model dimensionality) can be sampled to compute posterior means and credible intervals via the Gibbs sampling algorithm described in Appendix B. Most importantly, these posterior draws can be used to compute posterior model and factor probabilities, and, hence, identify robust sources of priced risk and -- if such a model exists -- a dominant model for pricing assets.

Model and factor probabilities can also be used for aggregating optimally, rather than selecting, the pricing information in the factor zoo. For each possible model $\boldsymbol{\gamma}^m$ that one could construct with the universe of factors, we have the corresponding SDF: $M_{t,\boldsymbol{\gamma}^m} = 1 - \left(\boldsymbol{f}_{t,\boldsymbol{\gamma}^m} - \mathbb{E}[\boldsymbol{f}_{t,\boldsymbol{\gamma}^m}]\right)^\top \boldsymbol{\lambda}_{\boldsymbol{\gamma}^m}$. Therefore, we construct a BMA-SDF by averaging all possible SDFs using the posterior probability of each model as weights:

$$M_t^{BMA} = \sum_{m=1}^{\bar{m}} M_{t,\boldsymbol{\gamma}^m} \Pr(\boldsymbol{\gamma}^m|\text{data}), \tag{7}$$

where $\bar{m}$ is the total number of possible models.[^22]

[^22]: See, e.g., Raftery et al. (1997) and Hoeting et al. (1999).

The BMA aggregates information about the true latent SDF over the space of all possible models, rather than conditioning on a particular model. At the same time, if a dominant model exists (a model for which $\Pr(\boldsymbol{\gamma}^m|\text{data}) \approx 1$), the BMA will use that model alone. Importantly, pricing with the BMA-SDF is robust to the problems arising from collinear loadings of assets on the factors, since any convex linear combination of factors with collinear loadings has exactly the same pricing implications. Moreover, the BMA-SDF can be microfounded, as in Heyerdahl-Larsen et al. (2023), thanks to the equivalence of a log utilities and heterogeneous beliefs economy with a representative agent using the Bayes rule. Furthermore, BMA aggregation is optimal under a wide range of criteria, but in particular, it is *optimal on average*: no alternative estimator can outperform it for all possible values of the true unknown parameters.[^23] Finally, since its predictive distribution minimizes the Kullback-Leibler information divergence relative to the true unknown data-generating process, the BMA aggregation delivers the most likely SDF given the data, and the estimated density is as close as possible to the true unknown one, even if all of the models considered are misspecified.

[^23]: See, e.g., Raftery and Zheng (2003) and Schervish (1995).

*(Page 10)*

Importantly, the BMA has particularly appealing properties when applied to the construction of the SDF. To see this, note that the BMA-SDF defined in equation (7) -- thanks to the linearity of the models considered -- can be rewritten as a weighted sum over the space of factors, rather than over the space of models. That is:

$$M_t^{BMA} = 1 - \sum_{j=1}^K \underbrace{\mathbb{E}[\lambda_j|\text{data}, \gamma_j = 1] \Pr(\gamma_j = 1|\text{data})}_{\equiv \; \mathbb{E}[\lambda_j|\text{data}]} \left(f_{j,t} - \mathbb{E}[f_{j,t}]\right), \quad \text{as } r \to 0. \tag{8}$$

This expression makes clear that the weight attached to each factor in the BMA-SDF is driven by two elements. First, the probability of the factor being a "true" source of priced risk, $\Pr(\gamma_j = 1|\text{data})$. Hence, naturally, when a factor is more likely (given the data) to drive asset risk premia, it features more prominently in the BMA-SDF. Second, when a factor commands a large market price of risk in the models that include it, i.e. when $\mathbb{E}[\lambda_j|\text{data}, \gamma_j = 1]$ is large, it will, ceteris paribus, have a larger role in the BMA-SDF. These two forces are jointly captured in $\mathbb{E}[\lambda_j|\text{data}]$, the posterior expectation of the market price of risk given the data only, i.e., independently of the individual models.

This property of the BMA-SDF implies that, when parsing the factor zoo, there are two quantities of key interest. First, $\Pr(\gamma_j = 1|\text{data})$, as we want to discern which variables are more likely, given the data, to be fundamental sources of risk and, hence, should be included in our theoretical models for explaining asset returns. Second, and arguably as important, $\mathbb{E}[\lambda_j|\text{data}]$, as this quantity pins down how salient the given factor is in the BMA approximation of the SDF. Furthermore, $\mathbb{E}[\lambda_j|\text{data}]$ yields the weights that should be assigned to the factors in a portfolio that best approximates the true latent SDF. For these reasons, we track both quantities in our empirical analysis.

Furthermore, this implies that posterior probabilities of factors that are not true sources of fundamental risk will not necessarily tend to zero if they nevertheless help span the true latent risks driving asset returns. That is, it might well be the case that, for a given factor, the posterior probability of being part of the SDF ($\Pr(\gamma_j = 1|\text{data})$) is smaller than the prior one -- hence indicating that the data do not support the factor being a fundamental risk -- while at the same time its estimated posterior market price of risk ($\mathbb{E}[\lambda_j|\text{data}]$) is substantial, since the factor helps the BMA-SDF span the risks in asset returns. This is not a contradiction, but rather an important element of strength of our method.

To illustrate these properties, consider the case in which the "true" SDF contains only one factor. That is, $M_t^{\text{true}} = 1 - \lambda_f f_{t,\text{true}}$, where $f_{\text{true}}$ is the true source of fundamental risk and to simplify exposition, we employ the normalizations $\mathbb{E}[f_{t,\text{true}}] = 0$ and $\text{var}(f_{t,\text{true}}) = 1$. Note that under this innocuous normalization the risk premium and market price of risk of the factor coincide, i.e. $\lambda_{\text{true}} = \sqrt{\text{var}(M_t^{\text{true}})} = -\text{cov}(M_t^{\text{true}}, f_{t,\text{true}}) = \mu_{\text{true}}$. Consistent with the postulated one factor structure, the vector of test assets' excess returns $\boldsymbol{R}_t$ follows the process

$$\boldsymbol{R}_t = \boldsymbol{\mu_R} + \boldsymbol{C} f_{t,\text{true}} + \boldsymbol{w}_{R,t},$$

where $\boldsymbol{w}_{R,t} \perp f_{t,\text{true}}$ and $\mathbb{E}[\boldsymbol{w}_{R,t}] = \boldsymbol{0}$. Hence, it follows that the true factor prices perfectly (in population) the asset returns, as $\boldsymbol{\mu_R} = -\text{cov}(M_t^{\text{true}}, \boldsymbol{R}_t) = \boldsymbol{C}\lambda_{\text{true}}$.

Suppose further that there are a set of factors, "noisy proxies" of the true factor $f_{\text{true}}$, that the researcher considers as potential sources of fundamental risk,

$$f_{j,t} = \delta_j f_{t,\text{true}} + \sqrt{1 - \delta_j^2} \; w_{j,t}, \quad |\delta_j| < 1,$$

for each noisy proxy $j$, with $w_{j,t} \perp f_{t,\text{true}}$ and $w_{j,t} \overset{\text{iid}}{\sim} (0, 1)$. Note that in this handy encoding $\delta_j$ captures both the correlation between the true source of risk and the $j$-th noisy proxy and the latter's signal-to-noise ratio (as $\sqrt{\text{var}(f_{j,t})} = 1$ by construction).

Suppose that a researcher tests the pricing ability of the $j$-th noisy proxy by considering the misspecified SDF $\widetilde{M}_{j,t} = 1 - \tilde{\lambda}_j f_{j,t}$. We then have that the misspecified SDF prices the test assets perfectly in population (as long as the noise in the factor is "classical," i.e. $w_{j,t} \perp \boldsymbol{w}_{R,t}$):

$$\boldsymbol{\mu_R} = -\text{cov}(\widetilde{M}_{j,t}, \boldsymbol{R}_t) = \boldsymbol{C}\delta_j \tilde{\lambda}_j \quad \text{with} \quad \tilde{\lambda}_j = \lambda_{\text{true}}/\delta_j. \tag{9}$$

That is, the noisy proxy seems indistinguishable from the true factor in its pricing ability for the test assets, and it yields an estimated market price of risk (in population) that is larger (in absolute terms) than that of the true factor.[^24]

[^24]: Furthermore, $|\tilde{\lambda}_j| \to \infty$ as $|\delta_j| \to 0$, in yet another manifestation of the weak factor problem.

*(Page 11)*

Nevertheless, our method will detect such factor as a noisy proxy since our hierarchical Bayesian framework requires factors to self-price. To see this, note that the true risk premium of the noisy proxy is $\mu_j \equiv -\text{cov}(M_t^{\text{true}}, f_{j,t}) \equiv \delta_j \lambda_{\text{true}}$, while instead the misspecified SDF that prices the cross-section of test assets yields an implied risk premium for the factor given by $\tilde{\mu}_j := -\text{cov}(\widetilde{M}_{j,t}, f_{j,t}) = \tilde{\lambda}_j = \lambda_{\text{true}}/\delta_j$. Thus, the noisy proxy will fail to self-price, since $|\tilde{\mu}_j| > |\mu_j| \; \forall |\delta_j| < 1$, and its self-mispricing will be proportional to $|\frac{1}{\delta_j^2} - 1|$.

This implies that, once the candidate factors are added to the set of test assets, factors that have a higher correlation ($\delta_j$) with the true source of risk will have overall better performance in the cross-sectional likelihood in equation (2). Moreover, since $\tilde{\mu}_j \xrightarrow{|\delta_j|\to 1} \mu_j$, noisy proxies with a higher signal-to-noise ratio will tend to have higher posterior probabilities. Importantly, the BMA-SDF is more robust in recovering the pricing of risk than other canonical estimators. The reason being that, as per equation (9), simple cross-sectional estimation with the noisy proxy included in the SDF yields an upward biased market price of risk for this factor, $\mathbb{E}[\lambda_j|\text{data}, \gamma_j = 1]$. Nevertheless, due to the self-pricing restriction that the noisy proxy will not satisfy, the posterior probability of such factors, $\Pr(\gamma_j = 1|\text{data})$, will be strictly smaller than one. This, in turn, will counteract the upward bias in the market price of risk since the factor enters the BMA in equation (8) with a weight equal to $\mathbb{E}[\lambda_j|\text{data}, \gamma_j = 1] \Pr(\gamma_j = 1|\text{data})$ (as $r \to 0$).

Note that this analytical example of the properties of our estimator is without loss of generality. For instance, a misspecified SDF with multiple noisy proxies will also yield an upward-biased measure of the market price of risk. Consequently, the misspecified SDF will not be able to satisfy the self-pricing restriction of the factors; hence, it will achieve a posterior probability strictly smaller than one. Therefore, this upward biased measure of the market price of risk implied by the misspecified SDF will be counteracted in the BMA in equation (8) by a $\Pr(\boldsymbol{\gamma}^m|\text{data}) << 1$.

But are these population (hence asymptotic) properties of our method likely to hold in a finite sample? We address this question with a realistic simulation exercise.

#### 2.4.1. Simulation

We calibrate a single (pseudo-true) useful factor ($f_{\text{true}}$) that mimics the pricing ability of the HML factor in the cross-section of the 25 Fama-French size and book-to-market portfolios. That is, we consider a setting with a partially misspecified pricing kernel (as HML yields sizable pricing errors in the cross-section used for calibration). To make the estimation challenging, we always include a useless factor (as this breaks the validity of canonical estimation methods), and consider noisy proxies with different correlations with the useful factor. In each experiment we include a variable number of noisy proxies $f_j$, $j = 1, ..., 4$ with correlations with the pseudo-true factor equal to 0.4, 0.3, 0.2, and 0.1, respectively. Further details of the simulation design are reported in Internet Appendix IA.2.

Simulation results are reported in Figure 1 for different sample sizes and a prior Sharpe ratio of 60% of the ex post maximum Sharpe ratio in the simulated samples. Results for different priors and sample sizes are reported in the Internet Appendix. We conduct six experiments. In the first three (experiments I to III), the pseudo-true factor is included among the candidate factors, while in the latter three (experiments IV to VI) only its noisy proxies are included.

Panel A of Figure 1 reports the BMA-SDF-implied market price of risk for several simulation designs in time series samples with only 400 monthly observations. The horizontal red dashed line denotes the Sharpe ratio of the pseudo-true factor, while the shaded grey area denotes the frequentist 95% confidence region for the market price of risk of the HML factor estimated via GMM in the (true) cross-section of 25 size and book-to-market portfolios with 665 monthly observations. Remarkably, the BMA-SDF estimator accurately recovers the market price of risk of the SDF not only when the pseudo-true factor is included among the candidate pricing factors (experiments I to III), but also when only noisy proxies of the true source of risk are included (experiments IV to VI). Moreover, the estimates are sharp -- the distributions of the BMA-MPRs across simulation runs have 95% coverage areas very similar to the ones obtained (without accounting for model uncertainty) in the much longer true sample. Furthermore, as the time series sample size increases, Panel B of Figure 1 illustrates that the BMA estimates of the MPRs of the SDF become progressively more concentrated on the pseudo-true value, and converge to it in the large sample (see Panel B of Figure IA.9 of the Internet Appendix), even if only noisy proxies of the true source of risk are among the factors considered.

That is, our method can correctly recover the pricing of risk in the economy even when the true source of risk is not among the set of tested factors. Nevertheless, as illustrated in Panels C to F of Figure 1, this goal is achieved by the BMA in two different ways, depending on whether the pseudo-true factor is included among the tested ones or not.

First, when the pseudo-true factor is among the tested ones (experiments I to III), its estimated MPR (Panels C and D) is concentrated on the pseudo-true value, and converges to it as the time series sample size increases (as per Figure IA.9 of the Internet Appendix), and its posterior probability of being part of the SDF becomes progressively closer to one. On the contrary, the estimated MPRs of the noisy proxies are small and tend to zero as the sample size increases. Similarly, the market price of risk of the useless factor is effectively shrunk to zero. Note that while the posterior probability of the pseudo-true factor goes to one as the sample size increases, the probabilities of the useless factor and noisy proxies do revert to their prior value (Panels E and F). This might seem counterintuitive at first, but it is exactly what should be expected: as the posterior MPR of a given factor

*(Page 12)*

<!-- @section-type: figure
  @key-claim: Simulation evidence shows BMA-SDF correctly recovers market price of risk even with only noisy proxies of the true factor.
  @importance: core
  @data-source: Simulated data calibrated to HML factor
  @depends-on: Section 2.4
  @equations: none
-->

**Figure 1: Simulation evidence with useless factors and noisy proxies.**

*Panels A-B:* BMA-SDF market price of risk for T = 400 and T = 1600. *Panels C-D:* Individual factors' market prices of risk for T = 400 and T = 1600. *Panels E-F:* Individual factors' posterior probabilities for T = 400 and T = 1600.

Simulation results from applying the Bayesian methods to different sets of factors. Each experiment is repeated 1,000 times with the specified sample size (T). The data-generating process is calibrated to match the pricing ability of the HML factor (as a pseudo-true factor) for the Fama-French 25 size and book-to-market portfolios. Horizontal red dashed lines denote the market price of risk of HML, and the grey shaded area the frequentist 95% confidence region of its GMM estimate in the historical sample of 665 monthly observations. The prior is set to 60% of the ex post maximum Sharpe ratio. Half-violin plots depict the distribution of the estimated quantities across the simulations, with black error bars denoting centered 95% coverage, and white circles denoting median values. In all experiments a useless factor ($u_f$) is included, while the pseudo-true factor ($f_{\text{true}}$) is included only in experiments I to III. Noisy proxies $f_j$, $j = 1, ..., 4$ have correlations with the pseudo-true factor equal to 0.4, 0.3, 0.2, and 0.1, respectively.

| Experiment | Factors |
|---|---|
| I | $u_f$ and $f_{\text{true}}$ |
| II | $u_f$, $f_{\text{true}}$ and $f_1$ |
| III | $u_f$, $f_{\text{true}}$, $f_1$ and $f_2$ |
| IV | $u_f$, and $f_1$ |
| V | $u_f$, $f_1$ and $f_2$ |
| VI | $u_f$, $f_1$, $f_2$, $f_3$ and $f_4$ |

*(Page 13)*

goes to zero, the fit of a model that includes that factor becomes indistinguishable from the one of a model that does not include said factor. Hence, the posterior probability of a factor whose MPR is sharply estimated to be close to zero should revert to its prior value -- exactly what our method delivers. Note also that such factors, as shown in equation (8), will have zero weight in the BMA-SDF (as $\mathbb{E}[\lambda_j|\text{data}] \to 0$).

Second, when the pseudo-true factor is *not* among the tested factors (experiments IV to VI), the BMA-SDF still correctly recovers the overall price of risk (Panels A and B), but does so by assigning non-zero MPRs (Panels C and D), and posterior probabilities above their prior values, to the noisy proxies. Furthermore, as in the above-derived analytical results, noisy proxies more correlated with the pseudo-true factor have higher posterior probabilities and MPRs. Nevertheless, even asymptotically (Panel F of Figure IA.9 of the Internet Appendix), the posterior probability of the noisy proxies will not tend to one -- as discussed above, thanks to the self-pricing restriction imposed by our estimator. This also implies that the BMA will not simply select the "best" noisy proxy. Instead, it will use multiple proxies in order to maximize the signal, and minimize the noise, that noisy proxies bring to the table.

The robustness of this last result should not be overstated. In the presence of the true factor among the tested ones, the data will always overcome the prior and converge to the truth under standard conditions (see, e.g., Schervish (1995, Thm. 7.78)). Nevertheless, when the true factor is not among the tested ones *and* the prior encodes a very high degree of shrinkage (via a very small prior Sharpe ratio), we should expect an attenuation bias in the BMA-SDF-implied MPR in the economy. This is due to the fact that, in the presence of only noisy proxies, no linear combination of them will be able to perfectly price (even asymptotically) both test assets and the factors themselves. Hence, the data will always provide some support for the case in which none of the factors should be included in the SDF, in turn reducing the BMA estimation of the overall MPR achievable with the factors (see, e.g., Panel B of Figure IA.10 of the Internet Appendix). This does not imply that one should prefer very little or no shrinkage at all, as this is preempting weak and useless factors from invalidating inference. Hence, exactly as we do in our empirical exercises, one should analyze the sensitivity of the results to the prior degree of shrinkage.

The above theoretical and simulation-based results stress the robustness of our method in both a large and small sample. Furthermore, they highlight that factor posterior probabilities and market prices of risk carry different, yet salient, information. Hence, both quantities should be tracked and analyzed (as we do in our empirical exploration). For instance, one might find that a given factor has both a posterior probability below its prior value -- hence, it is unlikely to be a source of fundamental risk -- and a large posterior MPR -- since it is highly correlated with the true sources of priced risk, and it will consequently have a large weight in the BMA approximation of the true latent SDF in equation (8). In a nutshell, posterior probabilities tell us which factors should be included in a theoretical model given the data, since they identify the most likely sources of priced risk, while instead posterior market prices of risk tell us which factors should be included (and with what weight) in a portfolio that best approximates the true latent SDF and delivers the maximum achievable Sharpe ratio with the factors at hand.

---

*(Page 13)*

<!-- @section-type: results
  @key-claim: Only five factors (PEADB, IVOL, PEAD, CREDIT, YSP) have posterior probabilities above the prior 50% for the co-pricing SDF; the true latent SDF is dense with median 22 factors.
  @importance: core
  @data-source: BAML/ICE bonds, CRSP equities, 54 factors
  @depends-on: Sections 1, 2
  @equations: none
-->

## 3. Estimation results

In this section, we apply the hierarchical Bayesian method to a large set of factors proposed in the previous bond and equity literature. Overall, we consider 40 tradable and 14 nontradable factors, yielding $2^{54} \approx 18$ quadrillion possible models for the combined bond and stock factor zoo. In Sections 3.1 and 3.4 we only consider returns for the bond portfolios in excess of the short-term risk-free rate (calculated as outlined in Section 1.1). In Section 3.3, we also use duration-adjusted excess returns, as well as U.S. Treasury portfolios, to disentangle the credit and Treasury term structure components of corporate bond returns.

### 3.1. Co-pricing bonds and stocks

We now consider the pricing power of the 54 factors to gauge the extent to which the cross-section of corporate bond and stock returns is priced by the joint factor zoo. The IS test assets include the 50 bond and 33 stock portfolios described in Section 1.3 in addition to the 40 tradable factor portfolios (for a total $N = 123$). Throughout, we use the continuous spike-and-slab approach described in Section 2. To report the results, we refer to the priors as a fraction of the ex post maximum Sharpe ratio in the data, which is equal to 5.4 annualized for the joint cross-section of portfolios, from a very strong degree of shrinkage (20%, i.e., a prior annualized Sharpe ratio of 1.0), to a very moderate one (80% or a prior annualized Sharpe ratio of 4.2). Given that the results demonstrate considerable stability across a wide range of prior Sharpe ratio values, we present selected findings for a prior set at 80% of the ex post maximum, as this choice tends to yield the best out-of-sample performance.[^25]

[^25]: Additional results for different values of the prior Sharpe ratio are reported in Table A.2 of Appendix C.

*(Page 14)*

#### 3.1.1. The co-pricing SDF

We start by asking which factors are likely components of the latent SDF in the economy. Figure 2 reports the posterior probabilities (given the data) of each factor (i.e., $\mathbb{E}[\gamma_j|\text{data}]$, $\forall j$) for different values of the prior Sharpe ratio achievable with the linear SDF (expressed as a percentage of the ex post maximum Sharpe ratio). See Table A.1 of Appendix A for a detailed description of the factors.

Recall that we have a uniform (hence flat) prior for the model dimensionality and each factor has an ex ante expected probability of being selected equal to 50%, depicted by the dashed horizontal line in Figure 2. Several observations are in order. First, with some notable exceptions, most factors proposed in the corporate bond and equity literatures have (individually) a posterior probability of being part of the SDF that is below its prior value of 50%. That is, given the data, they are unlikely sources of fundamental risks.

**Figure 2: Posterior factor probabilities: Co-pricing factor zoo.** Posterior probabilities, $\mathbb{E}[\gamma_j|\text{data}]$, of the 54 bond and stock factors. The prior for each factor inclusion is a Beta(1, 1), yielding a prior expectation for $\gamma_j$ of 50%. Results are shown for different values of the prior Sharpe ratio set to 20%, 40%, 60% and 80% of the ex post maximum Sharpe ratio. Labels are ordered by the average posterior probability across the four levels of shrinkage. Test assets are the 83 bond and stock portfolios and 40 tradable bond and stock factors. Sample period: 1986:01 to 2022:12 (T = 444). The five factors with posterior probabilities above 50% at the 80% prior SR level are: PEADB (~0.71), IVOL (~0.62), PEAD (~0.61), CREDIT (~0.55), YSP (~0.51). PEADB and PEAD are consistently above 50% across all prior SR levels; IVOL is above 50% at all levels but by thin margins at 20-40%; CREDIT and YSP hover near the 50% line at lower prior SR levels.

Second, given that their posterior probabilities are above the prior 50% value for the entire range of prior Sharpe ratios considered, five factors are identified as likely sources of fundamental risk in the bond and equity markets. In particular, there is strong evidence for including two tradable factors, PEADB and PEAD (i.e., respectively, the bond and stock post-earnings announcement drift factors), as a source of priced risk in the SDF. Partially, this is a surprising result, as PEADB has not specifically been proposed as a priced risk factor in the previous literature. Nozawa et al. (2025) are the first to document a post-earnings announcement drift in corporate bond prices, and they rationalize their finding with a stylized model of disagreement. They also show that a strategy that purchases bonds issued by firms with high earnings surprises and sells bonds of firms with low earnings surprises generates sizable Sharpe ratios and large risk-adjusted returns. On the other hand, Bryzgalova et al. (2023) and Avramov et al. (2023) find strong evidence that the stock market post-earnings announcement drift (PEAD) factor of Daniel et al. (2020a) exhibits a particularly high posterior probability of being part of the SDF for stock returns. In fact, PEAD is the only other tradable factor with a posterior probability of being part of the SDF that prices the joint cross-section of corporate bond and stock returns that is above 50%. That is, the only two tradable factors with high posterior probabilities are the bond and stock versions of the post-earnings announcement drift. Note that, in equilibrium models in which rational agents with limited risk-bearing capacity face behavioural asset demand, the drivers of the latter become part of the pricing measure -- exactly as we find (see, e.g., De Long et al. (1990)). Note also that, as shown in Table IA.III of the Internet Appendix, these are the tradable factors with the highest Sharpe ratio in our full sample. Moreover, PEADB has the highest Sharpe ratio among bond factors when the sample is split in half, while PEAD has the highest Sharpe ratio among stock factors in the first half, and one of the highest in the second half of the sample (see Table IA.IV of the Internet Appendix).[^26]

[^26]: Despite its reduced *time series* predictability in most recent data (see, e.g., Martineau (2022)), we document remarkable stability of the post-earnings announcement drift for forming long-short corporate bond and stock portfolios across subsamples in Internet Appendix IA.4. That is, the *cross-sectional* predictability of the post-earnings announcement drift within a portfolio context remains robust and does not appear to be driven by micro-cap stocks.

*(Page 15)*

Furthermore, the *nontradable* idiosyncratic equity volatility factor (IVOL) of Campbell and Taksler (2003) is supported by the data as a fundamental source of priced risk. Interestingly, the rationale behind this factor closely connects bond and stock markets: as per the seminal insight of Merton (1974), equity claims are akin to a call option on the value of the assets of the firm, while the debt claim contains a short put option on the same. Consequently, Campbell and Taksler (2003) suggest, changes in the firm's volatility should be expected to affect bond and stock prices.[^27]

[^27]: See, e.g., Dickerson et al. (2025) for a model of the correlation of bonds and stocks of the same firm.

Additionally, two more *nontradable* factors have posterior probabilities of being part of the SDF above 50% for all values of the prior Sharpe ratio: the slope of the Treasury yield term structure (YSP, Koijen et al. (2017)), a well-known predictor of business cycle variation, and the AAA/BAA yield spread (CREDIT, Fama and French (1993)), a common metric of the risk compensation differential between safer and riskier securities. Interestingly, the term premium and default risk factors are originally suggested in Fama and French (1993) exactly for the purpose of co-pricing bonds and stocks.

Third, there are a few factors for which the posterior probability is roughly equal to the prior (implying that at least some of these factors are likely to be weakly identified at best), and there is a large set of factors that are *individually* unlikely to be sources of fundamental risk in the SDF pricing the joint cross-section of bond and stock returns. In particular, besides PEADB and PEAD, *all* tradable bond and stock market factors are individually unlikely to capture fundamental risk in the SDF. For instance, with a prior Sharpe ratio set to 80% of the ex post maximum, the posterior probabilities for 30 of the 40 tradable bond and stock factors are below 40% (see Figure 2 as well as the top panel of Figure 4). Nevertheless, as shown theoretically and in the simulation in Section 2.4, and discussed extensively below, this does *not* imply that these factors, *jointly*, do not carry relevant information to characterize the true latent SDF.

Notably, the stock as well as the bond market factors (MKTS and MKTB, respectively) both exhibit posterior probabilities below 50% for almost the full range of prior Sharpe ratios for the joint cross-section of returns. Nevertheless, when separately pricing the cross-sections of stock and bond returns with only the factors in their respective zoos, both market indices become likely components of the SDF: for all prior levels in the MKTS case, and for all but one in the MKTB case (see Tables IA.V and IA.VI of the Internet Appendix). This confirms the finding that the equity market index contains valuable information for pricing stocks in an unconstrained SDF based on stock factors only (as in Bryzgalova et al. (2023)). However, when the space of potential factors is expanded to include both stock and bond factors, without dimensionality restrictions on the SDF as we do in our baseline co-pricing exercise, models with MKTS (and more so in the MKTB case) overall perform worse than denser models containing factors from both zoos. That is, the information in the market indices appears to be spanned by the other factors in the zoo.

Given the focus of most (yet not all) of the previous literature on selecting models characterized by a small number of factors, the above findings raise the question of whether the handful of most likely factors that we have identified are enough to capture the span of the true, latent, SDF that jointly prices bonds and stocks. Moreover, are factors less likely to be sources of fundamental risk really devoid of useful pricing information? Since our Bayesian method does not ex ante impose the existence of a unique, low-dimensional, and correctly specified model -- all assumptions that are needed with conventional frequentist asset pricing methods -- we can formally answer these questions.

*(Page 16)*

The top panel of Figure 3 reports the posterior dimensionality of the SDF in terms of observable factors to be included in it, and the bottom panel shows the posterior distribution of the Sharpe ratios achievable with such an SDF. It is evident that the sparse models suggested in the previous literature have very weak support in the data, and are misspecified with very high probability, as a substantial number of factors is needed to capture the span of the true latent SDF: **the posterior median number of factors is 22 with a centered 95% coverage of 15 to 29 factors.** In fact, the posterior probability of a model with less than 10 factors is virtually zero, indicating that the quest for a sparse, unique, SDF model among the observable factors in the joint bond and stock factor zoo is misguided at best.

**Figure 3: Posterior SDF dimensionality and Sharpe ratios: Co-pricing factor zoo.** (A) Posterior distribution of the number of factors: posterior median = 22, 95% CI = [15, 29]. Prior distribution is flat (uniform). (B) Posterior distribution of the SDF-implied Sharpe ratio: 90% CI shown. Prior Sharpe ratio set to 80% of ex post maximum. Sample period: 1986:01 to 2022:12 (T = 444).

**Table 1: Most likely (top five) factor contribution to the SDF**

| | Panel A: Co-pricing SDF | | | | Panel B: Bond SDF | | | | Panel C: Stock SDF | | | |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Total prior SR: | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
| $\mathbb{E}[SR_f|\text{data}]$ | 0.26 | 0.57 | 1.06 | 1.24 | 0.28 | 0.71 | 1.10 | 1.46 | 0.17 | 0.42 | 0.78 | 1.10 |
| $\mathbb{E}[SR^2_f / SR^2_m|\text{data}]$ | 0.13 | 0.20 | 0.32 | 0.28 | 0.34 | 0.57 | 0.65 | 0.70 | 0.12 | 0.22 | 0.35 | 0.42 |

Top five co-pricing factors: PEADB, IVOL, PEAD, CREDIT, YSP. Top five bond factors: PEADB, CREDIT, MOMBS, YSP, IVOL. Top five stock factors: PEAD, IVOL, MKTS, CMAs, LVL.

The share of the SDF squared Sharpe ratio generated by these five factors alone ($\mathbb{E}[SR^2_f / SR^2_m|\text{data}]$) is quite limited. This means that there is substantial additional priced risk in the factor zoo that is *not* captured by the most likely factors. That is, the less likely factors are noisy proxies for latent fundamental risks and are needed, jointly, to provide an accurate characterization of the risks priced by the true latent SDF.

*(Page 17)*

**Figure 4: Posterior factor probabilities and risk prices: Joint factor zoo (excess bond returns).** (A) Posterior probabilities: most factors below the 50% prior. PEADB is the highest (~0.71), followed by IVOL (~0.62), PEAD (~0.61), CREDIT (~0.55), YSP (~0.51). Three colors distinguish factor types: dark blue (nontradable), light blue (bond tradable), red (equity tradable). (B) Posterior market prices of risk (annualized): PEADB has the largest MPR (~0.65), followed by MOMBS (~0.50), CRY (~0.48), PEAD (~0.45), MKTS (~0.41), QMJ (~0.41), IVOL (~0.26), CREDIT (~0.20), YSP (~0.09). Several factors with low posterior probabilities nonetheless carry sizeable MPRs (e.g., MKTS, MOMBS, CRY, QMJ). Prior SR = 80% of ex post max. Sample: 1986:01 to 2022:12 (T = 444).

All five factors with posterior probabilities higher than their prior values (i.e., PEADB, IVOL, PEAD, CREDIT and YSP) command substantial market prices of risk, implying a considerable weight in a portfolio that best approximates the true latent SDF. Hence, not only does the data support their inclusion in the SDF, but they also play an important role in its BMA estimate.

Out of the next fifteen factors with the highest (individual) posterior probabilities, ten are nontradable in nature. Nevertheless, the risk prices of several of these nontradable factors are small and, in some cases, effectively

*(Page 18)*

shrunk toward zero. This is due to the fact that these are likely *weak factors* in the joint cross-section of corporate bond and stock returns and, consequently, carry a near-zero weight in the portfolio that approximates the SDF.[^28]

[^28]: That is, their correlations with the test assets are small and have little cross-sectional dispersion. See, e.g., Gospodinov et al. (2019) and Kleibergen (2009) for a formal definition of weak and level factors.

The occurrence of weak factors, which, in fact, is most common among the nontradable ones, causes identification failure and invalidates canonical estimation approaches (e.g., GMM, MLE, and two-pass regressions). This is not an issue for our Bayesian method, which restores inference by design, by regularizing the marginal likelihood. Furthermore, for these factors, both shown theoretically and in the simulation in Section 2.4, the posterior probabilities revert to their prior value as the market prices of risk tend to zero.

Interestingly, several factors with posterior probabilities below their prior values -- hence unlikely sources of fundamental risk -- do carry very sizeable posterior market prices of risk. For example, the equity market index factor carries the third largest MPR among equity factors and the sixth largest among the tradable ones. Section 2.4 informs us exactly how to interpret such findings: these are factors that the data do not support as being fundamental sources of risk (hence the posterior probability being below the prior value), but that nevertheless have a high correlation with the true latent priced risk and, hence, feature prominently in the BMA-SDF to provide an accurate approximation of the true latent SDF.

#### 3.1.2. Cross-sectional asset pricing

We now turn to the asset pricing performance of the BMA-SDF based on the joint cross-section and factor zoos, as well as based on bond and stock portfolios separately. In Table 2 we report results for in-sample cross-sectional pricing using various performance measures, while out-of-sample results are summarized in Table 3.

The in-sample assets for the joint cross-section in Panel A of Table 2 are the 83 portfolios of bonds and stocks (described in Section 1.4) plus 40 tradable factors. Panels B and C focus only on bonds (50 portfolios and 16 bond tradable factors) and stocks (33 anomaly portfolios and 24 stock tradable factors), respectively. The out-of-sample test assets in Table 3 comprise 77 bond portfolios and 77 stock portfolios (described in Section 1.4), which are considered jointly in Panel A and separately in Panels B and C.

When assessing the pricing performance, we compare our BMA-SDF for different levels of prior Sharpe ratio shrinkage with the performance of a number of benchmark models. In particular, we consider the bond CAPM (CAPMB), the stock CAPM, the Fama and French (1993) five-factor model (FF5), the intermediary asset pricing model of He et al. (2017) (HKM), the PCA-based SDF of Kozak et al. (2020) (KNS) and the risk premia PCA approach of Lettau and Pelger (2020) (RPPCA).[^29] In addition, since most of the previous literature focuses on selection (rather than aggregation) of pricing factors, we also include the respective 'top' factor models (TOP) from our Bayesian analysis that comprise only the five factors with the highest posterior probabilities (for the joint cross-section for example, this is a five-factor model with PEADB, IVOL, PEAD, CREDIT, and YSP). All the benchmark model SDFs are estimated via a GLS version of GMM.[^30]

[^29]: The SDFs of both KNS and RPPCA are re-estimated using our data and the methods proposed in the original papers. Details of the estimation for all benchmark models are reported in Appendix D.
[^30]: See Appendix D for further details.

*(Page 19-20)*

<!-- @section-type: table
  @key-claim: BMA-SDF outperforms all benchmark models IS and OS for co-pricing bonds and stocks.
  @importance: core
  @data-source: 123 IS test assets, 154 OS test assets
  @depends-on: Sections 1, 2, 3.1.1
  @equations: none
-->

**Table 2: In-sample cross-sectional asset pricing performance**

| | BMA-SDF 20% | BMA-SDF 40% | BMA-SDF 60% | BMA-SDF 80% | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Panel A: Co-pricing bonds and stocks** | | | | | | | | | | | |
| RMSE | 0.214 | 0.203 | 0.185 | **0.167** | 0.260 | 0.278 | 0.258 | 0.259 | 0.230 | 0.166 | 0.197 |
| MAPE | 0.167 | 0.154 | 0.139 | **0.125** | 0.194 | 0.221 | 0.198 | 0.192 | 0.171 | 0.126 | 0.132 |
| $R^2_{OLS}$ | 0.155 | 0.240 | 0.367 | **0.487** | -0.244 | -0.426 | -0.233 | -0.238 | 0.023 | 0.489 | 0.282 |
| $R^2_{GLS}$ | 0.106 | 0.168 | 0.232 | **0.285** | 0.078 | 0.083 | 0.087 | 0.078 | 0.263 | 0.176 | 0.267 |
| **Panel B: Pricing bonds** | | | | | | | | | | | |
| RMSE | 0.180 | 0.148 | 0.121 | **0.104** | 0.209 | 0.214 | 0.201 | 0.206 | 0.162 | 0.192 | 0.091 |
| MAPE | 0.129 | 0.109 | 0.091 | **0.079** | 0.146 | 0.135 | 0.143 | 0.146 | 0.128 | 0.111 | 0.067 |
| $R^2_{OLS}$ | 0.196 | 0.455 | 0.638 | **0.733** | -0.083 | -0.134 | -0.006 | -0.049 | 0.347 | 0.088 | 0.794 |
| $R^2_{GLS}$ | 0.211 | 0.299 | 0.381 | **0.444** | 0.172 | 0.195 | 0.238 | 0.175 | 0.549 | 0.071 | 0.419 |
| **Panel C: Pricing stocks** | | | | | | | | | | | |
| RMSE | 0.230 | 0.241 | 0.236 | **0.220** | 0.292 | 0.264 | 0.275 | 0.292 | 0.352 | 0.162 | 0.175 |
| MAPE | 0.186 | 0.189 | 0.181 | **0.166** | 0.229 | 0.211 | 0.221 | 0.226 | 0.294 | 0.133 | 0.141 |
| $R^2_{OLS}$ | 0.023 | -0.075 | -0.029 | **0.103** | -0.570 | -0.282 | -0.392 | -0.574 | -1.288 | 0.515 | 0.433 |
| $R^2_{GLS}$ | 0.145 | 0.213 | 0.287 | **0.353** | 0.120 | 0.118 | 0.130 | 0.121 | 0.330 | 0.311 | 0.493 |

Sample: 1986:01 to 2022:12 (T = 444). All data standardized (pricing errors in SR units).

**Table 3: Out-of-sample cross-sectional asset pricing performance**

| | BMA-SDF 20% | BMA-SDF 40% | BMA-SDF 60% | BMA-SDF 80% | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **Panel A: Co-pricing bonds and stocks** | | | | | | | | | | | |
| RMSE | 0.114 | 0.102 | 0.095 | **0.090** | 0.224 | 0.154 | 0.139 | 0.223 | 0.171 | 0.160 | 0.153 |
| MAPE | 0.081 | 0.074 | 0.069 | **0.065** | 0.192 | 0.129 | 0.102 | 0.190 | 0.135 | 0.143 | 0.130 |
| $R^2_{OLS}$ | 0.357 | 0.489 | 0.557 | **0.603** | -1.478 | -0.161 | 0.053 | -1.444 | -0.442 | -0.268 | -0.159 |
| $R^2_{GLS}$ | 0.038 | 0.070 | 0.098 | **0.124** | 0.028 | 0.034 | 0.036 | 0.028 | 0.090 | 0.065 | 0.028 |
| **Panel B: Pricing bonds** | | | | | | | | | | | |
| RMSE | 0.123 | 0.116 | 0.110 | **0.106** | 0.129 | 0.128 | 0.140 | 0.133 | 0.102 | 0.114 | 0.100 |
| MAPE | 0.090 | 0.085 | 0.081 | **0.079** | 0.094 | 0.092 | 0.104 | 0.098 | 0.084 | 0.083 | 0.073 |
| $R^2_{OLS}$ | 0.051 | 0.156 | 0.237 | **0.296** | -0.051 | -0.029 | -0.231 | -0.112 | 0.342 | 0.180 | 0.375 |
| $R^2_{GLS}$ | 0.019 | 0.056 | 0.081 | **0.102** | -0.004 | 0.024 | -0.032 | -0.007 | 0.101 | 0.066 | 0.045 |
| **Panel C: Pricing stocks** | | | | | | | | | | | |
| RMSE | 0.105 | 0.088 | 0.077 | **0.070** | 0.123 | 0.119 | 0.116 | 0.124 | 0.149 | 0.078 | 0.104 |
| MAPE | 0.078 | 0.067 | 0.062 | **0.057** | 0.089 | 0.085 | 0.082 | 0.091 | 0.115 | 0.060 | 0.082 |
| $R^2_{OLS}$ | 0.298 | 0.508 | 0.620 | **0.683** | 0.032 | 0.099 | 0.136 | 0.019 | -0.422 | 0.613 | 0.305 |
| $R^2_{GLS}$ | 0.090 | 0.160 | 0.227 | **0.280** | 0.103 | 0.065 | 0.099 | 0.107 | 0.079 | 0.207 | 0.072 |

OS test assets: 154 bond and stock portfolios (77 each). Models estimated on IS test assets, no re-fitting for OS. Sample: 1986:01 to 2022:12.

**Figure 5: Pricing out-of-sample stocks and bonds with different BMA-SDFs.** Distributions of $R^2_{GLS}$, $R^2_{OLS}$, RMSE and MAPE across 16,383 possible bond and stock cross-sections. Co-pricing BMA dominates in all panels: $R^2_{GLS}$ = 0.22 (vs. Bond BMA = 0.12, Stock BMA = 0.13); $R^2_{OLS}$ = 0.59 (vs. Bond BMA = -0.11, Stock BMA = -0.64); RMSE = 0.089 (vs. 0.144, 0.177); MAPE = 0.065 (vs. 0.119, 0.151). Joint pricing requires information from both factor zoos.

*(Page 21)*

#### 3.1.3. The saliency of factors over time

We now investigate to what extent the relevance of individual factors remains stable over time. We split our sample in half, resulting in two sub-samples with 222 monthly observations each. We first estimate the model for the first subsample spanning July 1986 to June 2004, and then re-estimate it every year, adding twelve new observations at each iteration. Similarly, we estimate backward in time starting with the second subsample from December 2022 to July 2004 and add one year of data at every step.

**Figure 6: Time-varying factor importance.** Heatmaps showing the top five factors over time, ordered by their posterior probabilities. (A) Expanding forward estimation: IVOL, PEAD, PEADB, YSP, INFLC, MOMBS, CREDIT all feature prominently. (B) Expanding backward estimation: IVOL, YSP, CREDIT, PEADB, LVL, PEAD remain stable. Overall, the relevant factors remain remarkably stable.

*(Page 22)*

#### 3.1.4. Which risks?

<!-- @section-type: results
  @key-claim: The SDF is dense in all factor subspaces. Multiple bond and stock factors are noisy proxies for common underlying risks. Both discount rate and cash-flow news contribute to the SDF Sharpe ratio.
  @importance: core
  @data-source: 54 factors decomposed by type
  @depends-on: Section 3.1.1
  @equations: none
-->

**Table 4: BMA-SDF dimensionality and Sharpe ratio decomposition by factor type**

Panel A: Co-pricing BMA-SDF (80% prior SR):
- Nontradable factors: Mean = 6.80, 90% CI = [4, 10], $\mathbb{E}[SR_f|\text{data}]$ = 1.12, share of $SR^2$ = 0.23
- Tradable factors: Mean = 15.51, 90% CI = [10, 21], $\mathbb{E}[SR_f|\text{data}]$ = 2.27, share of $SR^2$ = 0.84
- Tradable bond factors: Mean = 6.32, 90% CI = [3, 10], $\mathbb{E}[SR_f|\text{data}]$ = 1.51, share = 0.39
- Tradable stock factors: Mean = 9.19, 90% CI = [5, 13], $\mathbb{E}[SR_f|\text{data}]$ = 1.77, share = 0.53

Sum of shares across nontradable (0.23), tradable bond (0.39), and tradable stock (0.53) = 1.15, exceeding 100%, indicating substantial commonality among fundamental risks spanned by different factor types.

*(Page 23)*

**Table 5: Discount rate vs. cash-flow news**

Panel A: Co-pricing BMA-SDF, tradable bond and stock factors (80% prior SR):
- Discount rate news: Mean = 8.20, $\mathbb{E}[SR_f|\text{data}]$ = 2.10, share = 0.75
- Cash-flow news: Mean = 7.31, $\mathbb{E}[SR_f|\text{data}]$ = 1.77, share = 0.56

DR news factors marginally dominate the composition of the co-pricing BMA-SDF. The two most likely tradable components (PEAD and PEADB) are primarily driven by DR news.

*(Page 24)*

### 3.2. Trading the BMA-SDF

<!-- @section-type: results
  @key-claim: The BMA-SDF tradable portfolio achieves an out-of-sample annualized Sharpe ratio of 1.5-1.8, strongly outperforming all benchmarks including the equally-weighted portfolio.
  @importance: core
  @data-source: 40 tradable factors
  @depends-on: Sections 2, 3.1
  @equations: none
-->

Portfolio weights for the tradable strategies are constructed by normalizing the posterior means of the MPRs of the SDF representations to sum to one in each specification. Since all benchmark models are exclusively based on tradable factors, we constrain the BMA-SDF to use only such factors.

**Figure 7: Out-of-sample investing in the BMA-SDF tradable portfolio and benchmark models.** Cumulative return of $1 invested (2004:07 to 2023:08). BMA-80% reaches $174, RPPCA $71, KNS $43, EW $24, MKTS and MKTB around $5 each. The outperformance is extremely stable out-of-sample and not just driven by a few lucky events.

*(Page 25)*

**Table 6: Trading the BMA-SDF and benchmark models**

| | BMA 20% | BMA 40% | BMA 60% | BMA 80% | TOP $\gamma$ | TOP $\lambda$ | KNS | RPPCA | FF5 | HKM | MKTB | MKTS | EW |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| **Panel A: In-sample (T = 444)** | | | | | | | | | | | | | |
| Mean (%) | 31.38 | 38.94 | 43.43 | **45.03** | 33.77 | 34.04 | 40.54 | 39.59 | 12.20 | 8.37 | 10.18 | 8.29 | 19.42 |
| SR | 1.99 | 2.46 | 2.75 | **2.85** | 2.14 | 2.15 | 2.57 | 2.51 | 0.77 | 0.53 | 0.64 | 0.52 | 1.23 |
| Skew | 0.76 | 0.73 | 0.54 | 0.31 | 0.47 | 0.44 | 0.51 | 0.90 | -0.70 | -0.65 | -0.71 | -0.78 | -0.29 |
| Kurt | 3.55 | 3.08 | 2.47 | 2.00 | 2.53 | 2.54 | 2.98 | 3.07 | 3.41 | 1.91 | 4.68 | 2.22 | 4.63 |
| **Panel B: Out-of-sample (T = 222)** | | | | | | | | | | | | | |
| Mean (%) | 22.72 | 25.73 | 27.17 | **27.90** | 20.59 | 23.41 | 20.36 | 23.01 | 5.90 | 7.12 | 8.22 | 8.71 | 17.15 |
| SR | 1.46 | 1.65 | 1.74 | **1.79** | 1.32 | 1.50 | 1.31 | 1.48 | 0.38 | 0.46 | 0.53 | 0.56 | 1.10 |
| IR | 0.98 | 1.24 | 1.38 | **1.46** | 1.40 | 1.37 | 0.85 | 1.07 | -0.27 | -0.26 | -0.04 | -0.21 | -- |
| Skew | 0.30 | 0.04 | -0.10 | -0.13 | -0.62 | 0.17 | -1.19 | -0.60 | -1.59 | -0.37 | -0.93 | -0.54 | -1.06 |
| Kurt | 2.39 | 3.59 | 4.06 | 3.77 | 5.77 | 2.38 | 11.97 | 7.74 | 10.60 | 1.51 | 5.42 | 1.28 | 7.22 |

OS period: 2004:07 to 2022:12. Expanding window, yearly rebalancing. The BMA-SDF (80%) achieves SR = 1.79 OS, convincingly beating the EW portfolio (SR = 1.10) which is known to be exceedingly difficult to beat.

*(Page 25-27)*

### 3.3. The information content of the two factor zoos

<!-- @section-type: results
  @key-claim: Once corporate bond returns are adjusted for duration, equity and nontradable factors alone suffice for co-pricing; the bond factor zoo becomes largely redundant.
  @importance: core
  @data-source: Duration-matched Treasury portfolios, BAML/ICE bonds
  @depends-on: Sections 1, 3.1
  @equations: 10
-->

As shown in Section 3.1.2 (see Tables 2 and 3), although one can construct well-performing BMA-SDFs to price bonds and stocks separately using the information in their respective zoos, the joint pricing of these assets requires information from both sets of factors (see Figure 5). In this section, we demonstrate that this result arises from the fact that corporate bond returns reflect not only a component related to compensation for exposure to credit risk, but also a Treasury term structure risk premium that is not captured by equity-based factors.

To illustrate this point, we now turn our focus to bond returns in excess of duration-matched portfolios of U.S. Treasuries. More precisely, for every bond $i$, we construct the following duration-adjusted return

$$\underbrace{R_{\text{bond } i,t} - R^{\text{Treasury}}_{\text{dur bond } i,t}}_{\text{Duration-adjusted return}} \equiv \underbrace{R_{\text{bond } i,t} - R_{f,t}}_{\text{Excess return}} - \underbrace{\left(R^{\text{Treasury}}_{\text{dur bond } i,t} - R_{f,t}\right)}_{\text{Treasury component}}, \tag{10}$$

where $R_{\text{bond } i,t}$ is the return of bond $i$ at time $t$, $R_{f,t}$ denotes the short-term risk-free rate, and $R^{\text{Treasury}}_{\text{dur bond } i,t}$ denotes the return on a portfolio of Treasury securities with the same duration as bond $i$ (constructed as in van Binsbergen et al. (2025)).

**Figure 8: Pricing the joint cross-section of stock and duration-adjusted bond returns.** Once bond returns are adjusted for duration, the BMA-SDF based solely on equity information prices jointly bonds and stocks as effectively as the co-pricing BMA-SDF. Co-pricing BMA: $R^2_{GLS}$ = 0.18, $R^2_{OLS}$ = 0.52, RMSE = 0.121, MAPE = 0.101. Stock BMA: $R^2_{GLS}$ = 0.15, $R^2_{OLS}$ = 0.67, RMSE = 0.099, MAPE = 0.077. Bond BMA: $R^2_{GLS}$ = 0.02, $R^2_{OLS}$ = -0.76, RMSE = 0.233, MAPE = 0.209. The Stock BMA actually achieves lower RMSE and MAPE than the Co-pricing BMA for duration-adjusted returns. The information content of the bond factor zoo becomes largely irrelevant for co-pricing once the Treasury component of bond returns is removed.

**Figure 9: Pricing the Treasury component of corporate bond returns.** (A) IS with bond factors: Constrained $R^2$ = 97%, fitted slope = 1.13. (B) OS with bond factors: Constrained $R^2$ = 92%, fitted slope = 1.37. (C) IS with stock factors: Constrained $R^2$ = 6%, fitted slope = 20.75. (D) OS with stock factors: Constrained $R^2$ = 6%, fitted slope = 26.27. Bond factors price the Treasury component nearly perfectly; stock factors cannot.

The above highlights that the bond factor zoo is necessary for co-pricing bonds and stocks because the factors proposed in the corporate bond literature price well the Treasury component implicit in corporate bond returns -- a component that stock factors fail to price. However, once this component is accounted for -- as in the case of duration-adjusted bond returns -- co-pricing can effectively be achieved using only equity information.

Moreover, the Treasury component of corporate bonds is also economically important. The ex post (annualized) maximum Sharpe ratio of the duration-matched Treasury portfolios in equation (10) is approximately 1.48.

*(Page 29-30)*

### 3.4. The economic properties of the co-pricing SDF

<!-- @section-type: results
  @key-claim: The BMA-SDF and its conditional volatility exhibit clear business cycle patterns, are persistent, and predict future asset returns.
  @importance: core
  @data-source: BMA-SDF posterior mean time series
  @depends-on: Section 3.1
  @equations: none
-->

**Figure 10: The co-pricing BMA-SDF and its conditional mean.** The SDF and its conditional mean (ARMA(3,1)) exhibit clear business cycle behavior: they increase during expansions and tend to peak right before recessions, being substantially reduced during economic contractions. The BMA-SDF is highly predictable: virtually all autocorrelation coefficients are statistically significant at the 1% level up to 20 months ahead, and about one-fifth of its time series variance is explained by its own lags (23% for best AR, 19% for best ARMA). No other SDF model comes close to this level of business cycle variation and persistency.

**Figure 11: Conditional SDF Volatilities.** The figure plots annualized volatility of the co-pricing BMA-SDF (ARMA(3,1)-GARCH(1,1)) along with FF5 and CAPMB SDFs. GARCH coefficient estimates:

$$\sigma^2_{t+1} = \omega + \alpha \epsilon^2_t + \beta \sigma^2_t$$

| | $\omega$ | $\alpha$ | $\beta$ |
|---|---|---|---|
| Estimate | 0.01 | 0.15 | 0.81 |
| Robust SE | 0.00 | 0.04 | 0.06 |

The implied conditional Sharpe ratio is highly countercyclical with pronounced spikes during: Black Monday, WTC/9-11, Asian financial crisis, dot-com bubble, Iraq invasion, Bear Stearns, Lehman Brothers collapse, Greek default, COVID pandemic, Ukraine invasion (10 labeled events in the figure). Half-life of volatility shocks: 16.6 months (vs. 4.2 months for FF5, 3 months for CAPMB).

*(Page 32)*

**Figure 12: Predictability of tradable factors with lagged SDF information.** (A) Monthly horizon: median $R^2$ = 1.71%. Statistically significant at 5% in 62% of cases and at 10% in 75% of cases. (B) Twelve-month horizon: median $R^2$ = 9.71%. Significant at 5% in 45% of cases, at 10% in 57%. The amount of predictability is economically large: for statistically significant cases it ranges from 1.1% to 6% monthly and the median annual $R^2$ is about 10%, with many factors having more than one-fifth of their time series variation being predictable.

---

*(Page 33)*

<!-- @section-type: robustness
  @key-claim: Results are robust to factor tilting, imposed sparsity, removal of most likely factors, varying corporate bond data, varying cross-sections, and different factor zoos and sample periods.
  @importance: supporting
  @data-source: Multiple corporate bond datasets (LBFI/BAML, TRACE), Jensen et al. (2023), Dick-Nielsen et al. (2025)
  @depends-on: Sections 2, 3
  @equations: none
-->

## 4. Robustness

In this section, we discuss an extensive array of robustness exercises that all confirm our main findings.

### 4.1. Factor tilting

Our novel spike-and-slab prior in Section 2.3 allows us to assign a heterogeneous degree of prior shrinkage to the different types of factors by setting the hyper-parameter $\kappa$ to values different from zero. Consider $\kappa \in \{-0.5, 0.5\}$. Setting $\kappa = 0.5$ for bond factors implies the belief that, ceteris paribus, they explain a share of the squared Sharpe ratio of the SDF that is $\frac{1+\kappa}{1-\kappa} = 3$ times as large as the share of stock factors.

Remarkably, the factors identified as more likely in Section 3.1.1 still have posterior probabilities above the prior value in 9 out of 10 cases. The effect of the prior tilting on pricing performance is quite small but unambiguous in direction: as we tilt toward *either* type of factor, the out-of-sample pricing ability deteriorates. This strengthens the results in Section 3.3: for the co-pricing of bond and stock excess returns, we need information from both factor zoos.

When bond returns are duration-adjusted, tilting the prior *away from* bond factors improves OS pricing, and an extreme tilt in favor of stock factors maximizes pricing ability. This reinforces the finding that bond factors are largely redundant for co-pricing once the Treasury component is accounted for.

*(Page 34)*

### 4.2. Imposing sparsity

We set $a_\omega \approx 3.54$ and $b_\omega \approx 34.66$ to achieve: (i) the prior expectation of included factors yields the canonical five-factor model, and (ii) the prior two standard deviation credible interval encompasses models with zero to ten factors. Three key findings emerge: (1) the factors with posterior probabilities exceeding the prior value are essentially identical to baseline; (2) BMA-SDF pricing performance under sparsity remains superior to alternatives, particularly OS; (3) imposing sparsity degrades performance compared to the baseline dense BMA-SDF, as expected since the data strongly support a dense SDF.

### 4.3. Estimation excluding the most likely factors

We remove three different factor sets: (i) top five by posterior probability; (ii) top five by posterior MPR; (iii) the union of (i) and (ii). The BMA-SDF constructed with this limited information set still strongly outperforms canonical models both IS and OS. Performance is achieved by increasing the posterior weights of several noisy proxies -- precisely what the theoretical and simulation results in Section 2.4 predict. Some minor deterioration is observed, with OS $R^2$ measures dropping by only 8% in the worst case.

*(Page 35-36)*

### 4.4. Estimation uncertainty

#### 4.4.1. Varying corporate bond data

Pricing performance compared across five different corporate bond datasets: (i) baseline LBFI/BAML ICE bond-level, (ii) LBFI/BAML ICE firm-level, (iii) quotes-only LBFI/BAML ICE, (iv) WRDS TRACE, (v) DFPS TRACE. Results are very consistent: on average, eight out of the ten most likely factors (including the top five) match the baseline results.

#### 4.4.2. Varying cross-sections

BMA-SDF re-estimated for hundreds of alternative sets of test assets across bonds and stocks using 153 long-short equity anomalies from Jensen et al. (2023) and corporate bond counterparts from Dick-Nielsen et al. (2025). IVOL, PEADB, and PEAD still emerge as the most probable factors. OS performance evaluated across millions of potential cross-sections confirms BMA-SDF dominance.

#### 4.4.3. Varying factor zoos and sample periods

Robustness checks include: (1) expanded stock factor zoo (51 factors from Bryzgalova et al. (2023), shorter sample to 2016); (2) extended bond factor zoo (29 factors with Dick-Nielsen et al. (2025) composites); (3) TRACE-era only (2002+) with Bai et al. (2019) liquidity factor; (4) pre-TRACE period; (5) extended sample starting 1977 (549 observations). Results are remarkably robust across all specifications.

---

*(Page 36)*

<!-- @section-type: conclusion
  @key-claim: The true latent SDF is dense, behavioral factors (PEAD) are most likely components, and the BMA-SDF outperforms all low-dimensional models.
  @importance: core
  @data-source: none
  @depends-on: Sections 1-4
  @equations: none
-->

## 5. Conclusion

We generalize the Bayesian estimation method of Bryzgalova et al. (2023) to handle multiple asset classes, developing a novel understanding of factor posterior probabilities and model averaging in asset pricing, and we apply it to the study of over 18 quadrillion linear factor models for the joint pricing of corporate bond and stock returns.

Strikingly, decomposing bond excess returns into their credit and Treasury components reveals that nontradable and tradable *stock* factors are largely *sufficient* for pricing the credit component, making the bond factor literature effectively redundant for this purpose. Conversely, tradable *bond* factors (along with nontradable ones) remain necessary for pricing the Treasury component -- a risk that stock factors do not seem to capture.

Overall, we find that the true latent SDF is *dense* in the space of observable nontradable and tradable bond and stock factors. Importantly, this implies that *all* low dimensional observable factor models proposed to date are affected by severe misspecification and rejected by the data.

Individually, only very few factors should be included in the SDF with high probability. Most notably, two tradable behavioral factors capturing the post-earnings announcement drift in bonds and stocks exhibit posterior probabilities above their prior value, along with nontradable factors such as the slope of the Treasury yield curve, the AAA/BAA yield spread, and the idiosyncratic equity volatility. However, these factors capture only a fraction of the risks priced in the joint cross-section of bonds and stocks, and literally dozens of other factors, both tradable and nontradable, are necessary -- jointly -- to span the risks driving asset prices. Nevertheless, the SDF-implied maximum Sharpe ratio is not extreme because the many factors necessary for an accurate characterization of the latent SDF are multiple noisy proxies for common underlying sources of risk.


<!-- @section-type: conclusion
  @key-claim: BMA-SDF aggregates diffuse pricing information optimally and outperforms all existing models in explaining the cross-section of corporate bond and stock returns
  @importance: core
  @data-source: 83 bond and stock portfolios, 40 tradable factors, 1986:01-2022:12
  @depends-on: methodology, results
  @equations: none
-->

*(Page 37)*

A Bayesian Model Averaging over the space of all possible Stochastic Discount Factor models aggregates this diffuse pricing information optimally and outperforms all existing models in explaining -- jointly and individually -- the cross-section of corporate bond and stock returns, both in- and out-of-sample. Furthermore, leveraging the fact that the Bayesian averaging over the space of models is equivalent to an averaging over the space of factors, we show that the BMA-SDF yields a *tradable* strategy with a time-series *out-of-sample* Sharpe ratio of 1.5 to 1.8, with only yearly rebalancing, in the challenging evaluation period spanning July 2004 to December 2022.

The BMA-SDF exhibits a distinctive business cycle behavior, and persistent and cyclical first and second moments. Furthermore, its volatility increases sharply during recessions and at times of heightened economic uncertainty, suggesting time variation in conditional risk premia. And indeed, we find that lagged BMA-SDF information is a strong and significant predictor of future asset returns.

---

## Appendix A. The factor zoo list

<!-- @section-type: table
  @key-claim: 54 bond, stock and nontradable factors are considered for cross-sectional asset pricing
  @importance: supporting
  @data-source: Open Source Bond Asset Pricing, Kenneth French website, AQR data library, and others
  @depends-on: methodology
  @equations: none
-->

We list all 54 bond, stock and nontradable factors we consider in Table A.1 along with a detailed description of their construction, associated reference, and data source.

**Table A.1:** List of factors for cross-sectional asset pricing.

**Panel A: Tradable corporate bond factors**

| Factor ID | Factor name and description | Reference | Source |
|---|---|---|---|
| CRF | Credit risk factor. Equally-weighted average return on two 'credit portfolios': CRF_VaR, and CRF_REV. CRF_VaR is the average return difference between the lowest-rating (i.e., highest credit risk) portfolio and the highest-rating (i.e., lowest credit risk) portfolio across the VaR95 portfolios. CRF_REV is the average return difference between the lowest-rating portfolio and the highest-rating portfolio across quintiles sorted on bond short-term reversal. | Bai et al. (2019) | Open Source Bond Asset Pricing |
| CRY | Bond carry factor. Independent sort (5 x 5) to form 25 portfolios according to ratings and bond credit spreads (CS). For each rating quintile, calculate the weighted average return difference between the highest CS quintile and the lowest CS quintile. CRY is computed as the average long-short portfolio return across all rating quintiles. | Hottinga et al. (2001), Houweling and Van Zundert (2017) | Open Source Bond Asset Pricing |
| DEF | Bond default risk factor. The difference between the return on the market portfolio of long-term corporate bond returns (the Composite portfolio on the corporate bond module of Ibbotson Associates) and the long-term government bond return. | Fama and French (1992) and Gebhardt et al. (2005a). | Amit Goyal website |
| DRF | Downside risk factor. Independent sort (5 x 5) to form 25 portfolios according to ratings and 95% value-at-risk (VaR95). For each rating quintile, calculate the weighted average return difference between the highest VaR5 quintile and the lowest VaR5 quintile. DRF is computed as the average long-short portfolio return across all rating quintiles. | Bai et al. (2019) | Open Source Bond Asset Pricing |
| DUR | Bond duration factor. Independent sort (5 x 5) to form 25 portfolios according to ratings and bond duration (DUR^B). For each rating quintile, calculate the weighted average return difference between the highest DUR^B quintile and the lowest DUR^B quintile. DUR is computed as the average long-short portfolio return across all rating quintiles. | Gebhardt et al. (2005a) and Dang et al. (2023). | Open Source Bond Asset Pricing |
| HMLB | Bond book-to-market factor. Independent sort (2 x 3) to form 6 portfolios according to bond size and bond book-to-market (BBM), defined as bond principal value scaled by market value. For each size portfolio, calculate the weighted average return difference between the lowest BBM tercile and the highest BBM tercile. HMLB is computed as the average long-short portfolio return across the two size portfolios. | Bartram et al. (2025) | Open Source Bond Asset Pricing |
| LTREVB | Bond long-term reversal factor. Dependent sort (3 x 3 x 3) to form 27 portfolios according to ratings, maturity, and the 48-13 cumulative previous bond return (LTREV^B). For each rating quintile, the factor is computed as the average return differential between the portfolio with the lowest LTREV^B and the one with the highest LTREV^B within the rating and maturity portfolios. LTREVB is computed as the average long-short portfolio return across the nine rating-maturity terciles. | Bali et al. (2021a) | Open Source Bond Asset Pricing |
| MKTB | Corporate Bond Market excess return. Constructed using bond returns in excess of the one-month risk-free rate of return. | Dickerson et al. (2023) | Open Source Bond Asset Pricing |
| MKTBD | Corporate Bond Market duration-adjusted return. Constructed using bond returns in excess of their duration-matched U.S. Treasury bond rate of return. | van Binsbergen et al. (2025) | Open Source Bond Asset Pricing |
| MOMB | Bond momentum factor formed with bond momentum. Independent sort (5 x 5) to form 25 portfolios according to ratings and the 12-2 cumulative previous bond return (MOM). For each rating quintile, calculate the weighted average return difference between the highest MOM quintile and the lowest MOM quintile. MOMB is computed as the average long-short portfolio return across all rating quintiles. | Gebhardt et al. (2005b) | Open Source Bond Asset Pricing |

*(Page 38)*

| Factor ID | Factor name and description | Reference | Source |
|---|---|---|---|
| MOMBS | Bond momentum factor formed with equity momentum. Independent sort (5 x 5) to form 25 portfolios according to ratings and the 6-1 cumulative previous equity return (MOMs). For each rating quintile, calculate the weighted average return difference between the highest MOMs quintile and the lowest MOMs quintile. MOMBS is computed as the average long-short portfolio return across all rating quintiles. | Hottinga et al. (2001), Gebhardt et al. (2005b) and Dang et al. (2023) | Open Source Bond Asset Pricing |
| PEADB | Bond earnings announcement drift factor. Independent sort (2 x 3) to form 6 portfolios according to market equity and earnings surprises (CAR), computed according to Chan et al. (1996). For each firm size portfolio, calculate the weighted average return difference between the highest CAR terciles and the lowest CAR tercile. PEADB is computed as the average long-short portfolio return across the two firm size portfolios. | Nozawa et al. (2025) | Open Source Bond Asset Pricing |
| STREVB | Bond short-term reversal factor. Independent sort (5 x 5) to form 25 portfolios according to ratings and the prior month's bond return (REV). For each rating quintile, calculate the weighted average return difference between the lowest REV quintile and the highest REV quintile. STREVB is computed as the average long-short portfolio return across all rating quintiles. | Khang and King (2004) and Bali et al. (2021a) | Open Source Bond Asset Pricing |
| SZE | Bond size factor. Dependent sort (3 x 3) to form 3 portfolios according to ratings and then with each rating tercile another 3 portfolios on bond size (SIZE). Bond size is defined as bond price multiplied by issue size (amount outstanding). For each rating tercile, calculate the weighted average return difference between the lowest SIZE tercile and the highest SIZE tercile. SZE is computed as the average long-short portfolio return across all rating terciles. | Hottinga et al. (2001) and Houweling and Van Zundert (2017) | Open Source Bond Asset Pricing |
| TERM | Bond term structure risk factor. The difference between the monthly long-term government bond return and the one-month T-Bill rate of return. | Fama and French (1992) and Gebhardt et al. (2005a). | Amit Goyal website |
| VAL | Bond value factor. Independent sort (2 x 3) to form 6 portfolios according to bond size and bond value (VAL^B). VAL^B is computed via cross-sectional regressions of credit spreads on ratings, maturity, and the 3-month change in credit spread. The percentage difference between the actual credit spread and the fitted ('fair') credit spread for each bond is the VAL^B characteristic. For each size portfolio, calculate the weighted average return difference between the highest VAL^B tercile and the lowest VAL^B tercile. VAL is computed as the average long-short portfolio return across the two size portfolios. | Correia et al. (2012) and Houweling and Van Zundert (2017) | Open Source Bond Asset Pricing |

**Panel B: Tradable stock factors**

| Factor ID | Factor name and description | Reference | Source |
|---|---|---|---|
| BAB | Betting-against-beta factor, constructed as a portfolio that holds low-beta assets, leveraged to a beta of 1, and that shorts high-beta assets, de-leveraged to a beta of 1. | Frazzini and Pedersen (2014) | AQR data library |
| CMA | Investment factor, constructed as a long-short portfolio of stocks sorted by their investment activity. | Fama and French (2015) | Kenneth French website |
| CMAs | CMA with a hedged unpriced component. | Daniel et al. (2020b) | Kent Daniel website |
| CPTLT | The value-weighted equity return for the New York Fed's primary dealer sector not including new equity issuance. | He et al. (2017) | Zhiguo He website |
| FIN | Long-term behavioral factor, predominantly capturing the impact of share issuance and correction. | Daniel et al. (2020a) | Kent Daniel website |
| HML | Value factor, constructed as a long-short portfolio of stocks sorted by their book-to-market ratio. | Fama and French (1992) | Kenneth French website |
| HML_DEV | A version of the HML factor that relies on the current price level to sort the stocks into long and short legs. | Asness and Frazzini (2013) | AQR data library |
| HMLs | HML with a hedged unpriced component. | Daniel et al. (2020b) | Kent Daniel website |
| LIQ | Liquidity factor, constructed as a long-short portfolio of stocks sorted by their exposure to LIQ_NT. | Pastor and Stambaugh (2003) | Robert Stambaugh website |
| LTREV | Long-term reversal factor, constructed as a long-short portfolio of stocks sorted by their cumulative return accrued in the previous 60-13 months. | Jegadeesh and Titman (2001) | Kenneth French website |
| MGMT | Management performance mispricing factor. | Stambaugh and Yuan (2017) | Global factor data website |
| MKTS | Market excess return. | Sharpe (1964) and Lintner (1965) | Kenneth French website |
| MKTSs | Market factor with a hedged unpriced component. | Daniel et al. (2020b) | Kent Daniel website |
| MOMS | Momentum factor, constructed as a long-short portfolio of stocks sorted by their 12-2 months cumulative previous return. | Carhart (1997), Jegadeesh and Titman (1993) | Kenneth French website |
| PEAD | Short-term behavioral factor, reflecting post-earnings announcement drift. | Daniel et al. (2020a) | Kent Daniel website |
| PERF | Firm performance mispricing factor. | Stambaugh and Yuan (2017) | Global factor data website |
| QMJ | Quality-minus-junk factor, constructed as a long-short portfolio of stocks sorted by the combination of their safety, profitability, growth, and the quality of management practices. | Asness et al. (2019) | AQR data library |
| RMW | Profitability factor, constructed as a long-short portfolio of stocks sorted by their profitability. | Fama and French (2015) | Kenneth French website |
| RMWs | RMW with a hedged unpriced component. | Daniel et al. (2020b) | Kent Daniel website |
| R_IA | Investment factor, constructed as a long-short portfolio of stocks sorted by their investment-to-capital. | Hou et al. (2015) | Lu Zhang website |
| R_ROE | Profitability factor, constructed as a long-short portfolio of stocks sorted by their return on equity. | Hou et al. (2015) | Lu Zhang website |

*(Page 39)*

| Factor ID | Factor name and description | Reference | Source |
|---|---|---|---|
| SMB | Size factor, constructed as a long-short portfolio of stocks sorted by their market cap. | Fama and French (1992) | Kenneth French website |
| SMBs | SMB with a hedged unpriced component. | Daniel et al. (2020b) | Kent Daniel website |
| STREV | Short-term reversal factor, constructed as a long-short portfolio of stocks sorted by their previous month return. | Jegadeesh and Titman (1993) | Kenneth French website |

**Panel C: Nontradable corporate bond and stock factors**

| Factor ID | Factor name and description | Reference | Source |
|---|---|---|---|
| CPTL | Intermediary capital nontradable risk factor. Constructed using AR(1) innovations to the market-based capital ratio of primary dealers, scaled by the lagged capital ratio. | He et al. (2017) | Zhiguo He website |
| CREDIT | Bond credit risk factor. Difference between the yields of BAA and AAA indices from Moody's. Also computed with own data as the difference between the average yield of BAA and (AAA+AA) rated bonds. See Internet Appendix IA.11 for further computational details. | Fama and French (1993) | Amit Goyal website or FRED for AAA and BAA indices. |
| EPU | Economic Policy Uncertainty. First difference in the economic policy uncertainty index. | Baker et al. (2016) and Dang et al. (2023) | FRED |
| EPUT | Economic Tax Policy Uncertainty. First difference in the economic tax policy uncertainty index. | Baker et al. (2016) and Dang et al. (2023) | FRED |
| INFLC | Shocks to core inflation. Unexpected core inflation component captured by an ARMA(1,1) model. Monthly core inflation is calculated as the percentage change in the seasonally adjusted Consumer Price Index for All Urban Consumers: All Items Less Food and Energy which is lagged by one-month to account for the inflation data release lag. | Fang et al. (2024) | FRED |
| INFLV | Inflation volatility. Computed as the 6-month volatility of the unexpected inflation component captured by an ARMA(1,1) model. Monthly inflation is calculated as the percentage change in the seasonally adjusted Consumer Price Index for All Urban Consumers (CPI) which is lagged by one-month to account for the inflation data release lag. | Kang and Pflueger (2015) and Ceballos (2023) | FRED |
| IVOL | Idiosyncratic equity volatility factor. Cross-sectional volatility of all firms in the CRSP database in each month t. | Campbell and Taksler (2003) | CRSP |
| LVL | Level term structure factor. Constructed as the first principal component of the one- through 30-year CRSP Fixed Term Indices U.S. Treasury Bond yields. | Koijen et al. (2017) | CRSP Indices |
| LIQNT | Liquidity factor, computed as the average of individual-stock measures estimated with daily data (residual predictability, controlling for the market factor) | Pastor and Stambaugh (2003) | Robert Stambaugh website |
| UNC | First difference in the Macroeconomic uncertainty index. | Ludvigson et al. (2015) and Bali et al. (2021b) | Sydney Ludvigson website |
| UNCf | First difference in the Financial economic uncertainty index. | Ludvigson et al. (2015) | Sydney Ludvigson website |
| UNCr | First difference in the Real economic uncertainty index. | Ludvigson et al. (2015) | Sydney Ludvigson website |
| VIX | First difference in the CBOE VIX. | Chung et al. (2019) | FRED |
| YSP | Slope term structure factor. Constructed as the difference in the five and one-year U.S. Treasury Bond yields. | Koijen et al. (2017) | CRSP Indices |

*The table lists all tradable bond, stock as well as the nontradable factors used in the main paper. For each of the factors, we present their identification index (Factor ID), a description of the factor construction, and the source of the data for downloading and/or constructing the factor time series.*

---

## Appendix B. Posterior sampling

<!-- @section-type: proof
  @key-claim: Posterior distributions follow canonical Normal-inverse-Wishart in the time series layer and Normal/Beta/inverse-Gamma in the cross-sectional layer; sampling via Gibbs sampler
  @importance: supporting
  @data-source: none (theoretical)
  @depends-on: methodology (Section 2)
  @equations: A.1, A.2, A.3, A.4, A.5, A.6
-->

The posterior of the time series parameters follows the canonical Normal-inverse-Wishart distribution (see, e.g., Bauwens, Lubrano and Richard (1999)) given by

$$\boldsymbol{\mu}_Y | \boldsymbol{\Sigma}_Y, \mathbf{Y} \sim \mathcal{N}(\hat{\boldsymbol{\mu}}_Y, \; \boldsymbol{\Sigma}_Y / T), \tag{A.1}$$

$$\boldsymbol{\Sigma}_Y | \mathbf{Y} \sim \mathcal{W}^{-1}\left(T - 1, \; \sum_{t=1}^{T} (\mathbf{Y}_t - \widehat{\boldsymbol{\mu}}_Y)(\mathbf{Y}_t - \widehat{\boldsymbol{\mu}}_Y)^\top \right), \tag{A.2}$$

where $\hat{\boldsymbol{\mu}}_Y \equiv \frac{1}{T}\sum_{t=1}^{T} \mathbf{Y}_t$, $\mathcal{W}^{-1}$ is the inverse-Wishart distribution, $\mathbf{Y} \equiv \{\mathbf{Y}_t\}_{t=1}^{T}$, and note that the covariance matrix of factors and test assets, $\mathbf{C}_f$, is contained within $\boldsymbol{\Sigma}_Y$.

Define $\mathbf{D} = \tilde{\mathbf{D}} \times \boldsymbol{\kappa}$ where $\tilde{\mathbf{D}}$ is a diagonal matrix with elements $c, (r(\gamma_1)\psi_1)^{-1}, \ldots, (r(\gamma_K)\psi_K)^{-1}$ and $\boldsymbol{\kappa}$ is a conformable column vector with elements $1, 1+\kappa_1, \ldots, 1+\kappa_K$ such that $\sum_{k=1}^{K} \kappa_j = 0$ and $0 < |\kappa_j| < 1 \; \forall \; j$. It then follows that, given our prior formulations, the posterior distributions of the parameters in the cross-sectional layer $(\boldsymbol{\lambda}, \boldsymbol{\gamma}, \boldsymbol{\omega}, \sigma^2)$, conditional on the draws of $\boldsymbol{\mu}_R$, $\boldsymbol{\Sigma}_R$, and $\mathbf{C}$ from the time series layer, are:

$$\boldsymbol{\lambda} | \text{data}, \sigma^2, \boldsymbol{\gamma}, \boldsymbol{\omega} \sim \mathcal{N}(\hat{\boldsymbol{\lambda}}, \hat{\sigma}^2(\hat{\boldsymbol{\lambda}})), \tag{A.3}$$

$$\frac{p(\gamma_j = 1 | \text{data}, \boldsymbol{\lambda}, \boldsymbol{\omega}, \sigma^2, \boldsymbol{\gamma}_{-j})}{p(\gamma_j = 0 | \text{data}, \boldsymbol{\lambda}, \boldsymbol{\omega}, \sigma^2, \boldsymbol{\gamma}_{-j})} = \frac{\omega_j}{1 - \omega_j} \frac{p(\lambda_j | \gamma_j = 1, \sigma^2)}{p(\lambda_j | \gamma_j = 0, \sigma^2)}, \tag{A.4}$$

$$\omega_j | \text{data}, \boldsymbol{\lambda}, \boldsymbol{\gamma}, \sigma^2 \sim \text{Beta}(\gamma_j + a_\omega, 1 - \gamma_j + b_\omega), \tag{A.5}$$

*(Page 40)*

$$\sigma^2 | \text{data}, \boldsymbol{\omega}, \boldsymbol{\lambda}, \boldsymbol{\gamma} \sim \mathcal{IG}\left(\frac{N + K + 1}{2}, \frac{(\boldsymbol{\mu}_R - \mathbf{C}\boldsymbol{\lambda})^\top \boldsymbol{\Sigma}_R^{-1}(\boldsymbol{\mu}_R - \mathbf{C}\boldsymbol{\lambda}) + \boldsymbol{\lambda}^\top \mathbf{D}\boldsymbol{\lambda}}{2}\right), \tag{A.6}$$

where $\hat{\boldsymbol{\lambda}} = (\mathbf{C}^\top \boldsymbol{\Sigma}_R^{-1} \mathbf{C} + \mathbf{D})^{-1} \mathbf{C}^\top \boldsymbol{\Sigma}_R^{-1} \boldsymbol{\mu}_R$, $\hat{\sigma}^2(\hat{\boldsymbol{\lambda}}) = \sigma^2 (\mathbf{C}^\top \boldsymbol{\Sigma}_R^{-1} \mathbf{C} + \mathbf{D})^{-1}$ and $\mathcal{IG}$ denotes the inverse-Gamma distribution.

Hence, posterior sampling is achieved with a Gibbs sampler that draws sequentially the time series layer parameters ($\boldsymbol{\mu}_R$, $\boldsymbol{\Sigma}_R$, and $\mathbf{C}$) from equations (A.1) and (A.2), and then, conditional on these realizations, draws sequentially from equations (A.3) to (A.6).

---

## Appendix C. Probabilities and risk prices across prior Sharpe ratios

<!-- @section-type: table
  @key-claim: Full posterior probabilities and risk premia for all 54 factors across four prior Sharpe ratio levels
  @importance: supporting
  @data-source: 83 bond and stock portfolios, 40 tradable factors, 1986:01-2022:12 (T=444)
  @depends-on: methodology, Appendix B
  @equations: none
-->

We report the full list of posterior probabilities and the associated annualized risk premia (in Sharpe ratio units) which complements the results from Figure 2 in Table A.2.

**Table A.2:** Posterior factor probabilities and risk prices for the co-pricing factor zoo

| | Factor prob., E[gamma_j\|data] | | | | Price of risk, E[lambda_j\|data] | | | |
|---|---|---|---|---|---|---|---|---|
| **Factors** | **20%** | **40%** | **60%** | **80%** | **20%** | **40%** | **60%** | **80%** |
| PEADB | 0.555 | 0.629 | 0.713 | 0.711 | 0.054 | 0.213 | 0.446 | 0.645 |
| PEAD | 0.523 | 0.559 | 0.618 | 0.614 | 0.035 | 0.138 | 0.297 | 0.449 |
| IVOL | 0.502 | 0.529 | 0.567 | 0.623 | 0.010 | 0.043 | 0.108 | 0.265 |
| CREDIT | 0.498 | 0.497 | 0.530 | 0.557 | 0.008 | 0.033 | 0.084 | 0.191 |
| YSP | 0.507 | 0.502 | 0.504 | 0.519 | 0.003 | 0.014 | 0.034 | 0.088 |
| MOMBS | 0.492 | 0.518 | 0.543 | 0.476 | 0.059 | 0.200 | 0.366 | 0.432 |
| INFLV | 0.509 | 0.514 | 0.511 | 0.484 | 0.002 | 0.007 | 0.014 | 0.022 |
| INFLC | 0.500 | 0.501 | 0.494 | 0.492 | -0.001 | -0.004 | -0.011 | -0.028 |
| CMAs | 0.489 | 0.500 | 0.502 | 0.480 | 0.015 | 0.061 | 0.131 | 0.215 |
| LVL | 0.495 | 0.493 | 0.491 | 0.493 | 0.000 | 0.002 | 0.006 | 0.019 |
| EPU | 0.509 | 0.503 | 0.498 | 0.457 | 0.001 | 0.004 | 0.008 | 0.009 |
| UNCr | 0.494 | 0.490 | 0.499 | 0.480 | 0.001 | 0.004 | 0.012 | 0.032 |
| MKTS | 0.496 | 0.510 | 0.494 | 0.458 | 0.055 | 0.173 | 0.289 | 0.391 |
| EPUT | 0.500 | 0.492 | 0.497 | 0.462 | 0.003 | 0.009 | 0.016 | 0.019 |
| LIQNT | 0.501 | 0.482 | 0.492 | 0.475 | -0.003 | -0.013 | -0.039 | -0.095 |
| CRY | 0.483 | 0.463 | 0.501 | 0.479 | 0.049 | 0.151 | 0.334 | 0.500 |
| QMJ | 0.499 | 0.501 | 0.487 | 0.438 | 0.072 | 0.193 | 0.321 | 0.412 |
| RMWs | 0.500 | 0.501 | 0.481 | 0.438 | 0.025 | 0.077 | 0.141 | 0.205 |
| UNCf | 0.499 | 0.492 | 0.479 | 0.446 | -0.002 | -0.001 | 0.018 | 0.065 |
| UNC | 0.487 | 0.484 | 0.480 | 0.445 | -0.001 | -0.000 | 0.005 | 0.014 |
| VIX | 0.482 | 0.485 | 0.468 | 0.452 | 0.000 | 0.002 | 0.005 | 0.010 |
| SZE | 0.502 | 0.465 | 0.464 | 0.421 | 0.006 | 0.026 | 0.061 | 0.104 |
| CPTL | 0.487 | 0.480 | 0.457 | 0.411 | 0.016 | 0.046 | 0.067 | 0.074 |
| MKTB | 0.521 | 0.482 | 0.439 | 0.376 | 0.091 | 0.188 | 0.248 | 0.278 |
| MKTSs | 0.494 | 0.478 | 0.447 | 0.397 | 0.015 | 0.038 | 0.064 | 0.103 |
| LTREVB | 0.500 | 0.482 | 0.437 | 0.387 | 0.016 | 0.051 | 0.079 | 0.094 |
| SMBs | 0.491 | 0.476 | 0.450 | 0.384 | 0.004 | 0.016 | 0.029 | 0.034 |
| CPTLT | 0.478 | 0.459 | 0.456 | 0.406 | 0.023 | 0.068 | 0.130 | 0.186 |
| LIQ | 0.475 | 0.476 | 0.443 | 0.390 | 0.005 | 0.025 | 0.053 | 0.082 |
| BAB | 0.485 | 0.492 | 0.435 | 0.372 | 0.021 | 0.054 | 0.076 | 0.097 |
| VAL | 0.501 | 0.469 | 0.426 | 0.378 | 0.016 | 0.056 | 0.099 | 0.126 |
| STREV | 0.487 | 0.476 | 0.445 | 0.365 | 0.009 | 0.034 | 0.071 | 0.101 |
| LTREV | 0.498 | 0.473 | 0.432 | 0.357 | 0.009 | 0.031 | 0.052 | 0.057 |
| PERF | 0.503 | 0.469 | 0.433 | 0.343 | 0.048 | 0.104 | 0.120 | 0.093 |
| R_ROE | 0.490 | 0.465 | 0.416 | 0.357 | 0.049 | 0.103 | 0.135 | 0.159 |
| MGMT | 0.490 | 0.475 | 0.420 | 0.338 | 0.058 | 0.125 | 0.162 | 0.173 |
| CRF | 0.494 | 0.454 | 0.421 | 0.349 | 0.015 | 0.052 | 0.093 | 0.123 |
| HMLs | 0.478 | 0.461 | 0.411 | 0.357 | 0.004 | 0.011 | 0.021 | 0.026 |
| CMA | 0.469 | 0.464 | 0.421 | 0.351 | 0.028 | 0.063 | 0.077 | 0.063 |
| HML_DEV | 0.492 | 0.446 | 0.414 | 0.353 | 0.001 | 0.002 | 0.014 | 0.041 |
| HMLB | 0.475 | 0.464 | 0.438 | 0.326 | 0.038 | 0.104 | 0.148 | 0.120 |
| MOMB | 0.472 | 0.459 | 0.424 | 0.346 | -0.002 | -0.007 | -0.005 | -0.003 |
| MOMS | 0.464 | 0.445 | 0.422 | 0.365 | 0.020 | 0.057 | 0.095 | 0.139 |
| STREVB | 0.478 | 0.449 | 0.414 | 0.349 | 0.003 | 0.007 | 0.011 | 0.007 |
| MKTBD | 0.487 | 0.442 | 0.403 | 0.351 | 0.014 | 0.029 | 0.029 | 0.015 |
| R_IA | 0.473 | 0.437 | 0.418 | 0.349 | 0.034 | 0.079 | 0.120 | 0.140 |
| TERM | 0.474 | 0.443 | 0.397 | 0.354 | 0.027 | 0.058 | 0.085 | 0.116 |
| SMB | 0.476 | 0.434 | 0.410 | 0.331 | 0.010 | 0.044 | 0.079 | 0.086 |
| HML | 0.477 | 0.435 | 0.405 | 0.327 | 0.003 | -0.016 | -0.037 | -0.040 |
| DUR | 0.475 | 0.422 | 0.393 | 0.352 | 0.010 | -0.021 | -0.081 | -0.146 |
| DRF | 0.471 | 0.435 | 0.401 | 0.330 | 0.039 | 0.068 | 0.069 | 0.034 |
| DEF | 0.467 | 0.421 | 0.395 | 0.333 | 0.000 | -0.007 | -0.021 | -0.030 |
| FIN | 0.476 | 0.424 | 0.392 | 0.311 | 0.034 | 0.035 | 0.015 | -0.004 |
| RMW | 0.473 | 0.428 | 0.381 | 0.315 | 0.027 | 0.019 | -0.018 | -0.055 |

*The table reports posterior probabilities, $\mathbb{E}[\gamma_j|\text{data}]$, and posterior means of annualized market prices of risk, $\mathbb{E}[\lambda_j|\text{data}]$, of the 54 bond and stock factors described in Appendix A. The prior for each factor inclusion is a Beta(1, 1), yielding a prior expectation for $\gamma_j$ of 50%. Results are tabulated for different values of the prior Sharpe ratio, $\sqrt{\mathbb{E}_\pi[SR_f^2 \mid \sigma^2]}$, with values set to 20%, 40%, 60% and 80% of the ex post maximum Sharpe ratio of the test assets. The factors are ordered by the average posterior probability across the four levels of shrinkage. Test assets are the 83 bond and stock portfolios and 40 tradable bond and stock factors described in Section 1. The sample period is 1986:01 to 2022:12 (T = 444).*

---

## Appendix D. Benchmark asset pricing models

<!-- @section-type: methodology
  @key-claim: BMA-SDF benchmarked against CAPM, CAPMB, FF5, HKM, KNS, and RPPCA
  @importance: supporting
  @data-source: Kenneth French website, Zhiguo He website
  @depends-on: Section 3.1
  @equations: none
-->

*(Page 41)*

We benchmark the performance of the BMA-SDF against several frequentist asset pricing models as well as other latent factor models. In the following, we provide the estimation details for the models that are compared to the BMA-SDF in Section 3.1. A larger set of comparison benchmark models is considered in Internet Appendix IA.3.2.

*CAPM and CAPMB.* The single-factor equity CAPM and the bond equivalent CAPMB. The CAPM is the value-weighted equity market factor from Kenneth French's webpage. The bond CAPM (CAPMB) is the value-weighted corporate bond market factor. We estimate factor risk prices using a GLS version of GMM (see, e.g., Cochrane (2005, pp. 256-258)).

*FF5.* The original five-factor model of Fama and French (1993) that includes the MKTS, SMB and HML factors from Fama and French (1992) and the default (DEF) and term structure (TERM) factors introduced in Fama and French (1993). We estimate factor risk prices using a GLS version of GMM (see, e.g., Cochrane (2005, pp. 256-258)).

*HKM.* The intermediary capital two-factor asset pricing model of He, Kelly and Manela (2017). Includes the MKTS factor from Fama and French (1992) and the value-weighted (tradable version) of the intermediary capital factor, CPTLT in excess of the one-month risk-free rate. We estimate factor risk prices using a GLS version of GMM (see, e.g., Cochrane (2005, pp. 256-258)).

*KNS.* The latent factor model approach of Kozak et al. (2020). For each in-sample bond, stock or co-pricing cross-section, we select the optimal shrinkage level and number of factors chosen by twofold cross-validation. Given our data has a time series length of $T = 444$, the first sample is simply January 1986 to June 2004 and the second sample is July 2004 to December 2022.

*RPPCA.* The risk premia PCA methodology of Lettau and Pelger (2020). We use five principal components. In our main estimation used for the baseline results, we set $\gamma$ from their equation (4) equal to 20. Changing this parameter to 10, or a lower value, does not quantitatively affect pricing performance.

---

## References

<!-- @section-type: references
  @key-claim: Bibliography for the main paper
  @importance: supporting
  @data-source: none
  @depends-on: all sections
  @equations: none
-->

Asness, C., Frazzini, A., 2013. The devil in HML's details. Journal of Portfolio Management 39, 49-68.

Asness, C.S., Frazzini, A., Pedersen, L.H., 2019. Quality minus junk. Review of Accounting Studies 24, 34-112.

Avramov, D., Cheng, S., Metzker, L., Voigt, S., 2023. Integrating factor models. The Journal of Finance 78, 1593-1646.

Bai, J., Bali, T.G., Wen, Q., 2019. RETRACTED: Common risk factors in the cross-section of corporate bond returns. Journal of Financial Economics 131, 619-642.

Baker, S.R., Bloom, N., Davis, S.J., 2016. Measuring economic policy uncertainty. Quarterly Journal of Economics 131, 1593-1636.

Bali, T.G., Subrahmanyam, A., Wen, Q., 2021a. Long-term reversals in the corporate bond market. Journal of Financial Economics 139, 656-677.

Bali, T.G., Subrahmanyam, A., Wen, Q., 2021b. The macroeconomic uncertainty premium in the corporate bond market. Journal of Financial and Quantitative Analysis 56, 1653-1678.

Bansal, R., Khatchatrian, V., Yaron, A., 2005. Interpretable asset markets? European Economic Review 49, 531-560.

Bansal, R., Kiku, D., Yaron, A., 2012. An empirical evaluation of the long-run risks model for asset prices. Critical Finance Review 1, 183-221.

Barillas, F., Shanken, J., 2017. Which alpha? The Review of Financial Studies 30, 1316-1338.

Barillas, F., Shanken, J., 2018. Comparing asset pricing models. The Journal of Finance 73, 715-754.

Bartram, S.M., Grinblatt, M., Nozawa, Y., 2025. Book-to-market, mispricing, and the cross section of corporate bond returns. Journal of Financial and Quantitative Analysis 60, 1185-1233.

*(Page 42)*

Bauwens, L., Lubrano, M., Richard, J.F., 1999. Bayesian Inference in Dynamic Econometric Models. Oxford University Press, Oxford.

Beeler, J., Campbell, J.Y., 2012. The long-run risks model and aggregate asset prices: An empirical assessment. Critical Finance Review 1, 141-182.

Belloni, A., Chernozhukov, V., Hansen, C., 2014. Inference on treatment effects after selection among high-dimensional controls. Review of Economic Studies 81, 608-650.

Bhamra, H.S., Kuehn, L.A., Strebulaev, I.A., 2010. The levered equity risk premium and credit spreads: A unified framework. The Review of Financial Studies 23, 645-703.

van Binsbergen, J.H., Nozawa, Y., Schwert, M., 2025. Duration-based valuation of corporate bonds. The Review of Financial Studies 38, 158-191.

Blume, M.E., Keim, D.B., 1987. Lower-grade bonds: Their risks and returns. Financial Analysts Journal 43, 26-66.

Bollerslev, T., 1986. Generalized autoregressive conditional heteroskedasticity. Journal of Econometrics 31, 307-327.

Bollerslev, T., Wooldridge, J.M., 1992. Quasi-maximum likelihood estimation and inference in dynamic models with time-varying covariances. Econometric Reviews 11, 143-172.

Bryzgalova, S., Huang, J., Julliard, C., 2023. Bayesian solutions for the factor zoo: We just ran two quadrillion models. The Journal of Finance 78, 487-557.

Bryzgalova, S., Huang, J., Julliard, C., 2024. Macro strikes back: Term structure of risk premia and market segmentation. Working Paper, London School of Economics.

Campbell, J.Y., Shiller, R.J., 1988. The dividend-price ratio and expectations of future dividends and discount factors. The Review of Financial Studies 1, 195-228.

Campbell, J.Y., Taksler, G.B., 2003. Equity volatility and corporate bond yields. The Journal of Finance 58, 2321-2349.

Carhart, M.M., 1997. On persistence in mutual fund performance. The Journal of Finance 52, 57-82.

Ceballos, L., 2023. Inflation volatility risk and the cross-section of corporate bond returns. Working Paper, University of San Diego.

Chan, L.K., Jegadeesh, N., Lakonishok, J., 1996. Momentum strategies. The Journal of Finance 51, 1681-1713.

Chen, A.Y., 2017. External Habit in a Production Economy: A Model of Asset Prices and Consumption Volatility Risk. The Review of Financial Studies 30, 2890-2932.

Chen, A.Y., Zimmermann, T., 2022. Open source cross-sectional asset pricing. Critical Finance Review 27, 207-264.

Chen, H., Cui, R., He, Z., Milbradt, K., 2018. Quantifying Liquidity and Default Risks of Corporate Bonds over the Business Cycle. The Review of Financial Studies 31, 852-897.

Chen, L., Zhao, X., 2009. Return decomposition. The Review of Financial Studies 22, 5213-5249.

Chen, Z., Roussanov, N.L., Wang, X., Zou, D., 2024. Common risk factors in the returns on stocks, bonds (and options), redux. Working Paper, The Wharton School.

Chib, S., Zeng, X., Zhao, L., 2020. On comparing asset pricing models. The Journal of Finance 75, 551-577.

Choi, J., Kim, Y., 2018. Anomalies and market (dis)integration. Journal of Monetary Economics 100, 16-34.

Chordia, T., Goyal, A., Nozawa, Y., Subrahmanyam, A., Tong, Q., 2017. Are capital market anomalies common to equity and corporate bond markets? An empirical investigation. Journal of Financial and Quantitative Analysis 52, 1301-1342.

Chung, K.H., Wang, J., Wu, C., 2019. Volatility and the cross-section of corporate bond returns. Journal of Financial Economics 133, 397-417.

Cochrane, J.H., 2005. Asset Pricing. volume 1. Princeton University Press Princeton, NJ.

*(Page 43)*

Cochrane, J.H., 2011. Presidential address: Discount rate. The Journal of Finance 66, 1047-1108.

Cohen, R.B., Gompers, P.A., Vuolteenaho, T., 2002. Who underreacts to cash-flow news? Evidence from trading between individuals and institutions. Journal of Financial Economics 66, 409-462.

Correia, M., Richardson, S., Tuna, I., 2012. Value investing in credit markets. Review of Accounting Studies 17, 572-609.

Dang, T.D., Hollstein, F., Prokopczuk, M., 2023. Which factors for corporate bond returns? The Review of Asset Pricing Studies 13, 615-652.

Daniel, K., Hirshleifer, D., Sun, L., 2020a. Short- and long-horizon behavioral factors. The Review of Financial Studies 33, 1673-1736.

Daniel, K., Mota, L., Rottke, S., Santos, T., 2020b. The cross-section of risk and returns. The Review of Financial Studies 33, 1927-1979.

De Long, B., Shleifer, A., Summers, L.C., Waldman, R., 1990. Noise trader risk in financial markets. Journal of Political Economy 98, 703-738.

Delao, R., Han, X., Myers, S., 2025. The return of return dominance: Decomposing the cross-section of prices. Journal of Financial Economics 169, 104059.

Della Vigna, S., Pollet, J.M., 2009. Investor inattention and Friday earnings announcements. The Journal of Finance 64, 709-749.

Dello Preite, M., Uppal, R., Zaffaroni, P., Zviadadze, I., 2025. Cross-sectional asset pricing with unsystematic risk. Working Paper, EDHEC Business School.

DeMiguel, V., Garlappi, L., Uppal, R., 2009. Optimal versus naive diversification: How inefficient is the 1/N portfolio strategy? The Review of Financial studies 22, 1915-1953.

Dick-Nielsen, J., Feldhutter, P., Pedersen, L.H., Stolborg, C., 2025. Corporate bond factors: Replication failures and a new framework. Working Paper, Copenhagen Business School.

Dickerson, A., Fournier, M., Jeanneret, A., Mueller, P., 2025. A credit risk explanation of the correlation between corporate bonds and stocks. Working Paper, UNSW.

Dickerson, A., Mueller, P., Robotti, C., 2023. Priced risk in corporate bonds. Journal of Financial Economics 150, 103707.

Dickerson, A., Robotti, C., Rossetti, G., 2024. Common pitfalls in the evaluation of corporate bond strategies. Working Paper, Warwick Business School.

Duarte, J., Jones, C.S., Mo, H., Khorram, M., 2025. Too good to be true: Look-ahead bias in empirical option research. Working Paper, USC Marshall.

Elkamhi, R., Jo, C., Nozawa, Y., 2023. A one-factor model of corporate bond premia. Management Science 70, 1875-1900.

Elton, E.J., Gruber, M.J., Agrawal, D., Mann, C., 2001. Explaining the rate spread on corporate bonds. The Journal of Finance 56, 247-277.

Elton, E.J., Gruber, M.J., Blake, C.R., 1995. Fundamental economic variables, expected returns, and bond fund performance. The Journal of Finance 50, 1229-1256.

Engle, R.F., 1982. Autoregressive conditional heteroskedasticity with estimates of the variance of united kingdom inflation. Econometrica 50, 987-1007.

Fama, E.F., French, K.R., 1992. The cross-section of expected stock returns. The Journal of Finance 47, 427-465.

Fama, E.F., French, K.R., 1993. Common risk factors in the returns on stocks and bonds. Journal of Financial Economics 33, 3-56.

Fama, E.F., French, K.R., 2015. A five-factor asset pricing model. Journal of Financial Economics 116, 1-22.

Fang, X., Liu, Y., Roussanov, N., 2024. Getting to the core: Inflation risks within and across asset classes. forthcoming, Review of Financial Studies.

*(Page 44)*

Favilukis, J., Lin, X., Zhao, X., 2020. The elephant in the room: The impact of labor obligations on credit markets. American Economic Review 110, 1673-1712.

Feng, G., Giglio, S., Xiu, D., 2020. Taming the factor zoo: A test of new factors. The Journal of Finance 75, 1327-1370.

Fisher, L., 1959. Determinants of risk premiums on corporate bonds. Journal of Political Economy 67, 217-237.

Frazzini, A., Pedersen, L.H., 2014. Betting against beta. Journal of Financial Economics 111, 1-25.

Gebhardt, W.R., Hvidkjaer, S., Swaminathan, B., 2005a. The cross-section of expected corporate bond returns: Betas or characteristics? Journal of Financial Economics 75, 85-114.

Gebhardt, W.R., Hvidkjaer, S., Swaminathan, B., 2005b. Stock and bond market interaction: Does momentum spill over? Journal of Financial Economics 75, 651-690.

Gebhardt, W.R., Lee, C.M.C., Swaminathan, B., 2001. Toward an implied cost of capital. Journal of Accounting Research 39, 135-176.

Giesecke, K., Longstaff, F.A., Schaefer, S., Strebulaev, I., 2011. Corporate bond default risk: A 150-year perspective. Journal of Financial Economics 102, 233-250.

Giglio, S., Xiu, D., 2021. Asset pricing with omitted factors. Journal of Political Economy 129, 1947-1990.

Gomes, J.F., Schmid, L., 2021. Equilibrium asset pricing with leverage and default. The Journal of Finance 76, 977-1018.

Gospodinov, N., Kan, R., Robotti, C., 2014. Misspecification-robust inference in linear asset-pricing models with irrelevant risk factors. The Review of Financial Studies 27, 2139-2170.

Gospodinov, N., Kan, R., Robotti, C., 2019. Too good to be true? Fallacies in evaluating risk factor models. Journal of Financial Economics 132, 451-471.

Gospodinov, N., Robotti, C., 2021. Common pricing across asset classes: Empirical evidence revisited. Journal of Financial Economics 140, 292-324.

Hansen, L., Jagannathan, R., 1991. Implications of security market data for models of dynamic economies. Journal of Political Economy 99, 225-262.

Hansen, L.P., 1982. Large sample properties of method of moments estimators. Econometrica 50, 1029-1054.

Harvey, C.R., 2017. Presidential address: The scientific outlook in financial economics. The Journal of Finance 72, 1399-1440.

Harvey, C.R., Liu, Y., Zhu, H., 2016. ...and the cross-section of expected returns. The Review of Financial Studies 29, 5-68.

Hayashi, F., 2000. Econometrics. Princeton University Press, Princeton, NJ.

He, Z., Kelly, B., Manela, A., 2017. Intermediary asset pricing: New evidence from many asset classes. Journal of Financial Economics 126, 1-35.

Heyerdahl-Larsen, C., Illeditsch, P.K., Walden, J., 2023. Model selection by market selection. SSRN Working Paper No 4401170.

Hirshleifer, D., Lim, S.S., Teoh, S.H., 2011. Limited investor attention and stock market misreactions to accounting information. Review of Asset Pricing Studies 1, 35-73.

Hirshleifer, D., Teoh, S.H., 2003. Limited attention, information disclosure, and financial reporting. Journal of Accounting and Economics 36, 337-386.

Hoeting, J.A., Madigan, D., Raftery, A.E., Volinsky, C.T., 1999. Bayesian model averaging: A tutorial. Statistical Science 14, 382-401.

Hottinga, J., van Leeuwen, E., van Ijserloo, J., 2001. Successful factors to select outperforming corporate bonds. Journal of Portfolio Management 28, 88-101.

Hou, K., Xue, C., Zhang, L., 2015. Digesting anomalies: An investment approach. The Review of Financial Studies 28, 650-705.

*(Page 45)*

Houweling, P., Van Zundert, J., 2017. Factor investing in the corporate bond market. Financial Analysts Journal 73, 100-115.

Jeffreys, H., 1961. Theory of Probability. 3rd ed., Oxford University Press, Oxford.

Jegadeesh, N., Titman, S., 1993. Returns to buying winners and selling losers: Implications for stock market efficiency. The Journal of Finance 48, 65-91.

Jegadeesh, N., Titman, S., 2001. Profitability of momentum strategies: An evaluation of alternative explanations. The Journal of Finance 56, 699-720.

Jensen, T.I., Kelly, B., Pedersen, L.H., 2023. Is there a replication crisis in finance? The Journal of Finance 78, 2465-2518.

Kan, R., Zhang, C., 1999a. GMM tests of stochastic discount factor models with useless factors. Journal of Financial Economics 54, 103-127.

Kan, R., Zhang, C., 1999b. Two-pass tests of asset pricing models with useless factors. The Journal of Finance 54, 203-235.

Kang, J., Pflueger, C.E., 2015. Inflation risk in corporate bonds. The Journal of Finance 70, 115-162.

Khan, A., Thomas, J.K., 2013. Credit shocks and aggregate fluctuations in an economy with production heterogeneity. Journal of Political Economy 121, 1055-1107.

Khang, K., King, T.H.D., 2004. Return reversals in the bond market: Evidence and causes. Journal of Banking and Finance 28, 569-593.

Kleibergen, F., 2009. Tests of risk premia in linear factor models. Journal of Econometrics 149, 149-173.

Kleibergen, F., Zhan, Z., 2020. Robust inference for consumption-based asset pricing. The Journal of Finance 75, 507-550.

Koijen, R.S., Lustig, H., Van Nieuwerburgh, S., 2017. The cross-section and time series of stock and bond returns. Journal of Monetary Economics 88, 50-69.

Koijen, R.S., Van Nieuwerburgh, S., 2011. Predictability of returns and cash flows. Annual Review of Financial Economics 3, 467-491.

Kozak, S., Nagel, S., Santosh, S., 2020. Shrinking the cross-section. Journal of Financial Economics 135, 271-292.

Lettau, M., Maggiori, M., Weber, M., 2014. Conditional risk premia in currency markets and other asset classes. Journal of Financial Economics 114, 197-225.

Lettau, M., Pelger, M., 2020. Estimating latent asset-pricing factors. Journal of Econometrics 218, 1-31.

Lewellen, J., Nagel, S., Shanken, J., 2010. A skeptical appraisal of asset pricing tests. Journal of Financial Economics 96, 175-194.

Lin, H., Wang, J., Wu, C., 2011. Liquidity risk and expected corporate bond returns. Journal of Financial Economics 99, 628-650.

Lintner, J., 1965. Security prices, risk, and maximal gains from diversification. The Journal of Finance 20, 587-615.

Liu, Y., Wu, J.C., 2021. Reconstructing the yield curve. Journal of Financial Economics 142, 1395-1425.

Ljung, G.M., Box, G.E.P., 1978. On a measure of lack of fit in time series models. Biometrika 65, 297-303.

Ludvigson, S.C., Jurado, K., Ng, S., 2015. Measuring uncertainty. The American Economic Review 105, 1177-1216.

Martineau, C., 2022. Rest in peace post-earnings announcement drift. Critical Finance Review 11, 613-646.

McCullough, J.R., 1830. The Principles of Political Economy: With a Sketch of the Rise and Progress of the Science (2nd ed.). Edinburgh, London, and Dublin.

Merton, R.C., 1974. On the pricing of corporate debt: The risk structure of interest rates. The Journal of Finance 29, 449-470.

*(Page 46)*

Newey, W.K., McFadden, D., 1994. Large sample estimation and hypothesis testing, in: Engle, R.F., McFadden, D. (Eds.), Handbook of Econometrics. Elsevier Press. volume 4.

Newey, W.K., West, K.D., 1987. A simple, positive semi-definite, heteroskedasticity and autocorrelation consistent covariance matrix. Econometrica 55, 703-708.

Nozawa, Y., Qiu, Y., Xiong, Y., 2025. Disagreement and bond pead. Working Paper, University of Toronto.

Parker, J.A., Julliard, C., 2003. Consumption Risk and Cross-Sectional Returns. Working Paper 9538. National Bureau of Economic Research.

Parker, J.A., Julliard, C., 2005. Consumption risk and the cross section of expected returns. Journal of Political Economy 113, 185-222.

Pastor, L., 2000. Portfolio selection and asset pricing models. The Journal of Finance 55, 179-223.

Pastor, L., Stambaugh, R.F., 2000. Comparing asset pricing models: An investment perspective. Journal of Financial Economics 56, 335-381.

Pastor, L., Stambaugh, R.F., 2003. Liquidity risk and expected stock returns. Journal of Political Economy 111, 642-685.

Penman, S.H., Yehuda, N., 2019. A matter of principle: Accounting reports convey both cash-flow news and discount-rate news. Management Science 65, 5584-5602.

Raftery, A.E., Madigan, D., Hoeting, J.A., 1997. Bayesian model averaging for linear regression models. Journal of the American Statistical Association 92, 179-191.

Raftery, A.E., Zheng, Y., 2003. Discussion: Performance of Bayesian model averaging. Journal of the American Statistical Association 98, 931-938.

Sandulescu, M., 2022. How integrated are corporate bond and stock markets? Working Paper, Ross School of Business.

Schervish, M.J., 1995. Theory of Statistics. Springer Series in Statistics, Springer-Verlag.

Sharpe, W.F., 1964. Capital asset prices: A theory of market equilibrium under conditions of risk. The Journal of Finance 19, 425-442.

Stambaugh, R.F., Yuan, Y., 2017. Mispricing factors. The Review of Financial Studies 30, 1270-1315.

Vuolteenaho, T., 2002. What drives firm-level stock returns? The Journal of Finance 57, 233-264.

Zviadadze, I., 2021. Term structure of risk in expected returns. The Review of Financial Studies 34, 6032-6086.

---

# Internet Appendix for: The Co-Pricing Factor Zoo

<!-- @section-type: introduction
  @key-claim: Internet Appendix provides additional information, tables, figures, and empirical results supporting the main text
  @importance: supporting
  @data-source: same as main paper
  @depends-on: main paper
  @equations: none
-->

*(Page 47)*

Alexander Dickerson, Christian Julliard, and Philippe Mueller

December 2025

**Abstract:** This Internet Appendix provides additional information, tables, figures, and empirical results supporting the main text.

**Contents of the Internet Appendix**

- IA.1 Details on data sources, factors and test assets
- IA.2 Simulation design
- IA.3 Additional co-pricing results
- IA.4 The PEAD factor
- IA.5 Discount rate and cash-flow news decomposition
- IA.6 The Treasury component
- IA.7 Risk premia vs. market prices of risk
- IA.8 Economic properties
- IA.9 Prior perturbation
- IA.10 Estimation uncertainty
- IA.11 The nontradable CREDIT factor

---

## IA.1. Details on data sources, factors and test assets

<!-- @section-type: data
  @key-claim: Detailed description of corporate bond databases, data filters, sample coverage, factor robustness across data sources
  @importance: supporting
  @data-source: Mergent FISD, BAML ICE, LBFI, WRDS TRACE, DFPS TRACE, CRSP
  @depends-on: Section 1
  @equations: none
-->

*(Page 48)*

In this section we first describe in detail the various sources for corporate bond data and test assets before we briefly discuss the coverage of our bond and stock data sample. Next, we assess the robustness of the corporate bond factors for different construction methods and data sources. Finally, we provide a list of the bond and stock test assets in Table IA.II.

### IA.1.1. Corporate bond databases

First, we describe the sources of corporate bond data. All data filters below are applied verbatim across all of the bond databases we consider. Across all databases, we filter out bonds with maturity less than one year. Furthermore, for consistency, across all databases, we define bond ratings as those provided by Standard & Poors (S&P). We include the full spectrum of ratings (AAA to D) but exclude unrated bonds. Irrespective of the data source, we *do not* winsorize or trim bond returns in any way.

#### IA.1.1.1. Mergent Fixed Income Securities Database

The Mergent Fixed Income Securities Database (FISD) contains bond issue and issuer characteristic data. We apply the standard filters used in the extant literature to the FISD data:

1. Only keep bonds that are issued by firms domiciled in the United States of America, `COUNTRY_DOMICILE == 'USA'`.
2. Remove bonds that are private placements, `PRIVATE_PLACEMENT == 'N'`.
3. Only keep bonds that are traded in U.S. Dollars, `FOREIGN_CURRENCY == 'N'`.
4. Bonds that trade under the 144A Rule are discarded, `RULE_144A == 'N'`.
5. Remove all asset-backed bonds, `ASSET_BACKED == 'N'`.
6. Remove convertible bonds, `CONVERTIBLE == 'N'`.
7. Only keep bonds with a fixed or zero coupon payment structure, i.e., remove bonds with a floating (variable) coupon, `COUPON_TYPE != 'V'`.
8. Remove bonds that are equity linked, agency-backed, U.S. Government, and mortgage-backed, based on their `BOND_TYPE`.
9. Remove bonds that have a "non-standard" interest payment structure or bonds not caught by the variable coupon filter (`COUPON_TYPE`). We remove bonds that have an `INTEREST_FREQUENCY` equal to -1 (N/A), 13 (Variable Coupon), 14 (Bi-Monthly), and 15 and 16 (undocumented by FISD). Additional information on `INTEREST_FREQUENCY` is available on page 60 to 67 of the FISD Data Dictionary 2012 document.

#### IA.1.1.2. Bank of America Merrill Lynch Database

The Bank of America Merrill Lynch (BAML) data is made available by the Intercontinental Exchange (ICE) and provides daily bond price quotes, accrued interest, and a host of pre-computed corporate bond characteristics such as the bond option-adjusted credit spread (OAS), the asset swap spread, duration, convexity, and bond returns in excess of a portfolio of duration-matched Treasuries. The ICE sample spans the time period January 1997 to December 2022 and includes constituent bonds from the ICE Bank of America High Yield (H0A0) and Investment Grade (C0A0) Corporate Bond Indices.

*BAML ICE bond filters.* We follow van Binsbergen et al. (2025) and take the last quote of each month to form the bond-month panel. We then merge the ICE data to the filtered Mergent FISD data. The following ICE-specific filters are then applied:

1. Only include corporate bonds, `Ind_Lvl_1 == 'corporate'`
2. Only include bonds issued by U.S. firms, `Country == 'US'`
3. Only include corporate bonds denominated in U.S. dollars, `Currency == 'USD'`

*BAML ICE bond returns.* Total bond returns are computed in a standard manner in ICE, and no assumptions about the timing of the last trading day of the month are made because the data is quote based, i.e., there is always a valid quote at month-end to compute a bond return. This means that each bond return is computed using a price quote at exactly the end of the month, each and every month. This introduces homogeneity into the bond returns because prices are sampled at exactly the same time each month. ICE only provides bid-side pricing, meaning bid-ask bias is inherently not present in the monthly sampled prices, returns and credit spreads. The monthly ICE return variable is (as denoted in the original database) `trr_mtd_loc`, which is the month-to-date return on the last business day of month $t$.

*(Page 49)*

#### IA.1.1.3. Lehman Brothers Fixed Income Database

The Lehman Brothers Fixed Income (LBFI) database holds monthly price data for corporate (and other) bonds from January 1973 to December 1997. The database categorizes the prices as either quote or matrix prices and identifies whether the bonds are callable or not. However, as per Chordia et al. (2017), the difference between quote and matrix prices or callable and non-callable bonds does not have a material impact on cross-sectional return predictability. Hence, we include both types of observations. In addition, the LBFI data provides key bond details such as the amount outstanding, credit rating, offering date, and maturity date. For the main results, we use the LBFI data from January 1986 to December 1996.

*LBFI bond filters.* As for the other databases, we merge the LBFI data to the pre-filtered Mergent FISD data and then apply the following LBFI-specific filters following Elkamhi et al. (2023):

1. Only include corporate bonds classified as 'industrial,' 'telephone utility,' 'electric utility,' 'utility (other),' and 'finance,' as per the LBFI industry classification system, `icode == {3 | 4 | 5 | 6 | 7}`.
2. Remove the following dates for which there are no observations or valid return data, `date == {1975-08 | 1975-09 | 1984-12 | 1985-01}`.

*LBFI bond returns.* The LBFI data includes corporate bond returns that have been pre-computed. The accuracy is empirically verified by Elkamhi et al. (2023).

*LBFI additional filters.* We follow Bessembinder et al. (2008) and Chordia et al. (2017) and apply the following filters to the LBFI data to account for potential data errors:

1. Remove observations with large return reversals, defined as a 20% or greater return followed by a 20% or greater return of the opposite sign.
2. Remove observations if the prices appear to bounce back in an extreme fashion relative to preceding days. Denote $R_t$ as the month $t$ return, we exclude an observation at month $t$ if $R_t \times R_{t-k} < -0.02$ for $k = 1, \ldots, 12$.
3. Remove observations if prices do not change for more than three months, i.e., $\frac{P_t}{P_{t-3}} - 1 \neq 0$, where $P$ is the quoted or matrix price.

#### IA.1.1.4. Trade Reporting and Compliance Engine Database

For many researchers, the Trade Reporting and Compliance Engine (TRACE) database is the main source of corporate bond data as it is available through Wharton Research Data Services (WRDS TRACE) from August 2002 to December 2022. An alternative version of the TRACE data (DFPS TRACE) is processed by Dick-Nielsen et al. (2025) and provided online via Christian Stolborg's website. The DFPS TRACE data also assumes a return is valid if there are available bond prices in the last five business days of month $t$ and $t+1$. The data is then checked for erroneous data points, and 292 data points are discarded. See Appendix B of Dick-Nielsen et al. (2025) for additional details. The data is also available from August 2002 but ends in December 2021.

**Figure IA.1:** Calculating bond returns using transaction- and quote-based data.

*Panel A shows the timing of how prices are sampled to calculate monthly returns for the transaction-based WRDS TRACE data. The designated 'end-of-the-month' transaction price $P_t$ and $P_{t+1}$ must be within the last five business days of the month. The pseudo 'month-end' return is then computed with these clean prices and any accrued interest. Panel B shows the timing for a bond return calculation using quote-based prices in the BAML ICE and LBFI data. Price quotes are available on the very last business day of each month, resulting in a contiguous monthly return series.*

*TRACE returns.* A key difference between quote- (e.g., BAML ICE) and transaction-based (e.g., TRACE) databases is that for the latter transaction prices might not land on the very last business days of consecutive months $t$ and $t + 1$, implying that prices may not align with month-end CRSP equity signals. As a result, assumptions are required as to what kind of sampling criterion should be used to compute a monthly time series of bond returns. Consistent with Dickerson, Robotti and Rossetti (2024), we use the bond return variable denoted `RET_L5M` from WRDS TRACE which recognizes a valid monthly bond return if the bond trades within the 5-day window toward the end of months $t$ and $t + 1$, respectively. Mechanically, this implies a monthly time series of bond returns that is not strictly contiguous, i.e., in month $t$ the bond could be traded on the third last business day and in month $t + 1$ the same bond may trade on the very last business day. Although quote-based databases are not a 'panacea' for

*(Page 50)*

corporate bond data issues, they do allow for bond returns to be consistently computed because a valid month-end quote is always available.

Figure IA.1 illustrates the timing of prices used to compute 'monthly' bond returns with any version of the WRDS TRACE data vs. the BAML ICE quote-based data. In Panel A, a monthly transaction return is valid if a bond trades within the last five days of months $t$ and $t + 1$. Missing returns NaN are recorded if, for example, a bond trades in the middle of month $t$ and then only again on the last business day of month $t + 1$. In Panel B, contiguous returns can be computed because a valid indicative quote is available from the pool of dealers that are queried by BAML ICE, thus, bond return calculations are aligned with their analogue for stocks in CRSP.

We use WRDS TRACE as well as DFPS TRACE for our robustness tests that are discussed in Section 4 and in Internet Appendices IA.1.3 and IA.10.1.

**Figure IA.2:** Corporate bond and equity issuers.

*This figure depicts a Venn diagram where the red-shaded set comprises all 9,994 unique firms (as determined by the PERMNO) in the CRSP data. The blue-shaded set are all 5,824 unique issuing firms from the primary corporate bond sample as determined by the six digit ISSUER_CUSIP. The brown-shaded intersection comprises the 2,211 firms with outstanding corporate debt that can be matched to CRSP PERMNO identifiers. Listed-equity firms: 7,783. Bond-issuer firms: 3,613. Overlap: 2,211.*

### IA.1.2. Combined bond and stock data coverage

For our baseline results, we use corporate bond factors and test assets calculated from the dataset that combines the LBFI and the ICE data over the joint sample period January 1986 to December 2022, whereby we splice the data together. Before 1997 we use the LBFI data and, thereafter, we rely on ICE data. Stock factors and test asset returns are all calculated using CRSP data available through WRDS.

Our equity sample comprises close to ten thousand firms (9,994), while our corporate bond sample contains a total of 5,824 issuers. Overall, we can match 2,211 firms that have both public equity as well as corporate bonds outstanding throughout our sample period. That is, 78% of the firms in our sample do not issue corporate bonds, and 62% of the corporate bond issuers are not publicly listed. Figure IA.2 illustrates the overlap of equity and bond data in terms of the number of firms.

*(Page 51)*

In Figure IA.3 we further put in perspective the coverage of our data in terms of market capitalisation. Even though 62% of the firms in the CRSP sample do not issue corporate debt, our matched sample captures around the same percentage as the S&P 500 index in terms of total U.S. market capitalisation. At the end of our sample period, the total market capitalisation of CRSP firms is USD 22.1 trillion while the market capitalisation of our corporate bond matched equity sample is only about 16% smaller with USD 18.4 trillion (see Panel A in Figure IA.3). Panel B plots the coverage in percent, defined as the equity market capitalisation of firms in the merged sample divided by the total market capitalisation of all CRSP firms. The average coverage is 74.5% but remains at or above 80% for the post-2000 period.

**Figure IA.3:** Bond and stock issuers market capitalisation.

*Panel A plots the total market capitalisation (in USD trillions) of all listed firms in CRSP (red line) along with the total market capitalisation of the subset that has publicly traded debt in our merged bond-stock data sample at each month t. Panel B plots the time-varying coverage in percent, defined as the market capitalisation of the firms in our corporate bond matched sample divided by the total CRSP market capitalisation. The sample period is 1986:01 to 2022:12 (T = 444).*

### IA.1.3. Corporate bond factor zoo robustness

An extensive and ongoing academic debate discusses what could drive replication issues and differences in the performance of corporate bond factors. On the one hand, Dick-Nielsen et al. (2025) argue that data errors and researchers' data cleaning assumptions are the underlying cause of the bond replication 'crisis.' On the other hand, Dickerson et al. (2024) posit that a combination of the failure to adjust for corporate bond microstructure issues combined with *ex post* and asymmetric winsorization and/or trimming of the bond return distribution are the core drivers of the crisis.[^1]

[^1]: Recently, Jostova et al. (2024) and Li (2023) add to the debate by examining the role of outliers specifically for the corporate bond momentum factor (MOMB).

**Table IA.I:** The corporate bond factor zoo across data choices

| Benchmark data | Alternative data | Sample period | Significant difference |
|---|---|---|---|
| LBFI/BAML ICE | LBFI/BAML ICE firm-level | 1986:01-2022:12 | CRY, DUR, PEADB, STREVB |
| LBFI Q&M | LBFI Q only | 1986:01-1996:12 | VAL |
| BAML ICE | WRDS TRACE | 2002:08-2022:12 | CRF |
| BAML ICE | DFPS TRACE | 2002:08-2021:12 | CRY, HMLB |

*The table documents which corporate bond factors exhibit significantly different average returns when comparing the benchmark combined LBFI/BAML ICE data with factors calculated at the bond level with alternatives. We compare bond factors (i) calculated using bond- vs. firm-level data; (ii) that remove matrix prices (quotes and matrix vs. quotes only); (iii) that are calculated using transaction-based WRDS TRACE; and (iv) that are calculated using transaction-based DFPS TRACE data. The factors are listed in column "Significant difference" when factor averages between the benchmark construction and the alternative are significantly different at the 5% level of significance.*

In this section we examine to what extent data choices may affect corporate bond factors. For all comparisons we re-construct 14 of our 16 corporate bond factors, excluding DEF and TERM as they are independent of the corporate bond data.[^2] We first examine differences between factors formed at the bond vs. the firm level. Then, we confirm that removing bonds with matrix prices does not materially affect our corporate bond factors and, finally, we show that the differences between factors based on quotes and factors constructed using transaction prices are negligible. The results are summarized in Table IA.I. Unless otherwise noted, the benchmark data are corporate bond factors calculated at the bond-level using the combined LBFI/BAML ICE data as discussed in Section 1 (LBFI/BAML ICE). Overall, the factor construction is very robust to the different dimensions of comparison. Changes in data (rows two through four in Table IA.I) never lead to more than two factors displaying significantly different means, although the values remain economically small. Moreover, we show in Internet Appendix IA.10.1 that even these significant differences do not affect our estimation results.

[^2]: DEF and TERM rely on the data repository of Amit Goyal.

*(Page 52)*

#### IA.1.3.1. Bond- vs. firm-level factors

To study the differences between bond- and firm-level corporate bond factors, we focus on our baseline data, the combined LBFI and BAML ICE bond data. First, we merge the corporate bond data to firm-level PERMNO and GVKEY identifiers. We then follow Choi (2013) and compute a 'representative' firm(PERMNO)-level return as the value-weighted average comprising all outstanding bonds for firm $i$ over month $t + 1$ using bond market capitalization weights formed at the end of month $t$. As in our main analysis, the sample spans 37 years from January 1986 to December 2022. Before January 1997, we merge corporate bond issuers to their PERMNO via the historical NCUSIP and manually check for errors. Thereafter, we apply the merging methodology outlined in Fang (2025).[^3]

[^3]: The full panel of identification variables and dates necessary to merge the data are available on https://openbondassetpricing.com/bond-compustat-crsp-link/.

**Figure IA.4:** Bond factor comparison: Bond- vs. firm-level.

*Panel A displays the average monthly bond factor returns constructed at the bond or the firm level, respectively, using the combined LBFI/BAML ICE quote-based data. Panel B reports the average return differences in percent. The standard error bars represent the 95% confidence interval. The factors computed at the firm level use a 'representative' bond return for month t + 1 computed as the value-weighted average return of all of a firms' bonds outstanding over month t + 1 using bond market capitalization weights formed at month t. The sample period is 1986:01 to 2022:12 (T = 444).*

*Firm-level corporate bond factors.* There are benefits and costs associated with constructing factors with firm-level 'representative' bond returns. One potential benefit is that in a bond-level analysis, firms with a very large number of bonds are given a higher weight compared to firms with fewer or only a single bond outstanding. However, an obvious drawback is that bond-specific information may be aggregated out at the firm level. For example, firms with multiple outstanding bonds may have issued securities with different maturities or even different credit ratings. Thus, for corporate bond factors based on bond-level characteristics, bond-level returns are a natural choice for factor construction.

In Figure IA.4 we compare bond- and firm-level versions of our 14 tradable bond factors ordered by the average bond-level factor return. Panel A presents the respective average returns, while Panel B shows their differences along with associated 95% standard error bars. For most factors, the return differences are not only statistically insignificant but also economically small; only four factors have average differences that are statistically significant at the 5% level, three of which also generate sizable economic differences. These are all factors that are by construction dependent on bond-level information such as CRY (credit spread), DUR (duration) and STREVB (bond return), i.e., these are the factors where we would not only expect a difference, but where a factor construction using bond-level data is the natural choice. For both CRY and DUR, the bond-level factor returns are around 0.10% higher per month, while for STREVB, this difference is roughly twice as high. At the other end of the spectrum, PEADB generates an additional 0.04% per month on average using firm-level as opposed to bond-level returns.

The results suggest that within a representative firm with multiple bonds outstanding, aggregating returns across the term structure appears to negatively affect factors that capture term structure phenomena (such as CRY and DUR). At the same time, using firm-level returns may be more appropriate when using a signal based on firm- or equity-level characteristics as it will be homogeneous across all of the outstanding bonds. However, as we show in Section IA.10.1, these significant differences ultimately become irrelevant as they pertain to our baseline results and the estimated BMA-SDF.

**Figure IA.5:** Bond factor comparison: Quotes matrix prices vs. quotes only.

*Panel A displays the average monthly bond factor returns constructed at the bond level with the LBFI data using returns computed with both bond price quotes as well as matrix prices and with quotes only. Panel B reports the average return differences in percent. The standard error bars represent the 95% confidence interval. The sample period is 1986:01 to 1996:12 (T = 132).*

*(Page 53)*

#### IA.1.3.2. Quotes vs. quotes & matrix prices

Over the sample period January 1986 to December 1996 the LBFI database uses matrix pricing whereas the BAML ICE database uses a combination of actual transaction prices and indicative bid-side quotes sourced from multiple dealers at 3:00pm Eastern Time (Intercontinental Exchange, 2021). Overall, 39%, 41%, and 31% of all, investment-grade and noninvestment-grade bond prices are set with matrix pricing. To assess pricing differences we follow exactly the same factor construction process as with our baseline LBFI data (including matrix-priced bonds) used in the main results and then proceed to exclude any bond that is not priced with an actual quote. In Panel A of Figure IA.5 show the factor averages over the LBFI sample period January 1986 to December 1996. The return differences are presented in Panel B.

Overall, quote- and quote-matrix-factors are very similar, with the smallest and largest average monthly differences equal to -0.022% for SZE and 0.032% for VAL, respectively. In fact, only VAL has an average return difference that is statistically significant at the 5% level. Thus, our results are consistent with Hong and Warga (2000), Choi (2013), Choi and Richardson (2016) and Chordia et al. (2017), who all find that the impact of removing bonds set with matrix prices on factor premia is quantitatively immaterial.

#### IA.1.3.3. Quotes vs. transaction prices

We now compare the quote-based BAML ICE factors with factors formed using the 2025 version of WRDS TRACE. The time series of the comparison is restricted to August 2002 to December 2022, starting with the commencement of the WRDS TRACE bond return data. Note that the current version of the WRDS TRACE dataset does not truncate bond returns at the +100% level although Dickerson, Robotti and Rossetti (2024) documents that this truncation used in a prior version of the data does not result in material differences to out-of-sample factor premia.

**Figure IA.6:** Bond factor comparison: BAML ICE vs. WRDS TRACE.

*Panel A displays the average monthly bond factor returns constructed at the bond level with the BAML ICE and the WRDS TRACE data, respectively. Panel B reports the average return differences in percent. The standard error bars represent the 95% confidence interval. The sample period is 2002:08 to 2022:12 (T = 245), starting with the first observation in WRDS TRACE.*

Figure IA.6 presents the results comparing WRDS TRACE vs. BAML ICE factors. Across the 14 bond factors, all are very closely aligned. Only a single factor, the credit risk factor (CRF) of Bai et al. (2019) yields a statistically significant difference whereby the average return of the factor formed with the BAML ICE data is larger by just under 0.10% per month. In Figure IA.7 we repeat the exercise using DFPS TRACE using a sample that ends in 2021 (the last available observation in the DFPS TRACE data ends then). Not very surprisingly, the results are not very different. The differences remain economically small at under 0.10% per month, although now, CRY and HMLB exhibit statistically significantly different average returns.

While there is an ongoing debate regarding the use of quotes versus transaction prices in corporate bond research, the differences in average returns are relatively minor at the monthly rebalancing frequency and as long as the data are cleaned and processed appropriately.[^4]

[^4]: See Dickerson et al. (2024) for additional discussion on the differences between transaction vs. quote data.

*(Page 54)*

**Figure IA.7:** Bond factor comparison: BAML ICE vs. DFPS TRACE.

*Panel A displays the average monthly bond factor returns constructed at the bond level with the BAML ICE and the DFPS TRACE data, respectively. Panel B reports the average return differences in percent. The standard error bars represent the 95% confidence interval. The sample period is 2002:08 to 2021:12 (T = 232), starting with the first observation in DFPS TRACE.*

**Figure IA.8:** Principal components and generalized correlations between corporate bonds and stocks.

*Panel A shows the percent variation explained by the first five principal components of the IS stock test assets (49%, 65.1%, 73.2%, 78.2%, 81.8%). Panels B and D show the same information for the corporate bond portfolios constructed using bond excess (66.3%, 84.7%, 88%, 90%, 91.8%) and duration-adjusted bond excess returns (77.4%, 82.9%, 87.1%, 90.3%, 92.2%), respectively. Panels C and E report the respective generalized (canonical) correlations between corporate bonds and stocks. The stock test assets comprise 33 portfolios and the 24 tradable stock factors (N = 57), the bond test assets comprise the 50 portfolios and 16 tradable bond factors (N = 66). The sample period is 1986:01 to 2022:12 (T = 444).*

### IA.1.4. In- and out-of-sample test assets

In Table IA.II we describe the in- and out-of-sample portfolio and anomaly data we use to estimate and test the BMA-SDFs and other asset pricing models we consider in the paper along with the associated reference and source. The IS corporate bond test assets are the 50 IS bond portfolios listed in Panel A in addition to the 16 tradable corporate bond factors from Panel A in Table A.1 of Appendix A. The IS stock test assets are the 33 stock portfolios listed in Panel B in addition to the 25 tradable stock factors from Panel B in Table A.1 of Appendix A.

**Table IA.II:** List of corporate bond, stock and U.S. Treasury bond test assets.

**Panel A: In-sample bond portfolios/anomalies**

| Asset ID | Name and description | Reference | Source |
|---|---|---|---|
| 25 spread/size bond portfolios | 5 Bond credit spread x 5 bond market capitalization double sorted portfolios. | Nozawa (2017) and Elkamhi et al. (2023) | Open Source Bond Asset Pricing |
| 25 rating/maturity bond portfolios | 5 Bond rating x 5 bond time to maturity double sorted portfolios. | Gebhardt et al. (2005) and others | Open Source Bond Asset Pricing |

**Panel B: In-sample stock portfolios/anomalies**

| Asset ID | Name and description | Reference | Source |
|---|---|---|---|
| cash_at | CashAssets. Cash and short term investments scaled by assets. | Palazzo (2012) | Global Factor Data |
| ope_be | FCFBook. Operating profits-to-book equity. | Fama and French (2015) | Global Factor Data |
| ocf_me | CFPrice. Operating cash flow-to-market. | Desai et al. (2004) | Global Factor Data |
| at_turnover | Asset Turnover. Sales scaled by average of total assets. | Haugen and Baker (1996) | Global Factor Data |
| capx_gr2 | CapIntens. CAPEX 2 year growth. | Anderson and Garcia-Feijoo (2006) | Global Factor Data |
| div12m_me | DP tr. Dividend yield. | Litzenberger and Ramaswamy (1979) | Global Factor Data |
| ppeinv_gr1a | PPE delta. Change in property, plant and equipment less inventories scaled by lagged assets. | Lyandres et al. (2008) | Global Factor Data |
| sale_me | SalesPrice. Sales-to-market. | William C. Barbee et al. (1996) | Global Factor Data |
| ret_12_7 | IntermMom. Price momentum t-12 to t-7. | Novy-Marx (2012) | Global Factor Data |
| prc_highprc_252d | YearHigh. Current price to high price over last year. | George and Hwang (2004) | Global Factor Data |
| ni_me | PE tr. Earnings-to-price. | Basu (1983) | Global Factor Data |
| bidaskhl_21d | BidAsk. 21 day high-low bid-ask spread. | Corwin and Schultz (2012) | Global Factor Data |
| dolvol_126d | Volume. Dollar trading volume. | Brennan et al. (1998) | Global Factor Data |
| dsale_dsga | SGASales. Change sales minus change SG&A. | Abarbanell and Bushee (1998) | Global Factor Data |
| cop_atl1 | Cash-based operating profits-to-lagged book assets. | Ball et al. (2016) | Global Factor Data |
| ivol_capm_252d | iVolCAPM. Idiosyncratic volatility from the CAPM (252 days). | Ali et al. (2003) | Global Factor Data |

*(Page 55)*

| Asset ID | Name and description | Reference | Source |
|---|---|---|---|
| ivol_ff3_21d | iVolFF3. Idiosyncratic volatility from the Fama-French 3-factor model. | Ang et al. (2006) | Global Factor Data |
| rvol_21d | Return volatility. | Ang et al. (2006) | Global Factor Data |
| ebit_sale | ProfMargin. Operating profit margin after depreciation. | Soliman (2008) | Global Factor Data |
| ocf_at | PriceCostMargin. Operating cash flow to assets. | Bouchaud et al. (2019) | Global Factor Data |
| opex_at | OperLev. Operating leverage. | Novy-Marx (2011) | Global Factor Data |
| lnoa_gr1a | NetSalesNetOA. Change in long-term net operating assets. | Fairfield et al. (2003) | Global Factor Data |
| oaccruals_at | Operating accruals. | Sloan (1996) | Global Factor Data |
| at_gr1 | Asset growth. Asset growth (1yr). | Cooper et al. (2008) | Global Factor Data |
| eqnpo_12m | Net equity payout (1yr). | Daniel and Titman (2006) | Global Factor Data |
| gp_at | Gross profit scaled by assets. | Novy-Marx (2013) | Global Factor Data |
| capex_abn | Abnormal corporate investment. | Titman et al. (2004) | Global Factor Data |
| noa_at | NetOA. Net operating assets to total assets. | Hirshleifer et al. (2004) | Global Factor Data |
| o_score | Ohlson O-score. | Dichev (1998) | Global Factor Data |
| niq_at | ROA. Quarterly return on assets. | Balakrishnan et al. (2010) | Global Factor Data |
| chcsho_12m | Net stock issues. | Pontiff and Woodgate (2008) | Global Factor Data |
| re_60_12 | LRreversal. Long-run reversal. | De Bondt and Thaler (1985) | Open Asset Pricing |
| debt_me | Lev. Market leverage. | Bhandari (1988) | Open Asset Pricing |

**Panel C: Out-of-sample bond portfolios/anomalies**

| Asset ID | Name and description | Reference | Source |
|---|---|---|---|
| 10x VaR portfolios | Decile sorted bond portfolios sorted on 24-month rolling 95% historical value-at-risk (VaR). | Bai et al. (2019) | Open Source Bond Asset Pricing |
| 10x duration portfolios | Decile sorted bond portfolios sorted on bond duration. | Gebhardt et al. (2005) | Open Source Bond Asset Pricing |
| 10x bond value portfolios | Decile sorted bond portfolios sorted on bond market capitalization. | Houweling and Van Zundert (2017) | Open Source Bond Asset Pricing |
| 10x bond BTM portfolios | Decile sorted bond portfolios sorted on bond book-to-market (BTM). | Bartram et al. (2025) | Open Source Bond Asset Pricing |
| 10x bond LTREV portfolios | Decile sorted bond portfolios sorted on bond long-term reversal. | Bali et al. (2021a) | Open Source Bond Asset Pricing |
| 10x bond MOM portfolios | Decile sorted bond portfolios sorted on bond momentum. | Gebhardt et al. (2005) | Open Source Bond Asset Pricing |
| 17x bond FF17 portfolios | 17 Fama-French industry portfolios computed with bond returns. | Kelly et al. (2023) | Open Source Bond Asset Pricing |

**Panel D: Out-of-sample stock portfolios/anomalies**

| Asset ID | Name and description | Reference | Source |
|---|---|---|---|
| 10x E/P portfolios | Decile sorted stock portfolios sorted on the earnings-to-price ratio (E/P). | Fama & French | Kenneth French webpage |
| 10x MOM portfolios | Decile sorted stock portfolios sorted on equity momentum. | Fama & French | Kenneth French webpage |
| 10x LTREV portfolios | Decile sorted stock portfolios sorted on stock long-term reversals. | Fama & French | Kenneth French webpage |
| 10x accruals portfolios | Decile sorted stock portfolios sorted on equity accruals. | Fama & French | Kenneth French webpage |
| 10x size portfolios | Decile sorted stock portfolios sorted on firm size (market capitalization). | Fama & French | Kenneth French webpage |
| 10x variance portfolios | Decile sorted stock portfolios sorted on earnings-to-price ratio (E/P). | Fama & French | Kenneth French webpage |
| 17x stock FF17 portfolios | 17 Fama-French industry portfolios computed with stock returns. | Fama & French | Kenneth French webpage |

**Panel E: Out-of-sample Treasury portfolios**

| Asset ID | Name and description | Reference | Source |
|---|---|---|---|
| 29x Treasury portfolios | Monthly excess U.S. Treasury bond returns computed across the term structure using annualized continuously-compounded zero coupon yields computed as in Liu and Wu (2021). We price the U.S. Treasury Bonds each month using the yield-curve data and then compute monthly discrete excess returns across the term structure as the total return in excess of the one-month Treasury Bill rate. The portfolios span from the 2-year T Bond up until the 30-year T-Bond in increments of 1-year. | Liu and Wu (2021) | Jing Cynthia Wu webpage |

*(Page 56)*

---

## IA.2. Simulation design

<!-- @section-type: methodology
  @key-claim: Simulation calibrated to match HML pricing of 25 size-value portfolios; includes useless factors and noisy proxies
  @importance: supporting
  @data-source: 25 Fama-French size and value portfolios, HML factor
  @depends-on: Section 2.4.1
  @equations: simulation DGP
-->

We build a simple setting for a linear factor model that includes strong and weak factors and noisy proxies of the strong factors. The cross-section of asset returns is calibrated to mimic the empirical properties of 25 size and value portfolios of Fama-French. All factors and portfolio returns are generated from normal distributions. We calibrate the strong (useful) factor to mimic the HML portfolio. To generate a misspecified setting, we include the pricing errors from the GMM-OLS estimation of the model with HML as the only factor. A useless factor is simulated from an independent normal distribution with mean zero and standard deviation 1%. Noisy proxies, $f_{t,j}$, of the true factors are generated to have correlation $\rho_j$ with the useful factor and the same variance as the latter.

In summary,

$$f_{t,\text{useless}} \stackrel{\text{iid}}{\sim} \mathcal{N}(0, (1\%)^2), \qquad \begin{pmatrix} \mathbf{R}_t \\ f_{t,hml} \end{pmatrix} \stackrel{\text{iid}}{\sim} \mathcal{N}\left(\begin{bmatrix} \bar{\mathbf{R}} \\ \bar{f}_{hml} \end{bmatrix}, \begin{bmatrix} \hat{\boldsymbol{\Sigma}}_R & \widehat{\mathbf{C}}_{hml} \\ \widehat{\mathbf{C}}_{hml}^\top & \hat{\sigma}^2_{hml} \end{bmatrix}\right), \text{ and}$$

$$f_{t,j} = \delta_j f_{t,hml} + \sqrt{1 - \delta_j^2} w_{t,j}, \;\; |\delta_j| < 1, \;\; \text{where } w_{t,j} \stackrel{\text{iid}}{\sim} \mathcal{N}(0, \hat{\sigma}^2_{hml})$$

where the factor loadings, risk prices, and the variance-covariance matrix of returns and factors are equal to their sample estimates from the time series and cross-sectional regressions of the GMM-OLS procedure, applied to 25 size-and-value portfolios and HML as a factor. All the simulation parameters are estimated on monthly data from July 1963 to December 2017. For each sample size and experiment considered, we generate one thousand artificial samples, and in each artificial sample, we estimate the posterior probabilities of the factors, their posterior (mean) market prices of risk, and the BMA-SDF-implied market price of risk.

Figures IA.9 and IA.10 show some additional evidence from simulations that is discussed in Section 2.4.1.

**Figure IA.9:** Simulation evidence in very large and very small samples.

*Simulation results from applying the Bayesian methods to different sets of factors. Each experiment is repeated 1,000 times with the specified sample size (T). Data generating process calibrated to match the pricing ability of the HML factor (as pseudo-true factor) for the Fama-French 25 Size and Book-to-Market portfolios. Horizontal red dashed lines denote the market price of risk of HML, and the grey shaded area the frequentist 95% confidence region of its GMM estimate in the historical sample of 665 monthly observations. The prior is set to 40% of the ex post maximum Sharpe ratio. Half-violin plots depict the distribution of the estimated quantities across simulation, with black error bars denoting centered 95% coverage, and white circles denoting median values. Experiments I-VI use different combinations of useless factor (uf), pseudo-true factor (ftrue), and noisy proxies f1-f4 with correlations .4, .3, .2, and .1. Panels A-B: T=200 and T=20,000 for BMA-SDF MPR. Panels C-D: Factors' MPR. Panels E-F: Posterior probabilities.*

*(Page 57)*

**Figure IA.10:** Simulation evidence with useless factors and noisy proxies, prior Sharpe ratio = 40%.

*Same simulation design as Figure IA.9 but with T=400 (Panels A, C, E) and T=1,600 (Panels B, D, F).*

---

## IA.3. Additional co-pricing results

<!-- @section-type: results
  @key-claim: Factor statistics, posterior probabilities, no-intercept robustness, BMA-SDF vs KNS across 16,383 OS cross-sections, separate pricing of bonds and stocks, time-varying factor importance
  @importance: supporting
  @data-source: same as main paper
  @depends-on: Section 3.1
  @equations: none
-->

In this section we provide additional results to complement the analysis in Section 3.1.

### IA.3.1. The co-pricing SDF

*Factor statistics.* Tables IA.III and IA.IV provide performance statistics such as the Sharpe and Information ratio, average return $\mu$ and a one-factor $\alpha$ using MKTB and MKTS for the tradable bond and stock factors, respectively. The two factors with the highest Sharpe ratios in Table IA.III -- PEADB with a SR of 0.36 and PEAD with a SR of 0.26 -- are also the two tradable factors with the highest posterior probabilities in Figure 2. For comparison, the SR of the bond and stock market factors MKTB and MKTS are 0.19 and 0.15, respectively. Table IA.IV shows the performance statistics for subsamples pre- and post-2000. PEADB displays the highest SR for a bond factor for both subsample periods, whereas PEAD is particularly strong in the first half of the sample. In the second half, the stock factors with the highest SR are BAB and RMWs with a SR of 0.21.

**Table IA.III:** Tradable factor performance statistics: Full sample

| | SR | IR | mu | t-stat. | alpha | t-stat. |
|---|---|---|---|---|---|---|
| **Panel A: Corporate bond factors** | | | | | | |
| CRF | 0.04 | 0.04 | 0.08 | [0.75] | 0.08 | [0.69] |
| CRY | 0.13 | 0.02 | 0.23 | [2.21] | 0.03 | [0.41] |
| DEF | 0.02 | -0.03 | 0.03 | [0.39] | -0.05 | [-0.56] |
| DRF | 0.12 | -0.09 | 0.27 | [2.35] | -0.09 | [-1.88] |
| DUR | 0.08 | -0.15 | 0.14 | [1.66] | -0.14 | **[-2.51]** |
| HMLB | 0.14 | 0.06 | 0.21 | **[2.44]** | 0.09 | [1.19] |
| LTREVB | 0.11 | 0.12 | 0.09 | **[2.09]** | 0.11 | [1.97] |
| MKTB | 0.19 | - | 0.30 | **[3.55]** | - | - |
| MKTBD | 0.06 | -0.01 | 0.08 | [1.05] | -0.02 | [-0.20] |
| MOMB | -0.00 | 0.03 | -0.01 | [-0.10] | 0.04 | [0.53] |
| MOMBS | 0.19 | 0.26 | 0.18 | **[3.69]** | 0.23 | **[4.36]** |
| PEADB | 0.36 | 0.40 | 0.13 | **[7.17]** | 0.14 | **[6.88]** |
| STREVB | 0.04 | 0.00 | 0.07 | [0.95] | 0.00 | [-0.07] |
| SZE | 0.09 | 0.11 | 0.07 | [1.78] | 0.08 | **[2.30]** |
| TERM | 0.12 | 0.01 | 0.36 | **[2.50]** | 0.03 | [0.23] |
| VAL | 0.06 | 0.06 | 0.07 | [1.16] | 0.07 | [0.94] |
| **Panel B: Stock factors** | | | | | | |
| BAB | 0.20 | 0.23 | 0.74 | **[3.52]** | 0.84 | **[3.55]** |
| CMA | 0.14 | 0.20 | 0.29 | **[2.55]** | 0.40 | **[3.45]** |
| CMAs | 0.16 | 0.19 | 0.20 | **[3.24]** | 0.24 | **[3.77]** |
| CPTLT | 0.11 | -0.02 | 0.75 | **[2.21]** | -0.08 | [-0.42] |
| FIN | 0.14 | 0.23 | 0.59 | **[2.78]** | 0.86 | **[4.25]** |
| HML | 0.06 | 0.08 | 0.18 | [1.02] | 0.25 | [1.26] |
| HML_DEV | 0.04 | 0.04 | 0.16 | [0.81] | 0.14 | [0.68] |
| HMLs | 0.06 | 0.07 | 0.10 | [1.01] | 0.12 | [1.19] |
| LIQ | 0.08 | 0.06 | 0.29 | [1.52] | 0.24 | [1.24] |
| LTREV | 0.06 | 0.05 | 0.17 | [1.16] | 0.14 | [0.86] |
| MGMT | 0.18 | 0.26 | 0.52 | **[3.37]** | 0.70 | **[4.33]** |
| MKTS | 0.15 | - | 0.69 | **[3.22]** | - | - |
| MKTSs | 0.17 | 0.12 | 0.56 | **[3.39]** | 0.34 | **[2.27]** |
| MOMS | 0.11 | 0.15 | 0.51 | **[2.3]** | 0.66 | **[3.36]** |
| PEAD | 0.26 | 0.28 | 0.53 | **[5.4]** | 0.56 | **[5.98]** |
| PERF | 0.17 | 0.24 | 0.52 | **[3.4]** | 0.66 | **[4.93]** |
| QMJ | 0.19 | 0.32 | 0.47 | **[3.45]** | 0.69 | **[6.44]** |
| RMW | 0.15 | 0.20 | 0.38 | **[2.95]** | 0.48 | **[3.81]** |
| RMWs | 0.21 | 0.20 | 0.31 | **[4.67]** | 0.31 | **[4.46]** |
| R_IA | 0.14 | 0.20 | 0.31 | **[2.72]** | 0.42 | **[3.55]** |
| R_ROE | 0.18 | 0.24 | 0.49 | **[3.58]** | 0.62 | **[5.35]** |
| SMB | 0.02 | -0.01 | 0.06 | [0.45] | -0.03 | [-0.25] |
| SMBs | 0.03 | 0.04 | 0.06 | [0.58] | 0.08 | [0.72] |
| STREV | 0.07 | 0.02 | 0.24 | [1.69] | 0.06 | [0.45] |

*The table lists corporate bond and stock tradable factor performance statistics. SR is the Sharpe ratio, IR is the Information ratio, mu is the average return, and alpha is the single-factor MKTB (MKTS) alpha. All statistics are reported monthly. mu and alpha are reported in percent. t-statistics are reported in square brackets with Newey-West standard errors computed with four lags. The sample period is 1986:01 to 2022:12.*

*(Page 58-60)*

[Tables IA.IV through IA.IX and Figures IA.11 through IA.12 provide extensive robustness results for subsample factor performance, posterior probabilities and risk prices for the bond, stock, and co-pricing factor zoos with and without intercept. These tables are described in the Internet Appendix sections IA.3.1-IA.3.3. Key findings: (i) top five factors remain consistent (PEADB, PEAD, IVOL, CREDIT, YSP) across specifications; (ii) cumulative SDF-implied Sharpe ratio increases with number of factors, confirming aggregation property; (iii) BMA-SDF outperforms KNS in 96.6% of 16,383 OS cross-sections by R2_GLS.]

### IA.3.2. Cross-sectional asset pricing

*(Page 61)*

*BMA-SDF vs. KNS.* There is a legitimate concern that the strong OS performance of the co-pricing BMA-SDF might be driven by the particular, yet rich, selection of test assets that we use in the main text. To address this concern, we also consider the separate pricing of all the possible combinations of the 14 different cross-sections comprising our OS test assets. Figure IA.13 of the Internet Appendix visualizes the performance of the BMA-SDF vis-a-vis the best competitor, KNS, by depicting the distributions of different measures of fit across $2^{14} - 1 = 16,383$ OS cross-sections. For the cross-sectional $R^2_{OLS}$, RMSE, and MAPE, there is virtually no overlap in the distributions for the co-pricing BMA-SDF and KNS, with the former clearly besting the latter, implying that the Bayesian approach delivers strictly better OS pricing than its best competitor. There is only an overlap in the distribution when considering $R^2_{GLS}$ as the measure of fit, yet the BMA-SDF outperforms KNS in 96.6% of the OS cross-sections and its measure of fit concentrates on much higher values.

*No intercept.* For the baseline analysis in Section 3.1.2 we always include an intercept. In the following, we repeat the previous analysis excluding the intercept. Tables IA.X (IS) and IA.XI (OS) complement Tables 2 (IS) and 3 (OS) by reporting the in- and out-of-sample cross-sectional pricing performance of all models we consider with an estimation that excludes the intercept. Qualitatively, results remain unchanged although most measures of fit for the BMA-SDFs improve at least marginally when the intercept is excluded in the estimation.

*Additional asset specific models.* Following on from the discussion above, we show in Table IA.XII how well the BMA-SDF performs vis-a-vis an additional set of bond and stock factor models. For pricing the cross-section of bond excess and duration-adjusted returns, we compare the in- and out-of-sample performance of the BMA-SDF to (i) the modified three-factor model of Bai et al. (2019) including MKTB, DRF, and CRF bond factors (BBW3), (ii) the two-factor decomposed bond market factor model from van Binsbergen et al. (2025) (DCAPM), (iii) the DEFTERM model of Fama and French (1993), (iv) the MACRO model of Bali et al. (2021b) comprising MKTB and macroeconomic uncertainty UNC, and (v) the six-factor CWW model of Chung et al. (2019) that adds innovations to the VIX index as a sixth factor to the FF5 model of Fama and French (1993). To price the cross-section of excess stock returns, we consider (i) the Carhart (1997) four-factor model that adds MOMS to the Fama and French (1992) three-factor model (FFC4), (ii) the Hou et al. (2015) four-factor model (HXZ4), (iii) the five-factor model of Fama and French (2015) which augments their three-factor model with the RMW and CMA factors (FF5^2015), (v) the FF5* model of Daniel et al. (2020b) which removes unpriced risk from the original FF5 factors, and (vi) the FF6 model which augments the FF5 model with MOMS.

*(Page 62-64)*

**Table IA.XII:** Cross-sectional asset pricing performance: Additional models

| | BMA-SDF | Bond factor models | | | | | Stock factor models | | | | |
|---|---|---|---|---|---|---|---|---|---|---|---|
| | BMA-80% | BBW3 | DCAPM | DEFTERM | MACRO | CWW | FFC4 | HXZ4 | FF5^2015 | FF5* | FF6 |
| **Panel A: In-sample co-pricing** | | | | | | | | | | | |
| RMSE | 0.167 | 0.270 | 0.250 | 0.220 | 0.279 | 0.258 | 0.236 | 0.283 | 0.247 | 0.272 | 0.242 |
| MAPE | 0.125 | 0.217 | 0.192 | 0.171 | 0.222 | 0.198 | 0.174 | 0.236 | 0.193 | 0.217 | 0.193 |
| R2_OLS | 0.487 | -0.342 | -0.158 | 0.103 | -0.438 | -0.231 | -0.029 | -0.478 | -0.125 | -0.367 | -0.083 |
| R2_GLS | 0.285 | 0.087 | 0.080 | 0.077 | 0.083 | 0.087 | 0.091 | 0.116 | 0.111 | 0.127 | 0.117 |
| **Panel B: Out-of-sample co-pricing** | | | | | | | | | | | |
| RMSE | 0.090 | 0.147 | 0.145 | 0.144 | 0.150 | 0.139 | 0.227 | 0.272 | 0.229 | 0.152 | 0.234 |
| MAPE | 0.065 | 0.124 | 0.117 | 0.115 | 0.125 | 0.102 | 0.203 | 0.253 | 0.203 | 0.121 | 0.210 |
| R2_OLS | 0.603 | -0.068 | -0.035 | -0.018 | -0.111 | 0.049 | -1.544 | -2.648 | -1.580 | -0.135 | -1.697 |
| R2_GLS | 0.124 | 0.040 | 0.028 | 0.025 | 0.035 | 0.036 | 0.034 | 0.022 | 0.049 | 0.031 | 0.051 |
| **Panel C: Out-of-sample pricing stocks** | | | | | | | | | | | |
| RMSE | 0.076 | 0.114 | 0.117 | 0.115 | 0.119 | 0.102 | 0.079 | 0.084 | 0.089 | 0.097 | 0.075 |
| MAPE | 0.057 | 0.082 | 0.085 | 0.083 | 0.085 | 0.072 | 0.058 | 0.065 | 0.068 | 0.072 | 0.059 |
| R2_OLS | 0.629 | 0.171 | 0.117 | 0.156 | 0.097 | 0.327 | 0.597 | 0.549 | 0.489 | 0.403 | 0.641 |
| R2_GLS | 0.276 | 0.127 | 0.064 | 0.046 | 0.061 | 0.114 | 0.151 | 0.196 | 0.186 | 0.119 | 0.208 |
| **Panel D: Out-of-sample pricing bonds** | | | | | | | | | | | |
| RMSE | 0.101 | 0.123 | 0.136 | 0.140 | 0.127 | 0.138 | 0.134 | 0.122 | 0.127 | 0.122 | 0.130 |
| MAPE | 0.074 | 0.092 | 0.099 | 0.103 | 0.092 | 0.100 | 0.098 | 0.087 | 0.092 | 0.090 | 0.095 |
| R2_OLS | 0.354 | 0.050 | -0.164 | -0.243 | -0.015 | -0.197 | -0.136 | 0.058 | -0.012 | 0.055 | -0.073 |
| R2_GLS | 0.107 | 0.045 | 0.020 | 0.015 | 0.033 | 0.009 | -0.048 | -0.061 | 0.019 | 0.031 | -0.019 |

The Dick-Nielsen et al. (2025) five-factor corporate bond model (DFPS-5F) is also examined. BMA-SDF outperforms the DFPS model in 60% to 93% of cross-sections depending on the measure of fit and BMA-SDF variant.

**Figure IA.15: OS cross-sectional asset pricing performance: BMA-SDF vs. DFPS-5F (separate pricing).** Same structure as Figure IA.14 but for separate pricing of bonds and stocks (rather than co-pricing). Four panels: (A) $R^2_{GLS}$: Bond BMA = 0.06, Co-pricing BMA = 0.17, DFPS-5F = -0.42. Bond BMA > DFPS = 99.99%, Co-pricing > DFPS = 99.95%. (B) $R^2_{OLS}$: Bond BMA = 0.37, Co-pricing BMA = 0.35, DFPS-5F = 0.21. Bond BMA > DFPS = 81.77%, Co-pricing > DFPS = 75.89%. (C) RMSE: Bond BMA = 0.198, Co-pricing = 0.202, DFPS = 0.219. Bond BMA < DFPS = 81.31%, Co-pricing < DFPS = 75.35%. (D) MAPE: Bond BMA = 0.156, Co-pricing = 0.158, DFPS = 0.175. Bond BMA < DFPS = 83.08%, Co-pricing < DFPS = 79.59%. BMA-SDF dominates DFPS even more decisively under separate pricing than under co-pricing.

**Figure IA.16: OS cross-sectional asset pricing performance: Co-pricing vs. Bond vs. Stock BMA-SDFs.** Four-panel density plot (same legend as Figure 5) comparing the distributions of pricing metrics across $2^{14}-1$ = 16,383 OS cross-sections. Co-pricing BMA (pink), Bond BMA (purple/blue), Stock BMA (yellow). (A) $R^2_{GLS}$ for bonds: Co-pricing = 0.21, Bond BMA = 0.20, Stock BMA = -0.03. (B) $R^2_{OLS}$ for bonds: Co-pricing = 0.33, Bond BMA = 0.29, Stock BMA = -0.43. (C) $R^2_{GLS}$ for stocks: Co-pricing = 0.36, Bond BMA = 0.09, Stock BMA = 0.38. (D) $R^2_{OLS}$ for stocks: Co-pricing = 0.63, Bond BMA = -0.09, Stock BMA = 0.67. Confirms that factor zoos fail at cross-pricing: Bond BMA cannot price stocks (Panel D: $R^2_{OLS}$ = -0.09) and Stock BMA cannot price bonds (Panel B: $R^2_{OLS}$ = -0.43).

*Separate pricing of bonds and stocks.* The co-pricing BMA-SDF can individually price the respective bond and stock cross-sections well, implying that the superior performance of the co-pricing BMA-SDF is not due to the fact that it prices one cross-section better than the other. However, the respective factor zoos fail at "cross-pricing": the bond factor zoo alone is insufficient to price the cross-section of stock returns and vice versa.

### IA.3.3. The saliency of factors over time

To investigate the importance of factors over time, we split our sample in half for two sub-samples with 222 monthly observations each. We first estimate the model for the first subsample spanning July 1986 to June 2004 and then re-estimate every year adding twelve new observations at each iteration. Similarly, we go backwards in time starting with the second subsample from July 2004 to December 2022 and add one year of data at every step. We follow our methodology described in Section 2 and, throughout, we fix the shrinkage at 80% of the corresponding ex post maximum Sharpe ratio for the respective window.

**Figure IA.17: Top-5 factor MPR rankings over time (heatmaps).** Panel A (expanding forward, 2004-2022): Heatmap showing which factors rank in the top 5 by posterior MPR at each estimation window. Factors appearing: MOMBS (consistently rank 1-2), CRY (rank 1-5), PEADB (rank 2-5, appearing from 2006), PEAD (rank 1-3, especially pre-2014), IVOL (rank 2-5 from 2010), QMJ (sporadic), MKTB (rank 1-2 in 2004-2008), MKTS (sporadic, 2016-2017 and 2021). Color intensity: rank 1 = darkest, rank 5 = lightest. Panel B (expanding backward, 2004 back to 1986): PEADB consistently rank 1 across all windows. MOMBS rank 1-2. MKTS (rank 2-5 from mid-1990s onward). QMJ (rank 2-4 from late 1990s). IVOL (rank 1-3 in 2004-1998). CRY (sporadic). PEAD (appears late, rank 2-4 from 1990). CREDIT (rank 2-4 in 2004-2000). LVL (briefly in 2004).

**Figure IA.18: Expanding forward posterior probabilities and MPRs.** Panel A: Posterior probabilities from expanding forward estimation (2004:06 to 2022:12). Most likely factors (solid lines): IVOL rises from ~0.52 to 0.722 (highest at endpoint); PEADB rises from ~0.46 to 0.614; PEAD fluctuates from ~0.52 to 0.618; CREDIT ranges ~0.48-0.56 (endpoint 0.556); YSP fluctuates ~0.50-0.58 (endpoint 0.528). Least likely factors (dashed lines): MKTBD, RMW, DUR, HMLB, DEF all cluster ~0.30-0.36 throughout. Red dashed line at 0.50 = prior probability. NBER recessions shaded. Panel B: Posterior MPRs over same period. PEADB rises from ~0.09 to 0.189 (highest at endpoint); PEAD ranges ~0.13-0.15, endpoint 0.130; IVOL rises from ~0.04 to 0.076; CREDIT rises from ~0.02 to 0.055; YSP fluctuates ~0.00-0.08, endpoint 0.026. Ordering by MPR (PEADB >> PEAD > IVOL > CREDIT > YSP) differs from ordering by probability (IVOL > PEAD > PEADB > CREDIT > YSP), illustrating the distinct information in each quantity.

**Figure IA.19: Expanding backward posterior probabilities and MPRs.** Same structure as Figure IA.18 but expanding backward from 2004:07 toward 1986:01. Panel A: Posterior probabilities converge to the same full-sample endpoints (IVOL = 0.722, PEADB = 0.614, PEAD = 0.618, CREDIT = 0.556, YSP = 0.528). PEADB probability is highest in the early backward windows (~0.72 at 1990-07), while PEAD only rises above 0.50 from about 1993 onward as more early data is added. Panel B: MPRs converge to same full-sample endpoints (PEADB = 0.189, PEAD = 0.130, IVOL = 0.076, CREDIT = 0.055, YSP = 0.026).

### IA.3.4. Commonality in pricing

*(Page 65)*

We gauge the degree of commonality in pricing implications of the factors in the zoo by performing a principal component analysis on the matrix $\mathbf{C}^\top \mathbf{C}$ (in the OLS case, or $\mathbf{C}^\top \boldsymbol{\Sigma}^{-1} \mathbf{C}$ in the GLS case). The largest five principal components of the factor loadings explain more than 99% of their cross-sectional variation (in the OLS case, and more than 80% in the GLS case). This highlights that the factor zoo is akin to a jungle of noisy proxies of common underlying sources of risk.

---

## IA.4. The PEAD factor

<!-- @section-type: robustness
  @key-claim: PEAD and PEADB factors remain robust across size terciles and are not driven by micro-cap stocks
  @importance: supporting
  @data-source: Open Asset Pricing, CRSP
  @depends-on: Section 3.1.1
  @equations: none
-->

*(Page 66)*

Recent work by Martineau (2022) documents that, in the time series, the (stock) PEAD effect has diminished in recent years. While the author raises interesting points regarding the decay in time series predictability of PEAD, he does not comment on the robustness of using PEAD to form long-short portfolios (i.e., the cross-sectional predictability of PEAD within a portfolio context). In this section, we document that this dimension of the PEAD factor remains robust and is not driven purely by micro-cap stocks. In addition, we confirm the same result for the corporate bond version of the PEAD factor (i.e., PEADB).

To form the bond and stock PEAD factors, we first form tercile portfolios based on firm market capitalization. Thereafter, within each size tercile, we create quintile portfolios sorted on earnings announcement returns, `AnnouncementReturn`, obtained from Open Asset Pricing. Each PEAD factor is long in Q5 (high PEAD) and short Q1 (low PEAD), within each size tercile.[^5] We denote the small, mid and large cap PEAD factor as Small, Mid and Large respectively.

[^5]: Daniel et al. (2020a) are conservative with their choice of portfolio breakpoints and form PEAD with a two-by-three sort on size and earnings-announcement returns.

**Table IA.XIII:** Stock post-earnings announcement drift (PEAD) factors

| | 1986:01-2022:12 | | | 1986:01-1999:12 | | | 2000:01-2022:12 | | |
|---|---|---|---|---|---|---|---|---|---|
| | Small | Mid | Large | Small | Mid | Large | Small | Mid | Large |
| **Panel A: Excluding micro-cap (VW)** | | | | | | | | | |
| Ave. Ret | 1.34 | 0.95 | 0.45 | 1.32 | 1.50 | 0.84 | 1.35 | 0.61 | 0.20 |
| t-stat | **(11.45)** | **(8.46)** | **(3.14)** | **(10.27)** | **(10.66)** | **(4.57)** | **(7.88)** | **(3.92)** | (1.03) |
| Alpha | 1.30 | 0.98 | 0.54 | 1.25 | 1.54 | 0.83 | 1.32 | 0.60 | 0.27 |
| t-stat | **(9.29)** | **(7.01)** | **(3.90)** | **(9.64)** | **(11.26)** | **(4.67)** | **(6.54)** | **(3.75)** | (1.54) |
| SR | 0.54 | 0.40 | 0.15 | 0.79 | 0.82 | 0.35 | 0.47 | 0.24 | 0.06 |
| IR | 0.55 | 0.43 | 0.19 | 0.77 | 0.87 | 0.35 | 0.49 | 0.25 | 0.09 |
| **Panel B: Including micro-cap (VW)** | | | | | | | | | |
| Ave. Ret | 1.26 | 0.78 | 0.44 | 1.45 | 1.40 | 0.85 | 1.15 | 0.41 | 0.20 |
| t-stat | **(11.23)** | **(7.28)** | **(3.25)** | **(11.87)** | **(10.41)** | **(4.72)** | **(6.98)** | **(2.74)** | (1.04) |
| Alpha | 1.24 | 0.87 | 0.52 | 1.46 | 1.45 | 0.84 | 1.09 | 0.48 | 0.25 |
| t-stat | **(9.68)** | **(6.67)** | **(3.98)** | **(13.67)** | **(12.61)** | **(4.87)** | **(6.16)** | **(3.12)** | (1.52) |
| SR | 0.53 | 0.35 | 0.15 | 0.92 | 0.80 | 0.36 | 0.42 | 0.16 | 0.06 |
| IR | 0.55 | 0.40 | 0.19 | 0.94 | 0.87 | 0.37 | 0.43 | 0.21 | 0.08 |
| **Panel C: Excluding micro-cap (EW)** | | | | | | | | | |
| Ave. Ret | 1.25 | 1.08 | 0.52 | 1.20 | 1.61 | 1.03 | 1.28 | 0.75 | 0.21 |
| t-stat | **(10.19)** | **(9.77)** | **(4.77)** | **(8.20)** | **(11.84)** | **(7.45)** | **(7.26)** | **(4.88)** | (1.37) |
| Alpha | 1.18 | 1.10 | 0.62 | 1.10 | 1.67 | 1.11 | 1.22 | 0.73 | 0.29 |
| t-stat | **(7.68)** | **(7.95)** | **(5.43)** | **(6.98)** | **(12.07)** | **(7.75)** | **(5.58)** | **(4.71)** | **(2.26)** |
| SR | 0.48 | 0.46 | 0.23 | 0.63 | 0.91 | 0.57 | 0.44 | 0.29 | 0.08 |
| IR | 0.48 | 0.49 | 0.29 | 0.60 | 0.98 | 0.65 | 0.44 | 0.31 | 0.13 |
| **Panel D: Including micro-cap (EW)** | | | | | | | | | |
| Ave. Ret | 1.26 | 0.82 | 0.42 | 1.41 | 1.48 | 0.90 | 1.17 | 0.42 | 0.13 |
| t-stat | **(11.28)** | **(7.56)** | **(3.97)** | **(11.81)** | **(10.78)** | **(6.50)** | **(7.11)** | **(2.82)** | (0.88) |
| Alpha | 1.26 | 0.89 | 0.50 | 1.41 | 1.54 | 0.98 | 1.15 | 0.46 | 0.18 |
| t-stat | **(9.91)** | **(6.65)** | **(4.76)** | **(13.64)** | **(12.55)** | **(6.55)** | **(6.48)** | **(3.13)** | (1.48) |
| SR | 0.54 | 0.36 | 0.19 | 0.91 | 0.83 | 0.50 | 0.43 | 0.17 | 0.05 |
| IR | 0.56 | 0.40 | 0.24 | 0.93 | 0.91 | 0.57 | 0.46 | 0.20 | 0.08 |

*Ave. Ret is the average monthly return in percent. Alpha is the monthly Fama-French five-factor alpha in percent. t-statistics are adjusted using the Newey-West procedure with 4 lags.*

---

## IA.5. Discount rate and cash-flow news decomposition

<!-- @section-type: methodology
  @key-claim: Tradable factor returns decomposed into discount rate and cash-flow news via VAR methodology
  @importance: supporting
  @data-source: CRSP, Compustat, Amit Goyal repository, Gilchrist-Zakrajsek credit spread
  @depends-on: Section 3.1.4
  @equations: IA.1
-->

*(Page 69)*

### IA.5.1. Tradable factor return decomposition

Vuolteenaho (2002), Cohen et al. (2002), and others decompose unexpected asset returns into an expected return (discount rate) component on the one hand and a cash-flow component on the other hand:

$$r_{t+1} - E_t r_{t+1} = \Delta E_{t+1} \sum_{j=0}^{\infty} \rho^j e_{t+1+j} - \Delta E_{t+1} \sum_{j=1}^{\infty} \rho^j r_{t+1+j},$$

where $\Delta E_{t+1}$ denotes the change in expectations from $t$ to $t + 1$ (i.e., $E_{t+1}(\cdot) - E_t(\cdot)$), $e_{t+1}$ the aggregate return on equity (ROE), and $r_{t+1}$ the log asset return. $\rho$ is determined by the data, and in our setting is equal to 0.979, although any value between 0.95 and 1.00 does not materially affect the results.

We define the two return components as discount rate ($N_r$, DR) and cash-flow news ($N_{cf}$, CF), respectively:

$$N_{r,t+1} = \Delta E_{t+1} \sum_{j=1}^{\infty} \rho^j r_{t+1+j}, \qquad N_{cf,t+1} = \Delta E_{t+1} \sum_{j=0}^{\infty} \rho^j e_{t+1+j}.$$

### IA.5.2. Implementation using the VAR methodology

*(Page 70)*

To empirically estimate the decomposition, we implement a parsimonious vector autoregression (VAR). The behavior of the tradable factors is captured by a vector, $z_{i,t}$ of state variables. The first variable is always the tradable bond or stock factor, whilst the remaining variables could be any set of predictors that are associated with future stock or bond returns. We define the vector, $z_t = [r_t, roe_t, bm_t, gz_t]$, where $r_t$ is the tradable factor return, $roe_t$ is the log of aggregate return on equity (ROE), $bm_t$ is the log of the aggregate book-to-market ratio, and $gz_t$ is the first difference of the log of the Gilchrist and Zakrajsek (2012) aggregate credit spread (GZ).

The vector of state variables, $z_t$ is assumed to follow a first-order VAR,

$$z_{t+1} = Az_t + u_{t+1}$$

From the VAR, we estimate discount rate news as,

$$N_{dr,t+1} = (E_{t+1} - E_t) \sum_{j=1}^{\infty} \rho^j r_{t+1+j} = e_1' \sum_{j=1}^{\infty} \rho^j A^j u_{t+1} = e_1' \rho A(I - \rho A)^{-1} u_{t+1} = \lambda' u_{t+1}, \tag{IA.1}$$

where $\lambda' = e_1' \rho A(I - \rho A)^{-1}$ and $e_1$ is a vector whose first element is equal to one and zero otherwise. The cash-flow news component is computed as the residual of the total unexpected factor return and discount rate news,

$$Ncf_{t+1} = r_{t+1} - E_t r_{t+1} + Ndr = (e_1' + \lambda')u_{t+1}.$$

*(Page 71-72)*

**Figure IA.20:** The factor jungle: Commonality in cross-sectional pricing.

*Principal component decomposition of the matrix $H = \hat{C}^\top W \hat{C}$ where $\hat{C} \in \mathbb{R}^{N \times K}$ denotes the posterior mean of the covariance matrix of factors and returns, and $W$ is either an identity matrix (OLS case) or the inverse of the (posterior mean of the) covariance matrix of the test assets (GLS case). Panel A (OLS, IS): PC1 = 73.4%, PC2 = 87.0%, PC3 = 97.6%, PC4 = 98.9%, PC5 = 99.7%. Panel B (OLS, OS): PC1 = 85.4%, PC2 = 93.4%, PC3 = 97.6%, PC4 = 99.6%, PC5 = 99.9%. Panel C (GLS, IS): PC1 = 45.8%, PC2 = 61.7%, PC3 = 71.0%, PC4 = 77.2%, PC5 = 82.5%. Panel D (GLS, OS): PC1 = 44.7%, PC2 = 60.4%, PC3 = 69.6%, PC4 = 75.5%, PC5 = 80.9%.*


*(Page 73)*

<!-- @section-type: table
  @key-claim: Corporate bond PEAD factors generate significant returns across size groups and sample periods
  @importance: supporting
  @data-source: LBFI/BAML ICE corporate bond data, 1986:01-2022:12
  @depends-on: IA.4 (PEADB factor construction)
  @equations: none
-->

## Table IA.XIV: Corporate bond post-earnings announcement drift (PEADB) factors

This table presents the performance of the Corporate Bond Post-Earnings Announcement Drift (PEADB) factors across different bond market capitalization groups (Small, Mid, Large) and sample periods. For each size group, bonds are conditionally sorted into quintiles based on PEAD. The respective PEAD factor is long Q5 and short Q1. Panel A and C exclude micro-cap bonds (bottom 20% by market cap) at the portfolio formation month $t$, while Panel B and D include all bonds. Panels A and B use value-weights by bond market capitalization, while Panels C and D use equal-weights. Ave. Ret is the average monthly return in percent. Alpha is the monthly bond market one-factor alpha in percent. $t$-statistics are reported in parentheses and are adjusted using the Newey-West procedure with 4 lags, chosen as the integer component of $T^{1/4}$ following Greene (2012). SR is the monthly Sharpe ratio. IR is the monthly information ratio (alpha divided by residual volatility).

|  | 1986:01-2022:12 |  |  | 1986:01-1999:12 |  |  | 2000:01-2022:12 |  |  |
|--|--|--|--|--|--|--|--|--|--|
|  | Small | Mid | Large | Small | Mid | Large | Small | Mid | Large |
| **Panel A: Excluding micro-cap bonds (equally weighted)** | | | | | | | | | |
| Ave. Ret | 0.25 | 0.18 | 0.16 | 0.16 | 0.11 | 0.11 | 0.30 | 0.22 | 0.19 |
| *t*-stat | **(5.60)** | **(6.29)** | **(5.79)** | **(4.17)** | **(3.74)** | **(4.00)** | **(4.50)** | **(5.24)** | **(4.64)** |
| Alpha | 0.30 | 0.19 | 0.18 | 0.16 | 0.11 | 0.10 | 0.37 | 0.24 | 0.22 |
| *t*-stat | **(5.35)** | **(5.54)** | **(5.70)** | **(3.99)** | **(3.70)** | **(3.66)** | **(4.54)** | **(4.87)** | **(4.99)** |
| SR | 0.27 | 0.30 | 0.27 | 0.32 | 0.29 | 0.31 | 0.27 | 0.32 | 0.28 |
| IR | 0.33 | 0.33 | 0.32 | 0.33 | 0.27 | 0.29 | 0.35 | 0.36 | 0.35 |
| **Panel B: Including micro-cap bonds (value weighted)** | | | | | | | | | |
| Ave. Ret | 0.20 | 0.18 | 0.15 | 0.16 | 0.11 | 0.11 | 0.23 | 0.23 | 0.17 |
| *t*-stat | **(5.65)** | **(6.84)** | **(5.35)** | **(3.95)** | **(3.78)** | **(3.78)** | **(4.37)** | **(5.81)** | **(4.23)** |
| Alpha | 0.23 | 0.20 | 0.17 | 0.16 | 0.11 | 0.10 | 0.26 | 0.25 | 0.21 |
| *t*-stat | **(5.29)** | **(6.20)** | **(5.54)** | **(3.77)** | **(4.15)** | **(3.27)** | **(4.32)** | **(5.40)** | **(4.81)** |
| SR | 0.27 | 0.32 | 0.25 | 0.30 | 0.29 | 0.29 | 0.26 | 0.35 | 0.25 |
| IR | 0.31 | 0.36 | 0.29 | 0.30 | 0.29 | 0.27 | 0.32 | 0.40 | 0.31 |
| **Panel C: Excluding micro-cap bonds (equally weighted)** | | | | | | | | | |
| Ave. Ret | 0.25 | 0.18 | 0.16 | 0.14 | 0.11 | 0.09 | 0.31 | 0.22 | 0.20 |
| *t*-stat | **(4.64)** | **(6.13)** | **(6.13)** | **(3.43)** | **(3.57)** | **(4.25)** | **(3.82)** | **(5.12)** | **(5.04)** |
| Alpha | 0.30 | 0.19 | 0.18 | 0.14 | 0.11 | 0.09 | 0.39 | 0.24 | 0.23 |
| *t*-stat | **(4.83)** | **(5.46)** | **(5.43)** | **(3.10)** | **(3.52)** | **(3.92)** | **(4.26)** | **(4.81)** | **(4.89)** |
| SR | 0.22 | 0.29 | 0.29 | 0.26 | 0.28 | 0.33 | 0.23 | 0.31 | 0.30 |
| IR | 0.28 | 0.32 | 0.35 | 0.27 | 0.26 | 0.32 | 0.31 | 0.36 | 0.38 |
| **Panel D: Including micro-cap bonds (equally weighted)** | | | | | | | | | |
| Ave. Ret | 0.20 | 0.19 | 0.15 | 0.16 | 0.12 | 0.09 | 0.23 | 0.23 | 0.18 |
| *t*-stat | **(5.71)** | **(6.83)** | **(5.60)** | **(4.07)** | **(3.88)** | **(3.90)** | **(4.42)** | **(5.75)** | **(4.54)** |
| Alpha | 0.23 | 0.20 | 0.17 | 0.15 | 0.12 | 0.09 | 0.27 | 0.25 | 0.22 |
| *t*-stat | **(5.31)** | **(6.27)** | **(5.23)** | **(3.78)** | **(4.36)** | **(3.35)** | **(4.36)** | **(5.38)** | **(4.69)** |
| SR | 0.27 | 0.32 | 0.27 | 0.31 | 0.30 | 0.30 | 0.27 | 0.35 | 0.27 |
| IR | 0.31 | 0.36 | 0.32 | 0.31 | 0.30 | 0.29 | 0.32 | 0.39 | 0.35 |

---

<!-- @section-type: figure
  @key-claim: Bond factors are more frequently driven by discount rate news (62%) while stock factors lean toward cash-flow news (53%)
  @importance: supporting
  @data-source: Vuolteenaho (2002) VAR decomposition with Amit Goyal predictors
  @depends-on: IA.5 (factor decomposition methodology)
  @equations: IA.1
-->

## Figure IA.21: Tradable factors decomposition: Discount rate and cash-flow news

**Description:** Bar chart showing ordered ratios of the variance of the discount rate news component to total variance of residuals, $\mathbb{V}(N_{dr})/\mathbb{V}(u)$, for each bond and stock tradable factor (estimated using equation (IA.1) in Internet Appendix IA.5). The dashed horizontal line denotes the median value of the ratio (0.39). Bond factors are displayed in blue while stock factors are displayed in red on the x-axis.

**Key takeaway:** DR factors (left side, above median) include MKTB, MKTSs, MOMBS, PEADB, CRY, PERF, HMLs, PEAD, DRF, QMJ, DUR, HMLB, MGMT, MOMS, LIQ, SMBs. CF factors (right side, below median) include CMAs, TERM, MOMB, MKTBD, MKTS, CMA, BAB, DEF, STREVB, CRF, HML, SZE, RMW, R_ROE, FIN, R_IA, VAL, LTREVB, LTREV, STREV, CPTLT, RMWs, SMB, HML_DEV.

predictors in Amit Goyal's data library.

*Thousands VARs.* Finally, we perform a further extensive robustness exercise to alleviate concerns about potential data uncertainty by first fixing the number of predictors in the VAR to three. Then, we estimate 7,700 possible combinations of VARs with the set of 37 predictors.

---

*(Page 74)*

<!-- @section-type: table
  @key-claim: Factor DR/CF classification is consistent across three VAR approaches for most factors
  @importance: supporting
  @data-source: Three VAR methods (Vuolteenaho, PCA, 7770 VARs)
  @depends-on: IA.5 (factor decomposition)
  @equations: IA.1
-->

## Table IA.XV: Tradable factors decomposition: Discount rate and cash-flow news robustness

This table presents variance decomposition results showing the variance of the discount rate news component to total variance of the residuals, $\mathbb{V}(N_{dr})/\mathbb{V}(u)$ and classification (DR/CF) for each factor across three different approaches. The factors are ordered alphabetically. 'Vuolteenaho' uses the method proposed by Vuolteenaho (2002) using three predictors. The 'PCA' method follows the advice of Chen and Zhao (2009) and uses the first five principal components estimated using 37 predictors from Amit Goyal's website. The '7,770 VARs' method estimates the average DR and CF components across 7,770 VARs with combinations of three predictors from the total set of 37. The 'Match' column displays how often the three methods predict the same classification.

| Factor | Vuolteenaho | PCA | 7,770 VARs | Vuolteenaho | PCA | 7,770 VARs | Match |
|--------|-------------|-----|------------|-------------|-----|------------|-------|
| BAB | 0.32 | 0.36 | 0.32 | CF | CF | CF | 3/3 |
| CMA | 0.32 | 0.66 | 0.33 | CF | CF | CF | 3/3 |
| CMAs | 0.47 | 1.15 | 0.41 | DR | DR | DR | 3/3 |
| CPTLT | 0.11 | 0.20 | 0.21 | CF | CF | CF | 3/3 |
| CRF | 0.27 | 0.43 | 0.25 | CF | CF | CF | 3/3 |
| CRY | 0.93 | 1.81 | 0.86 | DR | DR | DR | 3/3 |
| DEF | 0.30 | 0.93 | 0.71 | CF | DR | DR | 2/3 |
| DRF | 0.72 | 1.61 | 0.70 | DR | DR | DR | 3/3 |
| DUR | 0.60 | 0.93 | 0.29 | DR | DR | CF | 2/3 |
| FIN | 0.17 | 0.26 | 0.15 | CF | CF | CF | 3/3 |
| HML | 0.22 | 0.48 | 0.25 | CF | CF | CF | 3/3 |
| HMLB | 0.57 | 2.12 | 1.07 | DR | DR | DR | 3/3 |
| HML_DEV | 0.08 | 0.33 | 0.37 | CF | CF | CF | 3/3 |
| HMLs | 0.80 | 0.94 | 0.38 | DR | DR | CF | 2/3 |
| LIQ | 0.52 | 1.27 | 0.49 | DR | DR | DR | 3/3 |
| LTREV | 0.14 | 0.43 | 0.26 | CF | CF | CF | 3/3 |
| LTREVB | 0.14 | 0.81 | 0.47 | CF | DR | DR | 2/3 |
| MGMT | 0.57 | 0.99 | 0.43 | DR | DR | DR | 3/3 |
| MKTB | 1.42 | 2.34 | 0.89 | DR | DR | DR | 3/3 |
| MKTBD | 0.39 | 1.02 | 0.68 | DR | DR | DR | 3/3 |
| MKTS | 0.38 | 0.63 | 0.39 | CF | CF | CF | 3/3 |
| MKTSs | 1.19 | 1.98 | 0.89 | DR | DR | DR | 3/3 |
| MOMB | 0.41 | 0.74 | 0.41 | DR | CF | CF | 2/3 |
| MOMBS | 1.16 | 1.68 | 0.78 | DR | DR | DR | 3/3 |
| MOMS | 0.54 | 1.35 | 0.84 | DR | DR | DR | 3/3 |
| PEAD | 0.80 | 1.20 | 0.66 | DR | DR | DR | 3/3 |
| PEADB | 1.00 | 1.78 | 0.84 | DR | DR | DR | 3/3 |
| PERF | 0.93 | 1.36 | 0.58 | DR | DR | DR | 3/3 |
| QMJ | 0.67 | 0.99 | 0.38 | DR | DR | CF | 2/3 |
| RMW | 0.19 | 0.16 | 0.09 | CF | CF | CF | 3/3 |
| RMWs | 0.10 | 0.15 | 0.14 | CF | CF | CF | 3/3 |
| R_IA | 0.16 | 0.51 | 0.29 | CF | CF | CF | 3/3 |
| R_ROE | 0.18 | 0.68 | 0.38 | CF | CF | CF | 3/3 |
| SMB | 0.09 | 0.56 | 0.37 | CF | CF | CF | 3/3 |
| SMBs | 0.50 | 0.87 | 0.49 | DR | DR | DR | 3/3 |
| STREV | 0.12 | 0.10 | 0.11 | CF | CF | CF | 3/3 |
| STREVB | 0.27 | 0.76 | 0.38 | CF | CF | CF | 3/3 |
| SZE | 0.20 | 0.79 | 0.51 | CF | CF | DR | 2/3 |
| TERM | 0.43 | 0.73 | 0.43 | DR | CF | DR | 2/3 |
| VAL | 0.15 | 0.68 | 0.65 | CF | CF | DR | 2/3 |

### IA.5.3. Factor decomposition

We now implement the VARs and decompose each tradable factor into the component related to either discount rate or cash-flow news across the three methods discussed above. Following Vuolteenaho (2002) and Cohen, Gompers and Vuolteenaho (2002) we compute the variance of the discount rate news component, $\mathbb{V}(N_{dr})$ and the ratio of the discount rate news variance to total unexpected factor return variance $\frac{\mathbb{V}(N_{dr})}{\mathbb{V}(u)}$. To pin down a relative classification of the factors into a discount rate or cash-flow news category, we use the median level of $\frac{\mathbb{V}(N_{dr})}{\mathbb{V}(u)}$ as a break-point. Factors above the break-point are classified (relatively) as more likely to capture discount rate news as opposed to cash-flow rate news. In Table IA.XV we present the $\frac{\mathbb{V}(N_{dr})}{\mathbb{V}(u)}$ and the classification (DR/CF) and the 'Match' column which displays a number out of three, illustrating how often the methods predict the same classification. Importantly, the classification remains consistent across all three approaches we consider. We focus on the 'Vuolteenaho' column, since these results pertain to the baseline results presented in Section 3.1.4.

We present the results of the Vuolteenaho (2002) decomposition in Figure IA.21. The y-axis of the figure shows the proportion of residual variance of each factor estimated from the VAR model that represents discount rate news. Overall, 10 of the 16 bond factors (62%) are driven relatively more by discount rate news as opposed to cash-flow news shocks. In contrast, slightly more stock factors (14/26=53%) are driven by cash-flow news shocks. However, this classification is a function of our estimated VARs. Thus, just because a factor is classified as (relatively) more either DR- or CF-based, does not mean that this factor cannot capture other asset pricing phenomena.

*(Page 75)*

The two most likely factors that ought to be included in the co-pricing BMA-SDF (i.e., PEAD and PEADB) are driven relatively more by discount rate news as opposed to cash-flow news. For a discussion on how PEAD and PEADB could be linked to both news sources via accounting (earnings) reports see Penman and Yehuda (2019). Most other behavioral-linked factors such as MOMBS (bond factor formed with equity momentum), PERF and MGMT (equity and management performance factor of Stambaugh and Yuan (2017)), are also classified as relatively more discount rate news-based.

---

<!-- @section-type: methodology
  @key-claim: Duration-adjusted corporate bond returns isolate the credit component by removing duration-matched Treasury returns
  @importance: core
  @data-source: LBFI/BAML ICE corporate bonds, U.S. Treasury bonds
  @depends-on: Section 3.3
  @equations: 10
-->

## IA.6. The Treasury component

Duration-adjusted corporate bond returns are computed for each bond $i$ at each time $t$ such that the resultant bond return is in 'excess' of a portfolio of duration-matched U.S. Treasury bond returns (van Binsbergen et al. (2025), Andreani et al. (2023)).

Start with the total return for corporate bond $i$ in month $t$:

$$R_{it} = \frac{B_{it} + AI_{it} + Coupon_{ijt}}{B_{it-1} + AI_{it-1}} - 1,$$

where $B_{it}$ is the clean price of bond $i$ in month $t$, $AI_{it}$ is the accrued interest, and $Coupon_{it}$ is the coupon payment, if any.

The bond duration-adjusted (or credit excess) return is the total bond return minus the return on a hedging portfolio of U.S. Treasury securities that has the same duration as the bond in month $t$. Thus, the duration-adjusted return isolates the portion of a bond's performance that is attributed to the credit risk of each bond (including other non-interest rate-related risks).

In equation (10) we define the duration-adjusted return as

$$\underbrace{R_{bond\,i,t} - R^{Treasury}_{dur\,bond\,i,t}}_{\text{Duration-adjusted return}} = \underbrace{R_{bond\,i,t} - R_{f,t}}_{\text{Excess return}} - \underbrace{\left(R^{Treasury}_{dur\,bond\,i,t} - R_{f,t}\right)}_{\text{Treasury component}} \tag{10}$$

where $R_{bond\,i,t}$ is the return of bond $i$ at time $t$, $R_{f,t}$ denotes the short-term risk-free rate, and $R^{Treasury}_{dur\,bond\,i,t}$ denotes the return on a portfolio of Treasury securities with the same duration as bond $i$ (constructed as in van Binsbergen et al. (2025)). The duration adjustment removes the implicit Treasury component from the bond excess return, hence isolating the remaining sources of risk compensation that investing in a given bond entails.

### IA.6.1. Pricing duration-adjusted corporate bond returns

We use duration-adjusted returns to re-compute the tradable bond factor returns and returns on bond test assets. In Section 3.3 we show that once corporate bond returns are adjusted for duration, the BMA-SDF based only on equity information jointly prices (duration-adjusted) corporate bond and stock returns as well as the co-pricing BMA-SDF that additionally includes bond factors. That is, the information content of the bond factor zoo becomes largely irrelevant for co-pricing once the Treasury component of bond returns is removed. In Table IA.XVI we repeat the in- and out-of-sample cross-sectional asset pricing exercises from Tables 2 and 3, respectively. That is, we estimate the co-pricing as well as the bond BMA-SDFs using duration-adjusted corporate bond test portfolios and tradable corporate bond factors. The resulting BMA-SDFs are then again used to price (with no additional parameter estimation) the OS test assets. In Panel C the OS test assets are the combined 154 bond and stock portfolios and in Panel D they are the 77 bond portfolios as described in Section 1. The results complement the information in Figure 8 and show how our co-pricing and bond BMA-SDFs still outperform all competitors out-of-sample.

In Table IA.XVII we repeat the analysis from Table IA.XII using duration-adjusted returns to assess how the BMA-SDF performs vis-a-vis the additional set of bond and stock factor models. Again, the BMA-SDFs outperform all additional models originally designed to price the individual bond and stock cross-sections, respectively.

### IA.6.2. Pricing the Treasury component

As per equation (10), the duration adjustment of corporate bond returns also yields Treasury components of corporate bond test assets that can be used for asset pricing exercises. In particular, we can estimate "Treasury component BMA-SDFs" using either the bond or stock factor zoos described in Appendix A (whereby the bond factors are *not* duration adjusted). For both exercises we use the Treasury component of the 50 bond portfolios as IS test assets and we do not impose self-pricing on the bond or stock factors, respectively. Figure 9 shows how the Treasury component bond BMA-SDF can price the Treasury component IS while the Treasury component stock BMA-SDF fails to do so. Mirroring the results presented in Section 3.1, Figure IA.22 shows the posterior SDF dimensionality and the distribution of Sharpe ratios when pricing the Treasury component using only the 14 nontradable and the 16 tradable bond factors (again, without self-pricing). While the median

*(Page 76)*

<!-- @section-type: table
  @key-claim: BMA-SDF outperforms all benchmarks pricing duration-adjusted bond returns both in- and out-of-sample
  @importance: core
  @data-source: Duration-adjusted corporate bond portfolios, 1986:01-2022:12
  @depends-on: IA.6 (duration adjustment), Tables 2 and 3
  @equations: 10
-->

## Table IA.XVI: Cross-sectional asset pricing performance: Duration-adjusted bond returns

The table presents the cross-sectional in and out-of-sample asset pricing performance of different models pricing (duration-adjusted) bonds and stocks jointly (Panels A and C), and (duration-adjusted) bonds only (Panels B and D), respectively. For the BMA-SDF, we provide results for prior Sharpe ratio values set to 20%, 40%, 60% and 80% of the ex post maximum Sharpe ratio of the test assets. TOP includes the top five factors with an average posterior probability greater than 50%. CAPM is the standard single-factor model using MKTS, and CAPMB is the bond version using MKTB. FF5 is the five-factor model of Fama and French (1993), HKM is the two-factor model of He et al. (2017). KNS stands for the SDF estimation of Kozak et al. (2020) and RPPCA is the risk premia PCA of Lettau and Pelger (2020). Bond returns are computed in excess of a duration matched portfolio of U.S. Treasury bonds. IS test assets are the 83 bond and stock portfolios and the 40 tradable bond and stock factors (Panel A), and the 50 bond portfolios and 16 tradable bond factors (Panel B), respectively. OS test assets are the combined 154 bond and stock portfolios (Panel C), as well as the 77 bond portfolios only (Panel D). The sample period is 1986:01 to 2022:12 ($T = 444$).

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: In-sample co-pricing stocks and bonds** | | | | | | | | | | | |
| RMSE | 0.203 | 0.197 | 0.186 | 0.174 | 0.326 | 0.297 | 0.278 | 0.324 | 0.294 | 0.157 | 0.219 |
| MAPE | 0.147 | 0.141 | 0.135 | 0.128 | 0.274 | 0.245 | 0.216 | 0.272 | 0.245 | 0.117 | 0.137 |
| $R^2_{OLS}$ | 0.106 | 0.157 | 0.246 | 0.339 | -1.310 | -0.913 | -0.675 | -1.282 | -0.885 | 0.465 | -0.047 |
| $R^2_{GLS}$ | 0.052 | 0.120 | 0.191 | 0.252 | 0.024 | 0.028 | 0.033 | 0.024 | 0.209 | 0.177 | 0.184 |
| **Panel B: In-sample pricing bonds** | | | | | | | | | | | |
| RMSE | 0.169 | 0.138 | 0.112 | 0.101 | 0.201 | 0.217 | 0.179 | 0.183 | 0.198 | 0.117 | 0.162 |
| MAPE | 0.103 | 0.088 | 0.080 | 0.076 | 0.120 | 0.119 | 0.088 | 0.111 | 0.143 | 0.069 | 0.110 |
| $R^2_{OLS}$ | 0.093 | 0.396 | 0.601 | 0.676 | -0.270 | -0.484 | -0.018 | -0.059 | -0.237 | 0.569 | 0.171 |
| $R^2_{GLS}$ | 0.057 | 0.187 | 0.324 | 0.430 | 0.003 | 0.036 | 0.068 | 0.019 | 0.412 | 0.262 | 0.243 |
| **Panel C: Out-of-sample co-pricing stocks and bonds** | | | | | | | | | | | |
| RMSE | 0.178 | 0.158 | 0.138 | 0.125 | 0.121 | 0.168 | 0.106 | 0.120 | 0.342 | 0.159 | 0.112 |
| MAPE | 0.158 | 0.139 | 0.119 | 0.106 | 0.093 | 0.146 | 0.078 | 0.091 | 0.315 | 0.144 | 0.086 |
| $R^2_{OLS}$ | 0.045 | 0.246 | 0.423 | 0.528 | 0.558 | 0.143 | 0.658 | 0.568 | -2.525 | 0.235 | 0.624 |
| $R^2_{GLS}$ | 0.030 | 0.058 | 0.078 | 0.097 | 0.024 | 0.002 | 0.023 | 0.025 | -0.003 | 0.049 | 0.028 |
| **Panel D: Out-of-sample pricing bonds** | | | | | | | | | | | |
| RMSE | 0.086 | 0.080 | 0.080 | 0.081 | 0.095 | 0.091 | 0.086 | 0.086 | 0.103 | 0.082 | 0.128 |
| MAPE | 0.066 | 0.059 | 0.057 | 0.057 | 0.074 | 0.070 | 0.067 | 0.067 | 0.075 | 0.057 | 0.096 |
| $R^2_{OLS}$ | 0.125 | 0.243 | 0.247 | 0.228 | -0.070 | 0.014 | 0.120 | 0.119 | -0.247 | 0.211 | -0.936 |
| $R^2_{GLS}$ | 0.018 | 0.042 | 0.055 | 0.065 | 0.009 | 0.009 | -0.028 | 0.015 | -0.029 | 0.040 | -0.080 |

---

<!-- @section-type: figure
  @key-claim: SDF remains dense even for pricing Treasury component only; low-dimensional models remain misspecified
  @importance: supporting
  @data-source: 14 nontradable + 16 tradable bond factors, Treasury component of 50 bond portfolios
  @depends-on: IA.6.2
  @equations: none
-->

## Figure IA.22: Posterior SDF dimensionality and Sharpe ratios: Treasury component

**Description:** Two panels. Panel (A) shows the posterior distribution of the number of factors to be included in the bond SDF: posterior median ~14 factors, 95% CI ~[8, 19]. Panel (B) shows the posterior distribution of the SDF-implied Sharpe ratio with 95% CI shaded.

**Key takeaway:** The posterior median number of factors (~14) is lower than for the co-pricing BMA-SDF (median 22), but the required SDF is still dense and low-dimensional factor models remain misspecified with very high probability even for pricing the Treasury component only. The SDF is dense in both nontradable as well as tradable factors (see Table IA.XVIII).

number of factors is now much lower than for the co-pricing BMA-SDF, the required SDF is still dense and low-dimensional factor models remain misspecified with very high probability even for pricing the Treasury component only. Moreover, the SDF is dense in both nontradable as well as tradable factors (see Table IA.XVIII).

---

*(Page 77)*

<!-- @section-type: table
  @key-claim: BMA-SDF outperforms all additional bond and stock factor models when using duration-adjusted returns
  @importance: supporting
  @data-source: Duration-adjusted bond returns, multiple factor models
  @depends-on: IA.6.1, Table IA.XII
  @equations: 10
-->

## Table IA.XVII: Cross-sectional asset pricing performance: Additional models (duration-adjusted bond returns)

Panel A presents the cross-sectional in-sample asset pricing performance of different bond and stock asset pricing models. Bond factor and test asset returns are duration adjusted as per equation (10). Panels B, C and D present the out-of-sample asset pricing performance for the joint, bond and stock cross-sections, respectively. For bonds we consider five models: (i) the modified three-factor model of Bai et al. (2019) including MKTB, DRF, and CRF bond factors (BBW3), (ii) the two-factor decomposed bond market factor model from van Binsbergen et al. (2025) (DCAPM), (iii) the DEFTERM model of Fama and French (1993), (iv) the MACRO model of Bali et al. (2021b) comprising MKTB and macro economic uncertainty UNC, and (v) the six-factor CWW model of Chung et al. (2019). For stocks we consider six models: (i) the Carhart (1997) four-factor model (FFC4), (ii) the Hou et al. (2015) four-factor model (HXZ4), (iii) the five-factor model of Fama and French (2015) (FF5$^{2015}$), (v) the FF5* model of Daniel et al. (2020b), and (vi) the FF6 model. The sample period is 1986:01 to 2022:12 ($T = 444$).

|  | BMA-SDF | Bond factor models |  |  |  | Stock factor models |  |  |  |  |
|--|--|--|--|--|--|--|--|--|--|--|
|  | BMA-80% | BBW3 | DCAPM | DEFTERM | MACRO | CWW | FFC4 | HXZ4 | FF5$^{2015}$ | FF5* | FF6 |
| **Panel A: IS co-pricing** | | | | | | | | | | | |
| RMSE | 0.174 | 0.305 | 0.275 | 0.219 | 0.276 | 0.272 | 0.264 | 0.252 | 0.249 | 0.251 | 0.223 |
| MAPE | 0.128 | 0.257 | 0.223 | 0.164 | 0.224 | 0.209 | 0.203 | 0.179 | 0.177 | 0.174 | 0.156 |
| $R^2_{OLS}$ | 0.339 | -1.023 | -0.643 | -0.044 | -0.660 | -0.604 | -0.518 | -0.378 | -0.350 | -0.369 | -0.084 |
| $R^2_{GLS}$ | 0.252 | 0.030 | 0.026 | 0.023 | 0.030 | 0.034 | 0.038 | 0.064 | 0.058 | 0.074 | 0.065 |
| **Panel B: OS co-pricing** | | | | | | | | | | | |
| RMSE | 0.125 | 0.162 | 0.164 | 0.147 | 0.155 | 0.111 | 0.103 | 0.116 | 0.097 | 0.147 | 0.103 |
| $R^2_{OLS}$ | 0.528 | 0.202 | 0.187 | 0.349 | 0.278 | 0.631 | 0.682 | 0.593 | 0.717 | 0.351 | 0.681 |
| $R^2_{GLS}$ | 0.097 | 0.002 | 0.010 | 0.004 | 0.002 | 0.020 | 0.034 | 0.039 | 0.057 | 0.044 | 0.059 |
| **Panel C: OS pricing stocks** | | | | | | | | | | | |
| RMSE | 0.077 | 0.121 | 0.117 | 0.114 | 0.119 | 0.105 | 0.080 | 0.086 | 0.092 | 0.098 | 0.078 |
| $R^2_{OLS}$ | 0.618 | 0.056 | 0.117 | 0.160 | 0.091 | 0.288 | 0.590 | 0.522 | 0.463 | 0.383 | 0.615 |
| $R^2_{GLS}$ | 0.271 | 0.052 | 0.041 | 0.020 | 0.038 | 0.080 | 0.132 | 0.182 | 0.169 | 0.097 | 0.188 |
| **Panel D: OS pricing bonds** | | | | | | | | | | | |
| RMSE | 0.082 | 0.092 | 0.088 | 0.085 | 0.090 | 0.104 | 0.121 | 0.123 | 0.102 | 0.102 | 0.114 |
| $R^2_{OLS}$ | 0.196 | -0.009 | 0.084 | 0.140 | 0.038 | -0.277 | -0.735 | -0.785 | -0.226 | -0.222 | -0.546 |
| $R^2_{GLS}$ | 0.098 | 0.013 | 0.013 | 0.005 | 0.016 | 0.006 | -0.055 | -0.035 | 0.076 | 0.038 | 0.022 |

---

## Table IA.XVIII: BMA-SDF dimensionality and Sharpe ratio decomposition for Treasury component

|  | Total prior SR |  |  |  | Total prior SR |  |  |  |
|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
|  | **Nontradable factors** |  |  |  | **Tradable factors** |  |  |  |
| Mean | 7.01 | 6.98 | 6.97 | 6.80 | 7.89 | 7.72 | 7.47 | 7.00 |
| 5% | 4 | 4 | 4 | 4 | 5 | 4 | 4 | 4 |
| 95% | 10 | 10 | 10 | 10 | 11 | 11 | 11 | 10 |
| $\mathbb{E}[SR_f \mid \text{data}]$ | 0.15 | 0.32 | 0.52 | 0.84 | 0.28 | 0.48 | 0.64 | 0.80 |
| $\mathbb{E}[SR_f^2/SR_m^2 \mid \text{data}]$ | 0.30 | 0.36 | 0.44 | 0.54 | 0.71 | 0.67 | 0.60 | 0.51 |

The table reports posterior means of number of factors (along with the 90% confidence intervals), implied Sharpe ratios $\mathbb{E}[SR_f \mid \text{data}]$, and the ratio of $SR_f^2$ to the total SDF-implied squared Sharpe ratio of the 14 nontradable and 16 tradable bond factors. Test assets are the Treasury components of the 50 corporate bond portfolios. The sample period is 1986:01 to 2022:12 ($T = 444$).

*(Page 78)*

In Figure IA.23 we mirror the analysis in Section 3.1 and assess which factors are more likely to price the Treasury component individually, and how factors should be optimally combined to achieve a portfolio that captures the priced risks in these assets. The top and bottom panels report the posterior factor probabilities and market prices of risk implied by the pricing of the Treasury component of corporate bond returns using the Treasury component of the corporate bond factor zoo (the prior Sharpe ratio is set to 80% of the ex post maximum Sharpe ratio). The first four factors with the highest posterior probability are nontradable. Furthermore, largely, these factors are the same as those that appear most likely when co-pricing bonds and stocks (the top three being YSP, CREDIT and LVL, followed by the IVOL factor). Moreover, they command large market prices of risk and the probability of zero nontradable factors being in the BMA-SDF that prices the Treasury component of corporate bond returns is virtually zero (or 0.014%).

## Figure IA.23: Posterior factor probabilities and risk prices: Treasury component

**Description:** Two panels. Panel (A) shows posterior probabilities $\mathbb{E}[\gamma_j \mid \text{data}]$; Panel (B) shows posterior means of annualized market prices of risk $\mathbb{E}[\lambda_j \mid \text{data}]$ of the 14 nontradable and 16 tradable bond factors. Factors ordered by posterior probability. Non-traded factors shown in dark blue, bond factors in lighter blue.

**Key takeaway:** The top factors for pricing the Treasury component are nontradable: YSP, CREDIT, LVL, IVOL. These are the same factors that appear most likely in the co-pricing BMA-SDF. The probability of zero nontradable factors being in the BMA-SDF is virtually zero (0.014%).

## Figure IA.24: Posterior factor probabilities and risk prices: Treasury component with DR tilt

**Description:** Same structure as Figure IA.23, but with the prior tilted via the $\kappa$ vector to assign positive weight to DR factors and negative weight to CF factors.

**Key takeaway:** The tilt towards DR factors makes them individually more likely, pushing the likelihood of MKTB above the prior value. However, the pricing results remain overall similar to the baseline estimation with the more diffuse prior encoding. Top factors: MOMBS, MKTB, PEADB, YSP, CREDIT, IVOL, LVL.

Given the nature of the Treasury component where, at least in nominal terms, cash flows are known in advance, one would expect discount rate news to be the main driver of their priced risk (Chen and Zhao (2009)). Thus, we implement a factor tilt (see Section 2.3) whereby we assign a positive weight to DR factors and a negative weight to CF factors as given by the decomposition discussed in Internet Appendix IA.5. The top and bottom panels of Figure IA.24 report the posterior factor probabilities and market prices of risk implied by the pricing of the Treasury component of corporate bond returns using the corporate bond factor zoo without self-pricing (the prior Sharpe ratio is set to 80% of the ex post maximum Sharpe ratio) and the encoded prior belief about the relative importance of DR versus CF news. The tilt towards DR factors makes them individually more likely, and for example pushes the likelihood of the MKTB factor above the prior value. However, the pricing results remain overall very similar to the baseline estimation with the more diffuse prior encoding.

This is highlighted in Table IA.XIX where we report in- and out-of-sample performance measures for the Treasury component bond BMA-SDF without (Panel A) and with (Panel B) the DR-factor tilt. The IS test assets are the Treasury components of the 50 corporate bond portfolios and the OS test assets are the 29 Treasury portfolios with maturities ranging from 2 to 30 years. All are described in Section 1. The numbers do not change materially when comparing the two panels in the table.

Finally, Table IA.XX provides the time series correlations between (the posterior means of) BMA-SDFs con-

*(Page 79)*

<!-- @section-type: table
  @key-claim: DR-factor tilt has minimal effect on Treasury component pricing performance
  @importance: supporting
  @data-source: Treasury component of 50 bond portfolios, 29 Treasury portfolios
  @depends-on: IA.6.2
  @equations: none
-->

## Table IA.XIX: IS and OS cross-sectional asset-pricing performance: Treasury component

|  | In-sample |  |  |  | Out-of-sample |  |  |  |
|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
| **Panel A: Baseline without factor tilt, GLS** | | | | | | | | |
| RMSE | 0.084 | 0.084 | 0.079 | 0.071 | 0.096 | 0.095 | 0.089 | 0.078 |
| MAPE | 0.064 | 0.064 | 0.060 | 0.053 | 0.076 | 0.074 | 0.068 | 0.059 |
| $R^2_{OLS}$ | -0.153 | -0.169 | -0.039 | 0.177 | -0.084 | -0.058 | 0.075 | 0.289 |
| $R^2_{GLS}$ | 0.045 | 0.087 | 0.131 | 0.194 | 0.081 | 0.134 | 0.186 | 0.259 |
| **Panel B: With DR-factor tilt, GLS** | | | | | | | | |
| RMSE | 0.084 | 0.084 | 0.079 | 0.070 | 0.096 | 0.095 | 0.089 | 0.078 |
| MAPE | 0.064 | 0.064 | 0.060 | 0.053 | 0.076 | 0.074 | 0.068 | 0.059 |
| $R^2_{OLS}$ | -0.155 | -0.163 | -0.019 | 0.193 | -0.086 | -0.056 | 0.092 | 0.309 |
| $R^2_{GLS}$ | 0.045 | 0.087 | 0.131 | 0.195 | 0.082 | 0.136 | 0.188 | 0.261 |
| **Panel C: BMA baseline, OLS** | | | | | | | | |
| RMSE | 0.056 | 0.037 | 0.030 | 0.027 | 0.075 | 0.060 | 0.054 | 0.051 |
| $R^2_{OLS}$ | 0.479 | 0.774 | 0.850 | 0.881 | 0.342 | 0.586 | 0.660 | 0.694 |
| $R^2_{GLS}$ | -3.653 | -6.475 | -8.242 | -9.518 | 0.402 | 0.442 | 0.456 | 0.463 |
| **Panel D: BMA with DR-factor tilt, OLS** | | | | | | | | |
| RMSE | 0.055 | 0.037 | 0.030 | 0.027 | 0.074 | 0.059 | 0.054 | 0.051 |
| $R^2_{OLS}$ | 0.493 | 0.778 | 0.851 | 0.881 | 0.354 | 0.592 | 0.662 | 0.694 |
| $R^2_{GLS}$ | -3.707 | -6.466 | -8.222 | -9.516 | 0.402 | 0.441 | 0.454 | 0.462 |

## Table IA.XX: BMA-SDF time series correlations: 60% and 80% SR shrinkage

|  | Co-pricing$_{Exc.}$ | Bond$_{Exc.}$ | Stock$_{Exc.}$ | T-Bond$_{Bond}$ | T-Bond$_{Stock}$ | Co-pricing$_{Dur.}$ | Bond$_{Dur.}$ |
|--|--|--|--|--|--|--|--|
| Co-pricing$_{Exc.}$ | -- | 0.716 | 0.738 | 0.284 | 0.198 | 0.967 | 0.671 |
| Bond$_{Exc.}$ | 0.744 | -- | 0.093 | 0.337 | 0.247 | 0.688 | 0.929 |
| Stock$_{Exc.}$ | 0.725 | 0.113 | -- | 0.122 | 0.035 | 0.730 | 0.098 |
| T-Bond$_{Bond}$ | 0.402 | 0.439 | 0.172 | -- | 0.379 | 0.213 | 0.229 |
| T-Bond$_{Stock}$ | 0.272 | 0.325 | 0.064 | 0.533 | -- | 0.182 | 0.252 |
| Co-pricing$_{Dur.}$ | 0.964 | 0.712 | 0.708 | 0.351 | 0.243 | -- | 0.729 |
| Bond$_{Dur.}$ | 0.686 | 0.908 | 0.121 | 0.335 | 0.286 | 0.754 | -- |

Lower (upper) triangular: 80% (60%) SR shrinkage. The sample period is 1986:01 to 2022:12 ($T = 444$).

structed with bond and stock factors, jointly and separately, to price (again jointly and separately) bond and stock excess returns, duration-adjusted bond returns, and the Treasury component of corporate bond returns.

---

*(Page 80)*

<!-- @section-type: methodology
  @key-claim: A factor not in the SDF can still command a non-zero risk premium if correlated with a true SDF factor
  @importance: core
  @data-source: Analytical derivation + CAPMB estimation
  @depends-on: Section 2
  @equations: multiple
-->

## IA.7. Risk premia vs. market prices of risk

In this section, we show that testing a risk premium is not the same as testing a market price of risk. In fact, a factor that is not part of the SDF might command a large risk premium just because it correlates with the latter.

To show this, we report two-pass regression estimates of the risk premium attached to MKTB as the sole factor, as well as linear SDF estimates of the market price of risk in the CAPMB model used to price our baseline cross-section of corporate bonds and bond tradable factors. Furthermore, we evaluate and report the risk premium and the market price of risk from the CAPM model when pricing duration-adjusted corporate bond returns and factors. To understand why the two types of estimations can lead to very different outcomes, let's consider a simple example with two (demeaned) tradable risk factors only, i.e. $f_t = [f_{1,t}, f_{2,t}]^\top$, and suppose for simplicity that their covariance matrix is

$$\Sigma = \begin{bmatrix} 1 & \rho \\ \rho & 1 \end{bmatrix}$$

Suppose further that only the first factor is part of the SDF, and has a market price of risk equal to $\kappa$. That is

$$M_t = 1 - f_t^\top \lambda_f = 1 - [f_{1,t}, f_{2,t}]^\top \begin{bmatrix} \kappa \\ 0 \end{bmatrix} = 1 - f_{1,t}\kappa$$

Denoting with $\mu_{RP} = [\mu_{RP,1}, \mu_{RP,2}]^\top$ the vector of risk premia of the factors, applying the fundamental asset pricing equation to the returns generated by the factors, we have

$$\mu_{RP} = \Sigma \lambda_f = \begin{bmatrix} 1 & \rho \\ \rho & 1 \end{bmatrix} \begin{bmatrix} \kappa \\ 0 \end{bmatrix} = \begin{bmatrix} \kappa \\ \rho\kappa \end{bmatrix}.$$

That is, the second factor, that is *not* part of the SDF, commands nevertheless a non-zero risk premium (equal to $\rho\kappa$) as long as the factor has non-zero correlation (i.e., as long as $\rho \neq 0$) with the true risk factor. This also implies that a two-pass regression method that uses the second factor as the sole driver of a cross-section of asset returns will estimate its ex post risk premium as being non-zero; in fact, the estimated risk premium for the second factor will be inflated relative to its true value. This is due to the fact that the estimated betas of $f_2$ will be, in population, smaller than the ones of $f_1$ by a factor equal to $\rho$. Hence, in population, the two-pass regression will yield an estimated risk premium for $f_2$ equal to $\rho^{-1}\kappa$ (where $|\rho| \leq 1$).

## Figure IA.25: CAPMB: Two-pass regression risk premium and market price of risk

**Description:** Two panels showing posterior distributions. Panel A: Two-pass regression ex post risk premium of CAPMB. Panel B: SDF-based market price of risk for CAPMB. Test assets are 50 bond portfolios and 16 tradable bond factors.

**Key takeaway:** Albeit MKTB carries a sizable and significant risk premium, it is unlikely that the data are generated by a "true" latent SDF with MKTB as the only factor. The (Bayesian) p-value of its market price of risk being equal to zero is about 52.34%.

**Example 1** (CAPMB pricing corporate bond excess returns). To estimate the SDF of the CAPMB model we rely on the Bayesian-SDF estimator in Definition 1 of Bryzgalova et al. (2023). This is equivalent to the method presented in Section 2 under the null that MKTB is the only factor in the SDF with probability one and that the model is true. To put the comparison of market prices of risk and ex post risk premia estimates on the same footing, we estimate the two-pass regression using the Bayesian implementation of the Fama and MacBeth (1973) method in Bryzgalova et al. (2022). Posterior distributions of the two-pass regression ex post risk premium and SDF-based market price of risk are plotted, respectively, in Panels A and B of Figure IA.25. The estimates suggest that, albeit MKTB carries a sizable and significant risk premium, it is very unlikely that the data are generated by a "true" latent SDF with MKTB as the only factor -- the (Bayesian) p-value of its market price of risk being equal to zero is about 52.34%.[^7]

**Example 2** (CAPM pricing corporate bond duration-adjusted returns). We follow a similar procedure, using the same set of corporate bond portfolios and factors, computed with duration-adjusted returns. Now, the null is defined such that MKTS (the stock market factor) is the only factor in the SDF with probability one and that the model is true. Posterior distributions of the two-pass regression ex post risk premium and SDF-based market price of risk are plotted, respectively, in Panels A and B of Figure IA.26.

The estimates suggest that MKTS, neither carries a significant ex post risk premium (as in van Binsbergen et al. (2025, Table A8)) in this heavily misspecified setting (given our results in the main text) nor it is likely that

[^7]: This broadly confirms the results presented in Dickerson et al. (2023). These authors show that incrementally, in a frequentist setting, other low dimensional models that they consider do not outperform the CAPMB. However, in itself, they also show that the CAPMB is a poor model for describing the cross-section of expected corporate bond excess returns (see their Fig. 2, on Page 11 of the published version of the paper and the $R_{GLS}$ values reported in Table 3).

---

*(Page 81)*

## Figure IA.26: CAPM: Two pass-regression risk premium and market price of risk with duration-adjusted bond returns

**Description:** Two panels. Panel A: Two-pass regression ex post risk premium of CAPM with duration-adjusted returns. Panel B: SDF-based market price of risk for CAPM. Test assets are 50 duration-adjusted bond portfolios and 16 tradable bond factors (also duration adjusted).

**Key takeaway:** MKTS neither carries a significant ex post risk premium nor is it likely that the duration-adjusted bond return data are generated by a "true" latent SDF with the stock market factor as the only factor. The (Bayesian) p-value of its market price of risk being equal to zero is about 76.30%.

the duration-adjusted bond return data are generated by a "true" latent SDF with the stock market factor as the only factor -- the (Bayesian) p-value of its market price of risk being equal to zero is about 76.30%.

---

<!-- @section-type: results
  @key-claim: The BMA-SDF displays strong autocorrelation and persistent conditional volatility not matched by competing models
  @importance: core
  @data-source: BMA-SDF time series, 1986:01-2022:12
  @depends-on: Section 3.4
  @equations: none
-->

## IA.8. Economic properties

In this section we provide additional results to complement the analysis in Section 3.4.

Panel A in Figure IA.27 shows that the BMA-SDF is highly predictable: virtually all of its autocorrelation coefficients are statistically significant at the 1% level up to 20 months ahead, and the p-value of the Ljung and Box (1978) test of joint significance is zero at this horizon. Additionally, about one fifth of its time series variance is explained by its own lags (23% for the best AR specification and 19% for the best ARMA specification according to the AIC and the BIC).

## Figure IA.27: Autocorrelation functions of co-pricing BMA-SDF and forecast errors

**Description:** Panel A shows autocorrelation coefficients of the co-pricing BMA-SDF with AR(1) R2: 13%, AR(10) R2: 23%, ARMA(3,1) R2: 19%, Ljung-Box (20 lags) p-val: 0.000. Panel B shows the squared forecast errors with Ljung-Box (20 lags) p-val: 0.000.

**Key takeaway:** The BMA-SDF is highly predictable with about 20% of its time series variance explained by its own lags. The conditional volatility is highly persistent with deviations from the mean exhibiting a half-life of approximately 16.6 months.

Figure IA.28 shows the autocorrelations for a range of models discussed in Appendix D. As is evident, none of the other models come close to displaying the same level of business cycle variation and persistency as our BMA-SDF: the KNS SDF has about 11% of its time series variation being predictable by its own history, while this number drops to 4% for RPPCA, and its only 2% to 3%, for FF5 and CAPMB, and zero for HKM and CAPM.

Moreover, as shown in Panel A of Table IA.XXI, the SDFs with a higher degree of persistency, KNS and RPPCA, are exactly the ones with the highest degree of correlation with the BMA-SDF (0.78 and 0.55, respectively), and are the closest competitors for the BMA-SDF in the pricing exercises in Section 3.1. Instead, SDFs that perform significantly worse in cross-sectional pricing have both little time series persistency and correlations with the BMA-SDF in the 0.16 to 0.29 range.

The GARCH(1,1) coefficient estimates in Figure 11 imply a highly persistent conditional volatility, with deviations from the mean exhibiting a half-life of approximately 16.6 months. In Figure IA.29 we show that the volatility patterns of the BMA-SDF are not simply driven by the tradable factors by removing them from the

*(Page 82)*

## Figure IA.28: Autocorrelation functions of SDFs from alternative models

**Description:** Six panels showing autocorrelation coefficients of SDFs estimated using KNS, RPPCA, CAPM, CAPMB, FF5, and HKM (from left to right and top to bottom).

**Key statistics:**
- KNS: ARMA(3,1) R2: 11%, Ljung-Box p-val: 0.000
- RPPCA: ARMA(0,1) R2: 4%, Ljung-Box p-val: 0.000
- CAPM: ARMA(0,0) R2: 0%, Ljung-Box p-val: 0.882
- CAPMB: ARMA(2,0) R2: 3%, Ljung-Box p-val: 0.06
- FF5: ARMA(2,0) R2: 2%, Ljung-Box p-val: 0.034
- HKM: ARMA(0,0) R2: 0%, Ljung-Box p-val: 0.744

## Table IA.XXI: Correlation of SDF levels and volatilities

| | KNS | RPPCA | CAPM | CAPMB | FF5 | HKM |
|--|--|--|--|--|--|--|
| **Panel A: SDF levels** | | | | | | |
| BMA | 0.78 | 0.55 | 0.16 | 0.28 | 0.29 | 0.16 |
| KNS | -- | 0.85 | 0.11 | 0.46 | 0.32 | 0.13 |
| RPPCA | | -- | 0.09 | 0.35 | 0.18 | 0.11 |
| CAPM | | | -- | 0.42 | 0.70 | 0.98 |
| CAPMB | | | | -- | 0.70 | 0.41 |
| FF5 | | | | | -- | 0.66 |
| **Panel B: SDF estimated volatilities** | | | | | | |
| BMA | 0.76 | 0.70 | 0.74 | 0.52 | 0.56 | 0.74 |
| KNS | -- | 0.71 | 0.64 | 0.55 | 0.55 | 0.65 |
| RPPCA | | -- | 0.54 | 0.18 | 0.24 | 0.56 |
| CAPM | | | -- | 0.57 | 0.61 | 0.98 |
| CAPMB | | | | -- | 0.75 | 0.57 |
| FF5 | | | | | -- | 0.58 |

*(Page 83)*

BMA-SDF and re-estimating the volatility process of the new nontradable-only SDF. The resulting volatility process remains very persistent (with a half-life of 12.3 months), with pronounced business cycle variation and reaction to periods of heightened economic uncertainty. Moreover, the correlation of the two BMA-SDF volatility time series in Figures 11 and IA.29 is around 62%. That is, both tradable and nontradable components of the BMA-SDF are characterized by a very persistent volatility with a clear business cycle pattern.

## Figure IA.29: Volatility of the co-pricing BMA-SDF with only nontradable factors

**Description:** Time series plot (1986-2022) showing the annualized volatility of the co-pricing BMA-SDF estimated using only nontradable factors, with NBER recession periods shaded. Key events labeled: Black Monday, WTC, Dot-com, Asia crisis, Iraq inv., Bear Stearns, Lehman, Greece def., Covid, Ukraine.

**GARCH(1,1) estimates:** $\sigma^2_{t+1} = \omega + \alpha\epsilon^2_t + \beta\sigma^2_t$

| | $\omega$ | $\alpha$ | $\beta$ |
|--|--|--|--|
| Estimate | 0.000202 | 0.142293 | 0.798533 |
| Robust SE | 0.000090 | 0.052041 | 0.047567 |

Panel B of Figure IA.27 reports the empirical autocorrelation function of the squared forecast errors of the co-pricing BMA-SDF while the squared forecast errors for the SDFs of the KNS, RPPCA, CAPM, CAPMB, FF5 and HKM models are reported in Figure IA.30. As mentioned above, the conditional volatility of the co-pricing BMA-SDF is highly persistent, with deviations from the mean exhibiting a half-life of approximately 16.6 months. Instead, Figure IA.30 for example shows that the half-life of volatility shocks to the FF5 SDF model is only 4.21 months, and for the CAPMB it is just 3 months. That is, the use of tradable factors in the SDF does not mechanically deliver our findings for the BMA-SDF.

Finally, it seems that the alternative SDF models do not sufficiently capture business cycle variation and periods of high economic uncertainty. We show this by linearly projecting the estimated volatility of our co-pricing BMA-SDF on the estimated volatilities of the KNS, RPPCA, CAPM, CAPMB, FF5 and HKM models. Figure IA.31 plots the time series of the residuals, revealing that they still show a very strong business cycle variation and they exhibit similar spikes as the volatility series in Figure 11. Overall, the observed business cycle variations and predictability in both the first and second moments of the BMA-SDF would imply, within a structural model, time-varying and predictable risk premia for tradable assets.

---

<!-- @section-type: robustness
  @key-claim: Prior perturbations (factor tilting, sparsity, factor exclusion) do not materially change the BMA-SDF results
  @importance: core
  @data-source: Multiple perturbation exercises, 1986:01-2022:12
  @depends-on: Sections 4.1, 4.2, 4.3
  @equations: none
-->

## IA.9. Prior perturbation

In this section we provide additional results to complement the robustness analysis in Sections 4.1, 4.2 and 4.3 with regards to perturbations of the prior and removing the most important factors in terms of posterior probabilities and market prices of risk, respectively.

### IA.9.1. Factor tilting

First, we tilt the estimation of the co-pricing BMA-SDF in favor of bond factors by setting $\kappa = 0.5$. This implies the belief that they explain a share of the squared Sharpe ratio of the SDF that is $\frac{1+\kappa}{1-\kappa} = 3$ times as large as the share of stock factors. Thereafter, we tilt toward stock factors. In Figure IA.32 we report the posterior factor probabilities estimated with the tilted priors either in favor of bond (bars with diagonal lines) or stock (bars with dots) factors, respectively. Overall, the likelihood of the data is quite informative for the posterior probabilities,

*(Page 84)*

## Figure IA.30: Autocorrelations of SDF squared residuals

**Description:** Six panels showing autocorrelation coefficients of squared residuals of SDFs from KNS, RPPCA, CAPM, CAPMB, FF5, and HKM.

**Key statistics:**
- KNS: Ljung-Box p-val: 0.000, Half-life: 4.43
- RPPCA: Ljung-Box p-val: 0.000, Half-life: 12.39
- CAPM: Ljung-Box p-val: 0.011, Half-life: 33.5
- CAPMB: Ljung-Box p-val: 0.000, Half-life: 3.02
- FF5: Ljung-Box p-val: 0.000, Half-life: 4.21
- HKM: Ljung-Box p-val: 0.001, Half-life: 23.1

especially for the nontradable factors. Posterior probabilities for bond and stock factors reflect the direction of the tilt.

Similarly, the posterior market prices of risk depicted in Figure IA.33 highlight that the set of factors that features more prominently in the co-pricing BMA-SDF is largely unchanged, albeit their individual posterior $\lambda$s do vary in the expected directions. That is, market prices of risk that are very small in absolute terms are not strongly affected by the factor tilt.

In Table IA.XXII we report in- and out-of-sample performance measures for the co-pricing BMA-SDF without (Panel A) and with bond (Panel B) and stock (Panel C) factor tilts. As in Tables 2 and 3 we first estimate the co-pricing BMA-SDF on the standard 123 test assets and then use the resulting BMA-SDF to price the 154 OS test assets that are all described in Section 1. The numbers do not change materially when comparing the two panels in the table. Overall, the effect of the prior tilting is small and unambiguous in direction: as we tilt toward either type of factor, the out-of-sample pricing ability deteriorates. This is very much in line with the findings in Section 3.3: for the co-pricing of stock and bond excess returns, we need information from both factor zoos. Consequently, over-reliance on either type of factor worsens the BMA-SDF performance. This result is further reinforced in Table IA.XXIII where we consider the separate pricing of bond and stock excess returns using the co-pricing BMA-SDF estimated with and without factor tilts. The deterioration in out-of-sample pricing performance is stronger for stocks when tilting the prior in favor of bond factors and vice versa, although it's asymmetric, again suggesting a much more limited information content in the bond factor zoo relative to the equity one.

Next, we apply the factor tilts to price duration-adjusted bond returns. As the results in Section 3.3 suggest, once we account for the Treasury component of bond returns, the bond factor zoo becomes largely redundant. This

*(Page 85)*

## Figure IA.31: Residual volatility of the co-pricing BMA-SDF

**Description:** Time series plot (1986-2022) of the residuals from linearly projecting the BMA-SDF volatility on the volatilities of CAPM, CAPMB, KNS, RPPCA, FF5 and HKM SDFs. Key events labeled: Black Monday, WTC, Dot-com, Asia crisis, Iraq inv., Lehman, Bear Stearns, Greece def., Covid, Ukraine.

**Key takeaway:** Residuals still show strong business cycle variation and spikes at periods of heightened economic uncertainty, indicating that alternative models do not sufficiently capture business cycle variation.

## Table IA.XXII: IS and OS cross-sectional asset pricing performance across $\kappa$ tilts

|  | In-sample |  |  |  | Out-of-sample |  |  |  |
|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
| **Panel A: Baseline ($\kappa = 0$)** | | | | | | | | |
| RMSE | 0.214 | 0.203 | 0.185 | 0.167 | 0.114 | 0.102 | 0.095 | 0.090 |
| MAPE | 0.167 | 0.154 | 0.139 | 0.125 | 0.081 | 0.074 | 0.069 | 0.065 |
| $R^2_{OLS}$ | 0.155 | 0.240 | 0.367 | 0.487 | 0.357 | 0.489 | 0.557 | 0.603 |
| $R^2_{GLS}$ | 0.106 | 0.168 | 0.232 | 0.285 | 0.038 | 0.070 | 0.098 | 0.124 |
| **Panel B: Bond factor tilt ($\kappa = 0.5$)** | | | | | | | | |
| RMSE | 0.200 | 0.185 | 0.175 | 0.161 | 0.117 | 0.113 | 0.111 | 0.104 |
| $R^2_{OLS}$ | 0.258 | 0.368 | 0.438 | 0.523 | 0.330 | 0.367 | 0.390 | 0.466 |
| $R^2_{GLS}$ | 0.106 | 0.168 | 0.224 | 0.272 | 0.040 | 0.072 | 0.096 | 0.119 |
| **Panel C: Stock factor tilt ($\kappa = -0.5$)** | | | | | | | | |
| RMSE | 0.240 | 0.229 | 0.209 | 0.183 | 0.122 | 0.116 | 0.112 | 0.105 |
| $R^2_{OLS}$ | -0.063 | 0.035 | 0.195 | 0.382 | 0.271 | 0.337 | 0.384 | 0.453 |
| $R^2_{GLS}$ | 0.107 | 0.163 | 0.222 | 0.281 | 0.035 | 0.064 | 0.092 | 0.122 |

would imply that tilting the prior in favor of stock (bond) factors should actually improve (worsen) the pricing ability of the BMA-SDF. Figure IA.34 highlights this: as the prior is tilted away from bond factors (moving from $\kappa = 0.5$ towards $\kappa = -0.5$), the OS measures of cross-sectional fit improve for the models estimated with duration-adjusted corporate bond returns.

Finally, an extreme tilt in favor of stock factors as implemented in Figure IA.35 maximizes the pricing ability of the BMA-SDF for duration-adjusted returns but performs worse for the standard corporate bond excess returns we use in our baseline analysis. Overall, this further reinforces our previous findings: the bond factor zoo is largely redundant for co-pricing bond and stock portfolios once the Treasury component of the latter is accounted

*(Page 86)*

## Table IA.XXIII: OS cross-sectional pricing performance for bonds and stocks across $\kappa$ tilts

|  | Stock test assets |  |  |  | Bond test assets |  |  |  |
|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
| **Panel A: Baseline ($\kappa = 0$)** | | | | | | | | |
| RMSE | 0.102 | 0.087 | 0.080 | 0.076 | 0.122 | 0.115 | 0.108 | 0.101 |
| $R^2_{OLS}$ | 0.330 | 0.513 | 0.591 | 0.629 | 0.064 | 0.171 | 0.267 | 0.354 |
| $R^2_{GLS}$ | 0.106 | 0.189 | 0.246 | 0.276 | 0.022 | 0.051 | 0.078 | 0.107 |
| **Panel B: Bond factor tilt ($\kappa = 0.5$)** | | | | | | | | |
| RMSE | 0.112 | 0.100 | 0.094 | 0.089 | 0.121 | 0.112 | 0.105 | 0.100 |
| $R^2_{OLS}$ | 0.195 | 0.356 | 0.435 | 0.494 | 0.078 | 0.216 | 0.307 | 0.365 |
| $R^2_{GLS}$ | 0.088 | 0.148 | 0.187 | 0.216 | 0.036 | 0.073 | 0.097 | 0.118 |
| **Panel C: Stock factor tilt ($\kappa = -0.5$)** | | | | | | | | |
| RMSE | 0.095 | 0.080 | 0.073 | 0.070 | 0.123 | 0.118 | 0.112 | 0.103 |
| $R^2_{OLS}$ | 0.419 | 0.591 | 0.655 | 0.687 | 0.050 | 0.116 | 0.215 | 0.334 |
| $R^2_{GLS}$ | 0.123 | 0.218 | 0.278 | 0.315 | 0.006 | 0.026 | 0.054 | 0.093 |

for.

### IA.9.2. Imposing sparsity

Our method not only allows tilting factors towards a certain group (bond vs. stock as discussed in Section IA.9.1 or DR vs. CF news as discussed in Section IA.6.2) but also provides the flexibility to encode beliefs about the density of the SDF through the Beta-distributed prior probability of factor inclusion $\pi(\gamma_j = 1 | \omega_j) = \omega_j \sim Beta(a_\omega, b_\omega)$. For our baseline estimations we do not take an ex ante stance on whether the SDF should be sparse or dense. However, since the extant literature overwhelmingly assumes a high degree of sparsity, typically favoring factor models with approximately five factors, we now tweak the prior mean and variance to mirror such a belief. In particular, by choosing the prior mean and variance of $\omega_j$, $\mathbb{E}[\omega_j] = \frac{a_\omega}{a_\omega + b_\omega}$ and $\text{Var}(\omega_j) = \frac{a_\omega b_\omega}{(a_\omega + b_\omega)^2(a_\omega + b_\omega + 1)}$ we can form a prior on the model dimensions that is similar to what is typically used in the literature. Setting $a_\omega \approx 3.54$ and $b_\omega \approx 34.66$ we get: (i) the prior expectation of included factors, $\mathbb{E}[\omega_j] \times K$, yields the canonical five-factor model, and (ii) the prior two standard deviation credible interval encompasses models with zero to ten factors (since $\text{Var}(\omega_j) = (2.5/K)^2$).

Table IA.XXIV shows that the factors with posterior probabilities exceeding the prior value (that is, 9.26%) are essentially identical to those in our baseline estimates in Table A.2. The only exception occurs under the lowest prior shrinkage, where PEAD's posterior probability drops below this threshold. Moreover, as shown in Table IA.XXV, the pricing performance of the co-pricing BMA-SDF with a sparsity-favoring prior remains superior compared to the list of models we consider in Appendix D, particularly out-of-sample. Finally, imposing sparsity degrades the performance of the BMA-SDF compared to our baseline findings in Tables 2 and 3. This is not surprising as Figure 3 and Table 4 demonstrate that the data strongly support a dense SDF.

### IA.9.3. Estimation excluding the most likely factors

In this section we assess whether our BMA-SDF method provides a robust characterization of the true latent SDF even when factors capturing fundamental risk sources are removed from the candidate set. Thus, we remove the factors identified as most salient for characterizing the true latent SDF and construct a BMA-SDF using the remaining factors. In Table IA.XXVI we report the pricing ability of the resulting co-pricing BMA-SDF both in- and out-of-sample. In Panel A we report the results from Tables 2 (IS) and 3 (OS). In Panel B we exclude PEADB, PEAD, IVOL, CREDIT, and YSP, the top five factors in terms of probability from Table A.2. In Panel C we exclude PEADB, PEAD, CRY, QMJ, and MOMBS, the top five factors in terms of market price of risk from Table A.2. In Panel D we exclude the eight factors PEADB, PEAD, IVOL, CREDIT, YSP, CRY, QMJ, MOMBS, the union of the factors excluded in Panels B and C.

*(Page 87)*

## Figure IA.32: Posterior factor probabilities across $\kappa$ tilts

**Description:** Horizontal bar chart showing posterior probabilities $\mathbb{E}[\gamma_j \mid \text{data}]$ for all 54 factors at 80% SR shrinkage, with three conditions: Baseline, Bond-tilt ($\kappa = 0.5$), Stock-tilt ($\kappa = -0.5$). Factors ordered by baseline probability. Factors with posterior probability > 0.5 for any value of $\kappa$ are marked with asterisks: PEADB, IVOL, PEAD, CREDIT, YSP, LVL, CMAs, CRY, MOMBS, LIQNT, MKTS, QMJ, RMWs, SZE, CPTLT, MKTSs, LIQ.

**Key takeaway:** The likelihood of the data is informative for the posterior probabilities, especially for nontradable factors. Bond and stock factor probabilities reflect the direction of the tilt but the top factors remain stable.

## Figure IA.33: Posterior market prices of risk across $\kappa$ tilts

**Description:** Horizontal bar chart showing posterior market prices of risk $\mathbb{E}[\lambda_j \mid \text{data}]$ at 80% SR shrinkage with same three conditions as Figure IA.32.

**Key takeaway:** The set of factors featuring most prominently in the co-pricing BMA-SDF is largely unchanged. Market prices of risk that are small in absolute terms are not strongly affected by the factor tilt. Large MPR factors: PEADB (~0.55-0.72), MOMBS (~0.4-0.7), CRY (~0.4-0.6), IVOL (~0.25-0.45), PEAD (~0.1-0.25), CREDIT (~0.08-0.15).

*(Page 88)*

## Figure IA.34: OS cross-sectional asset pricing performance across $\kappa$ tilts

**Description:** Four panels showing $R^2_{GLS}$ (Panels A and B) and $R^2_{OLS}$ (Panels C and D) for excess bond returns and duration-adjusted bond returns across three tilt conditions (Baseline, Bond tilt, Stock tilt) at four SR shrinkage levels (20%, 40%, 60%, 80%).

**Key takeaway:** As the prior is tilted away from bond factors (toward stock factors), OS measures of cross-sectional fit improve for duration-adjusted corporate bond returns, confirming that the bond factor zoo becomes largely redundant once the Treasury component is removed.

## Figure IA.35: OS cross-sectional asset pricing performance: Favoring stock factors

**Description:** Four panels showing $R^2_{GLS}$ and $R^2_{OLS}$ for excess and duration-adjusted returns with increasingly extreme stock-factor tilts ($\kappa = -0.5, -0.4, -2/3, -9/11$) implying stock factors explain 3, 4, 5, and 10 times as large a share of the squared Sharpe ratio than bond factors.

**Key takeaway:** An extreme stock tilt maximizes pricing ability for duration-adjusted returns but performs worse for standard excess returns, reinforcing the finding that the bond factor zoo contains unique information about the Treasury component of bond returns.

## Table IA.XXIV: Posterior factor probabilities and risk prices imposing sparsity

Top factors under sparsity prior (Beta(3.54, 34.66), yielding ~9.25% prior expectation for $\gamma_j$):

| Factors | Prob (80%) | MPR (80%) |
|---------|-----------|-----------|
| IVOL | 0.326 | 0.385 |
| PEADB | 0.152 | 0.176 |
| YSP | 0.127 | 0.075 |
| CREDIT | 0.104 | 0.076 |
| LVL | 0.079 | 0.010 |
| INFLV | 0.074 | 0.014 |
| UNCr | 0.067 | 0.011 |
| INFLC | 0.064 | -0.011 |
| PEAD | 0.064 | 0.064 |
| EPUT | 0.056 | 0.013 |

*(Page 89-90)*

## Table IA.XXV: IS and OS cross-sectional asset pricing performance: Imposing sparsity

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: In-sample** | | | | | | | | | | | |
| RMSE | 0.221 | 0.213 | 0.207 | 0.199 | 0.260 | 0.278 | 0.258 | 0.259 | 0.232 | 0.166 | 0.214 |
| $R^2_{OLS}$ | 0.101 | 0.160 | 0.206 | 0.267 | -0.244 | -0.426 | -0.233 | -0.238 | 0.008 | 0.489 | 0.152 |
| $R^2_{GLS}$ | 0.093 | 0.116 | 0.131 | 0.153 | 0.078 | 0.083 | 0.087 | 0.078 | 0.249 | 0.176 | 0.220 |
| **Panel B: Out-of-sample** | | | | | | | | | | | |
| RMSE | 0.125 | 0.120 | 0.117 | 0.111 | 0.224 | 0.154 | 0.139 | 0.223 | 0.172 | 0.160 | 0.109 |
| $R^2_{OLS}$ | 0.229 | 0.286 | 0.323 | 0.390 | -1.478 | -0.161 | 0.053 | -1.444 | -0.461 | -0.268 | 0.410 |
| $R^2_{GLS}$ | 0.029 | 0.042 | 0.057 | 0.078 | 0.028 | 0.034 | 0.036 | 0.028 | 0.099 | 0.065 | 0.030 |

## Table IA.XXVI: IS and OS cross-sectional asset pricing performance: Exclusion of top factors

|  | In-sample |  |  |  | Out-of-sample |  |  |  |
|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
| **Panel A: Baseline** | | | | | | | | |
| RMSE | 0.214 | 0.203 | 0.185 | 0.167 | 0.114 | 0.102 | 0.095 | 0.090 |
| $R^2_{OLS}$ | 0.155 | 0.240 | 0.367 | 0.487 | 0.357 | 0.489 | 0.557 | 0.603 |
| $R^2_{GLS}$ | 0.106 | 0.168 | 0.232 | 0.285 | 0.038 | 0.070 | 0.098 | 0.124 |
| **Panel B: Drop top 5 by probability** | | | | | | | | |
| RMSE | 0.200 | 0.196 | 0.192 | 0.186 | 0.115 | 0.105 | 0.100 | 0.098 |
| $R^2_{OLS}$ | 0.177 | 0.210 | 0.242 | 0.288 | 0.344 | 0.458 | 0.504 | 0.525 |
| $R^2_{GLS}$ | 0.107 | 0.149 | 0.189 | 0.223 | 0.035 | 0.060 | 0.083 | 0.102 |
| **Panel C: Drop top 5 by MPR** | | | | | | | | |
| RMSE | 0.196 | 0.187 | 0.180 | 0.171 | 0.116 | 0.103 | 0.097 | 0.094 |
| $R^2_{OLS}$ | 0.219 | 0.288 | 0.339 | 0.405 | 0.340 | 0.475 | 0.534 | 0.567 |
| $R^2_{GLS}$ | 0.098 | 0.140 | 0.174 | 0.205 | 0.033 | 0.056 | 0.077 | 0.101 |
| **Panel D: Drop union (8 factors)** | | | | | | | | |
| RMSE | 0.197 | 0.190 | 0.186 | 0.181 | 0.116 | 0.104 | 0.099 | 0.099 |
| $R^2_{OLS}$ | 0.210 | 0.265 | 0.300 | 0.337 | 0.336 | 0.467 | 0.513 | 0.520 |
| $R^2_{GLS}$ | 0.098 | 0.136 | 0.165 | 0.183 | 0.032 | 0.051 | 0.064 | 0.073 |

The BMA-SDF constructed with the limited set of factors still strongly outperforms canonical models from the literature both in- and out-of-sample.

Figures IA.36 to IA.38 present the posterior factor probabilities and market prices of risk corresponding to Panels B through D in Table IA.XXVI. Removing the top factors from Table A.2 results in increased posterior weights for $\mathbb{E}[\lambda_j \mid \text{data}]$ of several noisy proxies in the BMA-SDF -- precisely what our theoretical and simulation results in Section 2.4 predict.

*(Page 91-92)*

## Figure IA.36: Posterior factor probabilities and risk prices excluding top factors based on posterior probability

**Description:** Two panels showing posterior probabilities and MPR for 49 factors after excluding PEADB, PEAD, IVOL, CREDIT, and YSP.

**Key takeaway:** After removing top 5 factors, the next most likely factors include MOMBS, CMAs, LVL, LIQNT, CRY, INFLC, INFLV, UNCr. The SDF redistributes weight across remaining noisy proxies.

## Table IA.XXVII: Ex post Sharpe ratios by corporate bond data

| Data type | 20% | 40% | 60% | 80% | Max |
|-----------|-----|-----|-----|-----|-----|
| LBFI/BAML ICE bond-level | 1.05 | 2.10 | 3.14 | 4.19 | 5.24 |
| LBFI/BAML ICE firm-level | 0.98 | 1.96 | 2.94 | 3.92 | 4.90 |
| LBFI/BAML ICE bond-level quotes | 1.03 | 2.06 | 3.08 | 4.11 | 5.14 |
| WRDS TRACE | 1.02 | 2.05 | 3.07 | 4.10 | 5.12 |
| DFPS TRACE | 1.09 | 2.18 | 3.27 | 4.36 | 5.45 |

## Figure IA.37: Posterior factor probabilities and risk prices excluding top factors based on market price of risk

**Description:** Two panels for 49 factors after excluding PEADB, PEAD, CRY, QMJ, and MOMBS.

**Key takeaway:** After removal, IVOL, YSP, CMAs, CREDIT, LVL, INFLC, and INFLV become the top factors. The redistributed weights across noisy proxies again confirm theoretical predictions from Section 2.4.

## Figure IA.38: Posterior factor probabilities and risk prices excluding top factors (union)

**Description:** Two panels for 46 factors after excluding the union of 8 factors: PEADB, PEAD, IVOL, CREDIT, YSP, MOMBS, QMJ, and CRY.

**Key takeaway:** Even after removing 8 factors, the remaining BMA-SDF still captures priced risk, with CMAs, LVL, INFLV, UNCr, INFLC being the most likely factors.

## Figure IA.39: Varying corporate bond data

**Description:** Two panels showing average, minimum, and maximum posterior factor probabilities (Panel A) and market prices of risk (Panel B) across five corporate bond datasets at 80% SR shrinkage. Factors marked with asterisks indicate baseline top-five: PEADB, IVOL, PEAD, YSP, CREDIT.

**Key takeaway:** Eight out of ten and all top five most likely factors to be included in the SDF remain the same across the five datasets. PEADB and PEAD remain the most likely tradable factors with tight min/max bounds. CREDIT, YSP, and LVL remain top nontradable factors.

---

*(Page 93-96)*

<!-- @section-type: robustness
  @key-claim: BMA-SDF results are robust to varying corporate bond data sources, IS cross-sections, and OS cross-sections
  @importance: core
  @data-source: Five bond datasets, DFPS/JKP anomaly portfolios
  @depends-on: Section 4.4
  @equations: none
-->

## IA.10. Estimation uncertainty

In this section we provide additional results to complement the robustness analysis in Section 4.4.

### IA.10.1. Varying corporate bond data

We start by revisiting the different corporate bond datasets described in Internet Appendix IA.1. In particular, we study the pricing performance of the co-pricing BMA-SDF estimated using the baseline stock test assets, stock tradable factors, nontradable factors as well as bond test assets and bond tradable factors constructed using five different sets of corporate bond data: (i) our baseline LBFI/BAML ICE bond-level data, (ii) the LBFI/BAML ICE firm-level data, (iii) the LBFI/BAML ICE bond-level data but using only quotes (i.e., removing matrix prices), (iv) the transaction-based WRDS TRACE data, and (v) the transaction-based DFPS TRACE data. That is, we re-estimate the co-pricing BMA-SDF using the 83 test assets and 54 tradable and nontradable factors. Across estimations, only the 50 IS bond test assets and the tradable bond factors change.

We replicate the results in Section 3.1.1 across the five data samples. For consistency, we fix the sample period from January 1986 to December 2022, except for the DFPS TRACE data that ends in December 2021. That means for the two TRACE data sets we augment the data with our baseline LBFI/BAML ICE bond-level data January 1997 to July 2002 because TRACE is only available thereafter. Before January 1997, we always use LBFI (with and without matrix prices). For each dataset, the estimation yields posterior probabilities (given the data) of each factor, (i.e., $\mathbb{E}[\gamma_j \mid \text{data}], \forall j$) for different values of the prior Sharpe ratio achievable with the BMA-SDF (expressed as a percentage of the ex post maximum Sharpe ratio). We set the prior as a fraction (20%, 40%, 60% and 80%) of the ex post maximum Sharpe ratio given each dataset, as reported in Table IA.XXVII.

Across all five datasets, the maximum achievable Sharpe ratio is similar, ranging from 4.90 (LBFI/BAML ICE firm-level) to 5.45 (DFPS TRACE augmented with LBFI/BAML ICE bond-level). To concisely report which factors are the most likely components of the co-pricing BMA-SDF in the economy across datasets, we focus on the posterior probabilities estimated with 80% shrinkage, resulting in five $54 \times 1$ vectors of averaged posterior probabilities (given each respective dataset). In Figure IA.39 we report the means along with minimum and maximum values of posterior probabilities (Panel A) and market prices of risk (Panel B), ordered by probabilities. The average of the posterior probabilities across the five datasets yields a set of factors that are most likely to be included in the SDF that are very similar to the baseline results reported in Table Appendix C of the Appendix: eight out of ten and all top five most likely factors to be included in the SDF remain the same.

Examining the tradable factors first, both PEADB and PEAD remain the most likely to be included, with very tight min and max values. In fact, the minimum posterior probability for PEADB across the five datasets is still above the next highest value (the maximum of PEAD). Additionally, the ordering of the three most likely factors is identical to our baseline results (i.e., PEADB, PEAD and then IVOL). Turning to the nontradable factors, CREDIT, YSP and LVL are all in the top ten, again closely aligned with the results reported in the paper. Thus, overall, even though some of the tradable bond factors marginally differ across the respective datasets, this does not, on average, affect the results when considering factors individually.

Furthermore, the in- and out-of-sample asset pricing results remain very similar to what we report in Tables 2 and 3. The aggregated results across the five datasets are presented in Figures IA.40 (IS) and IA.41 (OS). For each model we consider in Tables 2 and 3, we report the average, minimum and maximum values for the $R^2_{GLS}$ (Panel A) and $R^2_{OLS}$ (Panel B) asset pricing metrics. For the BMA-SDF, the spread in the metrics between minimum and maximum values is very tight and the average BMA-SDF across all five datasets outperforms the frequentist and latent (KNS and RPPCA) factor models both in- and out-of-sample for higher percentages of shrinkage of the prior Sharpe ratio.

This result, given our estimation methodology, is expected. The BMA-SDF aggregates factors to optimize the signal-to-noise ratio of the SDF. Although different datasets may alter individual factors' signal-to-noise ratios, the BMA-SDF recombines these factors to extract common pricing information while minimizing noise effects, thereby mitigating concerns about data uncertainty in our analysis.

### IA.10.2. Varying in-sample cross-sections

In this section we fix the corporate bond data to construct the tradable bond factors to our baseline LBFI/BAML ICE bond-level data. However, we vary the cross-sections of IS test assets using publicly available corporate bond and stock anomaly portfolio data from Christian Stolborg's webpage (corporate bond data associated with Dick-Nielsen et al. (2025)) and the Jensen et al. (2023) equity data repository from jkpfactors.com.

The DFPS bond data repository contains 153 corporate bond anomaly portfolios formed with the underlying equity characteristics from JKP. The portfolios are long-short formed using (3 x 3), rating x characteristic tercile sorts and span the sample period January 1984 to December 2021, with a missing row of data in August 2002. We start the sample in January 1986 to align the start date of our baseline data, resulting in $T = 431$ observations in the time series. We then extract the same 153 anomaly portfolios from the JKP data repository, resulting in a total cross-section of 306 stock and bond anomaly portfolios.

To account for estimation uncertainty, we fix the size of our total co-pricing cross-section to 50. That is, we randomly sample 25 anomalies (one bond and one stock) resulting in a co-pricing cross-section of 50 test assets. We then repeat this process 100 times and apply our hierarchical Bayesian method including the constant with Beta(1,1) priors as in Section 3. For each estimation, we store the posterior factor probabilities, market prices of risk, and in-sample asset pricing performance metrics. We also price the baseline 154 OS test assets described in Section 1 using the estimated co-pricing BMA-SDF. For ease of exposition, we again focus on an ex post Sharpe ratio shrinkage set to 80%.

*Posterior probabilities and market prices of risk for hundreds of estimations.* We present the average posterior probabilities and market prices of risk with associated minimum and maximum values across the 100 estimations in Panels A and B of Figure IA.42 with the Sharpe ratio shrinkage set of 80% of the ex post maximum. On the x-axis, we denote factors which are in the top five based on posterior probabilities in Table A.2 of Appendix C with a leading asterisk. Affirming the results from Section 3, the factors which are most likely to be included are very closely aligned with IVOL, PEADB and PEAD coming out on top. Other factors which are in the top 10 most likely across both sets of estimations are MOMBS, YSP, CREDIT, LVL and MKTS (i.e., 8 out of 10 are the same). These results strengthen the case of these factors being likely candidates for inclusion in the SDF from estimations that use a very different set of cross-sectional assets, with data prepared by external sources, different bond data for the test assets (DFPS TRACE), and over a slightly shorter sample period.

*Asset pricing results for hundreds of estimations.* In Figure IA.43 we present the IS mean, minimum and maximum $R^2_{GLS}$ (Panel A) and $R^2_{OLS}$ (Panel B) values across 100 estimations for the BMA-SDF across our four Sharpe ratio shrinkage levels and other benchmark models discussed in Appendix D. Based on the $R^2_{GLS}$, the BMA-SDF with 60% and 80% shrinkage as well as the TOP model including the top 5 most likely factors outperform KNS, RPPCA and the frequentist asset pricing models by a wide margin.

The results carry over to the OS analysis presented in Figure IA.44 where we use the SDFs estimated on the 100 different cross-sections to price the baseline 154 OS test assets discussed in Section 1.

*Switch in- to out-of-sample test assets.* We further vary the IS test assets by swapping IS and OS test assets from our baseline analysis in Section 3. Thus, the IS test assets now comprise the combined 154 OS bond and stock portfolios discussed in Section 1 plus the 40 tradable bond and stock factors. The OS test assets are then the original 83 bond and stock portfolios. The posterior factor probabilities and market prices of risk with 80% Sharpe ratio shrinkage are reported in Figure IA.45. The most likely factors still remain very consistent with IVOL, PEADB, YSP, and CREDIT and LVL, followed by PEAD. The corresponding IS and OS asset pricing results are reported in Table IA.XXVIII, the BMA-SDF outperforms the competition both in- and out-of-sample.

*(Page 97-100)*

### IA.10.3. Varying out-of-sample cross-sections

Next we go back to the IS co-pricing BMA-SDFs from Section 3 that are estimated using our baseline set of test assets. In addition, we again consider the additional benchmark models described in Appendix D. Equipped with the IS SDFs, we price millions of possible combinations of the Dick-Nielsen et al. (2025) and Jensen et al. (2023) bond and stock anomalies *without* re-estimating the respective SDFs. We conduct the asset pricing tests using a bootstrap approach and summarize the results in Table IA.XXIX. The DFPS and JKP dataset comprises 153 anomalies for bonds and stocks, resulting in 306 combined bond and stock anomaly portfolios. We set the size of the OS cross-section to 50 portfolios in Panel A and to 100 portfolios in Panel B, implying that for each bootstrap iteration, we draw 25 and 50 unique anomalies, respectively. We then generate one million combinations for each cross-section size and report the average asset pricing metrics along with their standard deviations in square brackets. As in Panel A of Table 3, the BMA-SDF outperforms all other frequentist models and the latent factor models RPPCA and KNS.

## Table IA.XXVIII: IS and OS cross-sectional asset pricing performance: Switching IS and OS test assets

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: Switch IS to OS, in-sample** | | | | | | | | | | | |
| RMSE | 0.152 | 0.130 | 0.116 | 0.110 | 0.247 | 0.206 | 0.203 | 0.245 | 0.232 | 0.182 | 0.157 |
| $R^2_{OLS}$ | 0.304 | 0.491 | 0.594 | 0.636 | -0.843 | -0.281 | -0.240 | -0.807 | -0.628 | -0.004 | 0.258 |
| $R^2_{GLS}$ | 0.191 | 0.227 | 0.257 | 0.278 | 0.183 | 0.186 | 0.187 | 0.183 | 0.302 | 0.048 | 0.240 |
| **Panel B: Switch IS to OS, out-of-sample** | | | | | | | | | | | |
| RMSE | 0.195 | 0.190 | 0.184 | 0.175 | 0.199 | 0.220 | 0.189 | 0.202 | 0.207 | 0.199 | 0.194 |
| $R^2_{OLS}$ | 0.173 | 0.211 | 0.262 | 0.337 | 0.137 | -0.055 | 0.222 | 0.110 | 0.063 | 0.141 | 0.183 |
| $R^2_{GLS}$ | 0.057 | 0.104 | 0.138 | 0.159 | -0.064 | -0.033 | -0.071 | -0.062 | -0.019 | 0.083 | 0.027 |

## Table IA.XXIX: Millions of out-of-sample cross-sectional asset pricing tests

|  | BMA Prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: 50 OS portfolios** | | | | | | | | | | | |
| RMSE | 0.309 | 0.303 | 0.290 | 0.272 | 0.359 | 0.362 | 0.344 | 0.368 | 0.230 | 0.278 | 0.317 |
| $R^2_{OLS}$ | 0.047 | 0.080 | 0.155 | 0.255 | -0.287 | -0.310 | -0.175 | -0.351 | 0.453 | 0.228 | -0.017 |
| $R^2_{GLS}$ | 0.086 | 0.149 | 0.215 | 0.281 | -0.001 | 0.022 | 0.006 | 0.019 | 0.385 | 0.214 | 0.139 |
| **Panel B: 100 OS portfolios** | | | | | | | | | | | |
| RMSE | 0.313 | 0.307 | 0.293 | 0.274 | 0.363 | 0.367 | 0.348 | 0.372 | 0.231 | 0.281 | 0.320 |
| $R^2_{OLS}$ | 0.048 | 0.084 | 0.162 | 0.264 | -0.285 | -0.309 | -0.176 | -0.348 | 0.472 | 0.231 | -0.004 |
| $R^2_{GLS}$ | 0.043 | 0.093 | 0.143 | 0.192 | -0.019 | -0.011 | -0.019 | -0.015 | 0.250 | 0.152 | 0.098 |

### IA.10.4. Varying factor zoos and sample periods

Finally, we provide results to accompany the discussion in Section 4.4.3 where we vary the factor zoos as well as the sample periods. First, we expand the set of stock and nontradable factors by including all 51 stock factors considered in Bryzgalova et al. (2023) as well as their IS test assets. To do so we have to consider a shorter sample period ending in December 2016. Second, we extend the corporate bond factor zoo by adding the 13 Dick-Nielsen et al. (2025) composite bond return factors formed with equity characteristics. Third, extend the corporate bond factor zoo again, this time by including the tradable liquidity factor LRF from Bai et al. (2019) as well as the two nontradable illiquidity factors from Lin et al. (2011). Here, we restrict the sample period to the TRACE era from 2002 onwards. Fourth, we estimate the models on the maximally possible sample period starting in 1977 and resulting in a total of 549 observations in the time series. Finally, we consider two sample splits and estimate the models (i) for the pre- and post-TRACE period (i.e., pre-/post-2002) and (ii) for the pre- and post-2000 period as in van Binsbergen et al. (2025).

*Extended stock and nontradable factor zoo following Bryzgalova et al. (2023).* We extend the cross-sectional dimension of our stock and nontradable factor zoo to match BHJ, resulting in a time series spanning January 1986 to December 2016 for a total of 372 monthly observations. The number of stock factors increases from 24 to 35, and the number of nontradable factors from 14 to 24. We also use the 51 equity test asset portfolios from Bryzgalova et al. (2023). After combining their stock and nontradable factors with our co-pricing factor zoo, the number of factors totals 75, resulting in 37.8 sextillion possible models. We apply our hierarchical Bayesian method including the constant with Beta(1,1) priors as in Section 3 to the joint cross-section of stock and corporate bond excess returns. For brevity, we report the posterior factor probabilities and market prices of risk with 80% Sharpe ratio shrinkage in Figure IA.46. Confirming the main results, the top five factors are displayed in Panel A are IVOL, PEADB, PEAD, BW_ISENT, and CREDIT (four out of five match those from Table A.2 in Appendix C). These factors also yield large posterior market prices of risk in Panel B. In addition, the BW_ISENT sentiment nontradable factor of Baker and Wurgler (2006) is a likely candidate for inclusion in the co-pricing BMA-SDF using the extended factor zoo.

*Extended bond factor zoo following Dick-Nielsen et al. (2025).* We now extend the corporate bond factor zoo to include the 13 bond factor clusters (aggregated factors) formed with underlying equity characteristic data from DFPS.[^8] The sample spans the period January 1986 to December 2021 for a total of 432 monthly observations. The posterior factor probabilities and market prices of risk with 80% Sharpe ratio shrinkage are reported in Figure IA.47. Results again closely align with those reported in Section 3. Only 2 of the 13 DFPS aggregate factors are likely candidates for inclusion to the BMA-SDF. These include the composite bond factors formed with equity short-reversal, DFPS_STREV and momentum, DFPS_MOM equity characteristics. This overlaps with the factors already included in our baseline bond factor zoo (MOMBS and PEADB), both of which are formed with prior equity return data.

[^8]: This data is available for download here.

*Extended bond factor zoo including TRACE bond illiquidity factors.* We again tweak the bond factor zoo by including three additional illiquidity factors computed using TRACE transaction data. In particular, we include the tradable liquidity risk factor LRF from Bai et al. (2019) and the Amihud (2002) (AMD) and Pastor and Stambaugh (2003) (PSB) nontradable risk factors from Lin et al. (2011). The sample is restricted to the TRACE era from October 2002 to December 2022 for a total of 243 monthly observations (with two months lost to compute the illiquidity factors). The set of IS test assets remains the largely same, we only add the tradable LRF factor. The posterior factor probabilities and market prices of risk with 80% Sharpe ratio shrinkage are reported in Figure IA.48. None of the illiquidity factors are likely candidates for inclusion in the BMA-SDF. Notably, the LRF factor is the *least* likely bond factor to be included with a market price of risk close to zero. Likewise, nontradable AMD factor is the least likely nontradable factor for inclusion. Our results echo those of, e.g., Richardson and Palhares (2019) who document a very limited illiquidity premium in corporate bond returns using characteristic portfolio sorts.

*(Page 101-104)*

## Table IA.XXX: In-sample cross-sectional asset pricing performance: Robustness

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: Extended stock/NT zoo (BHJ), 1986-2016** | | | | | | | | | | | |
| RMSE | 0.281 | 0.237 | 0.198 | 0.165 | 0.330 | 0.292 | 0.277 | 0.331 | 0.295 | 0.168 | 0.203 |
| $R^2_{OLS}$ | 0.229 | 0.451 | 0.619 | 0.735 | -0.064 | 0.168 | 0.253 | -0.071 | 0.149 | 0.724 | 0.597 |
| $R^2_{GLS}$ | 0.141 | 0.200 | 0.271 | 0.348 | 0.120 | 0.131 | 0.131 | 0.120 | 0.336 | 0.184 | 0.226 |
| **Panel B: Extended bond zoo (DFPS), 1986-2021** | | | | | | | | | | | |
| RMSE | 0.259 | 0.235 | 0.212 | 0.189 | 0.292 | 0.299 | 0.269 | 0.289 | 0.203 | 0.191 | 0.251 |
| $R^2_{OLS}$ | 0.177 | 0.325 | 0.448 | 0.565 | -0.041 | -0.094 | 0.112 | -0.025 | 0.496 | 0.553 | 0.230 |
| $R^2_{GLS}$ | 0.120 | 0.181 | 0.242 | 0.299 | 0.097 | 0.104 | 0.105 | 0.098 | 0.284 | 0.171 | 0.222 |
| **Panel C: TRACE illiquidity, 2002-2022** | | | | | | | | | | | |
| RMSE | 0.206 | 0.178 | 0.155 | 0.135 | 0.240 | 0.233 | 0.235 | 0.219 | 0.247 | 0.182 | 0.175 |
| $R^2_{OLS}$ | 0.279 | 0.460 | 0.589 | 0.688 | 0.021 | 0.080 | 0.057 | 0.181 | -0.035 | 0.438 | 0.479 |
| $R^2_{GLS}$ | 0.056 | 0.085 | 0.120 | 0.158 | 0.054 | 0.053 | 0.057 | 0.056 | 0.242 | 0.022 | 0.110 |
| **Panel D: Extended to 1977, 1977-2022** | | | | | | | | | | | |
| RMSE | 0.206 | 0.209 | 0.197 | 0.179 | 0.264 | 0.304 | 0.325 | 0.265 | 0.332 | 0.145 | 0.227 |
| $R^2_{OLS}$ | -0.015 | -0.047 | 0.069 | 0.233 | -0.675 | -1.213 | -1.525 | -0.678 | -1.642 | 0.495 | -0.230 |
| $R^2_{GLS}$ | 0.062 | 0.147 | 0.237 | 0.322 | 0.018 | 0.016 | 0.031 | 0.019 | 0.239 | 0.338 | 0.237 |

## Table IA.XXXI: Out-of-sample cross-sectional asset pricing performance: Robustness

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: Extended stock/NT zoo (BHJ), 1986-2016** | | | | | | | | | | | |
| RMSE | 0.147 | 0.116 | 0.103 | 0.097 | 0.293 | 0.141 | 0.183 | 0.293 | 0.180 | 0.144 | 0.113 |
| $R^2_{OLS}$ | 0.422 | 0.642 | 0.717 | 0.751 | -1.296 | 0.468 | 0.104 | -1.301 | 0.129 | 0.447 | 0.656 |
| $R^2_{GLS}$ | 0.048 | 0.083 | 0.121 | 0.157 | 0.037 | 0.052 | 0.041 | 0.038 | 0.117 | 0.090 | 0.069 |
| **Panel B: Extended bond zoo (DFPS), 1986-2021** | | | | | | | | | | | |
| RMSE | 0.125 | 0.105 | 0.099 | 0.095 | 0.277 | 0.152 | 0.158 | 0.275 | 0.186 | 0.146 | 0.115 |
| $R^2_{OLS}$ | 0.428 | 0.596 | 0.643 | 0.665 | -1.833 | 0.153 | 0.081 | -1.785 | -0.271 | 0.221 | 0.514 |
| $R^2_{GLS}$ | 0.044 | 0.079 | 0.107 | 0.131 | 0.036 | 0.047 | 0.046 | 0.037 | 0.099 | 0.085 | 0.033 |
| **Panel C: TRACE illiquidity, 2002-2022** | | | | | | | | | | | |
| RMSE | 0.121 | 0.120 | 0.117 | 0.114 | 0.175 | 0.187 | 0.130 | 0.159 | 0.290 | 0.149 | 0.102 |
| $R^2_{OLS}$ | 0.030 | 0.048 | 0.100 | 0.143 | -1.030 | -1.308 | -0.112 | -0.671 | -4.553 | -0.475 | 0.312 |
| $R^2_{GLS}$ | 0.008 | 0.022 | 0.036 | 0.048 | 0.005 | 0.004 | 0.012 | 0.010 | -0.041 | 0.016 | 0.015 |
| **Panel D: Extended to 1977, 1977-2022** | | | | | | | | | | | |
| RMSE | 0.114 | 0.115 | 0.106 | 0.102 | 0.132 | 0.178 | 0.094 | 0.134 | 0.293 | 0.122 | 0.100 |
| $R^2_{OLS}$ | -0.191 | -0.210 | -0.016 | 0.047 | -0.587 | -1.876 | 0.192 | -0.639 | -6.775 | -0.359 | 0.089 |
| $R^2_{GLS}$ | 0.040 | 0.086 | 0.118 | 0.138 | 0.021 | 0.015 | 0.030 | 0.019 | -0.007 | 0.113 | 0.012 |

result remain unaffected compared to what we report in Section 3. The top five factors in terms of posterior probabilities are PEADB, PEAD, CRY, MOMBS, and CREDIT. Other factors outside the top five but with a posterior probability > 50% include LVL, IVOL and YSP, again aligning with the baseline results. These factors also yield relatively large posterior market prices of risk.

**Figure IA.49: Posterior factor probabilities and market prices of risk: Extended sample (1977-2022).** Two-panel bar chart for the maximally possible sample period starting in 1977 (T = 549). Panel (A) Posterior probabilities: PEADB (~0.79, highest), PEAD (~0.73), CRY (~0.71), MOMBS (~0.70), CREDIT (~0.64), LVL (~0.63), IVOL (~0.60), YSP (~0.59), with RMW_star near the 0.50 prior line. The "_star" suffix factors (HML_star, SMB_star, MktRF_star, CMA_star, RMW_star) from the extended factor set are included. Panel (B) Posterior market prices of risk for the same factors. Three factor categories: Non-traded (dark blue), Bond tradable (light blue), Equity tradable (red). Results confirm baseline findings with the extended sample.

*Varying subsamples.* Finally, we present the in- and out-of-sample cross-sectional asset pricing performance for two sample splits in Tables IA.XXXII and IA.XXXIII. In particular, we first estimate the models for the pre- and post-TRACE era, i.e., before and after July 2002 (respective Panels A and C). Second, we also split the sample into a pre- and post-2000 period as in van Binsbergen et al. (2025) (respective Panels B and D).

The results from the full sample estimation in Tables 2 and 3 carry over to the subsamples, the BMA-SDF and TOP models outperform the other competitor models. Note, however, that the OS pricing exercise in Table IA.XXXIII is more stringent than the one in Table 3. For the full sample, only the test assets are out-of-sample. Once we have two sample splits, we perform the OS pricing not only in the cross-section but also the time series. That is, we estimate the BMA-SDF using the IS test assets for the respective sample period and then use the resulting SDF to price (with no additional parameter estimation) each set of the OS test assets over the remaining sample.

## Table IA.XXXII: In-sample cross-sectional asset pricing performance across sample splits

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: Pre-TRACE, 1986:01-2002:07** | | | | | | | | | | | |
| RMSE | 0.318 | 0.308 | 0.295 | 0.279 | 0.362 | 0.391 | 0.365 | 0.359 | 0.364 | 0.263 | 0.357 |
| $R^2_{OLS}$ | 0.118 | 0.171 | 0.240 | 0.317 | -0.149 | -0.336 | -0.163 | -0.126 | -0.158 | 0.396 | -0.115 |
| $R^2_{GLS}$ | 0.078 | 0.098 | 0.120 | 0.144 | 0.086 | 0.088 | 0.090 | 0.086 | 0.189 | 0.097 | 0.156 |
| **Panel B: Pre-2000, 1986:01-1999:12** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.063 | 0.122 | 0.183 | 0.244 | 0.138 | -0.035 | 0.170 | 0.131 | -0.423 | 0.651 | 0.471 |
| $R^2_{GLS}$ | 0.125 | 0.136 | 0.149 | 0.165 | 0.185 | 0.185 | 0.187 | 0.186 | 0.251 | 0.100 | 0.250 |
| **Panel C: Post-TRACE, 2002:08-2022:12** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.283 | 0.480 | 0.604 | 0.700 | 0.029 | 0.086 | 0.047 | 0.210 | 0.020 | 0.452 | 0.505 |
| $R^2_{GLS}$ | 0.046 | 0.075 | 0.108 | 0.146 | 0.040 | 0.041 | 0.044 | 0.042 | 0.231 | 0.018 | 0.100 |
| **Panel D: Post-2000, 2000:01-2022:12** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.234 | 0.423 | 0.585 | 0.708 | -0.337 | -0.644 | -0.527 | -0.332 | -0.113 | 0.580 | 0.256 |
| $R^2_{GLS}$ | 0.033 | 0.081 | 0.132 | 0.185 | 0.008 | 0.015 | 0.020 | 0.008 | 0.234 | 0.115 | 0.097 |

## Table IA.XXXIII: Out-of-sample cross-sectional asset pricing performance across sample splits

|  | BMA-SDF prior SR |  |  |  | CAPM | CAPMB | FF5 | HKM | TOP | KNS | RPPCA |
|--|--|--|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | | | | | | | |
| **Panel A: Pre-TRACE** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.073 | 0.129 | 0.121 | -0.139 | -0.682 | -1.325 | -1.440 | -0.887 | -0.786 | -0.657 | -44.455 |
| $R^2_{GLS}$ | 0.001 | 0.008 | 0.014 | 0.017 | -0.004 | -0.003 | -0.015 | -0.008 | -0.120 | 0.014 | -0.284 |
| **Panel B: Pre-2000** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.225 | 0.420 | 0.578 | 0.641 | -2.656 | 0.139 | -4.540 | -2.486 | -2.099 | -0.073 | -5.469 |
| $R^2_{GLS}$ | 0.037 | 0.050 | 0.062 | 0.074 | 0.044 | 0.055 | 0.031 | 0.045 | -0.126 | -0.018 | -0.305 |
| **Panel C: Post-TRACE** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.157 | 0.279 | 0.305 | 0.226 | -1.078 | 0.414 | -0.121 | -1.218 | -0.230 | 0.440 | -2.830 |
| $R^2_{GLS}$ | 0.009 | 0.018 | 0.023 | 0.023 | 0.006 | 0.009 | 0.007 | 0.005 | -0.155 | 0.011 | 0.021 |
| **Panel D: Post-2000** | | | | | | | | | | | |
| $R^2_{OLS}$ | 0.126 | 0.181 | 0.094 | -0.126 | -0.398 | -0.308 | -0.008 | -0.408 | -1.132 | -0.173 | -0.864 |
| $R^2_{GLS}$ | 0.006 | 0.010 | 0.013 | 0.015 | 0.007 | 0.007 | 0.006 | 0.007 | -0.007 | 0.015 | 0.012 |

*(Page 105-106)*

<!-- @section-type: robustness
  @key-claim: The CREDIT factor is robust to alternative constructions; custom-made version yields nearly identical results
  @importance: supporting
  @data-source: Moody's BAA-AAA yield indices, custom-built LBFI/BAML ICE indices
  @depends-on: Section 3
  @equations: none
-->

## IA.11. The nontradable CREDIT factor

The nontradable CREDIT factor is defined as the difference between aggregate corporate bond yield indices made available by FRED (the BAA index minus the AAA index), using data constructed by Moody's. The CREDIT factor is consistently included as a top factor (large posterior probability) with a sizable market price of risk across all of our estimations.

A wider BAA-AAA spread indicates that investors are *less* willing to bear credit risk. That is, before (i.e., in the build-up to) a recession, investor portfolios are re-allocated to "safer" securities, implying they are more concerned about bearing credit risk, rendering the CREDIT factor not only a useful indicator of the health of the economy, but a likely candidate for inclusion in the SDF.

*Potential issues with the CREDIT factor.* Unfortunately, the data made available from Moody's is opaque, and perhaps more concerning, only two firms (Microsoft and Johnson & Johnson) are included in the AAA yield index (Boyarchenko and Shachar, 2020) toward the end of the sample. Given that the data filtering process used by Moody's is not publicly available, we reached out to the economics department at Moody's Analytics. The full (and unedited) response from the Moody's economics department is provided below:

> *We don't currently publish a detailed methodology but it is summarized as: "Yield index for US investment grade nonfinancial corporate bonds with long-term maturities. Based on seasoned bonds with remaining maturities of at least 20 Years. Derived from pricing data on a regularly-replenished population of over 100 seasoned corporate bonds in the US market, each with current outstandings over $100 million. The bonds have maturities as close as possible to 30 years, with an average maturity of 28 years; they are dropped from the list if their remaining life falls below 20 years or if their ratings change. Bonds with deep discounts or steep premiums to par are generally excluded. All yields are yield-to-maturity calculated on a semi-annual compounding basis. Each observation is an unweighted average, with Average Corporate Yields representing the unweighted average of the corresponding Average Industrial and Average Public Utility observations." For Aaa you are correct that we currently only have bonds from MSFT and JNJ in the actively traded list. We periodically update a master list of eligible bonds in each ratings bucket and then exclude bonds from the active list whose ratings no longer match the bucket or other criteria.*[^10]

[^10]: We thank David Mena from Moody's Analytics, Inc for helping us with the data.

*A custom made CREDIT factor.* To address the core issues above, (i) opaque data filtering rules and (ii) only two firms being present in the AAA index toward the end of the sample, we re-construct our own "custom-made" high grade and BAA indices with our core dataset comprising the Lehman Brothers and ICE/BAML corporate bond datasets.

We apply the following filters to our data, which ensures a reasonable sample whilst trying to adhere to the filters supposedly applied by Moody's:

(i) Remove bonds with a market capitalization less than $100 million.
(ii) Remove bonds with a credit spread less that 0 or greater than 5,000 bps.
(iii) Remove bonds which are classified as "financials."

When constructing the AAA yield index, we include all bonds rated Aaa to Aa3, e.g., those rated Prime and High Grade with maturities from 20 to 30 years. For the BAA yield index, we keep all bonds rated Baa1 to Baa3, e.g., those rated Lower Medium Grade with maturities from 20 to 30 years. This construction method implies we have 24 unique firms rated Aaa to Aa3 toward the end of the sample (as opposed to only two firms).

*(Page 107)*

On average, from 1986 to 2022, the high grade (Aaa to Aa3) index contains 24 firms, with an average number of bonds equaling 54. For the BAA index, the sample contains an average of 123 firms with an average number of bonds equaling 255. Toward the end of the sample, the BAA index contains 198 firms.

## Figure IA.50: The nontradable CREDIT factor

**Description:** Time series plot (1986-2022) comparing the CREDIT factor from Moody's (blue) and the custom-made version (red), both in basis points. Key statistics: Correlation = 0.89, Mean Custom CREDIT = 87.0 bp, Mean Moody's CREDIT = 97.3 bp.

**Key takeaway:** Despite different data filtering rules and an expanded AAA index (24 firms vs. 2), the two CREDIT factor time series have very similar dynamics with a correlation of 0.89.

## Table IA.XXXIV: IS and OS cross-sectional asset pricing performance: CREDIT factor robustness

|  | In-sample |  |  |  | Out-of-sample |  |  |  |
|--|--|--|--|--|--|--|--|--|
|  | 20% | 40% | 60% | 80% | 20% | 40% | 60% | 80% |
| **Panel A: Baseline with Moody's BAA-AAA** | | | | | | | | |
| RMSE | 0.214 | 0.203 | 0.185 | 0.167 | 0.114 | 0.102 | 0.095 | 0.090 |
| $R^2_{OLS}$ | 0.155 | 0.240 | 0.367 | 0.487 | 0.357 | 0.489 | 0.557 | 0.603 |
| $R^2_{GLS}$ | 0.106 | 0.168 | 0.232 | 0.285 | 0.038 | 0.070 | 0.098 | 0.124 |
| **Panel B: Custom CREDIT (BAA-(AAA+AA))** | | | | | | | | |
| RMSE | 0.214 | 0.203 | 0.186 | 0.169 | 0.114 | 0.102 | 0.095 | 0.091 |
| $R^2_{OLS}$ | 0.151 | 0.240 | 0.361 | 0.476 | 0.357 | 0.486 | 0.551 | 0.593 |
| $R^2_{GLS}$ | 0.106 | 0.167 | 0.229 | 0.281 | 0.037 | 0.069 | 0.096 | 0.120 |

Posterior probabilities and market prices of risk:

|  | 20% | 40% | 60% | 80% |
|--|--|--|--|--|
| **Panel C: Moody's CREDIT** | | | | |
| $\mathbb{E}[\gamma_j \mid \text{data}]$ | 0.498 | 0.497 | 0.530 | 0.557 |
| $\mathbb{E}[\lambda_j \mid \text{data}]$ | 0.002 | 0.009 | 0.024 | 0.055 |
| **Panel D: Custom CREDIT** | | | | |
| $\mathbb{E}[\gamma_j \mid \text{data}]$ | 0.487 | 0.494 | 0.517 | 0.518 |
| $\mathbb{E}[\lambda_j \mid \text{data}]$ | 0.001 | 0.006 | 0.015 | 0.034 |

*The BMA-SDF with the custom CREDIT factor.* We now re-estimate our baseline results with the custom made CREDIT factor. We report the in-and-out-of-sample asset pricing results over the four levels of SR shrinkage in Table IA.XXXIV. First, the in and out-of-sample asset pricing results are close to identical with numbers changing only at the third decimal place. Second, the table documents that both the posterior probabilities and the MPRs are closely aligned, confirming results in the main text using Moody's CREDIT factor. In unreported results, we also re-estimate the BMA-SDF with the GZ spread (as opposed to the CREDIT spread) from Gilchrist and Zakrajsek (2012) and document very similar results.[^11]

[^11]: We thank Yoshio Nozawa for making the GZ spread data available to us.

*Why are the results so consistent?* Our theoretical and simulation results (see Section 2.4) show that stability is expected from our robust inference method. Since individual factors contain both signals about fundamental risk sources and noise, the BMA-SDF optimally aggregates them to maximize the signal-to-noise ratio. While data perturbations may affect individual factors (such as the CREDIT factor), the BMA-SDF largely mitigates this impact.

---

*(Page 107-109)*

<!-- @section-type: references
  @key-claim: Bibliography for Internet Appendix
  @importance: supporting
  @data-source: N/A
  @depends-on: all sections
  @equations: none
-->

## References

Abarbanell, J.S., Bushee, B.J., 1998. Abnormal returns to a fundamental analysis strategy. The Accounting Review 73, 19-45.

Ali, A., Hwang, L.S., Trombley, M.A., 2003. Arbitrage risk and the book-to-market anomaly. Journal of Financial Economics 69, 355-373.

Amihud, Y., 2002. Illiquidity and stock returns: Cross-section and time-series effects. Journal of Financial Markets 5, 31-56.

Anderson, C.W., Garcia-Feijoo, L., 2006. Empirical evidence on capital investment, growth options, and security returns. The Journal of Finance 61, 171-194.

Andreani, M., Palhares, D., Richardson, S., 2023. Computing corporate bond returns: A word (or two) of caution. Review of Accounting Studies.

Ang, A., Hodrick, R.J., Xing, Y., Zhang, X., 2006. The cross-section of volatility and expected returns. The Journal of Finance 61, 259-299.

Bai, J., Bali, T.G., Wen, Q., 2019. RETRACTED: Common risk factors in the cross-section of corporate bond returns. Journal of Financial Economics 131, 619-642.

Baker, M., Wurgler, J., 2006. Investor sentiment and the cross-section of stock returns. The Journal of Finance 61, 1645-1680.

Balakrishnan, K., Bartov, E., Faurel, L., 2010. Post loss/profit announcement drift. Journal of Accounting and Economics 50, 20-41.

Bali, T.G., Subrahmanyam, A., Wen, Q., 2021a. Long-term reversals in the corporate bond market. Journal of Financial Economics 139, 656-677.

Bali, T.G., Subrahmanyam, A., Wen, Q., 2021b. The macroeconomic uncertainty premium in the corporate bond market. Journal of Financial and Quantitative Analysis 56, 1653-1678.

Ball, R., Gerakos, J., Linnainmaa, J.T., Nikolaev, V., 2016. Accruals, cash flows, and operating profitability in the cross section of stock returns. Journal of Financial Economics 121, 28-45.

Bartram, S.M., Grinblatt, M., Nozawa, Y., 2025. Book-to-market, mispricing, and the cross section of corporate bond returns. Journal of Financial and Quantitative Analysis 60, 1185-1233.

Basu, S., 1983. The relationship between earnings' yield, market value and return for NYSE common stocks: Further evidence. Journal of Financial Economics 12, 129-156.

Bessembinder, H., Kahle, K.M., Maxwell, W.F., Xu, D., 2008. Measuring abnormal bond performance. The Review of Financial Studies 22, 4219-4258.

Bhandari, L.C., 1988. Debt/equity ratio and expected common stock returns: Empirical evidence. The Journal of Finance 43, 507-528.

van Binsbergen, J.H., Nozawa, Y., Schwert, M., 2025. Duration-based valuation of corporate bonds. The Review of Financial Studies 38, 158-191.

Bouchaud, J.P., Kruger, P., Landier, A., Thesmar, D., 2019. Sticky expectations and the profitability anomaly. The Journal of Finance 74, 639-674.

Boyarchenko, N., Shachar, O., 2020. What's in A(AA) credit rating? Liberty Street Economics.

Brennan, M.J., Chordia, T., Subrahmanyam, A., 1998. Alternative factor specifications, security characteristics, and the cross-section of expected stock returns. Journal of Financial Economics 49, 345-373.

Bryzgalova, S., Huang, J., Julliard, C., 2022. Bayesian Fama-MacBeth. Working Paper, London School of Economics.

Bryzgalova, S., Huang, J., Julliard, C., 2023. Bayesian solutions for the factor zoo: We just ran two quadrillion models. The Journal of Finance 78, 487-557.

Carhart, M.M., 1997. On persistence in mutual fund performance. The Journal of Finance 52, 57-82.

Chamberlain, G., Rothschild, M., 1983. Arbitrage, factor structure and mean-variance analysis in large asset markets. Econometrica 51, 1305-1324.

Chen, L., Da, Z., Zhao, X., 2013. What drives stock price movements? The Review of Financial Studies 26, 841-876.

Chen, L., Zhao, X., 2009. Return decomposition. The Review of Financial Studies 22, 5213-5249.

Choi, J., 2013. What drives the value premium?: The role of asset risk and leverage. The Review of Financial Studies 26, 2845-2875.

Choi, J., Richardson, M., 2016. The volatility of a firm's assets and the leverage effect. Journal of Financial Economics 121, 254-277.

Chordia, T., Goyal, A., Nozawa, Y., Subrahmanyam, A., Tong, Q., 2017. Are capital market anomalies common to equity and corporate bond markets? An empirical investigation. Journal of Financial and Quantitative Analysis 52, 1301-1342.

Chung, K.H., Wang, J., Wu, C., 2019. Volatility and the cross-section of corporate bond returns. Journal of Financial Economics 133, 397-417.

Cohen, R.B., Gompers, P.A., Vuolteenaho, T., 2002. Who underreacts to cash-flow news? Evidence from trading between individuals and institutions. Journal of Financial Economics 66, 409-462.

Cooper, M.J., Gulen, H., Schill, M.J., 2008. Asset growth and the cross-section of stock returns. The Journal of Finance 63, 1609-1651.

Corwin, S.A., Schultz, P., 2012. A simple way to estimate bid-ask spreads from daily high and low prices. The Journal of Finance 67, 719-760.

Daniel, K., Hirshleifer, D., Sun, L., 2020a. Short- and long-horizon behavioral factors. The Review of Financial Studies 33, 1673-1736.

Daniel, K., Mota, L., Rottke, S., Santos, T., 2020b. The cross-section of risk and returns. The Review of Financial Studies 33, 1927-1979.

Daniel, K., Titman, S., 2006. Market reactions to tangible and intangible information. The Journal of Finance 61, 1605-1643.

De Bondt, W.F.M., Thaler, R., 1985. Does the stock market overreact? The Journal of Finance 40, 793-805.

Desai, H., Rajgopal, S., Venkatachalam, M., 2004. Value-glamour and accruals mispricing: One anomaly or two? The Accounting Review 79, 355-385.

Dichev, I.D., 1998. Is the risk of bankruptcy a systematic risk? The Journal of Finance 53, 1131-1147.

Dick-Nielsen, J., Feldhutter, P., Pedersen, L.H., Stolborg, C., 2025. Corporate bond factors: Replication failures and a new framework. Working Paper, Copenhagen Business School.

Dickerson, A., Mueller, P., Robotti, C., 2023. Priced risk in corporate bonds. Journal of Financial Economics 150, 103707.

Dickerson, A., Robotti, C., Rossetti, G., 2024. Common pitfalls in the evaluation of corporate bond strategies. Working Paper, Warwick Business School.

Elkamhi, R., Jo, C., Nozawa, Y., 2023. A one-factor model of corporate bond premia. Management Science 70, 1875-1900.

Fairfield, P.M., Whisenant, J.S., Yohn, T.L., 2003. Accrued earnings and growth: Implications for future profitability and market mispricing. The Accounting Review 78, 353-371.

Fama, E.F., French, K.R., 1992. The cross-section of expected stock returns. The Journal of Finance 47, 427-465.

Fama, E.F., French, K.R., 1993. Common risk factors in the returns on stocks and bonds. Journal of Financial Economics 33, 3-56.

Fama, E.F., French, K.R., 2015. A five-factor asset pricing model. Journal of Financial Economics 116, 1-22.

Fama, E.F., MacBeth, J., 1973. Risk, return, and equilibrium: Empirical tests. Journal of Political Economy 81, 607-636.

Fang, C., 2025. Monetary policy amplification through bond fund flows. Working Paper, Drexel University.

Gebhardt, W.R., Hvidkjaer, S., Swaminathan, B., 2005. The cross-section of expected corporate bond returns: Betas or characteristics? Journal of Financial Economics 75, 85-114.

George, T.J., Hwang, C.Y., 2004. The 52-week high and momentum investing. The Journal of Finance 59, 2145-2176.

Giglio, S., Xiu, D., 2021. Asset pricing with omitted factors. Journal of Political Economy 129, 1947-1990.

Gilchrist, S., Zakrajsek, E., 2012. Credit spreads and business cycle fluctuations. American Economic Review 102, 1692-1720.

Greene, W.H., 2012. Econometric Analysis. 7th ed., Prentice Hall, Upper Saddle River, NJ.

Haugen, R.A., Baker, N.L., 1996. Commonality in the determinants of expected stock returns. Journal of Financial Economics 41, 401-439.

He, Z., Kelly, B., Manela, A., 2017. Intermediary asset pricing: New evidence from many asset classes. Journal of Financial Economics 126, 1-35.

Hirshleifer, D., Kewei Hou, Teoh, S.H., Yinglei Zhang, 2004. Do investors overvalue firms with bloated balance sheets? Journal of Accounting and Economics 38, 297-331.

Hong, G., Warga, A., 2000. An empirical study of bond market transactions. Financial Analysts Journal 56, 32-46.

Hou, K., Xue, C., Zhang, L., 2015. Digesting anomalies: An investment approach. The Review of Financial Studies 28, 650-705.

Houweling, P., Van Zundert, J., 2017. Factor investing in the corporate bond market. Financial Analysts Journal 73, 100-115.

Intercontinental Exchange, 2021. Bond Index Methodologies.

Jensen, T.I., Kelly, B., Pedersen, L.H., 2023. Is there a replication crisis in finance? The Journal of Finance 78, 2465-2518.

Jostova, G., Nikolova, S., Philipov, A., 2024. Data uncertainty in corporate bonds. Working Paper, George Washington University.

Kelly, B.T., Palhares, D., Pruitt, S., 2023. Modeling corporate bond returns. The Journal of Finance 78, 1967-2008.

Kozak, S., Nagel, S., Santosh, S., 2020. Shrinking the cross-section. Journal of Financial Economics 135, 271-292.

Lettau, M., Pelger, M., 2020. Estimating latent asset-pricing factors. Journal of Econometrics 218, 1-31.

Li, L., 2023. Explaining the relationship between outliers and momentum in corporate bonds: Less bad news is more. Working Paper, XJTU.

Lin, H., Wang, J., Wu, C., 2011. Liquidity risk and expected corporate bond returns. Journal of Financial Economics 99, 628-650.

Litzenberger, R.H., Ramaswamy, K., 1979. The effect of personal taxes and dividends on capital asset prices: Theory and empirical evidence. Journal of Financial Economics 7, 163-195.

Liu, Y., Wu, J.C., 2021. Reconstructing the yield curve. Journal of Financial Economics 142, 1395-1425.

Ljung, G.M., Box, G.E.P., 1978. On a measure of lack of fit in time series models. Biometrika 65, 297-303.

Lyandres, E., Sun, L., Zhang, L., 2008. The new issues puzzle: Testing the investment-based explanation. The Review of Financial Studies 21, 2825-2855.

Martineau, C., 2022. Rest in peace post-earnings announcement drift. Critical Finance Review 11, 613-646.

Novy-Marx, R., 2011. Operating leverage. Review of Finance 15, 103-134.

Novy-Marx, R., 2012. Is momentum really momentum? Journal of Financial Economics 103, 429-453.

Novy-Marx, R., 2013. The other side of value: The gross profitability premium. Journal of Financial Economics 108, 1-28.

Nozawa, Y., 2017. What drives the cross-section of credit spreads?: A variance decomposition approach. The Journal of Finance 72, 2045-2072.

Palazzo, B., 2012. Cash holdings, risk, and expected returns. Journal of Financial Economics 104, 162-185.

Pastor, L., Stambaugh, R.F., 2003. Liquidity risk and expected stock returns. Journal of Political Economy 111, 642-685.

Penman, S.H., Yehuda, N., 2019. A matter of principle: Accounting reports convey both cash-flow news and discount-rate news. Management Science 65, 5584-5602.

Pontiff, J., Woodgate, A., 2008. Share issuance and cross-sectional returns. The Journal of Finance 63, 921-945.

Richardson, S., Palhares, D., 2019. (il)liquidity premium in credit markets: A myth? The Journal of Fixed Income 28, 5-23.

Ross, S.A., 1976. The arbitrage theory of capital asset pricing. Journal of Economic Theory 13, 341-360.

Sloan, R.G., 1996. Do stock prices fully reflect information in accruals and cash flows about future earnings? The Accounting Review 71, 289-315.

Soliman, M.T., 2008. The use of dupont analysis by market participants. The Accounting Review 83, 823-853.

Stambaugh, R.F., Yuan, Y., 2017. Mispricing factors. The Review of Financial Studies 30, 1270-1315.

Taggart, R.A., 1987. The growth of the "junk" bond market and its role in financing takeovers, in: Mergers and Acquisitions. University of Chicago Press, pp. 5-24.

Titman, S., Wei, K.C.J., Xie, F., 2004. Capital investments and stock returns. Journal of Financial and Quantitative Analysis 39, 677-700.

Vuolteenaho, T., 2002. What drives firm-level stock returns? The Journal of Finance 57, 233-264.

William C. Barbee, J., Mukherji, S., Raines, G.A., 1996. Do sales-price and debt-equity explain stock returns better than book-market and firm size? Financial Analysts Journal 52, 56-60.
