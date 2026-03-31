# Quick Start

Use this file as the canonical human runbook.

## 1. Clone The Repo

```bash
git clone https://github.com/Alexander-M-Dickerson/co-pricing-factor-zoo.git
cd co-pricing-factor-zoo
```

Run all commands from the repo root.

## 2. Place The Data

Copy the required project inputs into `data/` and any IA-only extras into `ia/data/`.

- Use [docs/manifests/data-files.csv](./docs/manifests/data-files.csv) as the exact checklist.
- The public source is Open Source Bond Asset Pricing: <https://openbondassetpricing.com/>.
- Do not guess filenames from old docs. The manifest is the source of truth.

## 3. Install The R Package Set

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
```

macOS or Linux:

```bash
Rscript tools/bootstrap_packages.R
```

If your shell does not know `Rscript`, use the full executable path from your R installation. The PowerShell wrappers already resolve this on Windows.

## 4. Run The Doctor

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
```

macOS or Linux:

```bash
Rscript tools/doctor.R --check-only
```

The doctor checks:

- required R packages
- required data files
- build toolchain visibility
- fast C++ backend readiness
- optional LaTeX availability

## 5. Run A Quick Smoke Test

```bash
Rscript _run_full_replication.R --quick
```

This keeps the full step boundaries intact while reducing MCMC draws for validation work.

## 6. Run The Main Pipeline

Single-command main pipeline:

```bash
Rscript _run_full_replication.R
```

Step-by-step main pipeline:

```bash
Rscript _run_all_unconditional.R
Rscript _run_all_conditional.R
Rscript _run_paper_results.R
Rscript _run_paper_conditional_results.R
Rscript _create_djm_tabs_figs.R
```

Useful reduced-scope commands:

```bash
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_unconditional.R --list
Rscript _run_all_conditional.R --ndraws=5000
Rscript ia/_run_ia_estimation.R --list
```

## 7. Find Outputs

- `output/paper/tables/`: main paper LaTeX tables
- `output/paper/figures/`: main paper and appendix figures
- `output/paper/latex/`: assembled LaTeX document
- `ia/output/paper/`: implemented IA tables and figures
- `output/logs/` and `ia/output/logs/`: run logs

Use [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv) to map an exhibit back to its generating script and saved inputs.

## Troubleshooting

- Missing packages: rerun `tools/bootstrap_packages.R` or the PowerShell wrapper.
- Missing data files: compare your folders against `docs/manifests/data-files.csv`.
- Fast backend compile failures: rerun `tools/doctor.R --force-rebuild` after fixing the toolchain.
- Fast backend compile failures inside a managed terminal: rerun the doctor in a normal PowerShell or shell before changing repo code.
- Final PDF blocked: `pdflatex` is optional until `_create_djm_tabs_figs.R`.

For drift checks before pushing docs or workflow changes:

```bash
Rscript tools/validate_repo_docs.R
```
