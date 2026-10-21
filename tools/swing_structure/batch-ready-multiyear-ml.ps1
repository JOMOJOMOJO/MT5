$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo
$out=Join-Path $repo 'reports/qa/three_wave/ready_multiyear_ml'
$qa=(Get-Content (Join-Path $repo 'reports/qa/usdjpy_hl_fib50/qa_path.txt') -Raw).Trim()
$years=@(2025,2023,2022,2021)
$completed=@()
$failed=@()
function Status($state,$step) {
 @{state=$state;step=$step;years=$years;completed=$completed;failed=$failed;updated=(Get-Date).ToString('o')} |
  ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'status.json') -Encoding UTF8
}
Status 'RUNNING' 'initializing'
foreach($year in $years) {
 $run='annual_'+$year
 try {
  Status 'RUNNING' $run
  & (Join-Path $PSScriptRoot 'run-ready-2024-ml.ps1') -TerminalRoot $qa -ReportGroup 'ready_multiyear_ml' -Run $run -From ($year.ToString()+'.01.01') -To (($year+1).ToString()+'.01.01') -Model 4 -ExpertName 'USDJPY_Ready2024MLCollector'
  & python (Join-Path $PSScriptRoot 'inspect-ready-collection.py') (Join-Path $out $run)
  if($LASTEXITCODE -ne 0){throw 'Post-run collection audit failed'}
  $quality=Get-Content (Join-Path $out ($run+'/collection_quality.json')) -Raw | ConvertFrom-Json
  $completed+=@{year=$year;candidates=$quality.candidate_count;verified_labels=$quality.verified_label_count}
 } catch {
  $failed+=@{year=$year;error=$_.Exception.Message}
  Write-Output ('FAILED '+$run+': '+$_.Exception.Message)
  # Never continue if the isolated terminal is still running.
  $exe=Join-Path $qa 'terminal64.exe'
  if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}) {
   Status 'STOPPED_TERMINAL_STILL_RUNNING' $run
   exit 1
  }
 }
}
$state=if($failed.Count -gt 0){'FINISHED_WITH_ERRORS_AWAITING_REVIEW'}else{'COLLECTION_COMPLETE_AWAITING_ANALYSIS'}
Status $state 'complete'
