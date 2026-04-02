param(
    [string]$Symbol = "USDJPY",
    [ValidateSet("M5")]
    [string]$Timeframe = "M5",
    [int]$AnalysisDays = 365,
    [int]$OosDays = 90,
    [int]$BarsFallback = 140000,
    [double]$TargetTradesPerDay = 1.0,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\usdjpy_downpersist_long_study.py"

$arguments = @(
    $scriptPath,
    "--symbol", $Symbol,
    "--timeframe", $Timeframe,
    "--analysis-days", $AnalysisDays,
    "--oos-days", $OosDays,
    "--bars-fallback", $BarsFallback,
    "--target-trades-per-day", $TargetTradesPerDay
)

if ($OutputDir) {
    $arguments += @("--output-dir", (Join-Path $repoRoot $OutputDir))
}

python @arguments
