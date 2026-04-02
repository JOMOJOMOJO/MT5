$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$livePreflightScriptPath = Join-Path $workspaceRoot "scripts/live-preflight.ps1"

& powershell -ExecutionPolicy Bypass -File $livePreflightScriptPath `
    -ReleaseNotePath ".company/release/usdjpy_20260402_round_continuation_long-quality12b_guarded.md" `
    -RunJsonPath "reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-165730-877395-usdjpy-20260402-round-continuati.json" `
    -ForwardGatePath "reports/forward/2026-04-02-usdjpy-quality12b-guarded-forward-gate.json" `
    -TelemetrySummaryPath "reports/telemetry/2026-04-02-usdjpy-quality12b-guarded-baseline.json" `
    -PresetPath "reports/presets/usdjpy_20260402_round_continuation_long-quality12b_guarded.set" `
    -OperatorCommandFileName "mt5_company_usdjpy_20260402_round_continuation_long_operator.txt" `
    -StatusFileName "mt5_company_usdjpy_20260402_round_continuation_long_status.txt"

exit $LASTEXITCODE
