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
- [docs/manifests/data-sources.csv](./docs/manifests/data-sources.csv): canonical public data bundle source
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): table, figure, and IA output map
- [docs/manifests/manuscript_exhibits.csv](./docs/manifests/manuscript_exhibits.csv): full manuscript exhibit inventory with repo coverage status
- [docs/manifests/paper_claims.csv](./docs/manifests/paper_claims.csv): headline claim-to-evidence map
- [docs/agent-context/prompt-recipes.md](./docs/agent-context/prompt-recipes.md): canonical Codex and Claude prompts
- [docs/agent-context/exhibits/README.md](./docs/agent-context/exhibits/README.md): exhibit-level explanation dossiers
- [docs/paper/co-pricing-factor-zoo.ai-optimized.md](./docs/paper/co-pricing-factor-zoo.ai-optimized.md): canonical full paper for deep tracing

## First Run

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\bootstrap_data.ps1
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
powershell -ExecutionPolicy Bypass -File tools\rebuild_fast_backends.ps1
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 500
```

Windows Command Prompt:

```bat
tools\bootstrap_packages.cmd
tools\bootstrap_data.cmd
tools\doctor.cmd --check-only
tools\rebuild_fast_backends.cmd
tools\run_conditional_smoke.cmd -Draws 500
```

macOS or Linux:

```bash
bash tools/bootstrap_packages.sh
bash tools/bootstrap_data.sh
bash tools/doctor.sh --check-only
bash tools/rebuild_fast_backends.sh
bash tools/run_conditional_smoke.sh --direction=both --ndraws=500
```

macOS toolchain note:
- install Xcode Command Line Tools with `xcode-select --install`
- install the CRAN-recommended GNU Fortran that matches your installed CRAN R version
- official references: <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>
- avoid mixing CRAN R binaries with Homebrew or MacPorts compilers unless you are rebuilding that toolchain consistently

Quick smoke run after the doctor passes:

```bash
Rscript _run_full_replication.R --quick
```

Validated Windows host path as of March 31, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Equivalent public wrappers now exist for Windows Command Prompt and macOS/Linux.
The underlying R entrypoints remain the source of truth; the wrappers only handle
platform-specific process and tool resolution.

Validated IA host path as of April 1, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

That IA host path completed cleanly on the maintainer Windows host. All nine IA
models finished at the 500-draw smoke boundary and again at the 5,000-draw
full-run boundary. The public wrappers then regenerated the implemented IA
tables and figures and compiled `ia/output/paper/latex/ia_main.tex`.

## Data

The default main-data path is now repo-tracked and agent-usable.

- Use `tools/bootstrap_data.*` or `Rscript tools/bootstrap_data.R` to download and extract the canonical public bundle into `data/`.
- Use [docs/manifests/data-sources.csv](./docs/manifests/data-sources.csv) as the source of truth for the bundle URL, extraction target, and verification metadata.
- Use [docs/manifests/data-files.csv](./docs/manifests/data-files.csv) as the exact filename checklist and bundle coverage map.
- `ia/data/w_all.rds` is a required tracked IA input and should already be present in the clone.

Fresh-clone agent expectation:

- Codex or Claude should bootstrap missing packages and bundle-managed data automatically before attempting a run.
- If the canonical bundle is missing required files, the agent should stop and report the exact gap instead of asking the user to guess filenames manually.

## Main Entrypoints

- `_run_full_replication.R`: full five-step main pipeline ending in LaTeX source assembly
- `_run_all_unconditional.R`: seven unconditional model runs
- `_run_all_conditional.R`: conditional expanding-window pipeline
- `_run_paper_results.R`: unconditional tables and figures
- `_run_paper_conditional_results.R`: conditional outputs including Figure 7 and Table 6 Panel B
- `ia/_run_ia_estimation.R`: nine IA estimation models
- `ia/_run_ia_results.R`: implemented IA output subset
- `ia/_run_ia_full.R`: IA estimation + outputs + LaTeX assembly
- `tools/run_ia_smoke.*`: public IA smoke wrappers
- `tools/run_ia_full.*`: public IA full-pipeline wrappers
- `tools/build_ia_paper.*`: assemble and compile `ia/output/paper/latex/ia_main.tex`

Useful checks:

```bash
Rscript tools/validate_repo_docs.R
Rscript _run_full_replication.R --help
Rscript _run_all_unconditional.R --list
Rscript ia/_run_ia_estimation.R --list
Rscript ia/_run_ia_results.R --help
Rscript ia/_create_ia_latex.R --help
Rscript ia/_run_ia_full.R --help
```

## Repo Tooling

- `tools/bootstrap_packages.R`: canonical installable R package set
- `tools/doctor.R`: repo readiness check for R, packages, data, and fast backends
- `tools/bootstrap_packages.ps1`, `tools/bootstrap_packages.cmd`, `tools/bootstrap_packages.sh`: platform wrappers for package bootstrap
- `tools/doctor.ps1`, `tools/doctor.cmd`, `tools/doctor.sh`: platform wrappers for the readiness doctor
- `tools/rebuild_fast_backends.ps1`, `tools/rebuild_fast_backends.cmd`, `tools/rebuild_fast_backends.sh`: rebuild and validation entrypoints for both fast C++ kernels
- `tools/run_conditional_smoke.ps1`, `tools/run_conditional_smoke.cmd`, `tools/run_conditional_smoke.sh`: public conditional smoke wrappers
- `tools/run_full_replication.ps1`, `tools/run_full_replication.cmd`, `tools/run_full_replication.sh`: public full replication wrappers
- `tools/build_paper.ps1`, `tools/build_paper.cmd`, `tools/build_paper.sh`: assemble and compile `output/paper/latex/djm_main.tex`
- `tools/run_figure1_simulation.ps1`, `tools/run_figure1_simulation.cmd`, `tools/run_figure1_simulation.sh`: explicit Figure 1 simulation-regeneration wrappers
- `tools/run_ia_smoke.ps1`, `tools/run_ia_smoke.cmd`, `tools/run_ia_smoke.sh`: public IA smoke wrappers
- `tools/run_ia_full.ps1`, `tools/run_ia_full.cmd`, `tools/run_ia_full.sh`: public IA full-pipeline wrappers
- `tools/build_ia_paper.ps1`, `tools/build_ia_paper.cmd`, `tools/build_ia_paper.sh`: assemble and compile `ia/output/paper/latex/ia_main.tex`
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

Canonical public prompt recipes live in [docs/agent-context/prompt-recipes.md](./docs/agent-context/prompt-recipes.md).

Useful prompts:

- `Set this repo up from a fresh clone. Install missing packages, download the canonical public data bundle, validate readiness, rebuild the fast backends, and stop at the first blocking issue.`
- `Replicate the main text. If packages or data are missing, bootstrap them automatically first. Use the smallest validated boundary before scaling up, and stop at the first failing step with the exact rerun boundary.`
- `Regenerate Figure 1 from the simulation validation path. Use the fast C++ engine, write the generated outputs under output/simulations/figure1/, and keep the default paper build anchored to the tracked Figure 1 panel fixtures unless I explicitly ask you to refresh them.`
- `Replicate the Internet Appendix. Bootstrap what is needed, run the 500-draw IA smoke boundary first, then tell me the exact next scale-up boundary.`
- `Fully explain Table 1. Cover the empirical question, the three panels, the two reported metrics, the top five co-pricing factors, the paper interpretation, the code path, the saved objects used, and the generated output file.`
- `Fully explain Figure 1. Cover the simulation design, the six experiments, why noisy proxies matter in this paper, the default tracked panel-fixture path, the optional regeneration path, and the generated output files.`
- `Tell me exactly which Internet Appendix results are implemented in this repo, which are paper-only, and where each implemented IA result is generated.`

Current freshness behavior:

- `_run_full_replication.R` now validates the seven unconditional workspaces after Step 1
- `_run_paper_results.R --strict-freshness` forces regeneration of cached unconditional intermediates and figure outputs
- use the top-level runner or explicit strict-freshness mode for publication-grade reruns
