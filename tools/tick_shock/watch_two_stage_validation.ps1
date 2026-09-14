param()
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$analysis=Join-Path $root 'reports\analysis\tick_shock\two_stage_ml_20260913'
$batch=Join-Path $root 'reports\backtest\batches\two_stage_development_20260913'
$state=Join-Path $batch 'validation_status.json'
if(Test-Path $state){throw 'Validation watcher already has state; no implicit restart'}
$scripts=@('two_stage_ml.py','audit_two_stage_development.py','rerun_two_stage_development.py')
$hashes=@{}
foreach($name in $scripts){$hashes[$name]=(Get-FileHash (Join-Path $root "tools\tick_shock\$name")).Hash}
function State([string]$status,[string]$detail){
 @{status=$status;detail=$detail;pid=$PID;updated=(Get-Date).ToString('o');holdout_read=$false;source_hashes=$hashes}|ConvertTo-Json|Set-Content $state -Encoding UTF8
}
function RunPython([string]$name){
 $script=Join-Path $root "tools\tick_shock\$name"
 if((Get-FileHash $script).Hash -ne $hashes[$name]){throw "Source changed: $name"}
 $stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
 $p=Start-Process 'C:\Users\windows\.pyenv\pyenv-win\versions\3.11.9\python.exe' -ArgumentList @('-u',('"'+$script+'"')) -WorkingDirectory $root -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $batch "$name.$stamp.stdout.txt") -RedirectStandardError (Join-Path $batch "$name.$stamp.stderr.txt")
 if($p.ExitCode -ne 0){throw "$name failed: exit $($p.ExitCode)"}
}
try {
 State 'WAITING_PYTHON_FREEZE' 'Development-only validation; no holdout launch'
 while($true){
  $training=Get-Content (Join-Path $batch 'analysis_status.json') -Raw|ConvertFrom-Json
  if($training.status -eq 'STOPPED_ERROR'){throw 'Training stopped; validation not started'}
  if($training.status -eq 'PYTHON_FROZEN_AWAITING_MQL'){break}
  Start-Sleep -Seconds 20
 }
 foreach($name in $scripts){if((Get-FileHash (Join-Path $root "tools\tick_shock\$name")).Hash -ne $hashes[$name]){throw "Source changed while waiting: $name"}}
 State 'INDEPENDENT_ACCOUNTING' 'Frozen candidate only; no reselection'
 RunPython 'audit_two_stage_development.py'
 State 'DETERMINISTIC_REFIT' 'Repeat all 180 original fits without changing design'
 RunPython 'rerun_two_stage_development.py'
 State 'COMPLETE_AWAITING_MQL' 'Independent accounting and full deterministic refit passed; holdout sealed'
}catch{State 'STOPPED_ERROR' $_.Exception.Message;throw}
