$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$targetScriptPath = Join-Path $workspaceRoot "scripts/usdjpy-quality12b-stack-parallel-live-preflight.ps1"

& powershell -ExecutionPolicy Bypass -File $targetScriptPath

exit $LASTEXITCODE
