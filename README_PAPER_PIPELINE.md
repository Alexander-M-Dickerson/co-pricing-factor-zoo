# Paper Pipeline

Use this file as the short human boundary map.

Primary references:
- [QUICKSTART.md](./QUICKSTART.md): full human runbook
- [docs/validation/validated_runs.csv](./docs/validation/validated_runs.csv): source of truth for validated runtime and build boundaries
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): exhibit-to-code mapping

## Main Smoke Boundary

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick`
- Windows Command Prompt: `tools\run_full_replication.cmd -Quick`
- macOS Terminal: `bash tools/run_full_replication.sh --quick`

Raw `Rscript` equivalent:

```bash
Rscript _run_full_replication.R --quick
```

Build the PDF with:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1`
- Windows Command Prompt: `tools\build_paper.cmd`
- macOS Terminal: `bash tools/build_paper.sh`

Output:
- [djm_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex/djm_main.pdf)

## Main Full Boundary

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000`
- Windows Command Prompt: `tools\run_full_replication.cmd -Draws 5000`
- macOS Terminal: `bash tools/run_full_replication.sh --ndraws=5000`

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

## IA Smoke Boundary

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

## IA Full Boundary

Wrapper path:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000`
- Windows Command Prompt: `tools\run_ia_full.cmd -Draws 5000`
- macOS Terminal: `bash tools/run_ia_full.sh --ndraws=5000`

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

Build the IA PDF with:
- Windows PowerShell: `powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1`
- Windows Command Prompt: `tools\build_ia_paper.cmd`
- macOS Terminal: `bash tools/build_ia_paper.sh`

Output:
- [ia_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper/latex/ia_main.pdf)

## If Something Fails, Rerun Here

- rerun the smallest failing boundary
- use the smoke boundary before the full boundary on a new machine
- use [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv) when you need to map a table or figure back to the smallest script boundary
