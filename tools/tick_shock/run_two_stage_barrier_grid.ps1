param([int]$TimeoutSeconds=86400,[string]$BatchTag='20260914_r3')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
if($BatchTag -notmatch '^\d{8}_r\d+$'){throw 'Invalid batch tag'}
$batch=Join-Path $root "reports\backtest\batches\two_stage_barrier_grid_$BatchTag"
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$python='C:\Users\windows\.pyenv\pyenv-win\versions\3.11.9\python.exe'
$commonRoot=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
if(Test-Path $batch){throw 'Batch exists; no overwrite or implicit resume'}
if(Get-Process terminal64 -ErrorAction SilentlyContinue){throw 'Terminal active; do not interfere'}
$model=Join-Path $root 'mql\Include\TickShockTwoStageModel.mqh'
$export=Get-Content (Join-Path $root 'reports\analysis\tick_shock\two_stage_ml_20260913\mql_export.json') -Raw|ConvertFrom-Json
if((Get-FileHash $model).Hash.ToLowerInvariant() -ne $export.mql_sha256){throw 'Frozen model mismatch'}
foreach($suffix in @('candidate','core','multi')){if((Get-Content (Join-Path $root "reports\compile\tick_shock\two_stage_barrier_$suffix.log") -Raw) -notmatch 'Result: 0 errors, 0 warnings'){throw 'Compile gate failed'}}
New-Item -ItemType Directory -Path $batch|Out-Null
function State([string]$s,[string]$d){@{status=$s;detail=$d;pid=$PID;updated=(Get-Date).ToString('o')}|ConvertTo-Json|Set-Content (Join-Path $batch 'status.json') -Encoding UTF8}
function Idle {
 $w=[Diagnostics.Stopwatch]::StartNew()
 while(Get-Process terminal64 -ErrorAction SilentlyContinue){if($w.Elapsed.TotalSeconds -gt 120){throw 'Terminal did not exit; do not force close'};Start-Sleep -Seconds 2}
}
try {
 $runs=@(@{name='core';tp='0.68';sl='0.55'},@{name='multi';tp='100';sl='100'},@{name='smoke';tp='0.68';sl='0.55'})
 foreach($tp in @('0.40','0.50','0.68')){foreach($sl in @('0.25','0.40','0.55')){$runs+=@{name=('tp'+$tp.Replace('.','')+'_sl'+$sl.Replace('.',''));tp=$tp;sl=$sl}}}
 $candidate=Join-Path $root 'mql\Experts\ExpectedValue_TickShockTwoStageBarrierCandidate.ex5'
 foreach($r in $runs){
  $name=$r.name;$id="ts2bg_${name}_$BatchTag";$run=Join-Path $batch $name
  if(Test-Path (Join-Path $commonRoot $id)){throw "RunId collision: $id"}
  New-Item -ItemType Directory -Path $run|Out-Null
  $from='2025.07.01';$to='2025.09.01';$mode=4;$expert='dev\mql\Experts\ExpectedValue_TickShockTwoStageBarrierCandidate.ex5'
  if($name -in @('core','multi','smoke')){$from='2025.01.02';$to='2025.01.04'}
  if($name -eq 'core'){$mode=1;$expert='dev\mql\Experts\tests\ExpectedValue_TickShockBarrierCoreHarness.ex5'}
  if($name -eq 'multi'){$mode=1;$expert='dev\mql\Experts\tests\ExpectedValue_TickShockBarrierMultiHarness.ex5'}
  $preset=Join-Path $run 'candidate.set'
  $hash=(Get-FileHash $candidate).Hash.ToLowerInvariant()
  $changes=@{InpRunId=$id;InpLogFolder=$id;InpResearchPeriod=($from+'_TO_'+$to);InpSourceCommit=((git -C $root rev-parse HEAD).Trim()+'+barrier-grid-source-hashes');InpEx5Hash=$hash}
  if($name -in @('core','multi')){@("InpFolder=$id")|Set-Content $preset -Encoding ASCII}
  else{Get-Content (Join-Path $root 'reports\backtest\batches\two_stage_development_20260913\202501\collector.set')|ForEach-Object {$k=($_ -split '=',2)[0];if($changes.ContainsKey($k)){"$k=$($changes[$k])"}else{$_}}|Set-Content $preset -Encoding ASCII}
  Add-Content $preset @("InpCandidateTpATR=$($r.tp)","InpCandidateSlATR=$($r.sl)",'InpCandidateRiskMoney=10.0','InpCandidateMagic=260914901','InpCandidateSpacingSeconds=900','InpCandidateHoldSeconds=14400') -Encoding ASCII
  @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',"Expert=$expert",'Symbol=EURUSD','Period=M1',"Model=$mode",'ExecutionMode=0','Optimization=0',"FromDate=$from","ToDate=$to",'Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=0','ShutdownTerminal=1',"Report=MQL5\Experts\dev\reports\backtest\batches\two_stage_barrier_grid_$BatchTag\$name\tester_report.html","PresetSource=$preset","PresetName=$id.set")|Set-Content (Join-Path $run 'tester_config.ini') -Encoding UTF8
 }
 $files=@($PSCommandPath,$terminal,(Join-Path $root 'tools\tick_shock\verify_two_stage_barrier_run.py'),(Join-Path $root 'docs\research\tick_shock\two_stage_barrier_grid_preregistration.md'))
 $files+=Get-ChildItem (Join-Path $root 'mql\Include') -File|Where-Object {$_.Name -match 'TwoStage|BarrierCore'}|Select-Object -ExpandProperty FullName
 $files+=Get-ChildItem (Join-Path $root 'mql\Include\TickShock4m2mFrozen') -Recurse -File|Select-Object -ExpandProperty FullName
 $files+=Get-ChildItem (Join-Path $root 'mql\Experts') -Recurse -File|Where-Object {$_.Name -match 'TwoStageBarrierCandidate|TickShockBarrier(Core|Multi)Harness'}|Select-Object -ExpandProperty FullName
 $files+=Get-ChildItem $batch -Recurse -File|Where-Object Extension -in '.ini','.set'|Select-Object -ExpandProperty FullName
 $files|ForEach-Object {Get-FileHash $_}|Export-Csv (Join-Path $batch 'source_hashes.csv') -NoTypeInformation -Encoding UTF8
 foreach($r in $runs){
  Idle
  foreach($h in (Import-Csv (Join-Path $batch 'source_hashes.csv'))){if((Get-FileHash $h.Path).Hash -ne $h.Hash){throw "Input changed: $($h.Path)"}}
  $name=$r.name;$run=Join-Path $batch $name;$common=Join-Path $commonRoot "ts2bg_${name}_$BatchTag"
  State "RUNNING_$name" 'Fixed grid, no result-dependent changes; Strategy Tester only'
  $timeout=if($name -in @('core','multi')){300}elseif($name -eq 'smoke'){1800}else{$TimeoutSeconds}
  & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $run 'tester_config.ini') -TimeoutSeconds $timeout *> (Join-Path $run 'runner.log')
  Idle
  if($name -in @('core','multi')){
   Copy-Item (Join-Path $common 'results.csv') (Join-Path $run 'results.csv')
   $checks=@(Import-Csv (Join-Path $run 'results.csv'));$expected=if($name -eq 'core'){13}else{7}
   if($checks.Count -ne $expected -or @($checks|Where-Object status -ne 'PASS').Count){throw "Harness gate failed: $name"}
  }
  if($name -ne 'core'){
   foreach($file in @('candidate_signals.csv','candidate_actions.csv','candidate_trades.csv','candidate_summary.csv')){Copy-Item (Join-Path $common $file) (Join-Path $run $file)}
   $process=Start-Process $python -ArgumentList @('-u',('"'+(Join-Path $root 'tools\tick_shock\verify_two_stage_barrier_run.py')+'"'),('"'+$run+'"')) -WorkingDirectory $root -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput (Join-Path $run 'qa.stdout.txt') -RedirectStandardError (Join-Path $run 'qa.stderr.txt')
   if($process.ExitCode -ne 0){throw "Trade integrity failed: $name"}
   if($name -eq 'smoke' -and @(Import-Csv (Join-Path $run 'candidate_trades.csv')).Count -eq 0){throw 'Smoke had no fills; no formal run'}
  }
  State "COMPLETED_$name" 'Evidence saved; no profitability ranking performed'
 }
 State 'COMPLETED_ALL_NINE' 'User-requested development grid complete; awaiting analysis'
}catch{State 'STOPPED_ERROR' $_.Exception.Message;throw}
