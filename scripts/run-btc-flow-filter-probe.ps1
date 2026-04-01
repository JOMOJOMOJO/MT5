param(
    [string]$FeaturesPath = "reports/research/2026-04-01-145500-btcusd-m5-feature-lab-flowfinal/analysis_window_features.csv.gz",
    [string]$SplitDate = "2026-01-02T08:45:00",
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\btc_flow_filter_probe.py"

$arguments = @(
    $scriptPath,
    "--features-path", (Join-Path $repoRoot $FeaturesPath),
    "--split-date", $SplitDate
)

if ($OutputDir) {
    $arguments += @("--output-dir", (Join-Path $repoRoot $OutputDir))
}

python @arguments
