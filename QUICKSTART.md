# Quick Start

Use this file as the canonical human runbook.

## 1. Choose Your Shell

Recommended human shells:
- Windows PowerShell: best default for long runs on Windows
- Windows Command Prompt: fully supported
- Posit/RStudio Terminal: supported if you prefer staying inside Posit
- macOS Terminal (`zsh` or `bash`): best default on macOS

Human default:
- use the public wrappers first
- use the raw `Rscript` boundaries below when you want transparency about the exact script order

If a long run fails inside a managed IDE or AI terminal, rerun it from a normal
PowerShell or Terminal before changing repo code.

## 2. Using Posit/RStudio Terminal

Posit/RStudio Terminal is supported.

Windows Posit/RStudio Terminal:
- wrapper path:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

- raw `Rscript` path:

```powershell
Rscript _run_full_replication.R --quick
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

macOS Posit/RStudio Terminal:
- wrapper path:

```bash
bash tools/run_full_replication.sh --quick
bash tools/build_paper.sh
```

- raw `Rscript` path:

```bash
Rscript _run_full_replication.R --quick
bash tools/build_paper.sh
```

## 3. Clone The Repo

```bash
git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git
cd co-pricing-factor-zoo
```

Run all commands from the repo root.

## 4. Set Up Data, Packages, And Toolchain

This stage should leave you with:
- the canonical public data bundle under `data/`
- required R packages installed
- fast backends rebuilt and ready
- a clean doctor pass

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_data.ps1
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
powershell -ExecutionPolicy Bypass -File tools\rebuild_fast_backends.ps1
```

Windows Command Prompt:

```bat
tools\bootstrap_data.cmd
tools\bootstrap_packages.cmd
tools\doctor.cmd --check-only
tools\rebuild_fast_backends.cmd
```

macOS Terminal:

```bash
bash tools/bootstrap_data.sh
bash tools/bootstrap_packages.sh
bash tools/doctor.sh --check-only
bash tools/rebuild_fast_backends.sh
```

Raw `Rscript` equivalent for the setup checks:

```bash
Rscript tools/bootstrap_data.R
Rscript tools/bootstrap_packages.R
Rscript tools/doctor.R --check-only
```

Notes:
- backend rebuild currently stays on the wrapper path
- use [docs/manifests/data-files.csv](./docs/manifests/data-files.csv) as the exact data checklist
- use [docs/manifests/data-sources.csv](./docs/manifests/data-sources.csv) as the source of truth for the canonical bundle URL and extraction target
- `ia/data/w_all.rds` is required tracked clone data and should already be present after clone
- use [docs/validation/validated_runs.csv](./docs/validation/validated_runs.csv) as the source of truth for which runtime boundaries are actually validated

macOS toolchain note:
- install Xcode Command Line Tools with `xcode-select --install`
- install the CRAN-recommended GNU Fortran that matches your installed CRAN R version
- official references: <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>

## 5. Fastest Validated Main-Paper Path

This is the shortest human path that keeps the validated wrapper flow intact.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Windows Command Prompt:

```bat
tools\run_full_replication.cmd -Quick
tools\build_paper.cmd
```

macOS Terminal:

```bash
bash tools/run_full_replication.sh --quick
bash tools/build_paper.sh
```

Raw `Rscript` equivalent:

```bash
Rscript _run_full_replication.R --quick
```

Then build the PDF with the platform wrapper for your shell:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1`
- Windows Command Prompt: `tools\build_paper.cmd`
- macOS Terminal: `bash tools/build_paper.sh`

Success looks like:
- main PDF at [djm_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex/djm_main.pdf)
- tables under [output/paper/tables](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/tables)
- figures under [output/paper/figures](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/figures)

If something fails, rerun here:
- start with the same wrapper command that failed
- if you need exact script boundaries, use the step-by-step main path below

## 6. Full Main-Paper Path

Wrapper path:

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Windows Command Prompt:

```bat
tools\run_full_replication.cmd -Draws 5000
tools\build_paper.cmd
```

macOS Terminal:

```bash
bash tools/run_full_replication.sh --ndraws=5000
bash tools/build_paper.sh
```

Raw `Rscript` equivalent:

```bash
Rscript _run_full_replication.R
```

Full transparency step-by-step path:

```bash
Rscript _run_all_unconditional.R
Rscript _run_all_conditional.R --direction=both
Rscript _run_paper_results.R
Rscript _run_paper_conditional_results.R
Rscript _create_djm_tabs_figs.R
```

Then compile the PDF with the wrapper for your shell.

## 7. Fastest Validated IA Path

On a new machine, run the IA smoke boundary first.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
```

