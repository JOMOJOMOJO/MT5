param(
    [string]$TelemetrySummaryPath = "reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json",
    [string]$ForwardGatePath = "reports/forward/2026-03-31-btcusd-session-meanrev-live035-guarded2-forward-gate.json",
    [string]$StatusFileName = "mt5_company_btcusd_20260330_session_meanrev_status.txt",
    [string]$Label = "btcusd_20260330_session_meanrev-live-review",
    [string]$Slug = "btcusd-session-meanrev-live-review",
    [double]$MaxSpreadPips = 2500.0,
    [double]$MaxHeartbeatAgeMinutes = 180.0,
    [switch]$ApplyRecommendedMode
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$telemetryResolvedPath = (Resolve-Path (Join-Path $workspaceRoot $TelemetrySummaryPath)).Path
$gateResolvedPath = (Resolve-Path (Join-Path $workspaceRoot $ForwardGatePath)).Path
$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$statusResolvedPath = if ([System.IO.Path]::IsPathRooted($StatusFileName)) {
    $StatusFileName
} else {
    Join-Path $commonFilesPath $StatusFileName
}

if (-not (Test-Path $statusResolvedPath)) {
    throw "Status file not found: $statusResolvedPath"
}

$datePrefix = Get-Date -Format "yyyy-MM-dd"
$outputPath = Join-Path $workspaceRoot "reports/live/$datePrefix-$Slug.json"
$markdownOutputPath = Join-Path $workspaceRoot "knowledge/experiments/$datePrefix-$Slug.md"
$scriptPath = Join-Path $workspaceRoot "plugins/mt5-company/scripts/evaluate_live_state.py"

$summary = & python $scriptPath `
    --telemetry-summary $telemetryResolvedPath `
    --forward-gate $gateResolvedPath `
    --status-file $statusResolvedPath `
    --output $outputPath `
    --markdown-output $markdownOutputPath `
    --label $Label `
    --max-spread-pips $MaxSpreadPips `
    --max-heartbeat-age-minutes $MaxHeartbeatAgeMinutes

if ($LASTEXITCODE -ne 0) {
    throw "Live state review failed."
}

$reviewJson = Get-Content -Raw $outputPath | ConvertFrom-Json
$recommendedAction = [string]$reviewJson.recommended_action

if ($ApplyRecommendedMode -and ($recommendedAction -eq "pause" -or $recommendedAction -eq "flatten")) {
    $operatorScriptPath = Join-Path $workspaceRoot "scripts/set-ea-operator-mode.ps1"
    & powershell -ExecutionPolicy Bypass -File $operatorScriptPath -Mode $recommendedAction
}

Write-Host "Telemetry : $telemetryResolvedPath"
Write-Host "Gate      : $gateResolvedPath"
Write-Host "Status    : $statusResolvedPath"
Write-Host "Review    : $outputPath"
Write-Host "Note      : $markdownOutputPath"
Write-Host "Result    : $summary"
