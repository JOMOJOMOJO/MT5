$scripts  = "$PSScriptRoot\backtest.ps1"
$terminal = "C:\Program Files\XMTrading MT5\terminal64.exe"
$base     = "$PSScriptRoot\..\reports\qa\three_wave"
$variants = @("cc_va\test.ini","cc_vb\test.ini","cc_vc\test.ini")

foreach ($cfg in $variants) {
    $path = Join-Path $base $cfg
    Write-Host "=== Starting: $cfg ==="
    & powershell.exe -ExecutionPolicy Bypass -File $scripts -TerminalPath $terminal -ConfigPath $path -TimeoutSeconds 900 -RestartExisting
    Write-Host "=== Done: $cfg (exit $LASTEXITCODE) ==="
}
Write-Host "All variants complete."
