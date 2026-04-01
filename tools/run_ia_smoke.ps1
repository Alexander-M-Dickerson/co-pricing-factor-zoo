param(
  [int] $Draws = 500,
  [switch] $Sequential,
  [int] $CoresPerModel = 4,
  [Nullable[int]] $Cores = $null,
  [ValidateSet("fast", "reference")]
  [string] $SelfPricingEngine = "fast",
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/run_ia_smoke.ps1 [-Draws <int>] [-Sequential] [-CoresPerModel <int>] [-Cores <int>] [-SelfPricingEngine fast|reference] [-Help]"
  Write-Host ""
  Write-Host "Run the implemented IA smoke boundary from the Windows host execution path."
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
$runner = Join-Path $repoRoot "ia\_run_ia_full.R"
$args = @(
  $runner,
  "--ndraws=$Draws",
  "--cores-per-model=$CoresPerModel",
  "--self-pricing-engine=$SelfPricingEngine"
)

if ($Sequential) {
  $args += "--sequential"
}
if ($null -ne $Cores) {
  $args += "--cores=$Cores"
}

Write-Host "Repo root: $repoRoot"
Write-Host "Rscript:   $rscript"
Write-Host "Running IA smoke with draws=$Draws"

Push-Location $repoRoot
try {
  & $rscript @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
