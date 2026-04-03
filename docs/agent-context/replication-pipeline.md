# Replication Pipeline

This is the shared runbook for executing the main paper and Internet Appendix workflows.

Current coverage target:

- all main paper tables and figures
- all main Appendix tables and figures
- some IA results

Canonical prompt recipes live in `docs/agent-context/prompt-recipes.md`.

## Preflight

Before estimation:

1. Resolve the full `Rscript` path. Do not assume bare `Rscript` is available in every subprocess.
2. Confirm the required `data/` inputs are present via `docs/manifests/data-files.csv`; if they are missing and covered by the canonical bundle, run `tools/bootstrap_data.*`.
3. Run `tools/doctor.R --check-only` before long runs on a new machine or after environment changes.
4. Confirm the fast C++ backends can load for the current environment.
5. Create or reuse `logs/` for top-level logs when needed.

Fresh-clone default:

1. `tools/bootstrap_packages.*`
2. `tools/bootstrap_data.*`
3. `tools/doctor.*`
4. requested replication boundary

## Main Paper Pipeline

The main root script sequence is:

1. `_run_all_unconditional.R`              ~8 min
2. `_run_all_conditional.R`                ~46 min
3. `_run_paper_results.R`                  ~10 min
4. `_run_paper_conditional_results.R`      <1 min
5. `_create_djm_tabs_figs.R`               <1 min
6. PDF compilation (pdflatex + bibtex)     <1 min

Representative total: **~65 min** at 50,000 draws on a 24-core desktop (Intel
Core Ultra 9 275HX, 128 GB RAM).

`_run_full_replication.R` now runs all six steps including PDF compilation.
`tools/build_paper.*` remains available for standalone PDF builds.

Figure 1 default behavior:

- `_run_paper_results.R` builds Figure 1 from tracked fixtures under `misc/figure1_simulation/`
- `tools/run_figure1_simulation.*` is the separate explicit regeneration path for the underlying Monte Carlo outputs

`_run_full_replication.R` orchestrates the main six-step flow (including PDF compilation), but agents should still understand the underlying step boundaries for resume and debugging.

Validated host path as of March 31, 2026:

- `powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 5000`
- `powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Draws 5000`
- `powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1`

That validated Windows host path completed cleanly on the maintainer machine.
Equivalent `.cmd` and `.sh` wrappers now exist for the same public tasks. The
underlying R scripts remain the source of truth.

## Main Commands

Typical entrypoints from the repo root:

```bash
Rscript tools/doctor.R --check-only
Rscript _run_complete_replication.R --help
Rscript _run_full_replication.R --help
Rscript _run_all_unconditional.R --ndraws=5000
Rscript _run_all_conditional.R --direction=both --ndraws=500
Rscript _run_all_conditional.R --direction=forward --ndraws=500
Rscript _run_paper_results.R
Rscript _run_paper_conditional_results.R
Rscript _create_djm_tabs_figs.R
```

Windows PowerShell wrappers:

```powershell
powershell -ExecutionPolicy Bypass -File tools\rebuild_fast_backends.ps1
powershell -ExecutionPolicy Bypass -File tools\run_conditional_smoke.ps1 -Draws 500
powershell -ExecutionPolicy Bypass -File tools\run_full_replication.ps1 -Quick
powershell -ExecutionPolicy Bypass -File tools\build_paper.ps1 -SkipAssembly
```

Windows Command Prompt wrappers:

```bat
tools\rebuild_fast_backends.cmd
tools\run_conditional_smoke.cmd -Draws 500
tools\run_full_replication.cmd -Quick
tools\build_paper.cmd -SkipAssembly
```

macOS or Linux wrappers:

