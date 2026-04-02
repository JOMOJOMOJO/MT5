param(
    [string]$Symbol = "USDJPY",
    [ValidateSet("M15")]
    [string]$Timeframe = "M15",
    [int]$AnalysisDays = 365,
    [int]$OosDays = 90,
    [int]$BarsFallback = 140000,
    [double]$StopLossPips = 20.0,
    [double]$TargetR = 1.2,
    [int]$MaxHoldBars = 18,
    [double]$TargetTradesPerDay = 1.0,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\usdjpy_breakout_followthrough_long_event_study.py"

$arguments = @(
    $scriptPath,
    "--symbol", $Symbol,
    "--timeframe", $Timeframe,
    "--analysis-days", $AnalysisDays,
    "--oos-days", $OosDays,
    "--bars-fallback", $BarsFallback,
    "--stop-loss-pips", $StopLossPips,
    "--target-r", $TargetR,
    "--max-hold-bars", $MaxHoldBars,
    "--target-trades-per-day", $TargetTradesPerDay
)

if ($OutputDir) {
    $arguments += @("--output-dir", (Join-Path $repoRoot $OutputDir))
}

python @arguments
