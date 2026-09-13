param([int]$MonthTimeoutSeconds=14400,[switch]$ResumeAfterParity)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$batch=Join-Path $root 'reports\backtest\batches\usdjpy_only_ml_20260912'
$analysis=Join-Path $root 'reports\analysis\tick_shock\usdjpy_only_ml_20260912'
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$editor='C:\Program Files\XMTrading MT5\MetaEditor64.exe'
$commonRoot=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$dataRoot=Split-Path (Split-Path (Split-Path $root))
function Hash([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function State([string]$status,[string]$detail){[ordered]@{status=$status;detail=$detail;updated=(Get-Date).ToString('o');pid=$PID} | ConvertTo-Json | Set-Content (Join-Path $batch 'status.json') -Encoding UTF8}
function Idle {
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(@(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $terminal}).Count){
  if($watch.Elapsed.TotalSeconds -gt 60){throw 'Terminal still running; do not interfere'}
  Start-Sleep -Seconds 2
 }
}
if(Test-Path $batch){if(-not $ResumeAfterParity){throw 'Existing batch; do not overwrite or silently resume'}}
elseif($ResumeAfterParity){throw 'Resume requires existing checkpoint'}
else{New-Item -ItemType Directory -Path $batch | Out-Null}
try {
 $freeze=Get-Content (Join-Path $analysis 'freeze_record.json') -Raw | ConvertFrom-Json
 $model=Join-Path $analysis 'frozen_model.json';$modelHash=Hash $model
 if($modelHash -ne $freeze.files.'frozen_model.json'){throw 'Model changed'}
 $candidate=Join-Path $root 'mql\Experts\ExpectedValue_USDJPY_TickShockMLHoldout.mq5'
 $harness=Join-Path $root 'mql\Experts\tests\ExpectedValue_USDJPY_TickShockMLParityHarness.mq5'
 if($ResumeAfterParity){
  $saved=Get-Content (Join-Path $batch 'status.json') -Raw | ConvertFrom-Json
  if($saved.status -ne 'STOPPED_ERROR' -or $saved.detail -ne 'Terminal already running; do not interfere'){throw 'Unexpected resume checkpoint'}
  $parity=@(Import-Csv (Join-Path $batch 'parity\results.csv'))
  if($parity.Count -ne 3644 -or @($parity | Where-Object status -ne 'PASS').Count){throw 'Parity checkpoint invalid'}
  $binary=[IO.Path]::ChangeExtension($candidate,'.ex5');$binaryHash=Hash $binary
  foreach($r in @(Import-Csv (Join-Path $batch 'source_hashes.csv'))){
   if($r.Path -ne $PSCommandPath -and (Hash $r.Path) -ne $r.Hash.ToLowerInvariant()){throw "Source changed: $($r.Path)"}
  }
  foreach($r in @(Import-Csv (Join-Path $batch 'pre_holdout_config_hashes.csv'))){if((Hash $r.Path) -ne $r.Hash.ToLowerInvariant()){throw 'Config changed'}}
  [ordered]@{reason='Tester report appeared before terminal finished shutdown';resume_at=(Get-Date).ToString('o');runner_sha256=(Hash $PSCommandPath);model_unchanged=$true;binary_unchanged=$true;configs_unchanged=$true} | ConvertTo-Json | Set-Content (Join-Path $batch 'resume_after_parity.json') -Encoding UTF8
 }else{
 State 'COMPILING' 'Immutable model and tester-only wrapper'
 & (Join-Path $root 'scripts\compile.ps1') -MetaEditorPath $editor -Source $candidate -LogPath (Join-Path $batch 'candidate_compile.log')
 & (Join-Path $root 'scripts\compile.ps1') -MetaEditorPath $editor -Source $harness -LogPath (Join-Path $batch 'parity_compile.log')
 $binary=[IO.Path]::ChangeExtension($candidate,'.ex5');$binaryHash=Hash $binary
 $files=@($candidate,$harness,$binary,[IO.Path]::ChangeExtension($harness,'.ex5'),$terminal,$editor,$model,$PSCommandPath,(Join-Path $root 'mql\Include\TickShockUSDJPYOnlyModel.mqh'))
 $files+=Get-ChildItem (Join-Path $root 'mql\Include\TickShock4m2mFrozen') -Recurse -File | Select-Object -ExpandProperty FullName
 $files | ForEach-Object {Get-FileHash -LiteralPath $_ -Algorithm SHA256} | Export-Csv (Join-Path $batch 'source_hashes.csv') -NoTypeInformation -Encoding UTF8
 foreach($period in @('parity','smoke','202505','202506')){
  $run=Join-Path $batch $period;New-Item -ItemType Directory -Path $run | Out-Null
  $rid="usdjpy_only_ml_${period}_20260912";$preset=Join-Path $run 'candidate.set'
  $from='2025.01.02';$to='2025.01.03'
  if($period -eq '202505'){$from='2025.05.01';$to='2025.06.01'}
  if($period -eq '202506'){$from='2025.06.01';$to='2025.07.01'}
  $changes=@{InpRunId=$rid;InpLogFolder=$rid;InpResearchPeriod=($from.Replace('.','-')+'_TO_'+$to.Replace('.','-'));InpSchemaVersion='tickshock-event-v1+tail-v1-persistent+technical-discovery-v1+candidate-v1';InpSourceCommit=((git -C $root rev-parse HEAD).Trim()+'+USDJPY-source-hashes');InpEx5Hash=$binaryHash}
  Get-Content (Join-Path $root 'reports\backtest\batches\tstech_real_202501_202506_20260910\202501\technical_discovery.set') | ForEach-Object {
   $key=($_ -split '=',2)[0];if($changes.ContainsKey($key)){"$key=$($changes[$key])"}else{$_}
  } | Set-Content $preset -Encoding UTF8
  Add-Content $preset @('InpTechnicalRiskMoney=10.0','InpTechnicalMagic=260912421') -Encoding UTF8
  $expert='dev\mql\Experts\ExpectedValue_USDJPY_TickShockMLHoldout.ex5';$modelMode=4
  if($period -eq 'parity'){$expert='dev\mql\Experts\tests\ExpectedValue_USDJPY_TickShockMLParityHarness.ex5';$modelMode=1}
  $config=@('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',"Expert=$expert",'Symbol=EURUSD','Period=M1',"Model=$modelMode",'ExecutionMode=0','Optimization=0',"FromDate=$from","ToDate=$to",'Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=0','ShutdownTerminal=1',"Report=MQL5\Experts\dev\reports\backtest\batches\usdjpy_only_ml_20260912\$period\tester_report.html")
  if($period -ne 'parity'){$config+=@("PresetSource=$preset","PresetName=$rid.set")}
  $config | Set-Content (Join-Path $run 'tester_config.ini') -Encoding UTF8
 }
 Get-ChildItem $batch -Recurse -File | Where-Object {$_.Extension -in @('.ini','.set')} | ForEach-Object {Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256} | Export-Csv (Join-Path $batch 'pre_holdout_config_hashes.csv') -NoTypeInformation -Encoding UTF8
 }
 $periods=if($ResumeAfterParity){@('smoke','202505','202506')}else{@('parity','smoke','202505','202506')}
 foreach($period in $periods){
  Idle
  if((Hash $binary) -ne $binaryHash -or (Hash $model) -ne $modelHash){throw 'Frozen binary/model changed'}
  $run=Join-Path $batch $period;$common=Join-Path $commonRoot "usdjpy_only_ml_${period}_20260912"
  if($period -ne 'parity' -and (Test-Path $common)){throw 'RunId collision'}
  $timeout=if($period -eq 'parity'){180}elseif($period -eq 'smoke'){900}else{$MonthTimeoutSeconds}
  State ('RUNNING_'+$period) 'No model changes permitted; only USDJPY orders'
  & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $run 'tester_config.ini') -TimeoutSeconds $timeout *> (Join-Path $run 'runner.log')
  if($period -eq 'parity'){
   $path=Join-Path $commonRoot 'usdjpy_only_parity_20260912\results.csv';$rows=@(Import-Csv $path)
   if($rows.Count -ne 3644 -or @($rows | Where-Object status -ne 'PASS').Count){throw 'MQL parity failed'}
   Copy-Item $path (Join-Path $run 'results.csv')
  }else{
   & 'C:\Users\windows\.pyenv\pyenv-win\versions\3.11.9\python.exe' (Join-Path $root 'tools\tick_shock\verify_technical_month_capture.py') --common $common --run $run --data-root $dataRoot
   if($LASTEXITCODE -ne 0){throw 'Collection QA failed'}
   foreach($name in @('candidate_signals.csv','candidate_actions.csv','candidate_trades.csv')){Copy-Item (Join-Path $common $name) (Join-Path $run $name)}
   $signals=@(Import-Csv (Join-Path $run 'candidate_signals.csv'))
   $features=@(Import-Csv (Join-Path $run 'technical_features.csv') | Where-Object symbol -eq 'USDJPY')
   if($signals.Count -eq 0 -or $signals.Count -ne $features.Count -or @($signals | Where-Object symbol -ne 'USDJPY').Count){throw 'USDJPY production callback parity failed'}
   $t=@(Import-Csv (Join-Path $run 'candidate_trades.csv'))
   if(@($t | Where-Object symbol -ne 'USDJPY').Count){throw 'Other symbol traded'}
  }
  State ('COMPLETED_'+$period) 'Awaiting independent reconciliation'
 }
 State 'COMPLETED_AWAITING_QA' 'Both months tested with identical frozen model'
}catch{State 'STOPPED_ERROR' $_.Exception.Message;throw}