```bash
bash tools/rebuild_fast_backends.sh
bash tools/run_conditional_smoke.sh --direction=both --ndraws=500
bash tools/run_full_replication.sh --quick
bash tools/build_paper.sh --skip-assembly
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

Preferred validation boundary:

- `Rscript _run_all_conditional.R --direction=both --ndraws=500` for the supervised paired smoke test
- `Rscript _run_all_conditional.R --direction=forward --ndraws=500` for single-direction diagnosis

When conditional outputs look wrong, trace:

- `_run_all_conditional.R`
- `code_base/run_bayesian_mcmc_time_varying.R`
- `_run_paper_conditional_results.R`

## Main Paper Outputs

Use these scripts after the required estimation artifacts exist:

- `_run_paper_results.R` for unconditional tables and figures
- `_run_paper_conditional_results.R` for conditional outputs
- `_create_djm_tabs_figs.R` for LaTeX source assembly
- `tools/build_paper.ps1`, `tools/build_paper.cmd`, or `tools/build_paper.sh` for final PDF compilation

Current freshness behavior for unconditional paper outputs:

- `_run_full_replication.R` validates the seven unconditional workspaces after Step 1
- `_run_paper_results.R --strict-freshness` forces regeneration of cached unconditional intermediates and figures
- the validated March 31, 2026 host path now exercises that strict-refresh boundary successfully

Generated artifacts belong under `output/`. Do not move them into source directories.

## Internet Appendix Pipeline

The IA workflow lives under `ia/` and should be treated as its own pipeline with source-of-truth model definitions in `ia/_run_ia_estimation.R`.

Canonical public IA wrappers:

1. `tools/run_ia_smoke.*`
2. `tools/run_ia_full.*`
3. `tools/build_ia_paper.*`

The high-level IA scripts are:

1. `ia/_run_ia_estimation.R`          ~12 min
2. `ia/_run_ia_results.R`             ~4 min
3. `ia/_create_ia_latex.R`            <1 min
4. PDF compilation (pdflatex+bibtex)  <1 min

Representative total: **~16 min** at 50,000 draws on a 24-core desktop.

`ia/_run_ia_full.R` orchestrates all four steps including PDF compilation.

Use `tools/run_ia_smoke.*` as the first IA validation boundary. The canonical IA
smoke run is `500` draws and should complete all nine IA models before any scale-up.

Validated Windows host IA path as of April 1, 2026:

- `powershell -ExecutionPolicy Bypass -File tools\run_ia_smoke.ps1 -Draws 500`
- `powershell -ExecutionPolicy Bypass -File tools\run_ia_full.ps1 -Draws 5000`
- `powershell -ExecutionPolicy Bypass -File tools\build_ia_paper.ps1`

That IA host path completed cleanly on the maintainer Windows host. The smoke
boundary completed all nine IA models, and the 5,000-draw full boundary also
completed cleanly and rebuilt the IA PDF from fresh artifacts.

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

IA engine map:

- Models `1-5`, `8`, and `9` are self-pricing IA runs and should use
  `continuous_ss_sdf_v2_fast` by default.
- Treasury IA models are not self-pricing in the estimator. For
  `model_type = "treasury"`, `run_bayesian_mcmc()` merges the bond-factor file
  into the no-self-pricing branch.
- `treasury_base` therefore uses `BayesianFactorZoo::continuous_ss_sdf`.
- `treasury_weighted` uses `continuous_ss_sdf_multi_asset_no_sp`.

Engine usage validated on the maintainer host:

- models `1-5`, `8`, and `9` ran on `continuous_ss_sdf_v2_fast`
- `treasury_base` ran on `BayesianFactorZoo::continuous_ss_sdf`
- `treasury_weighted` ran on `continuous_ss_sdf_multi_asset_no_sp`

Important coverage distinction:

- `ia/_run_ia_estimation.R` defines nine IA estimation models
- `ia/_run_ia_results.R` currently generates a substantial but partial IA results subset
- do not describe the repo as reproducing every IA result unless that output path is actually implemented
- `ia/data/w_all.rds` is required tracked clone data for the weighted treasury model

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

## Post-Run Audit

After any pipeline run, a replication manifest is automatically written to
`output/replication_manifest_<pipeline>_<timestamp>.json`. This records every
exhibit produced vs. expected, estimation engines used, per-model timings, and
overall completeness.

Run the audit standalone:

```bash
Rscript tools/audit_run.R --pipeline=both
Rscript tools/audit_run.R --list-runs --latest
```

## Output Expectations

Main paper artifacts are expected under `output/`.

IA artifacts are expected under `ia/output/`.

Use `docs/manifests/exhibits.csv` when you need the paper-to-script-to-output
mapping before opening helper code.
Use `docs/manifests/manuscript_exhibits.csv` when the user asks about the full
paper inventory rather than the executable subset, and use
`docs/manifests/paper_claims.csv` when the question is about a headline
manuscript claim rather than a single exhibit.

## Failure Patterns

- missing saved `.Rdata` or `.rds` files for downstream scripts
- stale assumptions about IA model count
- path bugs caused by running outside the repo root
- `pdflatex` or `bibtex` missing during `tools/build_paper.*`
- edits in `BayesianFactorZoo/` when the real fix belongs in `code_base/`
