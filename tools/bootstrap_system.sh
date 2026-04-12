#!/usr/bin/env bash
# Install R, build tools, and system libraries required by this repo.
# Designed for unattended use: detects the platform and installs everything
# needed before the R-based bootstrap scripts can run.
#
# Usage: bash tools/bootstrap_system.sh [--check]
#   --check   Report what is missing without installing anything.
set -euo pipefail

CHECK_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --help|-h)
      echo "Usage: bash tools/bootstrap_system.sh [--check]"
      echo "  --check   Report missing system dependencies without installing."
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------
OS="$(uname -s)"
DISTRO=""
DISTRO_CODENAME=""
PKG_MANAGER=""

if [[ "$OS" == "Linux" ]]; then
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO="${ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"
  fi
  if command -v apt-get >/dev/null 2>&1; then
    PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
  elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
  fi
elif [[ "$OS" == "Darwin" ]]; then
  DISTRO="macos"
  if command -v brew >/dev/null 2>&1; then
    PKG_MANAGER="brew"
  fi
fi

echo "Platform:  $OS"
echo "Distro:    ${DISTRO:-unknown}"
echo "Codename:  ${DISTRO_CODENAME:-unknown}"
echo "Pkg mgr:   ${PKG_MANAGER:-none detected}"
echo ""

# ---------------------------------------------------------------------------
# Detect what is missing
# ---------------------------------------------------------------------------
missing=()

command -v Rscript >/dev/null 2>&1 || missing+=("R")
command -v gcc     >/dev/null 2>&1 || missing+=("gcc")
command -v g++     >/dev/null 2>&1 || missing+=("g++")
command -v make    >/dev/null 2>&1 || missing+=("make")
command -v gfortran >/dev/null 2>&1 || missing+=("gfortran")

if [[ ${#missing[@]} -eq 0 ]]; then
  echo "All required system tools are present."
  if command -v Rscript >/dev/null 2>&1; then
    echo "  Rscript: $(command -v Rscript)"
    Rscript --version 2>&1 || true
  fi
  exit 0
fi

echo "Missing: ${missing[*]}"
echo ""

if $CHECK_ONLY; then
  echo "Run without --check to install missing dependencies."
  exit 1
fi

# ---------------------------------------------------------------------------
# Install on Debian/Ubuntu via apt
# ---------------------------------------------------------------------------
install_apt() {
  echo "=== Installing system dependencies via apt ==="

  # Ensure prerequisites for adding repos
  sudo apt-get update -qq
  sudo apt-get install -y -qq software-properties-common dirmngr wget ca-certificates

  # Add CRAN repository for latest R (if R is missing)
  if [[ " ${missing[*]} " == *" R "* ]]; then
    echo "Adding CRAN apt repository for R..."
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
      | sudo tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc >/dev/null

    # Use the codename for the CRAN repo (works for Ubuntu)
    if [[ -n "$DISTRO_CODENAME" ]]; then
      sudo add-apt-repository -y "deb https://cloud.r-project.org/bin/linux/ubuntu ${DISTRO_CODENAME}-cran40/"
    fi
    sudo apt-get update -qq
  fi

  # Install R and build tools in one pass
  sudo apt-get install -y -qq \
    r-base r-base-dev \
    build-essential gfortran \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libharfbuzz-dev libfribidi-dev \
    libfreetype-dev libpng-dev libtiff-dev libjpeg-dev

  echo ""
  echo "=== apt installation complete ==="
}

# ---------------------------------------------------------------------------
# Install on Fedora/RHEL via dnf
# ---------------------------------------------------------------------------
install_dnf() {
  echo "=== Installing system dependencies via dnf ==="
  sudo dnf install -y R gcc gcc-c++ make gcc-gfortran \
    libcurl-devel openssl-devel libxml2-devel \
    fontconfig-devel harfbuzz-devel fribidi-devel \
    freetype-devel libpng-devel libtiff-devel libjpeg-turbo-devel
  echo ""
  echo "=== dnf installation complete ==="
}

# ---------------------------------------------------------------------------
# Install on macOS via Homebrew
# ---------------------------------------------------------------------------
install_brew() {
  echo "=== Installing system dependencies via Homebrew ==="
  brew install r gcc gfortran
  echo ""
  echo "=== Homebrew installation complete ==="
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------
case "$PKG_MANAGER" in
  apt)  install_apt ;;
  dnf)  install_dnf ;;
  yum)
    echo "yum detected. Trying dnf-compatible install..."
    install_dnf
    ;;
  brew) install_brew ;;
  *)
    echo "ERROR: No supported package manager found." >&2
    echo "Install R (>= 4.5) and a C++ build toolchain manually, then re-run /onboard." >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
echo ""
echo "Verifying installation..."
for cmd in Rscript gcc g++ make gfortran; do
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "  $cmd: $(command -v "$cmd")"
  else
    echo "  $cmd: STILL MISSING" >&2
  fi
done

if command -v Rscript >/dev/null 2>&1; then
  echo ""
  Rscript --version 2>&1
  echo ""
  echo "System bootstrap complete. Ready for R-based setup."
else
  echo ""
  echo "ERROR: Rscript is still not available after installation." >&2
  echo "Check the output above for errors." >&2
  exit 1
fi
