# Quick Start

Use this file as the canonical human runbook.

## 1. Clone The Repo

```bash
git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git
cd co-pricing-factor-zoo
```

Run all commands from the repo root.

## 2. Bootstrap The Data

Bootstrap the canonical public data bundle into `data/`.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_data.ps1
```

Windows Command Prompt:

```bat
tools\bootstrap_data.cmd
```

macOS or Linux:

```bash
bash tools/bootstrap_data.sh
```

- Use [docs/manifests/data-files.csv](./docs/manifests/data-files.csv) as the exact checklist.
- Use [docs/manifests/data-sources.csv](./docs/manifests/data-sources.csv) as the source of truth for the canonical bundle URL and extraction target.
- `ia/data/w_all.rds` is a required tracked IA input and should already be present in the clone.
- Do not guess filenames from old docs. The manifests are the source of truth.

## 3. Install The R Package Set

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\rebuild_fast_backends.ps1
```

Windows Command Prompt:

```bat
tools\bootstrap_packages.cmd
tools\rebuild_fast_backends.cmd
```

macOS or Linux:

```bash
bash tools/bootstrap_packages.sh
bash tools/rebuild_fast_backends.sh
```

macOS toolchain note:
- install Xcode Command Line Tools with `xcode-select --install`
- install the CRAN-recommended GNU Fortran that matches your installed CRAN R version
- official references: <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>
- avoid mixing CRAN R binaries with Homebrew or MacPorts compilers unless you are rebuilding that toolchain consistently

If your shell does not know `Rscript`, use the full executable path from your R installation. The PowerShell wrappers already resolve this on Windows.

## 4. Run The Doctor

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 500
```

Windows Command Prompt:

```bat
tools\doctor.cmd --check-only
tools\run_conditional_smoke.cmd -Draws 500
```

macOS or Linux:

```bash
bash tools/doctor.sh --check-only
bash tools/run_conditional_smoke.sh --direction=both --ndraws=500
```

The doctor checks:

- required R packages
- required data files
- build toolchain visibility
- on macOS, explicit Xcode CLT, `clang`, and `gfortran` visibility
- fast C++ backend readiness
- optional LaTeX availability

If required data files are missing and the canonical bundle covers them, the doctor should tell you to run `tools/bootstrap_data.*`.
If `ia/data/w_all.rds` is missing, treat that as an incomplete checkout and restore the tracked file from git before running the IA pipeline.

For long replication runs on Windows, prefer the PowerShell or Command Prompt wrappers over ad hoc commands issued from managed IDE or AI terminals.

## 5. Run A Quick Smoke Test

```bash
Rscript _run_full_replication.R --quick
```

This keeps the full step boundaries intact while reducing MCMC draws for validation work.

Validated Windows host path as of March 31, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Equivalent `.cmd` and `.sh` wrappers now exist for the same public tasks. The wrappers are thin convenience layers over the canonical R entrypoints.

IA smoke boundary:

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
```

Windows Command Prompt:

```bat
tools\run_ia_smoke.cmd -Draws 500
```

macOS or Linux:

```bash
bash tools/run_ia_smoke.sh --ndraws=500
```

Validated IA Windows host path as of April 1, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

That IA host path completed cleanly on the maintainer Windows host. Use the
500-draw smoke boundary first on a new machine, then scale to the 5,000-draw
full IA wrapper once the smoke run and doctor both pass.

## 6. Run The Main Pipeline

Single-command main pipeline:

```bash
Rscript _run_full_replication.R
```

Step-by-step main pipeline:

```bash
Rscript _run_all_unconditional.R
Rscript _run_all_conditional.R --direction=both
Rscript _run_paper_results.R
Rscript _run_paper_conditional_results.R
Rscript _create_djm_tabs_figs.R
```

Build the final PDF with the platform wrapper after `_create_djm_tabs_figs.R`
or the full pipeline has produced `output/paper/latex/`:

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Windows Command Prompt:

```bat
tools\build_paper.cmd
```

macOS or Linux:

```bash
bash tools/build_paper.sh
```

Useful reduced-scope commands:

```bash
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_unconditional.R --list
Rscript _run_all_conditional.R --direction=both --ndraws=500
Rscript _run_all_conditional.R --direction=forward --ndraws=500
Rscript tools/run_figure1_simulation.R --help
Rscript ia/_run_ia_estimation.R --list
Rscript ia/_run_ia_results.R --help
Rscript ia/_create_ia_latex.R --help
Rscript ia/_run_ia_full.R --help
```

Windows host wrappers:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1 -SkipAssembly
powershell -ExecutionPolicy Bypass -File tools\run_figure1_simulation.ps1 -Help
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

IA PDF wrappers on other shells:

```bat
tools\build_ia_paper.cmd
```

```bash
bash tools/build_ia_paper.sh
```

## 7. Find Outputs

- `output/paper/tables/`: main paper LaTeX tables
- `output/paper/figures/`: main paper and appendix figures
- `output/simulations/figure1/`: explicit Figure 1 simulation-regeneration outputs
- `output/paper/latex/`: assembled LaTeX source tree and compiled PDF if you run the build wrapper
- `ia/output/paper/`: implemented IA tables and figures
- `ia/output/paper/latex/`: assembled IA LaTeX source tree and compiled IA PDF if you run the IA build wrapper
- `output/logs/` and `ia/output/logs/`: run logs

Use [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv) to map an exhibit back to its generating script and saved inputs.

Canonical agent prompts live in [docs/agent-context/prompt-recipes.md](./docs/agent-context/prompt-recipes.md). For exhibit explanation tasks, the deep context lives in [docs/agent-context/exhibits](./docs/agent-context/exhibits/README.md).

## Troubleshooting

- Missing packages: rerun `tools/bootstrap_packages.R` or the platform wrapper.
- Missing data files: run `tools/bootstrap_data.R` or the platform wrapper first, then compare your folders against `docs/manifests/data-files.csv`.
- Fast backend compile failures: rerun `tools/doctor.R --force-rebuild` after fixing the toolchain.
- macOS toolchain failures: install Xcode Command Line Tools plus the CRAN-recommended `gfortran` for your installed R version from <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>.
- Fast backend compile failures inside a managed terminal: rerun the doctor in a normal PowerShell or shell before changing repo code.
- Final PDF blocked: rerun `tools/build_paper.ps1`, `tools/build_paper.cmd`, or `tools/build_paper.sh`. Use `-SkipAssembly` or `--skip-assembly` if the LaTeX tree is already current.
- IA PDF blocked: rerun `tools/build_ia_paper.ps1`, `tools/build_ia_paper.cmd`, or `tools/build_ia_paper.sh`.

For drift checks before pushing docs or workflow changes:

```bash
Rscript tools/validate_repo_docs.R
```
