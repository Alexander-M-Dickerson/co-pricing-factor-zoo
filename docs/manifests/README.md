# Manifests

Machine-readable repo manifests live here so humans and AI agents can discover
inputs, exhibits, and coverage boundaries without re-parsing long prose docs.

## Files

- `data-files.csv`: required and optional input files, what each file supports,
  and where it belongs in the repo
- `exhibits.csv`: table, figure, and IA output mapping from paper exhibit to
  script boundary, helper path, and generated output path

## Conventions

- `coverage_status` is the execution reality of the repo, not a statement about
  the manuscript as a whole
- `entry_script` is the first script boundary to run or inspect
- `helper_or_generator` is the main downstream helper path when one exists
- `saved_inputs` names the saved objects or upstream artifacts that the exhibit
  depends on
- `output_path` may use a glob when the exact filename varies by model tag

Keep these CSVs synchronized with the executable pipeline. If prose and the
manifest disagree, fix the manifest or the code path before expanding the prose.
