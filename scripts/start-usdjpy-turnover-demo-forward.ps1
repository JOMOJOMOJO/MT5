param(
    [string]$RunLabel = "demo-forward"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$targetScriptPath = Join-Path $workspaceRoot "scripts/start-usdjpy-quality12b-stack-parallel-demo-forward.ps1"

& powershell -ExecutionPolicy Bypass -File $targetScriptPath `
    -RunLabel $RunLabel

exit $LASTEXITCODE
