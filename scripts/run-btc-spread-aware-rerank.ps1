param(
    [string]$FeaturesPath = "reports/research/2026-04-01-145500-btcusd-m5-feature-lab-flowfinal/analysis_window_features.csv.gz",
    [string]$SingleRulesPath = "reports/research/2026-04-01-145500-btcusd-m5-feature-lab-flowfinal/single_feature_rules.csv",
    [string]$PairRulesPath = "reports/research/2026-04-01-145500-btcusd-m5-feature-lab-flowfinal/pair_feature_rules.csv",
    [string]$SplitDate = "2026-01-02T08:45:00",
    [double]$CostQuantile = 0.75,
    [double]$MinTestExpectancy = 0.25,
    [double]$MinNetEdge = 0.00,
    [string]$OutputDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\btc_spread_aware_rerank.py"

$arguments = @(
    $scriptPath,
    "--features-path", (Join-Path $repoRoot $FeaturesPath),
    "--single-rules-path", (Join-Path $repoRoot $SingleRulesPath),
    "--pair-rules-path", (Join-Path $repoRoot $PairRulesPath),
    "--split-date", $SplitDate,
    "--cost-quantile", $CostQuantile,
    "--min-test-expectancy", $MinTestExpectancy,
    "--min-net-edge", $MinNetEdge
)

if ($OutputDir) {
    $arguments += @("--output-dir", (Join-Path $repoRoot $OutputDir))
} else {
    $arguments += @("--output-dir", (Join-Path $repoRoot "reports\research\btcusd-spread-aware-rerank"))
}

python @arguments
