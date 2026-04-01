param(
  [int] $Draws = 500,
  [ValidateSet("both", "forward", "backward")]
  [string] $Direction = "both",
  [int] $NumCores = 4,
  [ValidateSet("fast", "reference")]
  [string] $SelfPricingEngine = "fast",
  [ValidateSet("auto", "PSOCK", "FORK", "sequential")]
  [string] $ParallelType = "auto",
  [int] $ClusterTimeout = 30,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/run_conditional_smoke.ps1 [-Draws <int>] [-Direction both|forward|backward] [-NumCores <int>] [-SelfPricingEngine fast|reference] [-ParallelType auto|PSOCK|FORK|sequential] [-ClusterTimeout <int>] [-Help]"
  Write-Host ""
  Write-Host "Run the conditional replication smoke boundary from the Windows host execution path."
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
$runner = Join-Path $repoRoot "_run_all_conditional.R"
$args = @(
  $runner,
  "--direction=$Direction",
  "--ndraws=$Draws",
  "--num-cores=$NumCores",
  "--self-pricing-engine=$SelfPricingEngine",
  "--parallel-type=$ParallelType",
  "--cluster-timeout=$ClusterTimeout"
)

Write-Host "Repo root: $repoRoot"
Write-Host "Rscript:   $rscript"
Write-Host "Running conditional smoke: direction=$Direction draws=$Draws cores=$NumCores"

Push-Location $repoRoot
try {
  & $rscript @args
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
