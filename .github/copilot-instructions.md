# GitHub Copilot Instructions

This repository is an R-based replication package for "The Co-Pricing Factor Zoo".
The canonical shared agent context lives in `AGENTS.md`. Read that file for the full
repo map, domain constraints, output conventions, and editing guidance.

Shared references:

- `AGENTS.md`
- `docs/manifests/data-files.csv`
- `docs/manifests/data-sources.csv`
- `docs/manifests/exhibits.csv`
- `docs/manifests/manuscript_exhibits.csv`
- `docs/manifests/paper_claims.csv`
- `docs/agent-context/prompt-recipes.md`
- `docs/agent-context/exhibits/README.md`
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
- Bundle-managed main inputs belong in `data/` and should default to `data_folder = "data"`.
- Use `tools/bootstrap_data.*` rather than telling users to place main paper data manually when the canonical bundle can supply it.
- Generated results belong in `output/` and `logs/`; do not treat them as source.
- Use `docs/manifests/exhibits.csv` before reverse-engineering an output path from source.
- Use `docs/manifests/manuscript_exhibits.csv` when the question is about the full paper inventory rather than just the executable subset.
- Valid `model_type` values are `"bond"`, `"stock"`, `"bond_stock_with_sp"`, and
  `"treasury"`.
- Preserve BHJ function argument ordering:
  - `continuous_ss_sdf(f, R, ...)`
  - `continuous_ss_sdf_v2(f1, f2, R, ...)`
- When loading saved estimation files, use the stored factor-name vectors instead of
  recreating them from column-name heuristics.
