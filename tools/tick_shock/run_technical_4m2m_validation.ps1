param([int]$MonthTimeoutSeconds=21600)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$batch=Join-Path $root 'reports\backtest\batches\tstech_4m2m_validation_r2_20260911'
$analysis=Join-Path $root 'reports\analysis\tick_shock\technical_4m2m_real'
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$editor='C:\Program Files\XMTrading MT5\MetaEditor64.exe'
$commonRoot=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$dataRoot=Split-Path (Split-Path (Split-Path $root))
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function State([string]$Status,[string]$Detail){
 [ordered]@{status=$Status;detail=$Detail;updated=(Get-Date).ToString('o');pid=$PID} | ConvertTo-Json | Set-Content (Join-Path $batch 'status.json') -Encoding UTF8
}
function Idle {
 while(@(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $terminal}).Count -gt 0){Start-Sleep -Seconds 5}
}
if(Test-Path -LiteralPath $batch){throw "Existing batch; no overwrite/resume: $batch"}
New-Item -ItemType Directory -Path $batch | Out-Null
try {
 $freeze=Get-Content (Join-Path $analysis 'freeze_record.json') -Raw | ConvertFrom-Json
 if((Hash (Join-Path $analysis 'frozen_model.json')) -ne $freeze.frozen_model_sha256){throw 'Model changed'}
 $candidate=Join-Path $root 'mql\Experts\ExpectedValue_MultiCurrency_TickShockTechnical4m2mCandidate.mq5'
 $harness=Join-Path $root 'mql\Experts\tests\ExpectedValue_TickShock_Technical4m2mParityHarness.mq5'
 State 'COMPILING' 'Candidate and training-only parity harness'
 & (Join-Path $root 'scripts\compile.ps1') -MetaEditorPath $editor -Source $candidate -LogPath (Join-Path $batch 'candidate_compile.log')
 & (Join-Path $root 'scripts\compile.ps1') -MetaEditorPath $editor -Source $harness -LogPath (Join-Path $batch 'parity_compile.log')
 $binary=[IO.Path]::ChangeExtension($candidate,'.ex5');$binaryHash=Hash $binary
 $sourceFiles=@($candidate,$harness,$binary,[IO.Path]::ChangeExtension($harness,'.ex5'),$terminal,$editor,(Join-Path $analysis 'frozen_model.json'),$PSCommandPath)
 $sourceFiles+=Get-ChildItem (Join-Path $root 'mql\Include\TickShock4m2mFrozen') -Recurse -File | Select-Object -ExpandProperty FullName
 $sourceFiles | ForEach-Object {Get-FileHash -LiteralPath $_ -Algorithm SHA256} | Export-Csv (Join-Path $batch 'source_hashes.csv') -NoTypeInformation -Encoding UTF8
 $months=@()
 foreach($m in @(5,6)){
  $month='2025{0:00}' -f $m;$rid="tstech_4m2m_validation_r2_${month}_20260911"
  $run=Join-Path $batch $month;$common=Join-Path $commonRoot $rid
  if(Test-Path -LiteralPath $common){throw "Output collision $common"}
  New-Item -ItemType Directory -Path $run | Out-Null
  $preset=Join-Path $run 'candidate.set'
  $changes=@{InpRunId=$rid;InpLogFolder=$rid;InpSchemaVersion='tickshock-event-v1+tail-v1-persistent+technical-discovery-v1+candidate-v1';InpSourceCommit=((git -C $root rev-parse HEAD).Trim()+'+4m2m-source_hashes');InpEx5Hash=$binaryHash}
  Get-Content (Join-Path $root "reports\backtest\batches\tstech_real_202501_202506_20260910\$month\technical_discovery.set") | ForEach-Object {
   $key=($_ -split '=',2)[0];if($changes.ContainsKey($key)){"$key=$($changes[$key])"}else{$_}
  } | Set-Content $preset -Encoding UTF8
  Add-Content $preset @('InpTechnicalRiskMoney=10.0','InpTechnicalMagic=260911421') -Encoding UTF8
  $to='2025.{0:00}.01' -f ($m+1);$from='2025.{0:00}.01' -f $m
  @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',
    'Expert=dev\mql\Experts\ExpectedValue_MultiCurrency_TickShockTechnical4m2mCandidate.ex5',
    "PresetSource=$preset","PresetName=$rid.set",'Symbol=EURUSD','Period=M1','Model=4','ExecutionMode=0','Optimization=0',
    "FromDate=$from","ToDate=$to",'Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0',
    'ReplaceReport=0','ShutdownTerminal=1',"Report=MQL5\Experts\dev\reports\backtest\batches\tstech_4m2m_validation_r2_20260911\$month\tester_report.html") |
    Set-Content (Join-Path $run 'tester_config.ini') -Encoding UTF8
  Copy-Item -LiteralPath $binary -Destination (Join-Path $run 'executed_EA.ex5')
  $months+=[pscustomobject]@{month=$month;run_id=$rid;run=$run;common=$common;status='PLANNED'}
 }
 $months | Export-Csv (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8
 Get-ChildItem $batch -Recurse -File | Where-Object {$_.Extension -in @('.set','.ini','.ex5')} | ForEach-Object {Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256} | Export-Csv (Join-Path $batch 'pre_holdout_artifact_hashes.csv') -NoTypeInformation -Encoding UTF8
 # Test inference on training observations before either holdout run.
 $parity=Join-Path $batch 'parity';New-Item -ItemType Directory -Path $parity | Out-Null
 @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',
 'Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_Technical4m2mParityHarness.ex5','Symbol=EURUSD','Period=M1','Model=1','Optimization=0',
 'FromDate=2025.01.02','ToDate=2025.01.03','Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0',
 'Visual=0','ReplaceReport=0','ShutdownTerminal=1','Report=MQL5\Experts\dev\reports\backtest\batches\tstech_4m2m_validation_r2_20260911\parity\tester_report.html') |
 Set-Content (Join-Path $parity 'tester_config.ini') -Encoding UTF8
 State 'WAITING_FOR_TERMINAL_CLOSE' 'Do not close another terminal forcibly';Idle
 State 'PARITY_TEST' '11230 January-April observations'
 & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $parity 'tester_config.ini') -TimeoutSeconds 180 *> (Join-Path $parity 'runner.log')
 Idle
 $parityResult=Join-Path $commonRoot 'technical_4m2m_model_parity_r2\results.csv'
 $p=@(Import-Csv $parityResult)
 if($p.Count -ne 11230 -or @($p | Where-Object status -ne 'PASS').Count -gt 0){throw 'MQL model parity failed'}
 Copy-Item $parityResult (Join-Path $parity 'results.csv')
 # Actual research -> model -> candidate wiring smoke, on training data only.
 $smoke=Join-Path $batch 'smoke';New-Item -ItemType Directory -Path $smoke | Out-Null
 $smokeId='tstech_4m2m_wiring_r2_20250102';$smokeCommon=Join-Path $commonRoot $smokeId
 if(Test-Path $smokeCommon){throw 'Smoke output collision'}
 Get-Content (Join-Path $months[0].run 'candidate.set') | ForEach-Object {
  if($_ -match '^InpRunId='){"InpRunId=$smokeId"}elseif($_ -match '^InpLogFolder='){"InpLogFolder=$smokeId"}
  elseif($_ -match '^InpResearchPeriod='){'InpResearchPeriod=2025-01-02_TO_2025-01-03'}else{$_}
 } | Set-Content (Join-Path $smoke 'candidate.set') -Encoding UTF8
 Get-Content (Join-Path $months[0].run 'tester_config.ini') | ForEach-Object {
  if($_ -match '^PresetSource='){"PresetSource=$smoke\candidate.set"}elseif($_ -match '^PresetName='){"PresetName=$smokeId.set"}
  elseif($_ -match '^FromDate='){'FromDate=2025.01.02'}elseif($_ -match '^ToDate='){'ToDate=2025.01.03'}
  elseif($_ -match '^Report='){'Report=MQL5\Experts\dev\reports\backtest\batches\tstech_4m2m_validation_r2_20260911\smoke\tester_report.html'}else{$_}
 } | Set-Content (Join-Path $smoke 'tester_config.ini') -Encoding UTF8
 State 'WIRING_SMOKE' 'January 2 training-only production path';Idle
 & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $smoke 'tester_config.ini') -TimeoutSeconds 900 *> (Join-Path $smoke 'runner.log')
 Idle
 $smokeSignals=@(Import-Csv (Join-Path $smokeCommon 'candidate_signals.csv'))
 $smokeFeatures=@(Import-Csv (Join-Path $smokeCommon 'technical_features.csv'))
 if($smokeSignals.Count -eq 0 -or $smokeSignals.Count -ne $smokeFeatures.Count){throw 'Production snapshot callback wiring failed'}
 foreach($name in @('candidate_signals.csv','candidate_actions.csv','candidate_trades.csv','technical_features.csv')){Copy-Item (Join-Path $smokeCommon $name) (Join-Path $smoke $name)}
 [ordered]@{status='PASS';signals=$smokeSignals.Count;features=$smokeFeatures.Count;scope='TRAINING_DAY_PRODUCTION_WIRING'} | ConvertTo-Json | Set-Content (Join-Path $smoke 'wiring_qa.json') -Encoding UTF8
 foreach($row in $months){
  if((Hash $binary) -ne $binaryHash){throw 'EA EX5 changed after freeze'}
  if((Hash (Join-Path $analysis 'frozen_model.json')) -ne $freeze.frozen_model_sha256){throw 'Model changed after freeze'}
  if((Get-PSDrive C).Free -lt 20GB){throw 'Less than 20 GB free'}
  State 'WAITING_FOR_TERMINAL_CLOSE' $row.month;Idle
  $row.status='RUNNING';$months | Export-Csv (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8
  State 'RUNNING_HOLDOUT' $row.month
  & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $row.run 'tester_config.ini') -TimeoutSeconds $MonthTimeoutSeconds *> (Join-Path $row.run 'runner.log')
  Idle
  & python (Join-Path $root 'tools\tick_shock\verify_technical_month_capture.py') --common $row.common --run $row.run --data-root $dataRoot
  if($LASTEXITCODE -ne 0){throw 'Technical data QA failed'}
  foreach($name in @('candidate_signals.csv','candidate_actions.csv','candidate_trades.csv')){Copy-Item (Join-Path $row.common $name) (Join-Path $row.run $name)}
  $row.status='COMPLETED';$months | Export-Csv (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8
 }
 State 'COMPLETED_AWAITING_RECONCILIATION' 'Both locked holdout runs finished; no model changes'
}catch{
 State 'STOPPED_ERROR' $_.Exception.Message
 throw
}
