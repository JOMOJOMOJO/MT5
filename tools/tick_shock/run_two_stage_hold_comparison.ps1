param([int]$TimeoutSeconds=86400,[switch]$ResumeCompiled)
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$batch=Join-Path $root 'reports\backtest\batches\two_stage_hold_comparison_20260914'
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$analysis=Join-Path $root 'reports\analysis\tick_shock\two_stage_ml_20260913'
if(Test-Path $batch){
 if(-not $ResumeCompiled){throw 'Existing batch; no overwrite or implicit resume'}
 $old=Get-Content (Join-Path $batch 'status.json') -Raw|ConvertFrom-Json
 if($old.status -ne 'STOPPED_ERROR' -or (Test-Path (Join-Path $batch 'hold_300'))){throw 'Resume requires compile-only failure, no tester run'}
 if((Get-Content (Join-Path $batch 'compile.log') -Raw) -notmatch 'Result: 0 errors, 0 warnings'){throw 'Compile not successful'}
 Copy-Item (Join-Path $batch 'status.json') (Join-Path $batch 'compile_sync_failure.json')
}elseif($ResumeCompiled){throw 'Missing compiled checkpoint'}
if(Get-Process terminal64 -ErrorAction SilentlyContinue){throw 'Terminal already running; do not interfere'}
$export=Get-Content (Join-Path $analysis 'mql_export.json') -Raw|ConvertFrom-Json
if((Get-FileHash (Join-Path $root $export.source_path)).Hash.ToLowerInvariant() -ne $export.mql_sha256){throw 'Frozen model changed'}
if(-not (Test-Path $batch)){New-Item -ItemType Directory -Path $batch|Out-Null}
function State([string]$s,[string]$d){@{status=$s;detail=$d;pid=$PID;updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $batch 'status.json') -Encoding UTF8}
try {
 State 'COMPILING' 'Same frozen model; only hold input differs'
 $source=Join-Path $root 'mql\Experts\ExpectedValue_TickShockTwoStageCandidate.mq5'
 if(-not $ResumeCompiled){& (Join-Path $root 'scripts\compile.ps1') -MetaEditorPath 'C:\Program Files\XMTrading MT5\MetaEditor64.exe' -Source $source -LogPath (Join-Path $batch 'compile.log')}
 $binary=[IO.Path]::ChangeExtension($source,'.ex5');$binaryHash=(Get-FileHash $binary).Hash
 foreach($seconds in @(300,14400)){
  $run=Join-Path $batch "hold_$seconds";New-Item -ItemType Directory -Path $run|Out-Null
  $id="two_stage_hold_${seconds}_20260914";$preset=Join-Path $run 'candidate.set'
  if(Test-Path (Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\$id")){throw 'RunId collision'}
  $changes=@{InpRunId=$id;InpLogFolder=$id;InpResearchPeriod='2025-07-01_TO_2025-09-01';InpSourceCommit=((git -C $root rev-parse HEAD).Trim()+'+hold-comparison-source-hashes');InpEx5Hash=$binaryHash.ToLowerInvariant()}
  Get-Content (Join-Path $root 'reports\backtest\batches\two_stage_development_20260913\202501\collector.set')|ForEach-Object {
   $key=($_ -split '=',2)[0];if($changes.ContainsKey($key)){"$key=$($changes[$key])"}else{$_}
  }|Set-Content $preset -Encoding UTF8
  Add-Content $preset @('InpTechnicalRiskMoney=10.0','InpTechnicalMagic=260914521',"InpTechnicalHoldSeconds=$seconds") -Encoding UTF8
  @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',
  'Expert=dev\mql\Experts\ExpectedValue_TickShockTwoStageCandidate.ex5','Symbol=EURUSD','Period=M1','Model=4','ExecutionMode=0','Optimization=0','FromDate=2025.07.01','ToDate=2025.09.01','Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=0','ShutdownTerminal=1',
  "Report=MQL5\Experts\dev\reports\backtest\batches\two_stage_hold_comparison_20260914\hold_$seconds\tester_report.html","PresetSource=$preset","PresetName=$id.set")|Set-Content (Join-Path $run 'tester_config.ini') -Encoding UTF8
 }
 $files=@($source,$binary,$terminal,$PSCommandPath,(Join-Path $analysis 'frozen_model.json'))
 $files+=Get-ChildItem (Join-Path $root 'mql\Include') -File -Filter '*TwoStage*.mqh'|Select-Object -ExpandProperty FullName
 $files+=Get-ChildItem (Join-Path $root 'mql\Include\TickShock4m2mFrozen') -Recurse -File|Select-Object -ExpandProperty FullName
 $files+=Get-ChildItem $batch -Recurse -File|Where-Object Extension -in '.set','.ini'|Select-Object -ExpandProperty FullName
 $files|ForEach-Object {Get-FileHash $_}|Export-Csv (Join-Path $batch 'source_hashes.csv') -NoTypeInformation -Encoding UTF8
 foreach($seconds in @(300,14400)){
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while(Get-Process terminal64 -ErrorAction SilentlyContinue){if($watch.Elapsed.TotalSeconds -gt 120){throw 'Terminal did not shut down; do not force close'};Start-Sleep -Seconds 2}
  foreach($row in (Import-Csv (Join-Path $batch 'source_hashes.csv'))){if((Get-FileHash $row.Path).Hash -ne $row.Hash){throw "Frozen input changed: $($row.Path)"}}
  $run=Join-Path $batch "hold_$seconds"
  State "RUNNING_HOLD_$seconds" '2025-07-01 through 2025-08-31; no analysis or model changes'
  & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $run 'tester_config.ini') -TimeoutSeconds $TimeoutSeconds *> (Join-Path $run 'runner.log')
  $common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\two_stage_hold_${seconds}_20260914"
  foreach($name in @('candidate_signals.csv','candidate_actions.csv','candidate_trades.csv','fixed_time_outcomes.csv','technical_features.csv')){Copy-Item (Join-Path $common $name) (Join-Path $run $name)}
  State "COMPLETED_HOLD_$seconds" 'Results saved; no profitability analysis performed'
 }
 State 'COMPLETED_BOTH' 'User will request result review; 4h uses original 5-minute-trained model'
}catch{State 'STOPPED_ERROR' $_.Exception.Message;throw}
