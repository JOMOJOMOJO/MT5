$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$runRoot = $PSScriptRoot
$manifest = Get-Content (Join-Path $runRoot 'ini_manifest.txt')
$common = Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$terminal = 'C:\Program Files\XMTrading MT5 - 2\terminal64.exe'
$magics = @('2026054101', '2026054102', '2026054103', '2026054104')

foreach ($magic in $magics) {
    Get-ChildItem $common -Filter "*$magic*" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

foreach ($ini in $manifest) {
    Write-Host "RUN $ini"
    powershell -ExecutionPolicy Bypass -File (Join-Path $repo 'scripts/backtest.ps1') `
        -TerminalPath $terminal `
        -ConfigPath $ini `
        -TimeoutSeconds 900 `
        -RestartExisting
}

$rawDir = Join-Path $runRoot 'raw'
foreach ($magic in $magics) {
    Get-ChildItem $common -Filter "*$magic*" -ErrorAction SilentlyContinue |
        Copy-Item -Destination $rawDir -Force
}
