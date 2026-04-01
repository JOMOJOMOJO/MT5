$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$livePreflightScriptPath = Join-Path $workspaceRoot "scripts/live-preflight.ps1"

& powershell -ExecutionPolicy Bypass -File $livePreflightScriptPath `
    -ReleaseNotePath ".company/release/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.md" `
    -RunJsonPath "reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-132810-116558-btcusd-20260330-session-meanrev-.json" `
    -PresetPath "reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set"

exit $LASTEXITCODE
