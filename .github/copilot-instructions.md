# GitHub Copilot Instructions

This repository is an R-based replication package for "The Co-Pricing Factor Zoo".
The canonical shared agent context lives in `AGENTS.md`. Read that file for the full
repo map, domain constraints, output conventions, and editing guidance.

High-signal summary:

- Main estimation logic lives in `code_base/`.
- The upstream BHJ package copy lives in `BayesianFactorZoo/`; prefer extending
  behavior in `code_base/` unless you are intentionally changing package internals.
- Input CSVs belong in `data/` and should default to `data_folder = "data"`.
- Generated results belong in `output/` and `logs/`; do not treat them as source.
- Valid `model_type` values are `"bond"`, `"stock"`, `"bond_stock_with_sp"`, and
  `"treasury"`.
- Preserve BHJ function argument ordering:
  - `continuous_ss_sdf(f, R, ...)`
  - `continuous_ss_sdf_v2(f1, f2, R, ...)`
- When loading saved estimation files, use the stored factor-name vectors instead of
  recreating them from column-name heuristics.
