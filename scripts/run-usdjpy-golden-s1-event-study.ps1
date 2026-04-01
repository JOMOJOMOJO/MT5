param(
    [string]$Symbol = "USDJPY",
    [ValidateSet("M5", "M15")]
    [string]$Timeframe = "M5",
    [int]$AnalysisDays = 365,
    [int]$OosDays = 91,
    [int]$BarsFallback = 140000,
    [double]$StopLossPips = 10.0,
    [double]$TargetR = 1.2,
    [int]$MaxHoldBars = 96,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\usdjpy_golden_s1_event_study.py"

$arguments = @(
    $scriptPath,
    "--symbol", $Symbol,
    "--timeframe", $Timeframe,
    "--analysis-days", $AnalysisDays,
    "--oos-days", $OosDays,
    "--bars-fallback", $BarsFallback,
    "--stop-loss-pips", $StopLossPips,
    "--target-r", $TargetR,
    "--max-hold-bars", $MaxHoldBars
)

if ($OutputDir) {
    $arguments += @("--output-dir", $OutputDir)
}

python @arguments
