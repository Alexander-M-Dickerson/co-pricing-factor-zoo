#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

RSCRIPT="$(resolve_rscript)"
exec "$RSCRIPT" "${SCRIPT_DIR}/bootstrap_latex.R" "$@"
