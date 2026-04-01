#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_ASSEMBLY=0

usage() {
  cat <<'EOF'
Usage: tools/build_ia_paper.sh [--skip-assembly]

Assemble the IA LaTeX tree and compile ia_main.pdf.
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

RSCRIPT="$(resolve_rscript)"

cd "$REPO_ROOT"
if [[ "$SKIP_ASSEMBLY" -eq 0 ]]; then
  "$RSCRIPT" "${REPO_ROOT}/ia/_create_ia_latex.R"
fi

cd "${REPO_ROOT}/ia/output/paper/latex"
pdflatex -interaction=nonstopmode ia_main.tex
pdflatex -interaction=nonstopmode ia_main.tex
