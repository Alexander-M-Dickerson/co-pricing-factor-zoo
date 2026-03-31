# GitHub Copilot Instructions

This repository is an R-based replication package for "The Co-Pricing Factor Zoo".
The canonical shared agent context lives in `AGENTS.md`. Read that file for the full
repo map, domain constraints, output conventions, and editing guidance.

Shared references:

- `AGENTS.md`
- `docs/manifests/data-files.csv`
- `docs/manifests/exhibits.csv`
- `docs/agent-context/replication-pipeline.md`
- `docs/agent-context/paper-reading-guide.md`
- `docs/agent-context/tables-guide.md`
- `docs/agent-context/figures-guide.md`
- `docs/paper/co-pricing-factor-zoo.ai-optimized.md`
- `code_review.md`

High-signal summary:

- Main estimation logic lives in `code_base/`.
- The upstream BHJ package copy lives in `BayesianFactorZoo/`; prefer extending
  behavior in `code_base/` unless you are intentionally changing package internals.
- Public repo setup and drift checks live under `tools/`.
- Input CSVs belong in `data/` and should default to `data_folder = "data"`.
- Generated results belong in `output/` and `logs/`; do not treat them as source.
- Use `docs/manifests/exhibits.csv` before reverse-engineering an output path from source.
- Valid `model_type` values are `"bond"`, `"stock"`, `"bond_stock_with_sp"`, and
  `"treasury"`.
- Preserve BHJ function argument ordering:
  - `continuous_ss_sdf(f, R, ...)`
  - `continuous_ss_sdf_v2(f1, f2, R, ...)`
- When loading saved estimation files, use the stored factor-name vectors instead of
  recreating them from column-name heuristics.
