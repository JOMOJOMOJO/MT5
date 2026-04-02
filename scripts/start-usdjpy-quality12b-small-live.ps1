param(
    [string]$RunLabel = "small-live",
    [switch]$AllowReview
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$preflightScriptPath = Join-Path $workspaceRoot "scripts/usdjpy-quality12b-small-live-preflight.ps1"
$startScriptPath = Join-Path $workspaceRoot "scripts/start-demo-forward.ps1"

$preflightOutput = & powershell -ExecutionPolicy Bypass -File $preflightScriptPath 2>&1
$preflightExitCode = $LASTEXITCODE
$preflightText = ($preflightOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine

if ($preflightText -match "Live Preflight:\s+([a-zA-Z]+)") {
    $preflightStatus = $matches[1].ToLowerInvariant()
} else {
    throw "Could not determine small-live preflight status.`n$preflightText"
}

if ($preflightExitCode -ne 0) {
    throw "small-live preflight command failed.`n$preflightText"
}

if ($preflightStatus -eq "fail") {
    throw "small-live preflight returned fail.`n$preflightText"
}

if ($preflightStatus -eq "review" -and -not $AllowReview) {
    throw "small-live preflight returned review. Use -AllowReview only when the operator explicitly accepts the remaining review items.`n$preflightText"
}

Write-Host "Small-live preflight status: $preflightStatus"
& powershell -ExecutionPolicy Bypass -File $startScriptPath `
    -BasePresetPath "reports/presets/usdjpy_20260402_round_continuation_long-quality12b_smalllive050.set" `
    -RunLabel $RunLabel `
    -ReleaseNotePath ".company/release/usdjpy_20260402_round_continuation_long-quality12b_smalllive050.md" `
    -Stage "small-live" `
    -OperatorCommandFileName "mt5_company_usdjpy_20260402_round_continuation_long_smalllive050_operator.txt" `
    -StatusFileName "mt5_company_usdjpy_20260402_round_continuation_long_smalllive050_status.txt" `
    -TelemetryFilePrefix "mt5_company_usdjpy_20260402_round_continuation_long_quality12b_smalllive050" `
    -ChartSymbol "USDJPY" `
    -ChartTimeframe "M15"

exit $LASTEXITCODE
