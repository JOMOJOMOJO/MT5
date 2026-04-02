param(
    [string]$BasePresetPath = "reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set",
    [string]$RunLabel = "demo-forward",
    [string]$ReleaseNotePath = ".company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md",
    [string]$Stage = "demo-forward",
    [string]$OperatorCommandFileName = "mt5_company_btcusd_20260330_session_meanrev_operator.txt",
    [string]$StatusFileName = "mt5_company_btcusd_20260330_session_meanrev_status.txt",
    [string]$TelemetryFilePrefix = "",
    [string]$ChartSymbol = "",
    [string]$ChartTimeframe = ""
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedBasePresetPath = (Resolve-Path (Join-Path $workspaceRoot $BasePresetPath)).Path
$runtimePresetDir = Join-Path $workspaceRoot "reports/presets/runtime"
$manifestDir = Join-Path $workspaceRoot "reports/live"
$manifestNoteDir = Join-Path $workspaceRoot "knowledge/experiments"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$datePrefix = Get-Date -Format "yyyy-MM-dd"
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($resolvedBasePresetPath)
$runtimePresetPath = Join-Path $runtimePresetDir "$baseName-$RunLabel-$timestamp.set"
$telemetrySlug = if ([string]::IsNullOrWhiteSpace($TelemetryFilePrefix)) {
    "mt5_company_" + ($baseName -replace '[^A-Za-z0-9]+', '_').Trim('_').ToLowerInvariant()
} else {
    $TelemetryFilePrefix
}
$telemetryFileName = "$telemetrySlug`_$RunLabel-$timestamp.csv"
$manifestJsonPath = Join-Path $manifestDir "$datePrefix-$baseName-$RunLabel-$timestamp-launch.json"
$manifestMarkdownPath = Join-Path $manifestNoteDir "$datePrefix-$baseName-$RunLabel-$timestamp-launch.md"

New-Item -ItemType Directory -Path $runtimePresetDir -Force | Out-Null
New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null

$updatedLines = foreach ($line in Get-Content -Path $resolvedBasePresetPath) {
    if ($line -match '^\s*InpTelemetryFileName=') {
        "InpTelemetryFileName=$telemetryFileName||$telemetryFileName||0||0||N"
        continue
    }
    $line
}

Set-Content -Path $runtimePresetPath -Value $updatedLines -Encoding ascii

$operatorScriptPath = Join-Path $workspaceRoot "scripts/set-ea-operator-mode.ps1"
& powershell -ExecutionPolicy Bypass -File $operatorScriptPath -Mode normal -CommandFileName $OperatorCommandFileName | Out-Null

$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$telemetryPath = Join-Path $commonFilesPath $telemetryFileName
$releaseNoteResolvedPath = ""
if ($ReleaseNotePath) {
    $releaseNoteResolvedPath = (Resolve-Path (Join-Path $workspaceRoot $ReleaseNotePath)).Path
}

$manifest = [ordered]@{
    stage = $Stage
    run_label = $RunLabel
    started_at = (Get-Date).ToString("s")
    base_preset_path = $resolvedBasePresetPath
    runtime_preset_path = $runtimePresetPath
    telemetry_file_name = $telemetryFileName
    telemetry_path = $telemetryPath
    release_note_path = $releaseNoteResolvedPath
    operator_command_file = (Join-Path $commonFilesPath $OperatorCommandFileName)
    status_file = (Join-Path $commonFilesPath $StatusFileName)
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestJsonPath -Encoding utf8

$manifestMarkdown = @(
    "# Forward Launch Manifest",
    "",
    "- Stage: $Stage",
    "- Run label: $RunLabel",
    "- Started at: $($manifest.started_at)",
    "- Base preset: $resolvedBasePresetPath",
    "- Runtime preset: $runtimePresetPath",
    "- Telemetry file: $telemetryPath",
    "- Release packet: $releaseNoteResolvedPath",
    "- Operator file: $($manifest.operator_command_file)",
    "- Status file: $($manifest.status_file)",
    ""
) -join [Environment]::NewLine

Set-Content -Path $manifestMarkdownPath -Value $manifestMarkdown -Encoding utf8

Write-Host "Runtime preset : $runtimePresetPath"
Write-Host "Telemetry file : $telemetryPath"
Write-Host "Launch manifest: $manifestJsonPath"
Write-Host "Launch note    : $manifestMarkdownPath"
Write-Host "Next steps:"
if (-not [string]::IsNullOrWhiteSpace($ChartSymbol) -and -not [string]::IsNullOrWhiteSpace($ChartTimeframe)) {
    Write-Host "1. Attach the EA to $ChartSymbol $ChartTimeframe and load the runtime preset above."
} else {
    Write-Host "1. Attach the EA to the target chart and load the runtime preset above."
}
Write-Host "2. Leave the EA in operator mode normal."
Write-Host "3. After the forward window, run:"
Write-Host "   powershell -ExecutionPolicy Bypass -File `"$workspaceRoot\\scripts\\close-demo-forward.ps1`" -ManifestPath `"$manifestJsonPath`""
