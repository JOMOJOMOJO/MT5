$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo
$out=Join-Path $repo 'reports/qa/three_wave/ready_2024_ml'
$qa=(Get-Content (Join-Path $repo 'reports/qa/usdjpy_hl_fib50/qa_path.txt') -Raw).Trim()
function Status($state,$step,$errorText='') {
 @{state=$state;step=$step;updated=(Get-Date).ToString('o');error=$errorText} | ConvertTo-Json | Set-Content (Join-Path $out 'status.json') -Encoding UTF8
}
try {
 Status 'RUNNING' 'smoke_parity'
 & (Join-Path $PSScriptRoot 'run-ready-2024-ml.ps1') -TerminalRoot $qa -Run 'smoke' -From '2025.01.01' -To '2025.01.10' -Model 4 -ExpertName 'USDJPY_Ready2024MLCollector'
 & python (Join-Path $PSScriptRoot 'verify-ready-2024-collector.py')
 if($LASTEXITCODE -ne 0){throw 'Collector parity failed; annual run cancelled'}
 Status 'RUNNING' 'annual_2024'
 & (Join-Path $PSScriptRoot 'run-ready-2024-ml.ps1') -TerminalRoot $qa -Run 'annual_2024' -From '2024.01.01' -To '2025.01.01' -Model 4 -ExpertName 'USDJPY_Ready2024MLCollector'
 Status 'COLLECTION_COMPLETE_AWAITING_ANALYSIS' 'annual_2024'
} catch {
 Status 'FAILED' 'stopped' $_.Exception.Message
 Write-Error $_
 exit 1
}
