param(
    [string]$PresetPath = "reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set",
    [string]$TelemetryFileName = "mt5_company_btcusd_20260330_session_meanrev_bull37_long_h12_live035_guarded2.csv",
    [string]$ReleaseNotePath = ".company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md"
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedPresetPath = (Resolve-Path (Join-Path $workspaceRoot $PresetPath)).Path
$resolvedReleaseNotePath = (Resolve-Path (Join-Path $workspaceRoot $ReleaseNotePath)).Path
$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$telemetryPath = Join-Path $commonFilesPath $TelemetryFileName
$reviewScriptPath = Join-Path $workspaceRoot "scripts/review-forward-telemetry.ps1"

if (-not (Test-Path $resolvedPresetPath)) {
    throw "Preset not found: $resolvedPresetPath"
}

if (-not (Test-Path $resolvedReleaseNotePath)) {
    throw "Release note not found: $resolvedReleaseNotePath"
}

$instructions = @(
    "Demo-Forward Preparation",
    "========================",
    "",
    "Candidate preset : $resolvedPresetPath",
    "Telemetry target : $telemetryPath",
    "Release packet   : $resolvedReleaseNotePath",
    "",
    "MT5 operator steps:",
    "1. Attach btcusd_20260330_session_meanrev to BTCUSD M5.",
    "2. Load the guarded2 preset shown above.",
    "3. Keep telemetry enabled and leave the telemetry filename unchanged.",
    "4. Let the demo run accumulate enough rows, then review it with:",
    "   powershell -ExecutionPolicy Bypass -File `"$reviewScriptPath`"",
    "5. `scripts/start-demo-forward.ps1` now writes a launch manifest; pass that manifest to `close-demo-forward.ps1` when the run ends.",
    "",
    "The release note contains the promotion gate, rollback triggers, and quarterly review date."
)

$instructions -join [Environment]::NewLine
