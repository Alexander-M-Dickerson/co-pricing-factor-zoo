# Paper Pipeline

Use this file as the short human boundary map.

Primary references:
- [QUICKSTART.md](./QUICKSTART.md): full human runbook
- [docs/validation/validated_runs.csv](./docs/validation/validated_runs.csv): source of truth for validated runtime and build boundaries
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): exhibit-to-code mapping

The no-flag full pipelines are the exact paper replication path. They default to
50,000 draws. The smoke boundaries below are reduced-draw setup-validation
checks.

## Complete Replication: Main + IA (Default 50,000 Draws)

Single command for both pipelines (~81 minutes):
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_complete_replication.ps1`
- Windows Command Prompt: `tools\run_complete_replication.cmd`
- macOS Terminal: `bash tools/run_complete_replication.sh`

Raw `Rscript` equivalent: `Rscript _run_complete_replication.R`

Produces both PDFs and a replication manifest at `output/replication_manifest_both_<timestamp>.json`.

## Main Exact Boundary (Default 50,000 Draws)

Representative runtime: **~65 minutes** on a 24-core desktop (Intel Core Ultra 9
275HX, 128 GB RAM). The pipeline compiles the PDF automatically as its final
step.

| Step | Description | Time |
|------|-------------|------|
| 1 | Unconditional estimation (7 models) | ~8 min |
| 2 | Conditional estimation (2 directions) | ~46 min |
| 3 | Tables & figures (unconditional) | ~10 min |
| 4 | Tables & figures (conditional) | <1 min |
| 5 | LaTeX assembly | <1 min |
| 6 | PDF compilation | <1 min |

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1`
- Windows Command Prompt: `tools\run_full_replication.cmd`
- macOS Terminal: `bash tools/run_full_replication.sh`

Raw `Rscript` equivalent:

```bash
Rscript _run_full_replication.R
```

Step-by-step transparency path:

```bash
Rscript _run_all_unconditional.R
Rscript _run_all_conditional.R --direction=both
Rscript _run_paper_results.R
Rscript _run_paper_conditional_results.R
Rscript _create_djm_tabs_figs.R
```

Build the PDF separately (only needed with the step-by-step path or `--skip-pdf`):
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1`
- Windows Command Prompt: `tools\build_paper.cmd`
- macOS Terminal: `bash tools/build_paper.sh`

Output:
- [djm_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex/djm_main.pdf)

Figure 1 note:
- normal paper replication publishes the tracked Figure 1 assets and does not
  rerun the Monte Carlo simulation

## Main Smoke Boundary (Validated 5,000-Draw Test)

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick`
- Windows Command Prompt: `tools\run_full_replication.cmd -Quick`
- macOS Terminal: `bash tools/run_full_replication.sh --quick`

Raw `Rscript` equivalent:

```bash
Rscript _run_full_replication.R --quick
```

Output (PDF compiled automatically):
- [djm_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex/djm_main.pdf)

## IA Exact Boundary (Default 50,000 Draws)

Representative runtime: **~16 minutes** on a 24-core desktop. The IA pipeline
now compiles the PDF automatically as its final step.

| Step | Description | Time |
|------|-------------|------|
| 1 | IA estimation (9 models, 2 parallel batches) | ~12 min |
| 2 | IA tables & figures | ~4 min |
| 3 | IA LaTeX assembly | <1 min |
| 4 | IA PDF compilation | <1 min |

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1`
- Windows Command Prompt: `tools\run_ia_full.cmd`
- macOS Terminal: `bash tools/run_ia_full.sh`

Raw `Rscript` equivalent:

```bash
Rscript ia/_run_ia_full.R
```

Step-by-step transparency path:

```bash
Rscript ia/_run_ia_estimation.R
Rscript ia/_run_ia_results.R
Rscript ia/_create_ia_latex.R
```

Build the IA PDF separately (only needed with the step-by-step path or `--skip-pdf`):
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1`
- Windows Command Prompt: `tools\build_ia_paper.cmd`
- macOS Terminal: `bash tools/build_ia_paper.sh`

Output:
- [ia_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper/latex/ia_main.pdf)

## IA Smoke Boundary (Validated 500-Draw Test)

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500`
- Windows Command Prompt: `tools\run_ia_smoke.cmd -Draws 500`
- macOS Terminal: `bash tools/run_ia_smoke.sh --ndraws=500`

Raw `Rscript` equivalent:

```bash
Rscript ia/_run_ia_estimation.R --ndraws=500
Rscript ia/_run_ia_results.R --expected-ndraws=500
Rscript ia/_create_ia_latex.R
```

Optional validated reduced-draw scale-up boundary:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000`
- Windows Command Prompt: `tools\run_ia_full.cmd -Draws 5000`
- macOS Terminal: `bash tools/run_ia_full.sh --ndraws=5000`

## If Something Fails, Rerun Here

- rerun the smallest failing boundary
- use the smoke boundary before the full boundary on a new machine
- use [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv) when you need to map a table or figure back to the smallest script boundary
