param(
  [int] $Draws = 50000,
  [switch] $Quick,
  [switch] $SkipMain,
  [switch] $SkipIA,
  [switch] $SkipPdf,
  [switch] $FailFast,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/run_complete_replication.ps1 [-Draws <int> | -Quick] [-SkipMain] [-SkipIA] [-SkipPdf] [-FailFast] [-Help]"
  Write-Host ""
  Write-Host "Run the complete main paper + Internet Appendix replication."
  Write-Host "No flags runs the exact paper setting at the default 50,000 draws."
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
$runner = Join-Path $repoRoot "_run_complete_replication.R"
$rArgs = @($runner)

if ($Quick) {
  $rArgs += "--quick"
} else {
  $rArgs += "--ndraws=$Draws"
}
if ($SkipMain) { $rArgs += "--skip-main" }
if ($SkipIA) { $rArgs += "--skip-ia" }
if ($SkipPdf) { $rArgs += "--skip-pdf" }
if ($FailFast) { $rArgs += "--fail-fast" }

Write-Host "Repo root: $repoRoot"
Write-Host "Rscript:   $rscript"
Write-Host "Running complete replication with args: $($rArgs[1..($rArgs.Length - 1)] -join ' ')"

Push-Location $repoRoot
try {
  & $rscript @rArgs
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
