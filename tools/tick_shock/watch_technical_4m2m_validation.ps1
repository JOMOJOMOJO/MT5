param([int]$PollSeconds=30)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$batch=Join-Path $root 'reports\backtest\batches\tstech_4m2m_validation_r2_20260911'
$samples=Join-Path $batch 'runtime_samples.csv'
if(Test-Path $samples){throw 'Watcher output already exists'}
while($true){
 $state=Get-Content (Join-Path $batch 'status.json') -Raw | ConvertFrom-Json
 $agents=@(Get-Process metatester64 -ErrorAction SilentlyContinue)
 [pscustomobject]@{wall_time=(Get-Date).ToString('o');status=$state.status;month=$state.detail;
   metatester_processes=$agents.Count;working_set_bytes=($agents | Measure-Object WorkingSet64 -Sum).Sum;
   cpu_seconds=($agents | Measure-Object CPU -Sum).Sum} | Export-Csv $samples -NoTypeInformation -Encoding UTF8 -Append
 if($state.status -eq 'STOPPED_ERROR'){break}
 if($state.status -eq 'COMPLETED_AWAITING_RECONCILIATION'){
  foreach($month in @(202505,202506)){
   & python (Join-Path $root 'tools\tick_shock\evaluate_technical_4m2m_holdout.py') --month $month *> (Join-Path $batch "$month\reconciliation_command.log")
   if($LASTEXITCODE -ne 0){throw "Reconciliation failed $month"}
  }
  & python (Join-Path $root 'tools\tick_shock\finalize_technical_4m2m_validation.py') *> (Join-Path $batch 'finalization.log')
  if($LASTEXITCODE -ne 0){throw 'Finalization failed'}
  break
 }
 Start-Sleep -Seconds $PollSeconds
}
