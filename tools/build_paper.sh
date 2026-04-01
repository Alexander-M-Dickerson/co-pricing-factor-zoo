#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_ASSEMBLY=0
SKIP_BIBTEX=0

usage() {
  cat <<'EOF'
Usage: tools/build_paper.sh [--skip-assembly] [--skip-bibtex]

Assemble the paper LaTeX tree and compile djm_main.pdf.
EOF
}

resolve_rscript() {
  if command -v Rscript >/dev/null 2>&1; then
    command -v Rscript
    return
  fi

  if [[ -n "${R_HOME:-}" && -x "${R_HOME}/bin/Rscript" ]]; then
    printf '%s\n' "${R_HOME}/bin/Rscript"
    return
  fi

  if [[ -x "/Library/Frameworks/R.framework/Resources/bin/Rscript" ]]; then
    printf '%s\n' "/Library/Frameworks/R.framework/Resources/bin/Rscript"
    return
  fi

  printf 'Could not locate Rscript. Install R or add it to PATH.\n' >&2
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --skip-assembly)
      SKIP_ASSEMBLY=1
      ;;
    --skip-bibtex)
      SKIP_BIBTEX=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v pdflatex >/dev/null 2>&1; then
  printf 'Could not locate pdflatex. Install a LaTeX distribution and add it to PATH.\n' >&2
  exit 1
fi

if [[ "$SKIP_BIBTEX" -eq 0 ]] && ! command -v bibtex >/dev/null 2>&1; then
  printf 'Could not locate bibtex. Install a LaTeX distribution and add it to PATH.\n' >&2
  exit 1
fi

RSCRIPT="$(resolve_rscript)"

cd "$REPO_ROOT"
if [[ "$SKIP_ASSEMBLY" -eq 0 ]]; then
  "$RSCRIPT" "${REPO_ROOT}/_create_djm_tabs_figs.R"
fi

cd "${REPO_ROOT}/output/paper/latex"
pdflatex -interaction=nonstopmode djm_main.tex
if [[ "$SKIP_BIBTEX" -eq 0 ]]; then
  bibtex djm_main
fi
pdflatex -interaction=nonstopmode djm_main.tex
pdflatex -interaction=nonstopmode djm_main.tex
