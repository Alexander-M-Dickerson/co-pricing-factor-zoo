# Co-Pricing Factor Zoo

Replication repository for [The Co-Pricing Factor Zoo](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4589786).

Current coverage:
- all main paper tables and figures
- all main Appendix tables and figures
- some Internet Appendix results

## Run This Repo As A Human

If you want to reproduce the paper yourself, start with the public wrapper
commands. They are the default human path because they handle platform-specific
`Rscript`, LaTeX, and process details for you. If you want exact script
boundaries, the raw `Rscript` equivalents are documented in
[QUICKSTART.md](./QUICKSTART.md) and [README_PAPER_PIPELINE.md](./README_PAPER_PIPELINE.md).

### Fastest Validated Main-Paper Path

Windows PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File tools\bootstrap_data.ps1
powershell -ExecutionPolicy Bypass -File tools\bootstrap_packages.ps1
powershell -ExecutionPolicy Bypass -File tools\doctor.ps1 --check-only
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1
```

Windows Command Prompt:

```bat
tools\bootstrap_data.cmd
tools\bootstrap_packages.cmd
tools\doctor.cmd --check-only
tools\run_full_replication.cmd -Quick
tools\build_paper.cmd
```

macOS Terminal:

```bash
bash tools/bootstrap_data.sh
bash tools/bootstrap_packages.sh
bash tools/doctor.sh --check-only
bash tools/run_full_replication.sh --quick
bash tools/build_paper.sh
```

Posit/RStudio Terminal:
- on Windows, use the same PowerShell wrapper commands shown above, or use the raw
  `Rscript` boundaries from [QUICKSTART.md](./QUICKSTART.md)
- on macOS, use the same `bash` wrapper commands shown above, or the raw `Rscript`
  boundaries from [QUICKSTART.md](./QUICKSTART.md)

Expected output:
- main PDF: [djm_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex/djm_main.pdf)

### Fastest Validated IA Path

Use the IA smoke boundary first on a new machine, then scale up to the full IA
run once the smoke path passes.

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

Expected output:
- IA PDF: [ia_main.pdf](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper/latex/ia_main.pdf)

### Where Outputs Appear

- main tables: [output/paper/tables](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/tables)
- main figures: [output/paper/figures](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/figures)
- main LaTeX tree and PDF: [output/paper/latex](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/paper/latex)
- IA outputs: [ia/output/paper](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper)
- IA LaTeX tree and PDF: [ia/output/paper/latex](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/paper/latex)
- logs: [output/logs](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/output/logs) and [ia/output/logs](C:/Users/alexm/OneDrive/Documents/GitHub/co-pricing-factor-zoo/ia/output/logs)

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
