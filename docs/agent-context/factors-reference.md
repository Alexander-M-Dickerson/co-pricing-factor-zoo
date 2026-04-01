# Factors Reference

This is the repo's canonical factor map for answering questions like:

- "Explain the traded bond factors."
- "What are the nontraded factors?"
- "What is Table A.1?"
- "Which factors are bond, stock, or nontraded?"

Use this file before loading the full paper when the user wants factor-level
explanations.

## Manuscript Anchor

- Manuscript Table A.1: `List of factors for cross-sectional asset pricing`
- Appendix A: `The factor zoo list`

Important distinction:

- manuscript **Table A.1** is the factor list and explanation surface
- manuscript **Table A.2** is the posterior-probability table that complements Figure 2
- the repo output basename `table_a1_posterior_probs_*` is a draft-numbering artifact and should not be confused with manuscript Table A.1

## Structure

- 14 nontraded factors
- 16 traded bond factors
- 24 traded equity factors
- 54 total factors in the baseline joint zoo

When loading saved estimation outputs, use the stored factor-name vectors rather
than reconstructing groups from heuristics:

- `nontraded_names`
- `bond_names`
- `stock_names`

## How To Answer Factor Questions

- If the user asks for the full factor list, start from this file and say it is the repo version of manuscript Table A.1.
- If the user asks for one factor, explain:
  - factor group
  - economic idea
  - construction at a high level
  - why it matters in the paper if known
- If the user asks which factors matter most in the main results, connect back to:
  - `PEADB`
  - `IVOL`
  - `PEAD`
  - `CREDIT`
  - `YSP`

## Traded Bond Factors

| Factor | High-level meaning | Construction cue | Reference / source cue |
|---|---|---|---|
| `CRF` | credit-risk spread factor | long low-rating minus high-rating bond portfolios within VaR-sorted groups | Bai et al. (2019), Open Source Bond Asset Pricing |
| `CRY` | bond carry factor | long high-credit-spread minus low-credit-spread bonds within rating buckets | Houweling and Van Zundert / Open Source Bond Asset Pricing |
| `DEF` | default-risk factor | long corporate bond market minus long government bond return | Fama and French / Amit Goyal |
| `DRF` | downside-risk factor | long high downside-risk minus low downside-risk bond portfolios | Bai et al. (2019), Open Source Bond Asset Pricing |
| `DUR` | bond duration factor | long high-duration minus low-duration bonds within rating buckets | Gebhardt et al. / Open Source Bond Asset Pricing |
| `HMLB` | bond value / book-to-market factor | long cheap versus rich bonds using bond book-to-market | Bartram et al. / Open Source Bond Asset Pricing |
| `LTREVB` | bond long-term reversal | long past losers versus winners using 48-13 month bond returns | Bali et al. / Open Source Bond Asset Pricing |
| `MKTB` | bond market excess return | broad corporate bond market return over the short rate | Dickerson et al. / Open Source Bond Asset Pricing |
| `MKTBD` | duration-adjusted bond market return | corporate bond market return over duration-matched Treasury returns | van Binsbergen et al. / Open Source Bond Asset Pricing |
| `MOMB` | bond momentum from bond returns | long high 12-2 month bond-return momentum minus low momentum | Gebhardt et al. / Open Source Bond Asset Pricing |
| `MOMBS` | bond momentum from equity momentum | long bonds issued by high-equity-momentum firms minus low-equity-momentum firms | Hottinga / Gebhardt / Open Source Bond Asset Pricing |
| `PEADB` | bond post-earnings-announcement drift | long bonds of high-earnings-surprise firms minus low-surprise firms | Nozawa et al. / Open Source Bond Asset Pricing |
| `STREVB` | bond short-term reversal | long recent bond losers minus recent winners | Khang and King / Open Source Bond Asset Pricing |
| `SZE` | bond size factor | long small-issue bonds minus large-issue bonds | Houweling and Van Zundert / Open Source Bond Asset Pricing |
| `TERM` | term-structure factor | long-term government bond return minus T-bill return | Fama and French / Amit Goyal |
| `VAL` | bond value factor | long undervalued versus overvalued bonds from spread-based fair-value gaps | Correia et al. / Open Source Bond Asset Pricing |

## Traded Equity Factors

