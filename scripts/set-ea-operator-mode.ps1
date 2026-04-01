param(
    [ValidateSet("normal", "pause", "flatten")]
    [string]$Mode = "pause",
    [string]$CommandFileName = "mt5_company_btcusd_20260330_session_meanrev_operator.txt"
)

$commonFilesPath = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files"
$commandPath = Join-Path $commonFilesPath $CommandFileName

New-Item -ItemType Directory -Path $commonFilesPath -Force | Out-Null
Set-Content -Path $commandPath -Value $Mode -Encoding ascii -NoNewline

Write-Host "Operator command file: $commandPath"
Write-Host "Operator mode        : $Mode"
