param(
    [string]$Symbol = "BTCUSD",
    [int]$Samples = 10,
    [int]$SleepMs = 500,
    [int]$Levels = 10,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\market_book_probe.py"

$arguments = @(
    $scriptPath,
    "--symbol", $Symbol,
    "--samples", $Samples,
    "--sleep-ms", $SleepMs,
    "--levels", $Levels
)

if ($OutputDir) {
    $arguments += @("--output-dir", (Join-Path $repoRoot $OutputDir))
}

python @arguments
