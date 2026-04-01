param(
    [string]$PresetPath = "reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set",
    [string]$ReleaseNotePath = ".company/release/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.md",
    [string]$TelemetryFileName = "mt5_company_btcusd_20260330_session_meanrev_bull37_long_h12_smalllive015.csv"
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedPresetPath = (Resolve-Path (Join-Path $workspaceRoot $PresetPath)).Path
$resolvedReleaseNotePath = (Resolve-Path (Join-Path $workspaceRoot $ReleaseNotePath)).Path
$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$telemetryPath = Join-Path $commonFilesPath $TelemetryFileName
$preflightScriptPath = Join-Path $workspaceRoot "scripts/small-live-preflight.ps1"

if (-not (Test-Path $resolvedPresetPath)) {
    throw "Preset not found: $resolvedPresetPath"
}

if (-not (Test-Path $resolvedReleaseNotePath)) {
    throw "Release note not found: $resolvedReleaseNotePath"
}

$instructions = @(
    "Small-Live Preparation",
    "======================",
    "",
    "Staged preset  : $resolvedPresetPath",
    "Telemetry file : $telemetryPath",
    "Release packet : $resolvedReleaseNotePath",
    "",
    "Rules:",
    "1. Do not use this preset until the guarded2 demo-forward gate is accepted.",
    "2. Keep operator control and status heartbeat enabled.",
    "3. Run the staged preflight before attaching the EA:",
    "   powershell -ExecutionPolicy Bypass -File `"$preflightScriptPath`"",
    "4. If the first-capital run starts, launch it through the guarded wrapper:",
    "   powershell -ExecutionPolicy Bypass -File `"$workspaceRoot\\scripts\\start-small-live.ps1`"",
    "5. The launch script writes a manifest; use that manifest when closing the run with `close-demo-forward.ps1`.",
    "",
    "The release packet contains rollback triggers and the small-live risk doctrine."
)

$instructions -join [Environment]::NewLine
