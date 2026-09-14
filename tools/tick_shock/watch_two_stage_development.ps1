param([int]$Workers=3)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$state=Join-Path $root 'reports\backtest\batches\two_stage_development_20260913\status.json'
$log=Join-Path $root 'reports\backtest\batches\two_stage_development_20260913\analysis_runner.log'
$source=Join-Path $root 'tools\tick_shock\two_stage_ml.py'
$initial=(Get-FileHash $source -Algorithm SHA256).Hash
while($true){
 $status=(Get-Content $state -Raw|ConvertFrom-Json).status
 if($status -eq 'STOPPED_ERROR'){throw 'Collection stopped; model analysis is forbidden until QA passes'}
 if($status -eq 'COMPLETED_DEVELOPMENT_COLLECTION'){break}
 Start-Sleep -Seconds 30
}
if((Get-FileHash $source -Algorithm SHA256).Hash -ne $initial){throw 'Analysis source changed while waiting; review before restarting watcher'}
& 'C:\Users\windows\.pyenv\pyenv-win\versions\3.11.9\python.exe' $source --workers $Workers *> $log
if($LASTEXITCODE -ne 0){throw 'Two-stage development failed; holdout remains sealed'}
# Deliberately stop at Python freeze: generated MQL and parity must precede holdout.
