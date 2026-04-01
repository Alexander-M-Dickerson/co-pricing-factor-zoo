# Paper Pipeline

Use this file as the short map to the executable replication boundaries.

Primary references:

- [QUICKSTART.md](./QUICKSTART.md): human runbook
- [docs/agent-context/replication-pipeline.md](./docs/agent-context/replication-pipeline.md): shared agent pipeline context
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): exhibit-to-code mapping
- [docs/manifests/manuscript_exhibits.csv](./docs/manifests/manuscript_exhibits.csv): full paper inventory with repo coverage status
- [docs/manifests/paper_claims.csv](./docs/manifests/paper_claims.csv): claim-to-evidence coverage map
- [docs/agent-context/prompt-recipes.md](./docs/agent-context/prompt-recipes.md): canonical prompt surface for Codex and Claude
- [docs/paper/co-pricing-factor-zoo.ai-optimized.md](./docs/paper/co-pricing-factor-zoo.ai-optimized.md): full paper

Fresh-clone default:

1. `tools/bootstrap_packages.*`
2. `tools/bootstrap_data.*`
3. `tools/doctor.*`
4. requested pipeline boundary

Main five-step pipeline:

1. `_run_all_unconditional.R`
2. `_run_all_conditional.R`
3. `_run_paper_results.R`
4. `_run_paper_conditional_results.R`
5. `_create_djm_tabs_figs.R` to assemble the LaTeX source tree
6. `tools/build_paper.*` to compile `output/paper/latex/djm_main.tex`
7. `tools/run_figure1_simulation.*` only when you explicitly want to regenerate the Figure 1 simulation fixtures rather than use the tracked default build

Validated Windows host path as of March 31, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Windows Command Prompt equivalents:

```bat
tools\run_full_replication.cmd -Draws 5000
tools\build_paper.cmd
```

macOS or Linux equivalents:

```bash
bash tools/run_full_replication.sh --ndraws=5000
bash tools/build_paper.sh
```

That run completed end-to-end on the maintainer Windows host. The new build
wrapper turns the final PDF compilation step into a public repo command instead
of a manual `pdflatex` and `bibtex` sequence.

IA pipeline:

1. `tools/run_ia_smoke.*` for the canonical 500-draw IA smoke boundary
2. `tools/run_ia_full.*` or `ia/_run_ia_full.R` for estimation + outputs + LaTeX assembly
3. `tools/build_ia_paper.*` to compile `ia/output/paper/latex/ia_main.tex`

Validated IA Windows host path as of April 1, 2026:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

That IA run completed end-to-end on the maintainer Windows host, including the
5,000-draw estimation boundary, implemented IA outputs, LaTeX assembly, and IA
PDF compilation.

IA entrypoint breakdown:

1. `ia/_run_ia_estimation.R`
2. `ia/_run_ia_results.R`
3. `ia/_create_ia_latex.R`
4. `ia/_run_ia_full.R`

Resume rule:

- stop at the first failing script
- rerun the smallest failing boundary
- use the executable manifest, manuscript manifest, and shared pipeline doc before reading source in depth
