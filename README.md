# Co-Pricing Factor Zoo

Replication repository for [The Co-Pricing Factor Zoo](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4589786).

Current coverage:
- all main paper tables and figures
- all main Appendix tables and figures
- some Internet Appendix results

## Use Claude Code Or Codex

If you want an agent to drive setup or replication for you, open Claude Code or
Codex in the repo root and use the repo skills below. These are prompts you
type inside the agent session, not shell commands you run in PowerShell,
Command Prompt, or bash.

Claude Code:
- `/onboard` to set up a fresh clone
- `/replicate-paper` to run or resume the replication pipeline
- `/explain-paper` to explain tables, figures, factors, and code paths

Codex:
- `$replication-onboard` to set up a fresh clone
- `$replicate-paper` to run or resume the replication pipeline
- `$explain-paper` to explain tables, figures, factors, and code paths

Example prompt for either agent:

`Replicate the main text. If packages or data are missing, bootstrap them automatically first. Use the smallest validated boundary before scaling up, and stop at the first failing step with the exact rerun boundary.`

More agent prompts:
- [docs/agent-context/prompt-recipes.md](./docs/agent-context/prompt-recipes.md)

## Run This Repo As A Human

If you want to reproduce the paper yourself, start with the public wrapper
commands. They are the default human path because they handle platform-specific
`Rscript`, LaTeX, and process details for you. If you want exact script
boundaries, the raw `Rscript` equivalents are documented in
[QUICKSTART.md](./QUICKSTART.md) and [README_PAPER_PIPELINE.md](./README_PAPER_PIPELINE.md).
To exactly replicate the reported paper results, use the no-flag full pipeline:
it defaults to 50,000 draws for the main paper and the Internet Appendix.
Reduced-draw quick or smoke paths are setup-validation shortcuts, not the paper
setting.

### Complete Replication: Main Paper + Internet Appendix

To replicate both the main paper and Internet Appendix in a single command
(~81 minutes total at 50,000 draws):

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_complete_replication.ps1
```

Windows Command Prompt:

```bat
tools\run_complete_replication.cmd
```

macOS Terminal:

```bash
bash tools/run_complete_replication.sh
```

This produces both PDFs and a machine-readable replication manifest at
`output/replication_manifest_both_<timestamp>.json` documenting every exhibit,
engine, and timing.

### Exact Main-Paper Replication (50,000 Draws)

Representative runtime: **~65 minutes total** on a 24-core desktop (Intel Core
Ultra 9 275HX, 128 GB RAM). Step breakdown:

| Step | Description | Time |
|------|-------------|------|
| 1 | Unconditional estimation (7 models) | ~8 min |
| 2 | Conditional estimation (2 directions) | ~46 min |
| 3 | Tables & figures (unconditional) | ~10 min |
| 4 | Tables & figures (conditional) | <1 min |
| 5 | LaTeX assembly | <1 min |
| 6 | PDF compilation | <1 min |

The full pipeline now compiles the PDF automatically as Step 6. A separate
`build_paper` call is no longer required but remains available.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_data.ps1
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1
```

Windows Command Prompt:

```bat
tools\bootstrap_data.cmd
tools\bootstrap_packages.cmd
tools\doctor.cmd --check-only
tools\run_full_replication.cmd
```

macOS Terminal:

```bash
bash tools/bootstrap_data.sh
bash tools/bootstrap_packages.sh
bash tools/doctor.sh --check-only
bash tools/run_full_replication.sh
```

Posit/RStudio Terminal:
- on Windows, use the same PowerShell wrapper commands shown above, or use the raw
  `Rscript` boundaries from [QUICKSTART.md](./QUICKSTART.md)
- on macOS, use the same `bash` wrapper commands shown above, or the raw `Rscript`
  boundaries from [QUICKSTART.md](./QUICKSTART.md)

Expected output:
- main PDF: [djm_main.pdf](output/paper/latex/djm_main.pdf)

If you want a reduced-draw setup check first, use the validated 5,000-draw main
smoke path from [QUICKSTART.md](./QUICKSTART.md), then scale back to the no-flag
50,000-draw path for exact replication.

### Exact IA Replication (50,000 Draws)

Representative runtime: **~16 minutes total** on the same 24-core desktop. Step
breakdown:

| Step | Description | Time |
|------|-------------|------|
| 1 | IA estimation (9 models, 2 parallel batches) | ~12 min |
| 2 | IA tables & figures | ~4 min |
| 3 | IA LaTeX assembly | <1 min |
| 4 | IA PDF compilation | <1 min |

