# Replication Pipeline

This is the shared runbook for executing the main paper and Internet Appendix workflows.

Current coverage target:

- all main paper tables and figures
- all main Appendix tables and figures
- some IA results

## Preflight

Before estimation:

1. Resolve the full `Rscript` path. Do not assume bare `Rscript` is available in every subprocess.
2. Confirm the required `data/` inputs are present via `docs/manifests/data-files.csv`.
3. Run `tools/doctor.R --check-only` before long runs on a new machine or after environment changes.
4. Confirm the fast C++ backends can load for the current environment.
5. Create or reuse `logs/` for top-level logs when needed.

## Main Paper Pipeline

The main root script sequence is:

1. `_run_all_unconditional.R`
2. `_run_all_conditional.R`
3. `_run_paper_results.R`
4. `_run_paper_conditional_results.R`
5. `_create_djm_tabs_figs.R`

`_run_full_replication.R` orchestrates the main five-step flow, but agents should still understand the underlying step boundaries for resume and debugging.

## Main Commands

Typical entrypoints from the repo root:

```bash
Rscript tools/doctor.R --check-only
Rscript _run_full_replication.R --help
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_conditional.R --ndraws=5000
Rscript _run_paper_results.R
Rscript _run_paper_conditional_results.R
Rscript _create_djm_tabs_figs.R
```

Prefer reduced-draw runs first when validating changes to orchestration or output generation.

## Unconditional Estimation

Main entrypoint: `_run_all_unconditional.R`

This batch runner launches the seven main unconditional model specifications used in the paper. Saved estimation results are consumed later by the table and figure scripts.

When debugging estimation behavior, orient through:

- `_run_unconditional_model.R`
- `code_base/run_bayesian_mcmc.R`
- the relevant sampler dispatch in `code_base/`

## Conditional Estimation

Main entrypoint: `_run_all_conditional.R`

This produces the expanding-window results used for the conditional figures and the out-of-sample trading panel in Table 6.

When conditional outputs look wrong, trace:

- `_run_all_conditional.R`
- `code_base/run_bayesian_mcmc_time_varying.R`
- `_run_paper_conditional_results.R`

## Main Paper Outputs

Use these scripts after the required estimation artifacts exist:

- `_run_paper_results.R` for unconditional tables and figures
- `_run_paper_conditional_results.R` for conditional outputs
- `_create_djm_tabs_figs.R` for LaTeX assembly

Generated artifacts belong under `output/`. Do not move them into source directories.

## Internet Appendix Pipeline

The IA workflow lives under `ia/` and should be treated as its own pipeline with source-of-truth model definitions in `ia/_run_ia_estimation.R`.

The high-level IA scripts are:

1. `ia/_run_ia_estimation.R`
2. `ia/_run_ia_results.R`
3. `ia/_create_ia_latex.R`
4. `ia/_run_ia_full.R`

The actual IA estimation surface is nine models:

1. `bond_intercept`
2. `stock_intercept`
3. `bond_no_intercept`
4. `stock_no_intercept`
5. `joint_no_intercept`
6. `treasury_base`
7. `treasury_weighted`
8. `sparse_joint`
9. `isos_switch`

If another doc says five IA models, the code is newer. Follow `ia/_run_ia_estimation.R`.

Important coverage distinction:

- `ia/_run_ia_estimation.R` defines nine IA estimation models
- `ia/_run_ia_results.R` currently generates a substantial but partial IA results subset
- do not describe the repo as reproducing every IA result unless that output path is actually implemented

## Resume Strategy

If a long run fails:

- stop at the first failing step
- inspect the relevant log or console output
- rerun the smallest failing stage instead of restarting the full pipeline

Good resume boundaries:

- unconditional estimation only
- conditional estimation only
- paper outputs only
- IA estimation only
- IA outputs only

## Validation Guidance

- Documentation-only changes: no runtime verification required.
- Narrow pipeline changes: run the smallest affected script with reduced draws when possible.
- Full replication recommendations: provide the exact script boundary and expected outputs, but do not claim completion without a real run.

## Output Expectations

Main paper artifacts are expected under `output/`.

IA artifacts are expected under `ia/output/`.

Use `docs/manifests/exhibits.csv` when you need the paper-to-script-to-output
mapping before opening helper code.

## Failure Patterns

- missing saved `.Rdata` or `.rds` files for downstream scripts
- stale assumptions about IA model count
- path bugs caused by running outside the repo root
- `pdflatex` missing during final assembly
- edits in `BayesianFactorZoo/` when the real fix belongs in `code_base/`
