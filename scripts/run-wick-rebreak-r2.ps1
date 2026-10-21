# Isolated portability QA runner, adapted from the audited cost-channel runner.
param(
 [string]$PackagePath='reports\qa\wick_rebreak_20261013_r2',
 [string]$SourceDataRoot="$env:LOCALAPPDATA\CodexMT5Channel\20261008_171544_bbf5d27f",
 [ValidateRange(60,86400)][int]$TimeoutSecondsPerRun=7200,
 [switch]$CompileOnly,
 [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$package=if([IO.Path]::IsPathRooted($PackagePath)){[IO.Path]::GetFullPath($PackagePath)}else{Join-Path $repo $PackagePath}
$python=(Get-Command python).Source
& $python (Join-Path $repo 'tools\quality12b\prepare_wick_rebreak_r2.py') --out $package --check
if($LASTEXITCODE -ne 0){throw 'Frozen package verification failed'}
$manifest=Get-Content -Raw -Encoding UTF8 (Join-Path $package 'manifest.json')|ConvertFrom-Json
if($manifest.purpose -ne 'WICK_REBREAK_ENTRY_STUDY_R2'){throw 'Wrong package purpose'}
if($Execute -and $manifest.status -ne 'LOCKED'){throw 'Study is not locked'}
if(!$Execute -and !$CompileOnly){$manifest.runs|Format-Table run_id,date_from,date_to;return}
$batch=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$terminalRoot=Join-Path $env:LOCALAPPDATA ('CodexMT5WickRebreakR2\'+$batch)
$output=Join-Path $package ((@{ $true='preflight';$false='runs' }[[bool]$CompileOnly])+'\'+$batch)
$lockPath=Join-Path $package 'runner.lock'
$lock=$null;$child=$null;$privateLogin='';$runId='compile'
function SaveJson($Object,[string]$Path){$Object|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $Path -Encoding UTF8}
function Redact([string]$Text){
 if($privateLogin){$Text=$Text.Replace($privateLogin,'[ACCOUNT]')}
 return [regex]::Replace($Text,'(?im)(password|login|account)\s*[=:]\s*\S+','$1=[REDACTED]')
}
function Log([string]$Message){Add-Content -LiteralPath (Join-Path $output 'runner.log') -Value ((Get-Date -Format s)+' '+(Redact $Message)) -Encoding UTF8}
function WaitOwned($Process,[int]$Seconds){
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(!$Process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt $Seconds){throw 'Owned process timeout'}}
}
function WaitTesterReport($Process,[string]$Report,[datetime]$Started,[int]$Seconds){
 # LiveUpdate can terminate the original PID and launch a replacement terminal.
 # Observe only our unique executable path; never restart an unrelated terminal.
 $timer=[Diagnostics.Stopwatch]::StartNew();$idle=[Diagnostics.Stopwatch]::StartNew()
 $exe=Join-Path $terminalRoot 'terminal64.exe';$seen=@{}
 while($timer.Elapsed.TotalSeconds -le $Seconds){
  $running=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $exe})
  if(!$Process.HasExited -or $running.Count -gt 0){
   $idle.Restart()
   foreach($p in $running){if(!$seen.ContainsKey($p.Id)){$seen[$p.Id]=$true;Log "Tracking tester terminal PID $($p.Id)"}}
  } else {
   if((Test-Path -LiteralPath $Report) -and (Get-Item -LiteralPath $Report).LastWriteTimeUtc -ge $Started){return}
   if($idle.Elapsed.TotalSeconds -gt 120){throw 'No fresh report and no dedicated terminal after restart grace period'}
  }
  Start-Sleep -Milliseconds 1000
 }
 throw 'Tester timeout including update/restart handoff'
}
function ArchiveLogs([string]$Destination){
 foreach($folder in @('logs','Tester')){
  $base=Join-Path $terminalRoot $folder
  if(Test-Path -LiteralPath $base){
   foreach($file in Get-ChildItem -LiteralPath $base -Recurse -File -Filter '*.log'){
    $relative=$file.FullName.Substring($terminalRoot.Length+1)
    $target=Join-Path $Destination ('journals\'+$relative)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    Redact ([IO.File]::ReadAllText($file.FullName))|Set-Content -LiteralPath $target -Encoding UTF8
   }
  }
 }
}
try {
 $lock=[IO.File]::Open($lockPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 if(Test-Path -LiteralPath $terminalRoot){throw 'Dedicated directory already exists'}
 New-Item -ItemType Directory -Path $output -Force|Out-Null
 foreach($folder in @('config','MQL5\Experts\ChannelQA','MQL5\Profiles\Tester','MQL5\Include')){
  New-Item -ItemType Directory -Path (Join-Path $terminalRoot $folder) -Force|Out-Null
 }
 foreach($name in @('terminal64.exe','MetaEditor64.exe','metatester64.exe')){
  Copy-Item -LiteralPath (Join-Path $SourceDataRoot $name) -Destination (Join-Path $terminalRoot $name)
 }
 Get-ChildItem -LiteralPath (Join-Path $SourceDataRoot 'MQL5\Include')|Copy-Item -Destination (Join-Path $terminalRoot 'MQL5\Include') -Recurse
 SaveJson @{status='COMPILING';batch_id=$batch;output=$output;terminal_root=$terminalRoot} (Join-Path $output 'status.json')
 foreach($source in $manifest.sources.PSObject.Properties){
  $name=$source.Name;$target=Join-Path $terminalRoot ('MQL5\Experts\ChannelQA\'+$name+'.mq5')
  Copy-Item -LiteralPath (Join-Path $repo $source.Value) -Destination $target
  $clog=Join-Path $output ($name+'.compile.log')
  $child=Start-Process -FilePath (Join-Path $terminalRoot 'MetaEditor64.exe') -ArgumentList '/portable',('/compile:"'+$target+'"'),('/log:"'+$clog+'"') -WindowStyle Hidden -PassThru
  WaitOwned $child 180;$child=$null
  if(!(Test-Path -LiteralPath $clog) -or (Get-Content -LiteralPath $clog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings'){throw "Compile failed: $name"}
  Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($target,'.ex5')) -Destination (Join-Path $output ($name+'.ex5'))
 }
 if($CompileOnly){SaveJson @{status='COMPILED';output=$output} (Join-Path $output 'status.json');Write-Host "COMPILED: $output";return}
 $common=Get-Content -LiteralPath (Join-Path $SourceDataRoot 'config\common.ini') -Raw
 $server=[regex]::Match($common,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
 $privateLogin=[regex]::Match($common,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 if($server -ne $manifest.expected_server -or !$privateLogin){throw 'Authorized source account identity mismatch'}
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot ('config\'+$name)) -Destination (Join-Path $terminalRoot ('config\'+$name))}
 $base=Join-Path $SourceDataRoot ('bases\'+$server)
 $items=@('symbols')
 foreach($symbol in $manifest.symbols){$items+=@(('history\'+$symbol),('ticks\'+$symbol))}
 foreach($item in $items){
  $src=Join-Path $base $item
  if(Test-Path -LiteralPath $src){
   $dst=Join-Path $terminalRoot ('bases\'+$server+'\'+$item)
   New-Item -ItemType Directory -Path (Split-Path -Parent $dst) -Force|Out-Null
   Copy-Item -LiteralPath $src -Destination $dst -Recurse
  }
 }
 $privateCommon="[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`n"
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 ($privateCommon+$disabled)|Set-Content -LiteralPath (Join-Path $terminalRoot 'config\common.ini') -Encoding ASCII
 SaveJson @{batch_id=$batch;terminal_root=$terminalRoot;source_data_root=$SourceDataRoot;run_order=@($manifest.runs.run_id);manifest_sha256=(Get-FileHash -LiteralPath (Join-Path $package 'manifest.json')).Hash} (Join-Path $output 'provenance.json')
 foreach($run in $manifest.runs){
  $runId=$run.run_id;$runOut=Join-Path $output $runId
  New-Item -ItemType Directory -Path $runOut -Force|Out-Null
  $tag='channel_'+$batch+'_'+$runId;$telemetry=$tag+'.csv'
  $values=Get-Content -Raw -Encoding UTF8 (Join-Path $package ('frozen\'+$run.inputs))|ConvertFrom-Json
  $values.InpTelemetryFileName=$telemetry
  if($run.kind -eq 'm5'){$values.InpOperatorCommandFile=$tag+'.command.csv';$values.InpStatusFileName=$tag+'.status.txt'}
  $lines=@($values.PSObject.Properties|ForEach-Object{$_.Name+'='+$_.Value})
  $setName=$tag+'.set';$setPath=Join-Path $terminalRoot ('MQL5\Profiles\Tester\'+$setName)
  $lines|Set-Content -LiteralPath $setPath -Encoding ASCII
  Copy-Item -LiteralPath $setPath -Destination (Join-Path $runOut 'inputs.set')
  $body=$disabled+@"
[Tester]
Expert=ChannelQA\$($run.expert).ex5
ExpertParameters=$setName
Symbol=$($run.symbol)
Period=$($run.timeframe)
Model=0
ExecutionMode=0
Optimization=0
FromDate=$($run.date_from)
ToDate=$($run.date_to)
Deposit=10000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=39081
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
  $ini=Join-Path $terminalRoot ($tag+'.ini')
  ($privateCommon+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
  $body|Set-Content -LiteralPath (Join-Path $runOut 'tester_public.ini') -Encoding ASCII
  SaveJson @{status='RUNNING';batch_id=$batch;run_id=$runId;output=$output} (Join-Path $output 'status.json')
  Log "Starting $runId"
  $started=[datetime]::UtcNow
  $report=Join-Path $terminalRoot ($tag+'.htm')
  SaveJson @{terminal_sha256=(Get-FileHash -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).Hash;terminal_version=(Get-Item -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).VersionInfo.FileVersion} (Join-Path $runOut 'runtime_before.json')
  $child=Start-Process -FilePath (Join-Path $terminalRoot 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
  WaitTesterReport $child $report $started $TimeoutSecondsPerRun;$child=$null
  SaveJson @{terminal_sha256=(Get-FileHash -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).Hash;terminal_version=(Get-Item -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).VersionInfo.FileVersion} (Join-Path $runOut 'runtime_after.json')
  ArchiveLogs $runOut
  if(!(Test-Path -LiteralPath $report)){throw 'No tester report; see journals'}
  if((Get-Item -LiteralPath $report).LastWriteTimeUtc -lt $started){throw 'Stale report refused'}
  Copy-Item -LiteralPath $report -Destination (Join-Path $runOut 'report.htm')
  foreach($img in Get-ChildItem -LiteralPath $terminalRoot -File -Filter ($tag+'*.png')){
   [IO.File]::Copy(('\\?\'+$img.FullName),('\\?\'+[IO.Path]::GetFullPath((Join-Path $runOut $img.Name))),$false)
  }
  $commonFiles=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
  Copy-Item -LiteralPath (Join-Path $commonFiles $telemetry) -Destination (Join-Path $runOut 'telemetry.csv')
  if($run.kind -ne 'harness'){
   Copy-Item -LiteralPath (Join-Path $commonFiles ($telemetry+'.cost.csv')) -Destination (Join-Path $runOut 'cost.csv')
  }
  foreach($suffix in @('.rb_candidates.csv','.rb_events.csv','.rb_entries.csv','.rb_outcomes.csv','.rb_context.csv','.rb_execution.csv','.rb_bars.csv','.path.csv','.adjustment.csv','.risk.csv','.portable_context.csv','.context.csv','.funnel.csv','.environment.csv','.conversion.csv','.history.csv')){
   $artifact=Join-Path $commonFiles ($telemetry+$suffix)
   if(Test-Path -LiteralPath $artifact){Copy-Item -LiteralPath $artifact -Destination (Join-Path $runOut $suffix.Substring(1))}
  }
  & $python (Join-Path $repo 'tools\quality12b\analyze_wick_rebreak_r2.py') --run $runOut --run-id $runId --package $package
  if($LASTEXITCODE -ne 0){throw 'Run audit failed; remaining runs stopped'}
  Log "Audit passed $runId"
 }
 & $python (Join-Path $repo 'tools\quality12b\analyze_wick_rebreak_r2.py') --batch $output --package $package
 if($LASTEXITCODE -ne 0){throw 'Aggregate analysis failed'}
 SaveJson @{status='COMPLETED';batch_id=$batch;completed_runs=$manifest.runs.Count;output=$output;promotion='NOT_ASSESSED'} (Join-Path $output 'status.json')
} catch {
 if(Test-Path -LiteralPath $terminalRoot){ArchiveLogs (Join-Path $output $runId)}
 if(Test-Path -LiteralPath $output){SaveJson @{status='FAILED';run_id=$runId;reason=(Redact $_.Exception.Message);output=$output} (Join-Path $output 'status.json');Log $_.Exception.Message}
 throw
} finally {
 if($null -ne $child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $terminalRoot 'terminal64.exe')}|Stop-Process
 # Only agents loaded from this unique dedicated directory belong to this run.
 Get-Process metatester64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -and $_.Path.StartsWith($terminalRoot+'\',[StringComparison]::OrdinalIgnoreCase)}|Stop-Process
 if($null -ne $lock){$lock.Dispose();Remove-Item -LiteralPath $lockPath}
}
