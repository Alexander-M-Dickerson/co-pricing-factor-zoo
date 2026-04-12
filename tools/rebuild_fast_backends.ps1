param(
  [switch] $CheckOnly,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/rebuild_fast_backends.ps1 [-CheckOnly] [-Help]"
  Write-Host ""
  Write-Host "Run the repo doctor in force-rebuild mode to verify or rebuild the fast C++ backends."
  exit 0
}

function Resolve-Rscript {
  $command = Get-Command Rscript.exe -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  if ($env:R_HOME) {
    $candidate = Join-Path $env:R_HOME "bin\Rscript.exe"
    if (Test-Path $candidate) {
      return $candidate
    }
  }

  $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ }
  foreach ($root in $roots) {
    $rRoot = Join-Path $root "R"
    if (-not (Test-Path $rRoot)) {
      continue
    }

    $candidate = Get-ChildItem $rRoot -Directory |
      Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName "bin\Rscript.exe" } |
      Where-Object { Test-Path $_ } |
      Select-Object -First 1

    if ($candidate) {
      return $candidate
    }
  }

  throw "Could not locate Rscript.exe. Install R or add it to PATH."
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$rscript = Resolve-Rscript
Write-Host "Using Rscript: $rscript"
& $rscript --version 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Rscript found but failed to run. Check your R installation."
}

$doctorScript = Join-Path $PSScriptRoot "doctor.R"
$args = @($doctorScript, "--force-rebuild")
if ($CheckOnly) {
  $args += "--check-only"
}

Push-Location $repoRoot
try {
  & $rscript @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
