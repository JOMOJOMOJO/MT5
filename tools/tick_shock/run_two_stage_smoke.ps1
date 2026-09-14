$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$run=Join-Path $root 'reports\backtest\batches\two_stage_development_smoke_20260914'
$analysis=Join-Path $root 'reports\analysis\tick_shock\two_stage_ml_20260913'
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$common=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\two_stage_smoke_20260914'
if((Test-Path $run) -or (Test-Path $common)){throw 'Smoke evidence already exists; no overwrite'}
if(Get-Process terminal64 -ErrorAction SilentlyContinue){throw 'Terminal active; do not interfere'}
$qa=Get-Content (Join-Path $analysis 'independent_recalculation.json') -Raw|ConvertFrom-Json
$replay=Get-Content (Join-Path $analysis 'deterministic_rerun_summary.json') -Raw|ConvertFrom-Json
if($qa.failures -ne 0 -or $replay.failures -ne 0 -or $replay.tasks -ne 180){throw 'Development QA gate failed'}
$parity=@(Import-Csv (Join-Path $root 'reports\tests\tick_shock\two_stage_model_parity_20260914\results.csv'))
if($parity.Count -ne 15119 -or @($parity|Where-Object status -ne 'PASS').Count){throw 'MQL parity gate failed'}
$export=Get-Content (Join-Path $analysis 'mql_export.json') -Raw|ConvertFrom-Json
if((Get-FileHash (Join-Path $root $export.source_path)).Hash.ToLowerInvariant() -ne $export.mql_sha256){throw 'Model source changed'}
$model=Get-Content (Join-Path $analysis 'frozen_model.json') -Raw|ConvertFrom-Json
if($model.policy.policy.StartsWith('ROLLING')){throw 'Development smoke requires explicit pre-period rolling seed; do not use June seed'}
New-Item -ItemType Directory -Path $run|Out-Null
function State([string]$status,[string]$detail){@{status=$status;detail=$detail;pid=$PID;updated=(Get-Date).ToString('o');holdout_read=$false}|ConvertTo-Json|Set-Content (Join-Path $run 'status.json') -Encoding UTF8}
try {
 $binary=Join-Path $root 'mql\Experts\ExpectedValue_TickShockTwoStageCandidate.ex5'
 $hash=(Get-FileHash $binary).Hash.ToLowerInvariant()
 $preset=Join-Path $run 'candidate.set'
 $changes=@{InpRunId='two_stage_smoke_20260914';InpLogFolder='two_stage_smoke_20260914';InpResearchPeriod='2025-01-02_TO_2025-01-04';InpSourceCommit=((git -C $root rev-parse HEAD).Trim()+'+two-stage-hashed-model');InpEx5Hash=$hash}
 Get-Content (Join-Path $root 'reports\backtest\batches\two_stage_development_20260913\202501\collector.set')|ForEach-Object {
  $key=($_ -split '=',2)[0];if($changes.ContainsKey($key)){"$key=$($changes[$key])"}else{$_}
 }|Set-Content $preset -Encoding UTF8
 Add-Content $preset @('InpTechnicalRiskMoney=10.0','InpTechnicalMagic=260914521') -Encoding UTF8
 @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',
 'Expert=dev\mql\Experts\ExpectedValue_TickShockTwoStageCandidate.ex5','Symbol=EURUSD','Period=M1','Model=4','ExecutionMode=0','Optimization=0','FromDate=2025.01.02','ToDate=2025.01.04','Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=0','ShutdownTerminal=1',
 'Report=MQL5\Experts\dev\reports\backtest\batches\two_stage_development_smoke_20260914\tester_report.html',"PresetSource=$preset",'PresetName=two_stage_smoke_20260914.set')|Set-Content (Join-Path $run 'tester_config.ini') -Encoding UTF8
 @($binary,$preset,(Join-Path $root $export.source_path),$terminal)|ForEach-Object {Get-FileHash $_}|Export-Csv (Join-Path $run 'source_hashes.csv') -NoTypeInformation -Encoding UTF8
 State 'RUNNING_DEVELOPMENT_SMOKE' 'January only; fitted-model wiring test, not out-of-sample evidence'
 & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $run 'tester_config.ini') -TimeoutSeconds 1800 *> (Join-Path $run 'runner.log')
 foreach($name in @('candidate_signals.csv','candidate_actions.csv','candidate_trades.csv','technical_features.csv','fixed_time_outcomes.csv')){Copy-Item (Join-Path $common $name) (Join-Path $run $name)}
 State 'COMPLETE_AWAITING_RECONCILIATION' 'No holdout launched; verify fills, remaining positions and feature wiring'
}catch{State 'STOPPED_ERROR' $_.Exception.Message;throw}
