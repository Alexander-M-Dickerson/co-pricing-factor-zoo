# Testing Guidance

This directory is for targeted validation and harness code, especially around compiled backends and numerical checks.

## Priorities

- Preserve the harness role: detect regressions in sampler behavior, not just formatting differences.
- Prefer narrow validation runs that isolate one backend or one output family.
- Keep generated test artifacts out of tracked source unless the task explicitly needs fixtures.

## When Editing

- Do not casually rewrite oracles or expected values without understanding the numerical reason.
- If you change a fast backend or sampler path, update the smallest relevant harness or verification script here.
- Keep path handling explicit and portable.
