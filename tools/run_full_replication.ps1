param(
  [int] $Draws = 50000,
  [switch] $Quick,
  [switch] $Sequential,
  [switch] $SkipEstimation,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/run_full_replication.ps1 [-Draws <int> | -Quick] [-Sequential] [-SkipEstimation] [-Help]"
  Write-Host ""
  Write-Host "Run the full replication pipeline from the Windows host execution path."
  Write-Host "No flags runs the exact paper setting at the default 50,000 draws."
  Write-Host "-Quick is a reduced-draw 5,000 smoke boundary for setup validation."
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
$runner = Join-Path $repoRoot "_run_full_replication.R"
$args = @($runner)

if ($Quick) {
  $args += "--quick"
} else {
  $args += "--ndraws=$Draws"
}
if ($Sequential) {
  $args += "--sequential"
}
if ($SkipEstimation) {
  $args += "--skip-estimation"
}

Write-Host "Repo root: $repoRoot"
Write-Host "Rscript:   $rscript"
Write-Host "Running full replication with args: $($args[1..($args.Length - 1)] -join ' ')"

Push-Location $repoRoot
try {
  & $rscript @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
