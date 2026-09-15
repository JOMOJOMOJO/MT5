param(
 [string]$BatchId='tstech_real_202501_202506_20260910',
 [int]$MonthTimeoutSeconds=21600,
 [switch]$PrepareOnly,
 [switch]$Worker,
 [switch]$ResumeCompleted
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$batch=Join-Path $root "reports\backtest\batches\$BatchId"
$terminal='C:\Program Files\XMTrading MT5\terminal64.exe'
$dataRoot=Split-Path (Split-Path (Split-Path $root))
$commonRoot=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$baseline=Join-Path $root 'reports\backtest\runs\20260909_tstech_discovery_r2_202504'
$binaryHash='79FE8D7864EF82607F141CCAFC1CD527FC0BB127D4ED6FE927044F0A3EBB7CFF'
$sourceCommit='d904b913b9b3d25af928c22e6e70319bdfcc014c'
$expertRelative="dev\reports\backtest\batches\$BatchId\frozen\TechnicalResearch.ex5"
function Save-State([string]$Status,[string]$Month,[string]$Detail){
 [ordered]@{batch=$BatchId;status=$Status;month=$Month;detail=$Detail;updated=(Get-Date).ToString('o');pid=$PID} |
 ConvertTo-Json | Set-Content -LiteralPath (Join-Path $batch 'status.json') -Encoding UTF8
}
function Existing-Terminal {
 @(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $terminal })
}
if(!$Worker){
 if(Test-Path -LiteralPath $batch){throw "Batch exists; refusing overwrite: $batch"}
 if($BatchId -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Unsafe BatchId'}
 if(!(Test-Path -LiteralPath $terminal)){throw 'Bybit terminal executable missing'}
 if((Get-FileHash (Join-Path $baseline 'executed_EA.ex5') -Algorithm SHA256).Hash -ne $binaryHash){throw 'Frozen research EX5 mismatch'}
 $rows=@()
 for($month=1;$month -le 6;$month++){
  $date=Get-Date -Year 2025 -Month $month -Day 1 -Hour 0 -Minute 0 -Second 0
  $yyyymm=$date.ToString('yyyyMM');$runId="${BatchId}_$yyyymm"
  $run=Join-Path $batch $yyyymm;$common=Join-Path $commonRoot $runId
  if(Test-Path -LiteralPath $common){throw "Common output already exists: $common"}
  $rows += [pscustomobject]@{month=$yyyymm;from=$date.ToString('yyyy.MM.dd');to=$date.AddMonths(1).ToString('yyyy.MM.dd');run_id=$runId;run_path=$run;common_path=$common;status='PLANNED'}
 }
 New-Item -ItemType Directory -Path (Join-Path $batch 'frozen') | Out-Null
 Copy-Item (Join-Path $baseline 'executed_EA.ex5') (Join-Path $batch 'frozen\TechnicalResearch.ex5')
 Copy-Item (Join-Path $baseline 'exact_source_bundle.zip') (Join-Path $batch 'frozen\exact_source_bundle.zip')
 Copy-Item (Join-Path $baseline 'compile.log') (Join-Path $batch 'frozen\historical_compile.log')
 Copy-Item (Join-Path $baseline 'source_hashes.txt') (Join-Path $batch 'frozen\historical_source_hashes.txt')
 foreach($row in $rows){
  New-Item -ItemType Directory -Path $row.run_path | Out-Null
  $settings=@{InpRunId=$row.run_id;InpLogFolder=$row.run_id;InpResumeRun='false';InpResearchPeriod=($row.from.Replace('.','-')+'_TO_'+$row.to.Replace('.','-'));InpTesterModel='REAL_TICKS_MODEL_4';InpSourceCommit=$sourceCommit;InpEx5Hash=$binaryHash}
  $preset=Get-Content (Join-Path $baseline 'technical_discovery.set') | ForEach-Object {
   $key=($_ -split '=',2)[0];if($settings.ContainsKey($key)){"$key=$($settings[$key])"}else{$_}
  }
  $preset | Set-Content -LiteralPath (Join-Path $row.run_path 'technical_discovery.set') -Encoding UTF8
  @('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',
   "Expert=$expertRelative","PresetSource=$($row.run_path)\technical_discovery.set","PresetName=$($row.run_id).set",'Symbol=EURUSD','Period=M1',
   'Model=4','ExecutionMode=0','Optimization=0',"FromDate=$($row.from)","ToDate=$($row.to)",
   'Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=0','ShutdownTerminal=1',
   "Report=MQL5\Experts\dev\reports\backtest\batches\$BatchId\$($row.month)\tester_report.html") |
   Set-Content -LiteralPath (Join-Path $row.run_path 'tester_config.ini') -Encoding UTF8
 }
 $rows | Export-Csv -LiteralPath (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8
 @($terminal,(Join-Path $batch 'frozen\TechnicalResearch.ex5'),(Join-Path $batch 'frozen\exact_source_bundle.zip'),$PSCommandPath) |
  ForEach-Object { Get-FileHash -LiteralPath $_ -Algorithm SHA256 } | Export-Csv -LiteralPath (Join-Path $batch 'launch_hashes.csv') -NoTypeInformation -Encoding UTF8
 Save-State 'PREPARED' '' 'Six calendar months; archived compiled research binary; no source changes'
 if($PrepareOnly){Write-Output $batch;return}
 $child=Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-Worker','-BatchId',$BatchId,'-MonthTimeoutSeconds',$MonthTimeoutSeconds) -RedirectStandardOutput (Join-Path $batch 'worker.stdout.log') -RedirectStandardError (Join-Path $batch 'worker.stderr.log')
 Write-Output "Started batch worker PID=$($child.Id) path=$batch"
 return
}
if(!(Test-Path -LiteralPath (Join-Path $batch 'months.csv'))){throw 'Batch must first be prepared'}
$lock=$null
try {
 $lock=[IO.File]::Open((Join-Path $batch 'worker.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 $rows=@(Import-Csv (Join-Path $batch 'months.csv'))
 foreach($row in $rows){
  if($ResumeCompleted -and $row.status -eq 'COMPLETED'){
   $qa=Get-Content -LiteralPath (Join-Path $row.run_path 'collection_qa.json') -Raw | ConvertFrom-Json
   if($qa.status -notin @('PASS','PASS_WITH_LEGACY_WARNING')){throw 'Completed month lacks passing scoped QA'}
   foreach($name in @('technical_features.csv','technical_outcomes.csv')){
    if((Get-FileHash -LiteralPath (Join-Path $row.common_path $name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $qa.input_sha256.$name){throw 'Completed month changed'}
   }
   continue
  }
  if($row.status -ne 'PLANNED'){throw 'No implicit resume/re-execution; use a fresh BatchId'}
  if((Get-FileHash (Join-Path $batch 'frozen\TechnicalResearch.ex5') -Algorithm SHA256).Hash -ne $binaryHash){throw 'EX5 changed'}
  if(Test-Path -LiteralPath $row.common_path){throw "Output collision: $($row.common_path)"}
  Save-State 'WAITING_FOR_TERMINAL_CLOSE' $row.month 'Close the existing XMTrading MT5 terminal normally; no automatic forced shutdown'
  while(@(Existing-Terminal).Count -gt 0){Start-Sleep -Seconds 5}
  if((Get-PSDrive C).Free -lt 20GB){throw 'Less than 20 GB free; batch stopped'}
  $row.status='RUNNING';$rows | Export-Csv (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8
  Save-State 'RUNNING' $row.month $row.common_path
  # Existing helper handles preset routing, tester-only permissions and report import.
  & (Join-Path $root 'scripts\backtest.ps1') -TerminalPath $terminal -ConfigPath (Join-Path $row.run_path 'tester_config.ini') -TimeoutSeconds $MonthTimeoutSeconds *> (Join-Path $row.run_path 'runner.log')
  # Do not permit next month to restart a terminal still shutting down.
  $deadline=(Get-Date).AddMinutes(2)
  while(@(Existing-Terminal).Count -gt 0 -and (Get-Date) -lt $deadline){Start-Sleep -Seconds 2}
  if(@(Existing-Terminal).Count -gt 0){throw 'Terminal did not shut down after report; no force stop'}
  & python (Join-Path $root 'tools\tick_shock\verify_technical_month_capture.py') --common $row.common_path --run $row.run_path --data-root $dataRoot
  if($LASTEXITCODE -ne 0){throw "Monthly data gate failed: $($row.month); see collection_qa.json"}
  $row.status='COMPLETED';$rows | Export-Csv (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8
 }
 Save-State 'COMPLETED' '' 'All six months collected; ML and held-out profit analysis not performed'
}catch{
 if($null -ne $lock -and $null -ne $row -and $row.status -eq 'RUNNING'){$row.status='FAILED';$rows | Export-Csv (Join-Path $batch 'months.csv') -NoTypeInformation -Encoding UTF8}
 Save-State 'STOPPED_ERROR' '' $_.Exception.Message
 throw
}finally{if($null -ne $lock){$lock.Dispose()}}