Windows Command Prompt:

```bat
tools\run_ia_smoke.cmd -Draws 500
```

macOS Terminal:

```bash
bash tools/run_ia_smoke.sh --ndraws=500
```

Raw `Rscript` equivalent:

```bash
Rscript ia/_run_ia_estimation.R --ndraws=500
Rscript ia/_run_ia_results.R --expected-ndraws=500
Rscript ia/_create_ia_latex.R
```

Then build the IA PDF with the wrapper for your shell:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1`
- Windows Command Prompt: `tools\build_ia_paper.cmd`
- macOS Terminal: `bash tools/build_ia_paper.sh`

Success looks like:
- IA PDF at [ia_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper/latex/ia_main.pdf)
- IA outputs under [ia/output/paper](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper)

If something fails, rerun here:
- rerun the same smoke boundary first
- only scale up after the smoke path and doctor both pass

## 8. Full IA Path

Wrapper path:

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

Windows Command Prompt:

```bat
tools\run_ia_full.cmd -Draws 5000
tools\build_ia_paper.cmd
```

macOS Terminal:

```bash
bash tools/run_ia_full.sh --ndraws=5000
bash tools/build_ia_paper.sh
```

Raw `Rscript` equivalent:

```bash
Rscript ia/_run_ia_full.R
```

Full transparency step-by-step path:

```bash
Rscript ia/_run_ia_estimation.R
Rscript ia/_run_ia_results.R
Rscript ia/_create_ia_latex.R
```

Then compile the IA PDF with the wrapper for your shell.

## 9. Find Outputs

- main tables: [output/paper/tables](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/tables)
- main figures: [output/paper/figures](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/figures)
- main LaTeX tree and PDF: [output/paper/latex](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex)
- Figure 1 simulation-regeneration outputs: [output/simulations/figure1](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/simulations/figure1)
- IA outputs: [ia/output/paper](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper)
- IA LaTeX tree and PDF: [ia/output/paper/latex](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper/latex)
- logs: [output/logs](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/logs) and [ia/output/logs](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/logs)

Useful human references:
- [README_PAPER_PIPELINE.md](./README_PAPER_PIPELINE.md): short boundary map
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): map an exhibit back to its generating script and output
- [docs/validation/validated_runs.csv](./docs/validation/validated_runs.csv): source of truth for validated runtime and build boundaries

## 10. Troubleshooting

- Missing packages: rerun `tools/bootstrap_packages.R` or the platform wrapper.
- Missing data files: run `tools/bootstrap_data.R` or the platform wrapper first, then compare your folders against `docs/manifests/data-files.csv`.
- Fast backend compile failures: rerun `tools/doctor.R --force-rebuild` after fixing the toolchain.
- macOS toolchain failures: install Xcode Command Line Tools plus the CRAN-recommended `gfortran` for your installed R version from <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>.
- Fast backend compile failures inside a managed terminal: rerun the doctor in a normal PowerShell or Terminal before changing repo code.
- Final PDF blocked: rerun `tools/build_paper.ps1`, `tools/build_paper.cmd`, or `tools/build_paper.sh`. Use `-SkipAssembly` or `--skip-assembly` if the LaTeX tree is already current.
- IA PDF blocked: rerun `tools/build_ia_paper.ps1`, `tools/build_ia_paper.cmd`, or `tools/build_ia_paper.sh`.

For doc and workflow drift checks before pushing changes:

```bash
Rscript tools/validate_repo_docs.R
```
