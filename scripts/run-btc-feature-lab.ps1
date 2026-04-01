param(
    [string]$Symbol = "BTCUSD",
    [ValidateSet("M1", "M5", "M15", "M30", "H1")]
    [string]$Timeframe = "M5",
    [int]$Bars = 140000,
    [int]$AnalysisDays = 365,
    [int]$OosDays = 89,
    [int]$MinSamples = 120,
    [double]$MinTradesPerDay = 3.0,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\btc_feature_lab.py"

$arguments = @(
    $scriptPath,
    "--symbol", $Symbol,
    "--timeframe", $Timeframe,
    "--bars", $Bars,
    "--analysis-days", $AnalysisDays,
    "--oos-days", $OosDays,
    "--min-samples", $MinSamples,
    "--min-trades-per-day", $MinTradesPerDay
)

if ($OutputDir) {
    $arguments += @("--output-dir", (Join-Path $repoRoot $OutputDir))
}

python @arguments
