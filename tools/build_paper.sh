#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKIP_ASSEMBLY=0
SKIP_BIBTEX=0
FIXTURE_DIR=""

usage() {
  cat <<'EOF'
Usage: tools/build_paper.sh [--skip-assembly] [--skip-bibtex] [--fixture-dir PATH]

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

  for p in /usr/bin/Rscript /usr/local/bin/Rscript /opt/homebrew/bin/Rscript; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return
    fi
  done

  if [[ -x "/Library/Frameworks/R.framework/Resources/bin/Rscript" ]]; then
    printf '%s\n' "/Library/Frameworks/R.framework/Resources/bin/Rscript"
    return
  fi

  cat >&2 <<'ERRMSG'
Could not locate Rscript.
  Ubuntu/Debian: sudo apt install r-base
  macOS:         Download from https://cran.r-project.org/bin/macosx/
  Windows:       Download from https://cran.r-project.org/bin/windows/
ERRMSG
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
    --fixture-dir=*)
      FIXTURE_DIR="${arg#*=}"
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

if [[ -n "$FIXTURE_DIR" ]]; then
  LATEX_ROOT="${REPO_ROOT}/${FIXTURE_DIR}"
  if [[ ! -f "${LATEX_ROOT}/djm_main.tex" ]]; then
    printf 'Fixture directory does not contain djm_main.tex: %s\n' "$LATEX_ROOT" >&2
    exit 1
  fi
else
  RSCRIPT="$(resolve_rscript)"
  cd "$REPO_ROOT"
  if [[ "$SKIP_ASSEMBLY" -eq 0 ]]; then
    "$RSCRIPT" "${REPO_ROOT}/_create_djm_tabs_figs.R"
  fi
  LATEX_ROOT="${REPO_ROOT}/output/paper/latex"
fi

cd "$LATEX_ROOT"
pdflatex -interaction=nonstopmode djm_main.tex
if [[ "$SKIP_BIBTEX" -eq 0 ]]; then
  bibtex djm_main
fi
pdflatex -interaction=nonstopmode djm_main.tex
pdflatex -interaction=nonstopmode djm_main.tex
