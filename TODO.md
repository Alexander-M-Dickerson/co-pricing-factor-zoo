# TODO

Execution checklist after the March 31, 2026 host validation pass.

## Now

- [x] Run a fully fresh 5,000-draw top-level replication:
  `tools\run_full_replication.ps1 -Draws 5000`
- [x] Confirm that both unconditional and conditional outputs are regenerated
  fresh from that run, not reused from older cached artifacts.
- [x] Record the run boundary that is now actually validated in repo docs:
  host wrapper used, draw count, expected runtime, and output locations.
- [x] Update agent and human context after the fresh end-to-end run:
  `README.md`, `QUICKSTART.md`, `AGENTS.md`,
  `docs/agent-context/replication-pipeline.md`, and any skill text that should
  reflect the validated host execution path.

## Next

- [x] Remove the remaining non-fatal LaTeX reference warnings by hard-coding the
  generated `.tex` content so it does not point at missing sections from the old
  full-paper manuscript template:
  `sec:benchmark_models`, `sec:data`, `sec:factor_zoo`, `app:cf_dr`, `eq:dur`.
- [x] Review the `.tex` generators and templates that produce those references
  and replace manuscript-only `\ref{...}` hooks with plain text where needed.
- [x] Regenerate Figure 9 PDFs with a `pdfTeX`-compatible PDF device so the
  PDF-version warnings disappear during `pdflatex`.
- [ ] Review the remaining large-float warnings and decide whether pagination
  adjustments are worth doing for a cleaner compiled manuscript.
- [ ] Review the remaining LaTeX template warnings outside the stale-reference
  class:
  duplicate page destinations and the `Hfootnote.*` destination warnings.

## After That

- [x] Add Windows `.cmd` shims for the public wrappers so users can run either
  `.ps1` or `.cmd` entrypoints.
- [x] Add Unix shell wrappers for the same public tasks:
  conditional smoke, backend rebuild, full replication, and final paper build.
- [x] Add a dedicated document-build wrapper so users do not need to run
  `pdflatex` and `bibtex` manually.
- [x] Expand `README.md` and `QUICKSTART.md` into a clear cross-platform command
  matrix for Windows PowerShell, Windows Command Prompt, macOS, and Linux.

## Later

- [x] Tighten cache invalidation for unconditional paper-output helpers so a
  strict fresh rebuild regenerates cached intermediate `.rds` files and figure
  artifacts instead of silently reusing them.
- [x] Add cross-platform smoke validation for the public wrappers and
  `tools/doctor.R`, including macOS in GitHub Actions.
- [ ] Add a PDF-build smoke check that compiles
  `output/paper/latex/djm_main.tex` and flags unresolved references or missing
  bibliography output.
- [ ] Decide whether `_create_djm_tabs_figs.R` should remain a LaTeX-assembly
  step only or gain an optional compile mode.
- [ ] Run a literal fresh-clone acceptance drill for Codex and Claude and record
  whether the agents correctly bootstrap packages, fetch the canonical data
  bundle, recognize tracked `ia/data/w_all.rds`, and choose the validated main
  and IA smoke boundaries before scaling up.
- [ ] Add the same fresh-clone acceptance drill for the prompt
  `Fully explain Table 1` and verify the answer routes through the exhibit
  dossier, paper refs, code path, saved objects, and generated output file.
- [ ] Add a real macOS host validation pass before claiming seamless
  cross-platform execution, especially for source-package compilation
  (`Rcpp`, `rugarch`, `rmgarch`, and the local `BayesianFactorZoo` install).
- [x] Improve macOS-facing doctor/docs guidance for toolchain prerequisites
  such as Xcode Command Line Tools and `gfortran`.
