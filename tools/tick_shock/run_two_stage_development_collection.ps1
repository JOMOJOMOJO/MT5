param([int]$TimeoutSeconds=14400)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$batch=Join-Path $root 'reports\backtest\batches\two_stage_development_20260913'
$old=Join-Path $root 'reports\backtest\batches\tstech_real_202501_202506_20260910'
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$python='C:\Users\windows\.pyenv\pyenv-win\versions\3.11.9\python.exe'
$commonRoot=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$dataRoot=Split-Path (Split-Path (Split-Path $root))
if(Test-Path $batch){throw 'Existing batch; no implicit resume or overwrite'}
New-Item -ItemType Directory $batch | Out-Null
function State([string]$state,[string]$detail){@{status=$state;detail=$detail;updated=(Get-Date).ToString('o');pid=$PID}|ConvertTo-Json|Set-Content (Join-Path $batch 'status.json') -Encoding UTF8}
try {
 $binary=Join-Path $root 'mql\Experts\ExpectedValue_TickShockTwoStageCollector.ex5'
 $hash=(Get-FileHash $binary -Algorithm SHA256).Hash
 $sources=@($binary,$PSCommandPath,(Join-Path $root 'mql\Experts\ExpectedValue_TickShockTwoStageCollector.mq5'),(Join-Path $root 'mql\Include\TickShockTwoStageTimeLabels.mqh'),$terminal)
 $sources+=Get-ChildItem (Join-Path $root 'mql\Include\TickShock4m2mFrozen') -Recurse -File | Select-Object -ExpandProperty FullName
 $sources|ForEach-Object {Get-FileHash $_ -Algorithm SHA256}|Export-Csv (Join-Path $batch 'source_hashes.csv') -NoTypeInformation -Encoding UTF8
 foreach($month in 1..6){
  $wait=[Diagnostics.Stopwatch]::StartNew()
  while(@(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object Path -eq $terminal).Count){
   if($wait.Elapsed.TotalSeconds -gt 60){throw 'Terminal busy; do not interfere'}
   Start-Sleep -Seconds 2
  }
  if((Get-FileHash $binary -Algorithm SHA256).Hash -ne $hash){throw 'Binary changed'}
  $m='2025{0:D2}' -f $month;$rid="two_stage_dev_${m}_20260913"
  $run=Join-Path $batch $m;$common=Join-Path $commonRoot $rid
  if(Test-Path $common){throw 'RunId collision'}
  New-Item -ItemType Directory $run|Out-Null
  $from=[datetime]::new(2025,$month,1);$to=$from.AddMonths(1)
  $preset=Join-Path $run 'collector.set'
  $changes=@{InpRunId=$rid;InpLogFolder=$rid;InpResearchPeriod=($from.ToString('yyyy-MM-dd')+'_TO_'+$to.ToString('yyyy-MM-dd'));InpSourceCommit=(git -C $root rev-parse HEAD).Trim();InpEx5Hash=$hash}
  Get-Content (Join-Path $old "$m\technical_discovery.set")|ForEach-Object {$key=($_ -split '=',2)[0];if($changes.ContainsKey($key)){"$key=$($changes[$key])"}else{$_}}|Set-Content $preset -Encoding UTF8
  @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]','Expert=dev\mql\Experts\ExpectedValue_TickShockTwoStageCollector.ex5','Symbol=EURUSD','Period=M1','Model=4','ExecutionMode=0','Optimization=0',('FromDate='+$from.ToString('yyyy.MM.dd')),('ToDate='+$to.ToString('yyyy.MM.dd')),'Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=0','ShutdownTerminal=1',"Report=MQL5\Experts\dev\reports\backtest\batches\two_stage_development_20260913\$m\tester_report.html","PresetSource=$preset","PresetName=$rid.set")|Set-Content (Join-Path $run 'tester_config.ini') -Encoding UTF8
  State "RUNNING_$m" 'Development only; no orders; no July/August access'
  & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $run 'tester_config.ini') -TimeoutSeconds $TimeoutSeconds *> (Join-Path $run 'runner.log')
  & $python (Join-Path $root 'tools\tick_shock\verify_technical_month_capture.py') --common $common --run $run --data-root $dataRoot
  if($LASTEXITCODE -ne 0){throw 'Original collection gate failed'}
  Copy-Item (Join-Path $common 'fixed_time_outcomes.csv') (Join-Path $run 'fixed_time_outcomes.csv')
  & $python (Join-Path $root 'tools\tick_shock\verify_two_stage_collection.py') --run $run --baseline (Join-Path $old $m)
  if($LASTEXITCODE -ne 0){throw 'Fixed-time label/parity gate failed'}
  State "COMPLETED_$m" 'Independent collection and original feature parity passed'
 }
 State 'COMPLETED_DEVELOPMENT_COLLECTION' 'Awaiting two-stage model analysis; holdout still sealed'
}catch{State 'STOPPED_ERROR' $_.Exception.Message;throw}
