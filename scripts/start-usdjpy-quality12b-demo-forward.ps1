param(
    [string]$RunLabel = "demo-forward"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$startScriptPath = Join-Path $workspaceRoot "scripts/start-demo-forward.ps1"

& powershell -ExecutionPolicy Bypass -File $startScriptPath `
    -BasePresetPath "reports/presets/usdjpy_20260402_round_continuation_long-quality12b_guarded.set" `
    -RunLabel $RunLabel `
    -ReleaseNotePath ".company/release/usdjpy_20260402_round_continuation_long-quality12b_guarded.md" `
    -Stage "demo-forward" `
    -OperatorCommandFileName "mt5_company_usdjpy_20260402_round_continuation_long_operator.txt" `
    -StatusFileName "mt5_company_usdjpy_20260402_round_continuation_long_status.txt" `
    -TelemetryFilePrefix "mt5_company_usdjpy_20260402_round_continuation_long_quality12b_guarded" `
    -ChartSymbol "USDJPY" `
    -ChartTimeframe "M15"

exit $LASTEXITCODE
