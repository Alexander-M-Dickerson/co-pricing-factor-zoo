# Co-Pricing Factor Zoo

Replication repository for [The Co-Pricing Factor Zoo](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4589786).

Current coverage:
- all main paper tables and figures
- all main Appendix tables and figures
- some Internet Appendix results

## Start Here

- [QUICKSTART.md](./QUICKSTART.md): canonical human setup and run guide
- [README_PAPER_PIPELINE.md](./README_PAPER_PIPELINE.md): short pipeline map and resume boundaries
- [docs/manifests/data-files.csv](./docs/manifests/data-files.csv): source-of-truth input checklist
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): table, figure, and IA output map
- [docs/paper/co-pricing-factor-zoo.ai-optimized.md](./docs/paper/co-pricing-factor-zoo.ai-optimized.md): canonical full paper for deep tracing

## First Run

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
```

macOS or Linux:

```bash
Rscript tools/bootstrap_packages.R
Rscript tools/doctor.R --check-only
```

Quick smoke run after the doctor passes:

```bash
Rscript _run_full_replication.R --quick
```

## Data

Place required inputs under `data/` and optional IA-only inputs under `ia/data/`.

- Use [docs/manifests/data-files.csv](./docs/manifests/data-files.csv) as the exact filename checklist.
- The public data source is Open Source Bond Asset Pricing: <https://openbondassetpricing.com/>.
- After copying data into place, rerun `tools/doctor.R`.

## Main Entrypoints

- `_run_full_replication.R`: full five-step main pipeline
- `_run_all_unconditional.R`: seven unconditional model runs
- `_run_all_conditional.R`: conditional expanding-window pipeline
- `_run_paper_results.R`: unconditional tables and figures
- `_run_paper_conditional_results.R`: conditional outputs including Figure 7 and Table 6 Panel B
- `ia/_run_ia_estimation.R`: nine IA estimation models
- `ia/_run_ia_results.R`: implemented IA output subset

Useful checks:

```bash
Rscript tools/validate_repo_docs.R
Rscript _run_full_replication.R --help
Rscript _run_all_unconditional.R --list
Rscript ia/_run_ia_estimation.R --list
```

## Repo Tooling

- `tools/bootstrap_packages.R`: canonical installable R package set
- `tools/doctor.R`: repo readiness check for R, packages, data, and fast backends
- `tools/validate_repo_docs.R`: drift check for docs, manifests, skills, and public entrypoints
- `testing/`: deeper validation and performance scripts for the fast kernels and optimization work

## AI Collaboration

Shared surfaces:

- `AGENTS.md`: canonical repo instructions for coding agents
- `docs/agent-context/`: shared paper, method, onboarding, and pipeline docs
- `docs/manifests/`: machine-readable input and exhibit maps
- `docs/paper/`: full manuscript and paper-tagging guidance
- `code_review.md`: review checklist tuned for research-code risks

Codex-native surfaces:

- `.codex/config.toml`
- `.agents/skills/`

Claude-native surfaces:

- `CLAUDE.md`
- `.claude/paper-context.md`
- `.claude/skills/`

Codex and Claude are intended to work from the same shared core.
