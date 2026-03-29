# CLAUDE.md

Project-level agent guidance lives in `AGENTS.md`.

Read `AGENTS.md` first for:

- what this repository does
- how the replication pipeline is organized
- which directories are source vs generated state
- model and data invariants that must be preserved
- preferred validation and editing patterns

Claude-specific notes:

- `.claude/settings.local.json` is a local tool settings file, not the canonical
  project instructions source.
- If this file and `AGENTS.md` ever diverge, treat `AGENTS.md` as the repo source of
  truth and keep this file as a thin adapter.
