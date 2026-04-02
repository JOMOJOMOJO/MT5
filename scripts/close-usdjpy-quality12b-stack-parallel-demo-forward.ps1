param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$closeScriptPath = Join-Path $workspaceRoot "scripts/close-demo-forward.ps1"

& powershell -ExecutionPolicy Bypass -File $closeScriptPath `
    -ManifestPath $ManifestPath `
    -BaselineSummaryPath "reports/telemetry/2026-04-02-usdjpy-quality12b-stack-parallel-guarded-baseline.json" `
    -ForwardLabel "usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded" `
    -ReleaseNotePath ".company/release/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.md" `
    -RunJsonPath "reports/backtest/runs/usdjpy-20260402-round-continuation-long/usdjpy/m15/2026-04-02-192837-849112-usdjpy-20260402-round-continuati.json" `
    -PresetPath "reports/presets/usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded.set" `
    -OperatorCommandFileName "mt5_company_usdjpy_20260402_round_continuation_long_stack_parallel_operator.txt" `
    -StatusFileName "mt5_company_usdjpy_20260402_round_continuation_long_stack_parallel_status.txt"

exit $LASTEXITCODE