The IA pipeline now compiles the PDF automatically as Step 4.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1
```

Windows Command Prompt:

```bat
tools\run_ia_full.cmd
```

macOS Terminal:

```bash
bash tools/run_ia_full.sh
```

Posit/RStudio Terminal:
- on Windows, use the same PowerShell wrapper commands shown above, or the raw
  `Rscript` IA boundaries from [QUICKSTART.md](./QUICKSTART.md)
- on macOS, use the same `bash` wrapper commands shown above, or the raw `Rscript`
  IA boundaries from [QUICKSTART.md](./QUICKSTART.md)

Expected output:
- IA PDF: [ia_main.pdf](ia/output/paper/latex/ia_main.pdf)

### Validated IA Smoke And Scale-Up Path

Use the IA smoke boundary first on a new machine, then scale up to the full IA
run once the smoke path passes. These reduced-draw boundaries are for setup
validation only; exact IA replication is the no-flag 50,000-draw path above.

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000
powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1
```

Windows Command Prompt:

```bat
tools\run_ia_smoke.cmd -Draws 500
tools\run_ia_full.cmd -Draws 5000
tools\build_ia_paper.cmd
```

macOS Terminal:

```bash
bash tools/run_ia_smoke.sh --ndraws=500
bash tools/run_ia_full.sh --ndraws=5000
bash tools/build_ia_paper.sh
```

Posit/RStudio Terminal:
- on Windows, use the same PowerShell wrapper commands shown above, or the raw
  `Rscript` IA boundaries from [QUICKSTART.md](./QUICKSTART.md)
- on macOS, use the same `bash` wrapper commands shown above, or the raw `Rscript`
  IA boundaries from [QUICKSTART.md](./QUICKSTART.md)

### Audit a Completed Run

After any pipeline run, inspect the replication manifest:

```bash
Rscript tools/audit_run.R --pipeline=both
Rscript tools/audit_run.R --list-runs --latest
```

The manifest records every exhibit produced, estimation engines used, per-model
timings, and overall completeness status.

### Where Outputs Appear

- main tables: [output/paper/tables](output/paper/tables)
- main figures: [output/paper/figures](output/paper/figures)
- main LaTeX tree and PDF: [output/paper/latex](output/paper/latex)
- IA outputs: [ia/output/paper](ia/output/paper)
- IA LaTeX tree and PDF: [ia/output/paper/latex](ia/output/paper/latex)
- logs: [output/logs](output/logs) and [ia/output/logs](ia/output/logs)

Figure 1 note:
- ordinary paper replication publishes the tracked Figure 1 assets and does not
  rerun the Monte Carlo simulation
- use `tools/run_figure1_simulation.*` only if you explicitly want to regenerate
  Figure 1; that regeneration tool has its own separate 5,000-draw default

## Start Here

- [QUICKSTART.md](./QUICKSTART.md): full human setup and run guide
- [README_PAPER_PIPELINE.md](./README_PAPER_PIPELINE.md): short human boundary map
- [docs/validation/validated_runs.csv](./docs/validation/validated_runs.csv): source of truth for validated runtime and build boundaries
- [docs/manifests/data-files.csv](./docs/manifests/data-files.csv): required input checklist
- [docs/manifests/data-sources.csv](./docs/manifests/data-sources.csv): canonical public data bundle source
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): table, figure, and IA output map

Important setup notes:
- bootstrap bundle-managed main data with `tools/bootstrap_data.*`
- `ia/data/w_all.rds` is required tracked clone data and should already be present after clone
- validated runtime and build boundaries are recorded in [docs/validation/validated_runs.csv](./docs/validation/validated_runs.csv)
- macOS users should install Xcode Command Line Tools plus the CRAN-recommended GNU Fortran that matches their installed CRAN R version; official references are <https://cran.r-project.org/bin/macosx/tools/> and <https://mac.r-project.org/tools/>

## Advanced Human References

- [docs/manifests/manuscript_exhibits.csv](./docs/manifests/manuscript_exhibits.csv): full manuscript exhibit inventory with repo coverage status
- [docs/manifests/paper_claims.csv](./docs/manifests/paper_claims.csv): claim-to-evidence map
- [docs/acceptance/prompt_harness.csv](./docs/acceptance/prompt_harness.csv): acceptance rubric used for fresh-thread Codex and Claude checks
- [tools/validate_repo_docs.R](./tools/validate_repo_docs.R): drift check for docs, manifests, skills, and public entrypoints

## For Codex / Claude

This repo is also designed for coding agents, but the human path above is the
primary front door for manual replication.

Shared surfaces:
- [AGENTS.md](./AGENTS.md)
- [docs/agent-context](./docs/agent-context/)
- [docs/manifests](./docs/manifests/)
- [docs/paper](./docs/paper/)

Codex-native surfaces:
- `.codex/config.toml`
- `.agents/skills/`

Claude-native surfaces:
- [CLAUDE.md](./CLAUDE.md)
- `.claude/paper-context.md`
- `.claude/skills/`

Optional AI references:
- [docs/agent-context/prompt-recipes.md](./docs/agent-context/prompt-recipes.md)
- [docs/agent-context/exhibits/README.md](./docs/agent-context/exhibits/README.md)
- [docs/paper/co-pricing-factor-zoo.ai-optimized.md](./docs/paper/co-pricing-factor-zoo.ai-optimized.md)
- [docs/validation/agent_acceptance_log.csv](./docs/validation/agent_acceptance_log.csv)
