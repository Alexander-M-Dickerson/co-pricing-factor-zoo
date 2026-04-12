param(
  [switch] $SkipAssembly,
  [string] $FixtureDir,
  [switch] $Help
)

$ErrorActionPreference = "Stop"

if ($Help) {
  Write-Host "Usage: tools/build_ia_paper.ps1 [-SkipAssembly] [-FixtureDir PATH] [-Help]"
  Write-Host ""
  Write-Host "Assemble the IA LaTeX tree if requested and compile ia/output/paper/latex/ia_main.pdf."
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

function Resolve-CommandPath {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name
  )

  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }

  # Try TinyTeX standard location on Windows
  $tinyTexDir = Join-Path $env:APPDATA "TinyTeX\bin\windows"
  if (Test-Path $tinyTexDir) {
    $candidate = Get-ChildItem $tinyTexDir -Filter $Name -Recurse -ErrorAction SilentlyContinue |
      Select-Object -First 1
    if ($candidate) {
      return $candidate.FullName
    }
  }

  throw "Could not locate $Name. Run 'Rscript tools/bootstrap_latex.R' or install a TeX distribution."
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$pdflatex = Resolve-CommandPath -Name "pdflatex.exe"

if ($FixtureDir) {
  $latexRoot = Join-Path $repoRoot $FixtureDir
  if (-not (Test-Path (Join-Path $latexRoot "ia_main.tex"))) {
    throw "Fixture directory does not contain ia_main.tex: $latexRoot"
  }
} else {
  $rscript = Resolve-Rscript
  $latexRoot = Join-Path $repoRoot "ia\\output\\paper\\latex"
  if (-not $SkipAssembly) {
    $assemblyScript = Join-Path $repoRoot "ia\\_create_ia_latex.R"
    Push-Location $repoRoot
    try {
      & $rscript $assemblyScript
      if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
      }
    } finally {
      Pop-Location
    }
  }
}

Push-Location $latexRoot
try {
  & $pdflatex "-interaction=nonstopmode" "ia_main.tex"
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  & $pdflatex "-interaction=nonstopmode" "ia_main.tex"
  exit $LASTEXITCODE
} finally {
  Pop-Location
}
