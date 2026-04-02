$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$prepareScriptPath = Join-Path $workspaceRoot "scripts/prepare-small-live.ps1"

& powershell -ExecutionPolicy Bypass -File $prepareScriptPath `
    -PresetPath "reports/presets/usdjpy_20260402_round_continuation_long-quality12b_smalllive050.set" `
    -ReleaseNotePath ".company/release/usdjpy_20260402_round_continuation_long-quality12b_smalllive050.md" `
    -TelemetryFileName "mt5_company_usdjpy_20260402_round_continuation_long_quality12b_smalllive050.csv" `
    -RequiredDemoForwardLabel "the quality12b_guarded demo-forward packet" `
    -PreflightScriptPath "scripts/usdjpy-quality12b-small-live-preflight.ps1" `
    -StartScriptPath "scripts/start-usdjpy-quality12b-small-live.ps1"

exit $LASTEXITCODE
