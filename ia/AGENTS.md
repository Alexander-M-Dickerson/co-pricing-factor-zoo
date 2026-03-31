# IA Guidance

This directory contains the Internet Appendix pipeline and should be treated as a separate execution surface from the main paper outputs.

## Source Of Truth

For IA model coverage, use `ia/_run_ia_estimation.R` as the source of truth.

The current IA workflow defines nine models:

1. `bond_intercept`
2. `stock_intercept`
3. `bond_no_intercept`
4. `stock_no_intercept`
5. `joint_no_intercept`
6. `treasury_base`
7. `treasury_weighted`
8. `sparse_joint`
9. `isos_switch`

If `ia/README.md` or another note says five models, the code is newer.

## Execution Guidance

- Run IA scripts from the repo root unless the script explicitly handles directory switching.
- Keep IA artifacts under `ia/output/`.
- Prefer targeted IA reruns over restarting the full IA pipeline.

## Editing Guidance

- Keep IA-specific orchestration in `ia/`.
- If reusable logic belongs in shared code, move it to `code_base/` rather than duplicating it here.
- Update IA docs when executable IA behavior changes.
