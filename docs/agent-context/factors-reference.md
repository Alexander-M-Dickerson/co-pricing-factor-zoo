# Factors Reference

This is the compact factor map for explaining the 54-factor zoo used in the paper.

## Structure

- 14 non-traded factors
- 16 traded bond factors
- 24 traded equity factors

When loading saved estimation outputs, use the stored factor-name vectors instead of rebuilding these groups from heuristics.

## Non-Traded Factors

Examples:

- `VIX`
- `CREDIT`
- `YSP`
- `LVL`
- `IVOL`
- `INFLC`
- `INFLV`
- `UNC`
- `UNCr`
- `UNCf`
- `EPU`
- `EPUT`
- `CPTL`
- `LIQNT`

## Traded Bond Factors

Examples:

- `MKTB`
- `MKTBD`
- `DEF`
- `TERM`
- `DUR`
- `CRY`
- `CRF`
- `DRF`
- `HMLB`
- `MOMB`
- `MOMBS`
- `STREVB`
- `LTREVB`
- `SZE`
- `VAL`
- `PEADB`

## Traded Equity Factors

Examples:

- `MKTS`
- `MKTSs`
- `SMB`
- `SMBs`
- `HML`
- `HMLs`
- `HML_DEV`
- `CMA`
- `CMAs`
- `RMW`
- `RMWs`
- `MOMS`
- `LTREV`
- `STREV`
- `PEAD`
- `BAB`
- `QMJ`
- `MGMT`
- `PERF`
- `R_IA`
- `R_ROE`
- `CPTLT`
- `LIQ`
- `FIN`

## Recurring High-Importance Factors

The main paper repeatedly highlights this short list:

1. `PEADB`
2. `IVOL`
3. `PEAD`
4. `CREDIT`
5. `YSP`

## DR Versus CF Reading

The repo also uses discount-rate versus cash-flow classifications for some decompositions. Those classifications matter for the Table 5 style questions, but the safest path is to rely on the saved classification inputs and generated outputs rather than reconstructing them informally.
