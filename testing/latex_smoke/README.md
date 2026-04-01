# LaTeX Smoke Fixtures

These fixtures exist so CI can prove the public paper-build wrappers compile a
small tracked LaTeX tree without depending on gitignored runtime outputs under
`output/` or `ia/output/`.

Use:

- `testing/latex_smoke/main/` with `tools/build_paper.* --fixture-dir`
- `testing/latex_smoke/ia/` with `tools/build_ia_paper.* --fixture-dir`

The fixture trees intentionally mimic the wrapper expectations:

- `djm_main.tex` for the main paper wrapper
- `ia_main.tex` for the IA paper wrapper

The fixture content is deliberately small. It tests wrapper behavior and LaTeX
tool availability, not the full manuscript.
