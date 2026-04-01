# Bootstrap Sequence

Use this when the task is a fresh clone or an environment that is missing pieces.

Default sequence:

1. Resolve `Rscript`.
2. Check or install packages with `tools/bootstrap_packages.*`.
3. If required bundle-managed data are missing, run `tools/bootstrap_data.*`.
4. Run `tools/doctor.*`.
5. Rebuild fast backends if the doctor reports a backend problem.
6. Stop at the first blocking dependency and report the exact next action.

Do not ask the user to copy main paper data by hand if `tools/bootstrap_data.*` can supply it.
