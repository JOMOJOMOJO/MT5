$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo
$out=Join-Path $repo 'reports/qa/three_wave/ready_alternate_broker_ml'
$qa=(Get-Content (Join-Path $out 'terminal_path.txt') -Raw).Trim()
function Status($state,$errorText='') {
 @{state=$state;broker='VantageTradingLtd-Live';run='vantage_2023';updated=(Get-Date).ToString('o');error=$errorText} |
  ConvertTo-Json | Set-Content (Join-Path $out 'status.json') -Encoding UTF8
}
try {
 Status 'RUNNING'
 & (Join-Path $PSScriptRoot 'run-ready-2024-ml.ps1') -TerminalRoot $qa -ReportGroup 'ready_alternate_broker_ml' -Run 'vantage_2023' -From '2023.01.01' -To '2024.01.01' -Model 4 -ExpertName 'USDJPY_Ready2024MLCollector'
 & python (Join-Path $PSScriptRoot 'inspect-ready-collection.py') (Join-Path $out 'vantage_2023')
 if($LASTEXITCODE -ne 0){throw 'Post-run audit failed; inspect saved logs and CSVs'}
 Status 'COLLECTION_COMPLETE_AWAITING_REVIEW'
} catch {
 Status 'FAILED' $_.Exception.Message
 Write-Output $_.Exception.Message
 exit 1
}
