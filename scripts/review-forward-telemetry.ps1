param(
    [string]$TelemetryFileName = "mt5_company_btcusd_20260330_session_meanrev_bull37_long_h12_live035_guarded2.csv",
    [string]$Label = "btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2-demo-forward",
    [string]$Slug = "btcusd-session-meanrev-live035-guarded2-demo-forward",
    [ValidateSet("all", "latest", "first")]
    [string]$RunMode = "latest",
    [Nullable[int]]$RunIndex = $null
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"

if ([System.IO.Path]::IsPathRooted($TelemetryFileName)) {
    $inputPath = $TelemetryFileName
} else {
    $inputPath = Join-Path $commonFilesPath $TelemetryFileName
}

if (-not (Test-Path $inputPath)) {
    throw "Telemetry CSV not found: $inputPath"
}

$datePrefix = Get-Date -Format "yyyy-MM-dd"
$jsonOutputPath = Join-Path $workspaceRoot "reports/telemetry/$datePrefix-$Slug.json"
$markdownOutputPath = Join-Path $workspaceRoot "knowledge/experiments/$datePrefix-$Slug.md"
$summaryScriptPath = Join-Path $workspaceRoot "plugins/mt5-company/scripts/mt5_telemetry_summary.py"

$arguments = @(
    $summaryScriptPath,
    "--input", $inputPath,
    "--output", $jsonOutputPath,
    "--markdown-output", $markdownOutputPath,
    "--label", $Label,
    "--run-mode", $RunMode
)

if ($RunIndex -ne $null) {
    $arguments += @("--run-index", $RunIndex.ToString())
}

$summary = & python @arguments
if ($LASTEXITCODE -ne 0) {
    throw "Telemetry summary generation failed."
}

Write-Host "Telemetry input: $inputPath"
Write-Host "JSON summary : $jsonOutputPath"
Write-Host "Markdown note: $markdownOutputPath"
Write-Host "Summary      : $summary"
