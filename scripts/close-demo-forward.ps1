param(
    [string]$TelemetryFileName,
    [string]$ManifestPath,
    [string]$BaselineSummaryPath = "reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json",
    [string]$RunLabel = "demo-forward"
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$summaryScriptPath = Join-Path $workspaceRoot "plugins/mt5-company/scripts/mt5_telemetry_summary.py"
$gateScriptPath = Join-Path $workspaceRoot "plugins/mt5-company/scripts/evaluate_forward_gate.py"
$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$manifestResolvedPath = $null
$manifestData = $null

if ($ManifestPath) {
    $manifestResolvedPath = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
        (Resolve-Path $ManifestPath).Path
    } else {
        (Resolve-Path (Join-Path $workspaceRoot $ManifestPath)).Path
    }
    $manifestData = Get-Content -Raw $manifestResolvedPath | ConvertFrom-Json
}

if (-not $TelemetryFileName) {
    if ($manifestData -and $manifestData.telemetry_file_name) {
        $TelemetryFileName = [string]$manifestData.telemetry_file_name
    } else {
        throw "TelemetryFileName is required when ManifestPath is not provided."
    }
}

if ($manifestData -and $RunLabel -eq "demo-forward" -and $manifestData.run_label) {
    $RunLabel = [string]$manifestData.run_label
}

$telemetryPath = if ([System.IO.Path]::IsPathRooted($TelemetryFileName)) {
    $TelemetryFileName
} else {
    Join-Path $commonFilesPath $TelemetryFileName
}

if (-not (Test-Path $telemetryPath)) {
    throw "Telemetry file not found: $telemetryPath"
}

$slugSeed = ([System.IO.Path]::GetFileNameWithoutExtension($telemetryPath) -replace '^mt5_company_', '')
$slug = "$slugSeed-$RunLabel"
$datePrefix = Get-Date -Format "yyyy-MM-dd"
$summaryJsonPath = Join-Path $workspaceRoot "reports/telemetry/$datePrefix-$slug.json"
$summaryMarkdownPath = Join-Path $workspaceRoot "knowledge/experiments/$datePrefix-$slug.md"
$gateJsonPath = Join-Path $workspaceRoot "reports/forward/$datePrefix-$slug-gate.json"
$gateMarkdownPath = Join-Path $workspaceRoot "knowledge/experiments/$datePrefix-$slug-gate.md"
$resolvedBaselinePath = (Resolve-Path (Join-Path $workspaceRoot $BaselineSummaryPath)).Path
$label = "btcusd_20260330_session_meanrev-$slug"

& python $summaryScriptPath `
    --input $telemetryPath `
    --output $summaryJsonPath `
    --markdown-output $summaryMarkdownPath `
    --label $label `
    --run-mode latest

if ($LASTEXITCODE -ne 0) {
    throw "Telemetry summary generation failed."
}

& python $gateScriptPath `
    --baseline $resolvedBaselinePath `
    --candidate $summaryJsonPath `
    --output $gateJsonPath `
    --markdown-output $gateMarkdownPath `
    --label "$label-gate"

if ($LASTEXITCODE -ne 0) {
    throw "Forward gate evaluation failed."
}

$preflightScriptPath = Join-Path $workspaceRoot "scripts/live-preflight.ps1"
& powershell -ExecutionPolicy Bypass -File $preflightScriptPath `
    -TelemetrySummaryPath $summaryJsonPath `
    -ForwardGatePath $gateJsonPath

if ($manifestData) {
    $manifestData | Add-Member -NotePropertyName closed_at -NotePropertyValue (Get-Date).ToString("s") -Force
    $manifestData | Add-Member -NotePropertyName telemetry_summary_path -NotePropertyValue $summaryJsonPath -Force
    $manifestData | Add-Member -NotePropertyName telemetry_summary_note_path -NotePropertyValue $summaryMarkdownPath -Force
    $manifestData | Add-Member -NotePropertyName forward_gate_path -NotePropertyValue $gateJsonPath -Force
    $manifestData | Add-Member -NotePropertyName forward_gate_note_path -NotePropertyValue $gateMarkdownPath -Force
    $manifestData | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestResolvedPath -Encoding utf8
}

Write-Host "Summary JSON : $summaryJsonPath"
Write-Host "Summary Note : $summaryMarkdownPath"
Write-Host "Gate JSON    : $gateJsonPath"
Write-Host "Gate Note    : $gateMarkdownPath"
if ($manifestResolvedPath) {
    Write-Host "Manifest     : $manifestResolvedPath"
}
