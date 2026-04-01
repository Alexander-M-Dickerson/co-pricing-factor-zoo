# Main Text Flow

Use this when the task is to run or resume the main paper pipeline.

Execution order:

1. `_run_all_unconditional.R`
2. `_run_all_conditional.R`
3. `_run_paper_results.R`
4. `_run_paper_conditional_results.R`
5. `_create_djm_tabs_figs.R`
6. `tools/build_paper.*`

Fresh-clone default:

1. `tools/bootstrap_packages.*`
2. `tools/bootstrap_data.*`
3. `tools/doctor.*`
4. requested pipeline boundary

Use `docs/manifests/exhibits.csv` for executable routing and `docs/manifests/manuscript_exhibits.csv` when the user asks about the full paper inventory.
