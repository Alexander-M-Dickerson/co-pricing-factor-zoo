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

  if [[ -x "/Library/Frameworks/R.framework/Resources/bin/Rscript" ]]; then
    printf '%s\n' "/Library/Frameworks/R.framework/Resources/bin/Rscript"
    return
  fi

  printf 'Could not locate Rscript. Install R or add it to PATH.\n' >&2
  exit 1
}

RSCRIPT="$(resolve_rscript)"
exec "$RSCRIPT" "${SCRIPT_DIR}/doctor.R" "$@"
