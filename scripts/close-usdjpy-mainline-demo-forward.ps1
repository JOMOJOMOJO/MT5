param(
    [string]$ManifestPath,
    [string]$RunLabel = "demo-forward"
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$targetScriptPath = Join-Path $workspaceRoot "scripts/close-usdjpy-quality12b-demo-forward.ps1"

& powershell -ExecutionPolicy Bypass -File $targetScriptPath `
    -ManifestPath $ManifestPath `
    -RunLabel $RunLabel

exit $LASTEXITCODE
