param(
    [string]$TelemetrySummaryPath = "reports/telemetry/2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json",
    [string]$ForwardGatePath = "reports/forward/2026-03-31-btcusd-session-meanrev-live035-guarded2-forward-gate.json",
    [string]$StatusFileName = "mt5_company_btcusd_20260330_session_meanrev_status.txt",
    [string]$Label = "btcusd_20260330_session_meanrev-live-review",
    [string]$Slug = "btcusd-session-meanrev-live-review",
    [double]$MaxSpreadPips = 2500.0,
    [double]$MaxHeartbeatAgeMinutes = 180.0,
    [switch]$SetNormalOnContinue
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$reviewScriptPath = Join-Path $workspaceRoot "scripts/review-live-state.ps1"
$operatorScriptPath = Join-Path $workspaceRoot "scripts/set-ea-operator-mode.ps1"
$datePrefix = Get-Date -Format "yyyy-MM-dd"
$actionJsonPath = Join-Path $workspaceRoot "reports/live/$datePrefix-$Slug-action.json"
$actionMarkdownPath = Join-Path $workspaceRoot "knowledge/experiments/$datePrefix-$Slug-action.md"
$reviewJsonPath = Join-Path $workspaceRoot "reports/live/$datePrefix-$Slug.json"

& powershell -ExecutionPolicy Bypass -File $reviewScriptPath `
    -TelemetrySummaryPath $TelemetrySummaryPath `
    -ForwardGatePath $ForwardGatePath `
    -StatusFileName $StatusFileName `
    -Label $Label `
    -Slug $Slug `
    -MaxSpreadPips $MaxSpreadPips `
    -MaxHeartbeatAgeMinutes $MaxHeartbeatAgeMinutes

if ($LASTEXITCODE -ne 0) {
    throw "Live review command failed."
}

$reviewJson = Get-Content -Raw $reviewJsonPath | ConvertFrom-Json
$recommendedAction = [string]$reviewJson.recommended_action
$appliedMode = "none"

if ($recommendedAction -eq "pause" -or $recommendedAction -eq "flatten") {
    & powershell -ExecutionPolicy Bypass -File $operatorScriptPath -Mode $recommendedAction | Out-Null
    $appliedMode = $recommendedAction
} elseif ($recommendedAction -eq "continue" -and $SetNormalOnContinue) {
    & powershell -ExecutionPolicy Bypass -File $operatorScriptPath -Mode normal | Out-Null
    $appliedMode = "normal"
}

$actionRecord = [ordered]@{
    label = $Label
    acted_at = (Get-Date).ToString("s")
    review_status = $reviewJson.review_status
    recommended_action = $recommendedAction
    applied_mode = $appliedMode
    review_report = $reviewJsonPath
}

$actionRecord | ConvertTo-Json -Depth 5 | Set-Content -Path $actionJsonPath -Encoding utf8

$markdown = @(
    "# Live Review Action",
    "",
    "- Label: $Label",
    "- Review status: $($reviewJson.review_status)",
    "- Recommended action: $recommendedAction",
    "- Applied mode: $appliedMode",
    "- Review report: $reviewJsonPath",
    ""
) -join [Environment]::NewLine

Set-Content -Path $actionMarkdownPath -Value $markdown -Encoding utf8

Write-Host "Review JSON: $reviewJsonPath"
Write-Host "Action JSON: $actionJsonPath"
Write-Host "Action Note: $actionMarkdownPath"
Write-Host "Applied   : $appliedMode"
