# Manifests

Machine-readable repo manifests live here so humans and AI agents can discover
inputs, exhibits, and coverage boundaries without re-parsing long prose docs.

## Files

- `data-files.csv`: required and optional input files, what each file supports,
  where it belongs in the repo, and which canonical bootstrap source covers it
- `data-sources.csv`: canonical public bundle sources, extraction targets, and
  verification metadata
- `exhibits.csv`: table, figure, and IA output mapping from paper exhibit to
  script boundary, helper path, generated output path, and explanation dossier
- `manuscript_exhibits.csv`: full paper inventory with repo coverage status and
  executable exhibit linkage where available
- `paper_claims.csv`: headline manuscript claims mapped to the exhibits and
  equations that support them

## Conventions

- `coverage_status` is the execution reality of the repo, not a statement about
  the manuscript as a whole
- `bootstrap_source_id` in `data-files.csv` names the canonical public bundle
  that should supply that file
- `entry_script` is the first script boundary to run or inspect
- `helper_or_generator` is the main downstream helper path when one exists
- `saved_inputs` names the saved objects or upstream artifacts that the exhibit
  depends on
- `output_path` may use a glob when the exact filename varies by model tag
- `context_dossier` points to the preferred deep-explanation markdown file for
  that exhibit

Keep these CSVs synchronized with the executable pipeline. If prose and the
manifest disagree, fix the manifest or the code path before expanding the prose.
