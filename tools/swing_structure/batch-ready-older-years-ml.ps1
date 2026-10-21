$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo
$out=Join-Path $repo 'reports/qa/three_wave/ready_multiyear_ml'
$qa=(Get-Content (Join-Path $repo 'reports/qa/usdjpy_hl_fib50/qa_path.txt') -Raw).Trim()
$years=@(2020,2019,2018,2017,2016)
$completed=@()
$failed=@()
function Status($state,$step) {
 @{state=$state;step=$step;years=$years;completed=$completed;failed=$failed;updated=(Get-Date).ToString('o')} |
  ConvertTo-Json -Depth 6 | Set-Content (Join-Path $out 'extension_status.json') -Encoding UTF8
}
Status 'QUEUED_WAITING_FOR_CURRENT_BATCH' 'waiting'
try {
 $prior=Get-Process -Id 26472 -ErrorAction SilentlyContinue
 if($prior -and $prior.ProcessName -eq 'powershell') { $prior.WaitForExit() }
 $previous=Get-Content (Join-Path $out 'status.json') -Raw | ConvertFrom-Json
 if($previous.step -ne 'complete') {throw 'Prior batch did not reach its final state'}
 $exe=Join-Path $qa 'terminal64.exe'
 if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}) {throw 'Isolated terminal is still occupied'}
} catch {
 $failed+=@{year=0;error=$_.Exception.Message}
 Status 'STOPPED_DEPENDENCY_CHECK' 'waiting'
 exit 1
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
