param(
    [Parameter(Mandatory = $true)]
    [string]$ManifestPath
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$workspaceRoot = (Resolve-Path (Join-Path $scriptRoot "..")).Path
$targetScriptPath = Join-Path $workspaceRoot "scripts/close-usdjpy-quality12b-stack-parallel-demo-forward.ps1"

& powershell -ExecutionPolicy Bypass -File $targetScriptPath `
    -ManifestPath $ManifestPath

exit $LASTEXITCODE
