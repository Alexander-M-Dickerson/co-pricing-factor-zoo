param(
  [string] $Pipeline = "both",
  [int] $Draws,
  [string] $RunTimestamp,
  [switch] $ListRuns,
  [switch] $Latest,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/audit_run.ps1 [-Pipeline main|ia|both] [-Draws N] [-RunTimestamp TS] [-ListRuns] [-Latest] [-Help]"
  Write-Host ""
  Write-Host "Audit a completed replication run and write a manifest."
  exit 0
}

function Resolve-Rscript {
  $command = Get-Command Rscript.exe -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
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
  throw "Could not locate Rscript.exe. Install R or add it to PATH."
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$rscript = Resolve-Rscript
$rArgs = @("tools/audit_run.R", "--pipeline=$Pipeline")

if ($Draws) { $rArgs += "--ndraws=$Draws" }
if ($RunTimestamp) { $rArgs += "--run-timestamp=$RunTimestamp" }
if ($ListRuns) { $rArgs += "--list-runs" }
if ($Latest) { $rArgs += "--latest" }

Push-Location $repoRoot
try {
  & $rscript @rArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
