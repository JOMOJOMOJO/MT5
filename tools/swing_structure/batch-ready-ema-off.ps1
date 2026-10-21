$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo
$out=Join-Path $repo 'reports/qa/three_wave/m15_normal_ready_ema_off'
$qa=(Get-Content (Join-Path $repo 'reports/qa/usdjpy_hl_fib50/qa_path.txt') -Raw).Trim()
$runner=Join-Path $PSScriptRoot 'run-normal-ready-m15-ema-off.ps1'
function Status([string]$state,[string]$step,[string]$errorText='') {
 @{state=$state;step=$step;updated=(Get-Date).ToString('o');error=$errorText} | ConvertTo-Json | Set-Content (Join-Path $out 'batch_status.json') -Encoding UTF8
}
function Run([string]$name,[string]$from,[string]$to,[string]$expert='USDJPY_ReadyM15EMAOffResearch') {
 Status 'RUNNING' $name
 & $runner -TerminalRoot $qa -Run $name -From $from -To $to -Model 4 -ExpertName $expert
}
try {
 Run 'smoke_native' '2025.01.01' '2025.01.10' 'USDJPY_M1_M5_3WaveIn3Wave_Long'
 Run 'smoke_observer' '2025.01.01' '2025.01.10'
 & python (Join-Path $PSScriptRoot 'verify-ready-ema-off.py') --smoke
 if($LASTEXITCODE -ne 0){throw 'Smoke parity failed; long tests not started'}
 Run 'known_2025h1' '2025.01.01' '2025.07.01'
 Run 'known_2024q3' '2024.07.01' '2024.10.01'
 Run 'repeat_2025h1' '2025.01.01' '2025.07.01'
 & python (Join-Path $PSScriptRoot 'verify-ready-ema-off.py')
 if($LASTEXITCODE -ne 0){throw 'Final audit failed; inspect validation output'}
 Status 'TESTS_COMPLETE_AWAITING_ANALYSIS' 'complete'
} catch {
 Status 'FAILED' 'stopped' $_.Exception.Message
 Write-Error $_
 exit 1
}
