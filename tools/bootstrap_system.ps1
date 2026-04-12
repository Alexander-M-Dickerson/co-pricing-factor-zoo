param(
  [switch] $CheckOnly,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: powershell -ExecutionPolicy Bypass -File tools\bootstrap_system.ps1 [-CheckOnly]"
  Write-Host "  -CheckOnly   Report missing system dependencies without installing."
  exit 0
}

# ---------------------------------------------------------------------------
# Detect what is missing
# ---------------------------------------------------------------------------
function Find-Rscript {
  $cmd = Get-Command Rscript.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  if ($env:R_HOME) {
    $candidate = Join-Path $env:R_HOME "bin\Rscript.exe"
    if (Test-Path $candidate) { return $candidate }
  }

  $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
  foreach ($root in $roots) {
    $rRoot = Join-Path $root "R"
    if (-not (Test-Path $rRoot)) { continue }
    $candidate = Get-ChildItem $rRoot -Directory |
      Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName "bin\Rscript.exe" } |
      Where-Object { Test-Path $_ } |
      Select-Object -First 1
    if ($candidate) { return $candidate }
  }
  return $null
}

function Find-Rtools {
  if (Test-Path "C:\rtools45") { return "C:\rtools45" }
  if (Test-Path "C:\rtools44") { return "C:\rtools44" }
  if (Test-Path "C:\rtools43") { return "C:\rtools43" }
  $cmd = Get-Command gcc.exe -ErrorAction SilentlyContinue
  if ($cmd) { return (Split-Path (Split-Path $cmd.Source)) }
  return $null
}

$rscriptPath = Find-Rscript
$rtoolsPath = Find-Rtools

Write-Host "Platform:  Windows"
Write-Host "Rscript:   $( if ($rscriptPath) { $rscriptPath } else { 'not found' } )"
Write-Host "Rtools:    $( if ($rtoolsPath) { $rtoolsPath } else { 'not found' } )"
Write-Host ""

$missing = @()
if (-not $rscriptPath) { $missing += "R" }
if (-not $rtoolsPath) { $missing += "Rtools" }

if ($missing.Count -eq 0) {
  Write-Host "All required system tools are present."
  & $rscriptPath --version 2>&1 | Write-Host
  exit 0
}

Write-Host "Missing: $($missing -join ', ')"
Write-Host ""

if ($CheckOnly) {
  Write-Host "Run without -CheckOnly to install missing dependencies."
  exit 1
}

# ---------------------------------------------------------------------------
# Install via winget
# ---------------------------------------------------------------------------
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $winget) {
  Write-Host "ERROR: winget is not available on this system." -ForegroundColor Red
  Write-Host "Install the App Installer from the Microsoft Store, or install R manually from:"
  Write-Host "  https://cran.r-project.org/bin/windows/"
  Write-Host "  https://cran.r-project.org/bin/windows/Rtools/"
  exit 1
}

Write-Host "=== Installing system dependencies via winget ==="
Write-Host ""

if ($missing -contains "R") {
  Write-Host "Installing R..."
  winget install --id RProject.R --source winget --accept-package-agreements --accept-source-agreements
  Write-Host ""
}

if ($missing -contains "Rtools") {
  Write-Host "Installing Rtools..."
  winget install --id RProject.Rtools --source winget --accept-package-agreements --accept-source-agreements
  Write-Host ""
}

Write-Host "=== winget installation complete ==="
Write-Host ""

# ---------------------------------------------------------------------------
# Refresh PATH and verify
# ---------------------------------------------------------------------------
# winget installs update the system PATH but the current session may not see it.
# Re-read the machine and user PATH from the registry.
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

Write-Host "Verifying installation..."
$rscriptPath = Find-Rscript
$rtoolsPath = Find-Rtools

Write-Host "  Rscript: $( if ($rscriptPath) { $rscriptPath } else { 'STILL MISSING' } )"
Write-Host "  Rtools:  $( if ($rtoolsPath) { $rtoolsPath } else { 'STILL MISSING' } )"

if ($rscriptPath) {
  Write-Host ""
  & $rscriptPath --version 2>&1 | Write-Host
  Write-Host ""
  Write-Host "System bootstrap complete. Ready for R-based setup."
} else {
  Write-Host ""
  Write-Host "ERROR: R is still not available after installation." -ForegroundColor Red
  Write-Host "PATH was refreshed in this session. Other terminal windows may need to be restarted."
  exit 1
}
