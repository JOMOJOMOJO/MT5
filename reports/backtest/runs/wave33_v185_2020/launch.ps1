# Fixed, isolated annual comparison. No installed terminal is changed or stopped.
[CmdletBinding()]
param(
 [string]$SourceDataRoot="$env:APPDATA\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675",
 [string]$RuntimeSeed="$env:LOCALAPPDATA\CodexMT5WickRebreakR3\20261014_094513_6f6042e2",
 [ValidateRange(120,21600)][int]$TimeoutSecondsPerRun=7200,
 [switch]$Smoke,
 [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
$source=Join-Path $repo 'mql/Experts/Wave33ChopDiagnostic.mq5'
$binary=[IO.Path]::ChangeExtension($source,'.ex5')
$manifestPath=Join-Path $PSScriptRoot 'deployment.json'
$dateFrom='2020.01.01';$dateTo=if($Smoke){'2020.01.11'}else{'2021.01.01'}
$baseInputs=[ordered]@{}
foreach($line in Get-Content -LiteralPath (Join-Path $repo 'presets/wave33/Wave33Pair_v184_A_BothOn.set') -Encoding UTF8){
 if($line -match '^(Inp\w+)=(.*)$'){$baseInputs[$matches[1]]=[string]$matches[2]}
}
$baseInputs.InpDraw='false';$baseInputs.InpShowInfoPanel='false';$baseInputs.InpScreenshots='false'
$baseInputs.InpAuditOppositeExitTicks='false';$baseInputs.InpEnableTesterOrders='true'
$baseInputs.InpScaleOut='true'
$runs=@()
foreach($pattern in @('a','b')){foreach($policy in @('off','on')){
 $inputs=[ordered]@{};foreach($key in $baseInputs.Keys){$inputs[$key]=$baseInputs[$key]}
 $inputs.InpPattern=[string][int]($pattern -eq 'b');$inputs.InpScaleOut=(@{off='false';on='true'}[$policy])
 $runs+=[pscustomobject]@{id=('v185_'+$pattern+'_scale_'+$policy);period=(@{a='M5';b='M1'}[$pattern]);inputs=$inputs}
}}
if(!$Execute){$runs|Select-Object id,period,@{n='scale_out';e={$_.inputs.InpScaleOut}};return}
function Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function SaveJson($Object,[string]$Path){$Object|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $Path -Encoding UTF8}
if(!(Test-Path -LiteralPath $manifestPath)){throw 'Final QA deployment manifest missing; annual start is gated.'}
$deployment=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8|ConvertFrom-Json
if($deployment.qa_status -ne 'PASS' -or $deployment.ea_version -ne '1.85'){throw 'Deployment QA must be PASS for v1.85'}
if((Hash $source) -ne $deployment.source_sha256.ToLowerInvariant() -or (Hash $binary) -ne $deployment.binary_sha256.ToLowerInvariant()){throw 'EA differs from final QA deployment'}
foreach($header in $deployment.header_sha256.PSObject.Properties){
 if((Hash (Join-Path $repo ('mql/Include/'+$header.Name))) -ne $header.Value.ToLowerInvariant()){throw ('Verified header changed: '+$header.Name)}
}
$inputNames=@([regex]::Matches((Get-Content -LiteralPath $source -Raw -Encoding UTF8),'(?m)^input\s+\w+\s+(Inp\w+)\s*=')|ForEach-Object{$_.Groups[1].Value})
$missing=@($inputNames|Where-Object{!$baseInputs.Contains($_)});$unknown=@($baseInputs.Keys|Where-Object{$_ -notin $inputNames})
if($missing.Count -or $unknown.Count){throw ('Incomplete fixed inputs: missing '+($missing -join ',')+' unknown '+($unknown -join ','))}
$batch=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$runtimeParent=Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33ScaleOut'
$runtime=Join-Path $runtimeParent $batch
$package=if($Smoke){Join-Path $PSScriptRoot 'smoke'}else{$PSScriptRoot}
$output=Join-Path $package $batch
$privateTokens=New-Object System.Collections.Generic.List[string]
$lock=$null;$child=$null;$runId='prepare'
function Redact([string]$Text){
 foreach($token in $privateTokens){if($token){$Text=$Text.Replace($token,'[ACCOUNT]')}}
 $Text=[regex]::Replace($Text,'(?im)((?:password|login|account)\s*[=:]\s*)\S+','$1[REDACTED]')
 return [regex]::Replace($Text,"'\d{5,}'","'[ACCOUNT]'")
}
function Log([string]$Message){Add-Content -LiteralPath (Join-Path $output 'runner.log') -Value ((Get-Date -Format s)+' '+(Redact $Message)) -Encoding UTF8}
function ArchiveLogs([string]$Destination){
 foreach($folder in @('logs','Tester')){
  $base=Join-Path $runtime $folder;if(!(Test-Path -LiteralPath $base)){continue}
  foreach($file in Get-ChildItem -LiteralPath $base -Recurse -File -Filter '*.log'){
   $target=Join-Path $Destination ('journals/'+$file.FullName.Substring($runtime.Length+1))
   New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
   $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
   $reader=[IO.StreamReader]::new($stream);try{$text=$reader.ReadToEnd()}finally{$reader.Dispose()}
   Redact $text|Set-Content -LiteralPath $target -Encoding UTF8
  }
 }
}
function WaitReport($Process,[string]$Report,[datetime]$Started,[int]$Seconds){
 $timer=[Diagnostics.Stopwatch]::StartNew();$idle=[Diagnostics.Stopwatch]::StartNew();$exe=Join-Path $runtime 'terminal64.exe'
 while($timer.Elapsed.TotalSeconds -le $Seconds){
  $owned=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $exe})
  if(!$Process.HasExited -or $owned.Count){$idle.Restart()}
  else{
   if((Test-Path -LiteralPath $Report) -and (Get-Item -LiteralPath $Report).LastWriteTimeUtc -ge $Started){return}
   if($idle.Elapsed.TotalSeconds -gt 90){throw 'Dedicated tester exited without a fresh native report'}
  };Start-Sleep -Milliseconds 1000
 };throw 'Dedicated annual tester timeout'
}
try{
 $lock=[IO.File]::Open((Join-Path $PSScriptRoot 'runner.lock'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 if(Test-Path -LiteralPath $runtime){throw 'Unique portable path already exists'}
 foreach($folder in @($output,$runtime,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts'),(Join-Path $runtime 'MQL5/Profiles/Tester'),(Join-Path $runtime 'MQL5/Include'))){New-Item -ItemType Directory -Path $folder -Force|Out-Null}
 foreach($name in @('terminal64.exe','MetaEditor64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $RuntimeSeed $name) -Destination (Join-Path $runtime $name)}
 Get-ChildItem -LiteralPath (Join-Path $RuntimeSeed 'MQL5/Include')|Copy-Item -Destination (Join-Path $runtime 'MQL5/Include') -Recurse
 foreach($header in $deployment.header_sha256.PSObject.Properties){
  $target=Join-Path $runtime ('MQL5/Include/'+$header.Name);New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
  Copy-Item -LiteralPath (Join-Path $repo ('mql/Include/'+$header.Name)) -Destination $target -Force
  $frozen=Join-Path $output ('frozen_include/'+$header.Name);New-Item -ItemType Directory -Path (Split-Path -Parent $frozen) -Force|Out-Null
  Copy-Item -LiteralPath $target -Destination $frozen
 }
 foreach($artifact in @($source,$binary)){
  Copy-Item -LiteralPath $artifact -Destination (Join-Path $runtime ('MQL5/Experts/'+[IO.Path]::GetFileName($artifact)))
  Copy-Item -LiteralPath $artifact -Destination (Join-Path $output ([IO.Path]::GetFileName($artifact)))
 }
 Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $output 'deployment.json')
 $methodHashes=[ordered]@{}
 foreach($name in @('launch.ps1','analyze.py','PLAN.md')){
  $path=Join-Path $PSScriptRoot $name;$dest=Join-Path $output ('method/'+$name)
  New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
  Copy-Item -LiteralPath $path -Destination $dest;$methodHashes[$name]=Hash $path
 }
 $nativeParser=Join-Path $repo 'tools/wave33_visual/audit_opposite_exit.py'
 Copy-Item -LiteralPath $nativeParser -Destination (Join-Path $output 'method/audit_opposite_exit.py')
 $methodHashes['audit_opposite_exit.py']=Hash $nativeParser
 $identity=Get-Content -LiteralPath (Join-Path $SourceDataRoot 'config/common.ini') -Raw
 $server=[regex]::Match($identity,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
 $privateLogin=[regex]::Match($identity,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 if(!$server -or !$privateLogin){throw 'Source identity cache missing'}
 $privateTokens.Add($privateLogin)
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot ('config/'+$name)) -Destination (Join-Path $runtime ('config/'+$name))}
 $base=Join-Path $SourceDataRoot ('bases/'+$server)
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $base 'symbols') -File){foreach($m in [regex]::Matches($file.Name,'\d{5,}')){$privateTokens.Add($m.Value)}}
 New-Item -ItemType Directory -Path (Join-Path $runtime ('bases/'+$server)) -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $base 'symbols') -Destination (Join-Path $runtime ('bases/'+$server+'/symbols')) -Recurse
 $historyDest=Join-Path $runtime ('bases/'+$server+'/history/XAUUSD+')
 $ticksDest=Join-Path $runtime ('bases/'+$server+'/ticks/XAUUSD+')
 New-Item -ItemType Directory -Path $historyDest,$ticksDest -Force|Out-Null
 $cacheHashes=[ordered]@{};$copiedHistory=@();$copiedTicks=@()
 foreach($year in @(2019,2020,2021)){
  $name=[string]$year+'.hcc';$path=Join-Path $base ('history/XAUUSD+/'+$name)
  if(!(Test-Path -LiteralPath $path)){throw ('Annual history cache missing: '+$name)}
  Copy-Item -LiteralPath $path -Destination (Join-Path $historyDest $name);$cacheHashes[$name]=Hash $path;$copiedHistory+=$name
 }
 foreach($month in @( '201912')+(1..12|ForEach-Object{'2020{0:d2}' -f $_})+@('202101')){
  $name=$month+'.tkc';$path=Join-Path $base ('ticks/XAUUSD+/'+$name)
  if(Test-Path -LiteralPath $path){Copy-Item -LiteralPath $path -Destination (Join-Path $ticksDest $name);$cacheHashes[$name]=Hash $path;$copiedTicks+=$name}
 }
 $privateCommon="[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`n"
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 ($privateCommon+$disabled)|Set-Content -LiteralPath (Join-Path $runtime 'config/common.ini') -Encoding ASCII
 $runtimeHashes=[ordered]@{};foreach($name in @('terminal64.exe','metatester64.exe')){$runtimeHashes[$name]=Hash (Join-Path $runtime $name)}
 SaveJson @{batch_id=$batch;terminal_root=$runtime;source_data_root=$SourceDataRoot;runtime_seed=$RuntimeSeed;server=$server;symbol='XAUUSD+';date_from=$dateFrom;date_to=$dateTo;model=4;deposit=5000;copied_history=$copiedHistory;copied_ticks=$copiedTicks;cache_sha256=$cacheHashes;runtime_sha256=$runtimeHashes;method_sha256=$methodHashes;deployment_sha256=(Hash $manifestPath);run_order=@($runs.id);purpose=$(if($Smoke){'SHORT_EXECUTION_SMOKE_NOT_ANNUAL'}else{'FIXED_SCALE_OUT_REGRESSION_NOT_PROMOTION'});terminal_live_trading_enabled=$false} (Join-Path $output 'provenance.json')
 SaveJson @{status='PREPARED';batch_id=$batch;output=$output;terminal_root=$runtime} (Join-Path $output 'status.json')
 SaveJson @{status='RUNNING';batch_id=$batch;output=$output;terminal_root=$runtime} (Join-Path $package 'latest.json')
 $python=(Get-Command python).Source
 foreach($run in $runs){
  $runId=$run.id;$runOut=Join-Path $output $runId;New-Item -ItemType Directory -Path $runOut -Force|Out-Null
  $tag='w33s_'+$batch+'_'+$runId;$run.inputs.InpRunTag=$tag
  $setName=$tag+'.set';$setPath=Join-Path $runtime ('MQL5/Profiles/Tester/'+$setName)
  @($run.inputs.GetEnumerator()|ForEach-Object{$_.Key+'='+$_.Value})|Set-Content -LiteralPath $setPath -Encoding ASCII
  Copy-Item -LiteralPath $setPath -Destination (Join-Path $runOut 'inputs.set')
  $body=$disabled+@"
[Tester]
Expert=Wave33ChopDiagnostic.ex5
ExpertParameters=$setName
Symbol=XAUUSD+
Period=$($run.period)
Model=4
ExecutionMode=0
Optimization=0
FromDate=$dateFrom
ToDate=$dateTo
Deposit=5000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=39285
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
  $ini=Join-Path $runtime ($tag+'.ini');($privateCommon+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
  $body|Set-Content -LiteralPath (Join-Path $runOut 'tester_public.ini') -Encoding ASCII
  SaveJson @{run_id=$runId;tag=$tag;expert='Wave33ChopDiagnostic';inputs=$run.inputs;symbol='XAUUSD+';date_from=$dateFrom;date_to=$dateTo;chart_period=$run.period;visual_mode=$false;model=4} (Join-Path $runOut 'run.json')
  SaveJson @{status='RUNNING';batch_id=$batch;run_id=$runId;output=$output} (Join-Path $output 'status.json');Log ('Starting '+$runId)
  SaveJson @{sha256=(Hash (Join-Path $runtime 'terminal64.exe'));version=[string](Get-Item -LiteralPath (Join-Path $runtime 'terminal64.exe')).VersionInfo.FileVersion} (Join-Path $runOut 'runtime_before.json')
  $started=[datetime]::UtcNow;$report=Join-Path $runtime ($tag+'.htm')
  $child=Start-Process -FilePath (Join-Path $runtime 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
  WaitReport $child $report $started $TimeoutSecondsPerRun;$child=$null
  SaveJson @{sha256=(Hash (Join-Path $runtime 'terminal64.exe'));version=[string](Get-Item -LiteralPath (Join-Path $runtime 'terminal64.exe')).VersionInfo.FileVersion} (Join-Path $runOut 'runtime_after.json')
  if((Hash (Join-Path $runtime 'terminal64.exe')) -ne $runtimeHashes['terminal64.exe']){throw 'Private terminal self-updated during fixed comparison; stop and preserve evidence'}
  ArchiveLogs $runOut
  Redact ([IO.File]::ReadAllText($report))|Set-Content -LiteralPath (Join-Path $runOut 'report.htm') -Encoding UTF8
  foreach($image in Get-ChildItem -LiteralPath $runtime -File -Filter ($tag+'*.png')){Copy-Item -LiteralPath $image.FullName -Destination (Join-Path $runOut $image.Name)}
  $commonFiles=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
  foreach($artifact in Get-ChildItem -LiteralPath $commonFiles -File -Filter ($tag+'*')){Copy-Item -LiteralPath $artifact.FullName -Destination (Join-Path $runOut $artifact.Name.Substring($tag.Length).TrimStart('_'))}
  if(!(Test-Path -LiteralPath (Join-Path $runOut 'events.csv'))){throw ('No event ledger for '+$runId)}
  Log ('Collected '+$runId)
 }
 if((Hash (Join-Path $PSScriptRoot 'analyze.py')) -ne $methodHashes['analyze.py'] -or (Hash $nativeParser) -ne $methodHashes['audit_opposite_exit.py']){throw 'Analysis method changed during native runs; preserve exports and audit separately'}
 if($Smoke){& $python (Join-Path $PSScriptRoot 'analyze.py') --batch $output --short-smoke}else{& $python (Join-Path $PSScriptRoot 'analyze.py') --batch $output}
 if($LASTEXITCODE -ne 0){throw 'Annual independent audit failed'}
 SaveJson @{status='COMPLETED';batch_id=$batch;completed_runs=4;output=$output;promotion='NOT_ASSESSED'} (Join-Path $output 'status.json')
 SaveJson @{status='COMPLETED';batch_id=$batch;output=$output;terminal_root=$runtime} (Join-Path $package 'latest.json');Log 'Completed all four conditions'
 Write-Output ('COMPLETED '+$output)
}catch{
 if(Test-Path -LiteralPath $runtime){ArchiveLogs (Join-Path $output $runId)}
 if(Test-Path -LiteralPath $output){SaveJson @{status='FAILED';run_id=$runId;reason=(Redact $_.Exception.Message);output=$output} (Join-Path $output 'status.json');Log $_.Exception.Message}
 throw
}finally{
 if($null -ne $child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 $fullRuntime=[IO.Path]::GetFullPath($runtime);$fullParent=[IO.Path]::GetFullPath($runtimeParent).TrimEnd('\')+'\'
 if($fullRuntime.StartsWith($fullParent,[StringComparison]::OrdinalIgnoreCase)){
  Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $fullRuntime 'terminal64.exe')}|Stop-Process
  Get-Process metatester64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -and $_.Path.StartsWith($fullRuntime+'\',[StringComparison]::OrdinalIgnoreCase)}|Stop-Process
 }
 if($null -ne $lock){$lock.Dispose();Remove-Item -LiteralPath (Join-Path $PSScriptRoot 'runner.lock')}
}
