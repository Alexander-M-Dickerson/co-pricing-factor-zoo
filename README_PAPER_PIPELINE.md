# Paper Pipeline

Use this file as the short map to the executable replication boundaries.

Primary references:

- [QUICKSTART.md](./QUICKSTART.md): human runbook
- [docs/agent-context/replication-pipeline.md](./docs/agent-context/replication-pipeline.md): shared agent pipeline context
- [docs/manifests/exhibits.csv](./docs/manifests/exhibits.csv): exhibit-to-code mapping
- [docs/paper/co-pricing-factor-zoo.ai-optimized.md](./docs/paper/co-pricing-factor-zoo.ai-optimized.md): full paper

Main five-step pipeline:

1. `_run_all_unconditional.R`
2. `_run_all_conditional.R`
3. `_run_paper_results.R`
4. `_run_paper_conditional_results.R`
5. `_create_djm_tabs_figs.R`

IA pipeline:

1. `ia/_run_ia_estimation.R`
2. `ia/_run_ia_results.R`
3. `ia/_create_ia_latex.R`
4. `ia/_run_ia_full.R`

Resume rule:

- stop at the first failing script
- rerun the smallest failing boundary
- use the manifest and the shared pipeline doc before reading source in depth
