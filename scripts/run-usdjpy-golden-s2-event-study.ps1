param(
    [string]$Symbol = "USDJPY",
    [string]$Timeframe = "M5",
    [int]$AnalysisDays = 365,
    [int]$OOSDays = 91
)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$scriptPath = Join-Path $repoRoot "plugins\mt5-company\scripts\usdjpy_golden_s2_event_study.py"

if (-not (Test-Path $scriptPath)) {
    throw "Strategy 2 event study script was not found at '$scriptPath'."
}

python $scriptPath `
    --symbol $Symbol `
    --timeframe $Timeframe `
    --analysis-days $AnalysisDays `
    --oos-days $OOSDays
