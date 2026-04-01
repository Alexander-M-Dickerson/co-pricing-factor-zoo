param(
  [int] $SimSize = 1000,
  [string] $SampleSizes = "400,1600",
  [string] $PriorPcts = "60",
  [ValidateSet("OLS", "GLS")]
  [string] $Type = "OLS",
  [int] $Draws = 5000,
  [ValidateSet("fast_cpp", "reference")]
  [string] $Engine = "fast_cpp",
  [int] $NumCores = 1,
  [switch] $Publish,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/run_figure1_simulation.ps1 [-SimSize <int>] [-SampleSizes <csv>] [-PriorPcts <csv>] [-Type OLS|GLS] [-Draws <int>] [-Engine fast_cpp|reference] [-NumCores <int>] [-Publish] [-Help]"
  Write-Host ""
  Write-Host "Regenerate the Figure 1 simulation outputs from the host execution path."
  exit 0
}

function Resolve-Rscript {
  $command = Get-Command Rscript.exe -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  if ($env:R_HOME) {
    $candidate = Join-Path $env:R_HOME "bin\\Rscript.exe"
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
      ForEach-Object { Join-Path $_.FullName "bin\\Rscript.exe" } |
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
$runner = Join-Path $repoRoot "tools\\run_figure1_simulation.R"
$args = @(
  $runner,
  "--sim-size=$SimSize",
  "--sample-sizes=$SampleSizes",
  "--prior-pcts=$PriorPcts",
  "--type=$Type",
  "--ndraws=$Draws",
  "--engine=$Engine",
  "--num-cores=$NumCores"
)

if ($Publish) {
  $args += "--publish"
}

Push-Location $repoRoot
try {
  & $rscript @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
