param(
    [string]$RunLabel = "small-live",
    [switch]$AllowReview
)

$workspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$preflightScriptPath = Join-Path $workspaceRoot "scripts/small-live-preflight.ps1"
$startScriptPath = Join-Path $workspaceRoot "scripts/start-demo-forward.ps1"
$presetPath = "reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set"
$releaseNotePath = ".company/release/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.md"

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
& powershell -ExecutionPolicy Bypass -File $startScriptPath -BasePresetPath $presetPath -RunLabel $RunLabel -ReleaseNotePath $releaseNotePath -Stage "small-live"
