param(
    [string]$PresetPath = "reports/presets/usdjpy_20260402_golden_method-s2-sell-breakout-active.set",
    [string]$EventsPath = "reports/research/2026-04-02-020757-usdjpy-m5-golden-s2-event-study/events.csv",
    [string]$Symbol = "USDJPY",
    [string]$Timeframe = "M5",
    [int]$AnalysisDays = 365,
    [string]$OosStart = "2025-12-31T20:05:00"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $workspaceRoot "plugins/mt5-company/scripts/usdjpy_golden_s2_reconcile.py"

$resolvedPresetPath = (Resolve-Path (Join-Path $workspaceRoot $PresetPath)).Path
$resolvedEventsPath = (Resolve-Path (Join-Path $workspaceRoot $EventsPath)).Path

@(
    "Running USDJPY Golden S2 reconciliation",
    "- Preset : $resolvedPresetPath",
    "- Events : $resolvedEventsPath",
    "- Symbol : $Symbol",
    "- TF     : $Timeframe",
    "- OOS    : $OosStart"
) | ForEach-Object { Write-Host $_ }

python $scriptPath --preset-path $resolvedPresetPath --events-path $resolvedEventsPath --symbol $Symbol --timeframe $Timeframe --analysis-days $AnalysisDays --oos-start $OosStart