| Factor | High-level meaning | Construction cue | Reference / source cue |
|---|---|---|---|
| `BAB` | betting-against-beta | low-beta leveraged minus high-beta deleveraged equities | Frazzini and Pedersen / AQR |
| `CMA` | investment factor | conservative minus aggressive investment firms | Fama and French / Kenneth French |
| `CMAs` | hedged CMA | CMA stripped of the unpriced component | Daniel et al. / Kent Daniel |
| `CPTLT` | intermediary-capital tradable factor | primary-dealer sector equity return excluding new issuance | He et al. / Zhiguo He |
| `FIN` | long-horizon behavioral factor | issuance and correction style mispricing factor | Daniel et al. / Kent Daniel |
| `HML` | value factor | high book-to-market minus low book-to-market stocks | Fama and French / Kenneth French |
| `HML_DEV` | price-based HML variant | value factor using current-price sorting variant | Asness and Frazzini / AQR |
| `HMLs` | hedged HML | HML stripped of the unpriced component | Daniel et al. / Kent Daniel |
| `LIQ` | tradable liquidity factor | stock factor sorted on exposure to `LIQNT` | Pastor and Stambaugh |
| `LTREV` | long-term reversal | long past 60-13 month losers minus winners | Jegadeesh and Titman / Kenneth French |
| `MGMT` | management mispricing | anomaly linked to management-related firm behavior | Stambaugh and Yuan |
| `MKTS` | market excess return | aggregate stock market excess return | Sharpe / Lintner / Kenneth French |
| `MKTSs` | hedged market factor | market factor stripped of the unpriced component | Daniel et al. / Kent Daniel |
| `MOMS` | stock momentum | long past 12-2 month winners minus losers | Carhart / Kenneth French |
| `PEAD` | stock post-earnings-announcement drift | short-horizon behavioral factor tied to earnings-surprise drift | Daniel et al. / Kent Daniel |
| `PERF` | performance mispricing | anomaly linked to firm performance mispricing | Stambaugh and Yuan |
| `QMJ` | quality-minus-junk | long high-quality firms minus low-quality firms | Asness et al. / AQR |
| `RMW` | profitability factor | robust minus weak profitability firms | Fama and French / Kenneth French |
| `RMWs` | hedged profitability factor | RMW stripped of the unpriced component | Daniel et al. / Kent Daniel |
| `R_IA` | investment-to-assets factor | long low-investment versus high-investment firms | Hou et al. / Lu Zhang |
| `R_ROE` | return-on-equity factor | long high-ROE versus low-ROE firms | Hou et al. / Lu Zhang |
| `SMB` | size factor | small minus big equities | Fama and French / Kenneth French |
| `SMBs` | hedged size factor | SMB stripped of the unpriced component | Daniel et al. / Kent Daniel |
| `STREV` | short-term reversal | long recent losers minus recent winners | Jegadeesh and Titman / Kenneth French |

## Nontraded Factors

| Factor | High-level meaning | Construction cue | Reference / source cue |
|---|---|---|---|
| `CPTL` | intermediary-capital nontraded factor | innovation in primary-dealer capital ratio | He et al. / Zhiguo He |
| `CREDIT` | credit-spread factor | BAA minus AAA yield spread | Fama and French / Amit Goyal or FRED |
| `EPU` | economic policy uncertainty | first difference in the EPU index | Baker et al. / FRED |
| `EPUT` | tax policy uncertainty | first difference in tax-policy uncertainty | Baker et al. / FRED |
| `INFLC` | core inflation shock | unexpected core inflation from an ARMA filter | Fang et al. / FRED |
| `INFLV` | inflation volatility | short-horizon volatility of unexpected inflation | Kang and Pflueger / FRED |
| `IVOL` | idiosyncratic equity volatility | cross-sectional volatility of firm-level stock returns | Campbell and Taksler / CRSP |
| `LVL` | level term-structure factor | first principal component of Treasury yields | Koijen et al. / CRSP Indices |
| `LIQNT` | nontraded liquidity factor | average stock-level liquidity shock / residual predictability measure | Pastor and Stambaugh |
| `UNC` | macro uncertainty | first difference in macro uncertainty index | Ludvigson et al. |
| `UNCf` | financial uncertainty | first difference in financial uncertainty index | Ludvigson et al. |
| `UNCr` | real uncertainty | first difference in real uncertainty index | Ludvigson et al. |
| `VIX` | implied-volatility shock | first difference in the VIX index | Chung et al. / FRED |
| `YSP` | yield-slope factor | 5-year minus 1-year Treasury yield | Koijen et al. / CRSP Indices |

## Recurring High-Importance Factors

These are the five factors that repeatedly stand out in the main co-pricing
results:

1. `PEADB`
2. `IVOL`
3. `PEAD`
4. `CREDIT`
5. `YSP`

High-level reading:

- `PEADB` and `PEAD` are the two post-earnings-announcement drift factors and
  are the main tradable factors with posterior inclusion probabilities above
  the 50% prior threshold.
- `CREDIT`, `YSP`, and `IVOL` are nontraded factors tied to credit conditions,
  the Treasury term structure, and equity risk conditions.

## Treasury And Duration Questions

If the user asks why bond factors matter:

- `MKTB`, `MKTBD`, `TERM`, `DUR`, `CRY`, `CRF`, and related bond factors are
  especially relevant for the Treasury-component and duration-adjusted
  exercises.
- The paper's main interpretation is not simply that "bond factors are always
  best," but that bond factors are especially useful for pricing the Treasury
  component implicit in corporate bond returns.

## Related Files

- manuscript Table A.1 explanation: `docs/agent-context/exhibits/table-a1.md`
- posterior-probability appendix table: `docs/agent-context/exhibits/table-a2.md`
- main factor-importance results: `docs/agent-context/exhibits/figure-2.md`
- main top-factor table: `docs/agent-context/exhibits/table-1.md`
