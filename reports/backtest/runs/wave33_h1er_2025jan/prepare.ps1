[CmdletBinding()]
param(
 [string]$SourceDataRoot=(Join-Path $env:APPDATA 'MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675'),
 [string]$RuntimeSeed=(Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33DayPartial/20261026_140018_UTC_5f514c4a')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))
function Hash([string]$path){return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
function SaveJson($value,[string]$path){$value|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $path -Encoding UTF8}
function SymbolDigest([string]$path){
 $items=@(Get-ChildItem -LiteralPath $path -Recurse -File|Sort-Object FullName|ForEach-Object{[pscustomobject]@{name=($_.FullName.Substring($path.Length));content=(Hash $_.FullName)}})
 $payload=$items|ConvertTo-Json -Compress
 $digest=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($digest.ComputeHash([Text.Encoding]::UTF8.GetBytes($payload)))).Replace('-','').ToLowerInvariant()}finally{$digest.Dispose()}
}
$deploy=Get-Content -LiteralPath (Join-Path $repo 'reports/qa/w33_h1eff_20261027/deployment.json') -Raw -Encoding UTF8|ConvertFrom-Json
if($deploy.qa_status -ne 'BUILD_STATIC_PASS_NATIVE_PENDING'){throw 'Build/static gate missing'}
foreach($p in $deploy.files_sha256.PSObject.Properties){if((Hash (Join-Path $repo $p.Name)) -ne $p.Value){throw ('Verified artifact changed '+$p.Name)}}
if((Get-PSDrive -Name C).Free -lt 1GB){throw 'Less than 1 GB free; do not start'}
$identity=[IO.File]::ReadAllText((Join-Path $SourceDataRoot 'config/common.ini'))
$server=[regex]::Match($identity,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
$privateLogin=[regex]::Match($identity,'(?m)^Login=(\d+)\s*$').Groups[1].Value
if(!$server -or !$privateLogin){throw 'Preserved tester identity missing'}
if($server -ne 'Bybit-Live'){throw 'Expected Bybit-Live source; never mix server datasets'}
$sourceBase=Join-Path $SourceDataRoot ('bases/'+$server)
$history=@{};$ticks=@{}
foreach($year in @(2024,2025)){$name=[string]$year+'.hcc';$p=Join-Path $sourceBase ('history/XAUUSD+/'+$name);if(!(Test-Path -LiteralPath $p)){throw ('Missing history '+$name)};$history[$name]=$p}
foreach($month in @('202412','202501')){$name=$month+'.tkc';$p=Join-Path $sourceBase ('ticks/XAUUSD+/'+$name);if(Test-Path -LiteralPath $p){$ticks[$name]=$p}}
if(!$ticks.ContainsKey('202501.tkc')){throw 'January tick cache required; no silent generated-tick comparison'}
$batch='20261027_'+[datetime]::UtcNow.ToString('HHmmss')+'_UTC_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$out=Join-Path $PSScriptRoot $batch
$parent=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33H1ER/'+$batch)
if((Test-Path -LiteralPath $out) -or (Test-Path -LiteralPath $parent)){throw 'Unique batch path already exists'}
New-Item -ItemType Directory -Path $out,$parent -Force|Out-Null
$arms=@();$firstSettings=$null;$firstCache=$null;$firstSymbols=''
foreach($arm in @('off','on')){
 $runtime=Join-Path $parent $arm;$publicOut=Join-Path $out $arm
 foreach($path in @($runtime,$publicOut,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts'),(Join-Path $runtime 'MQL5/Profiles/Tester'),(Join-Path $runtime ('bases/'+$server)))){New-Item -ItemType Directory -Path $path -Force|Out-Null}
 foreach($exe in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $RuntimeSeed $exe) -Destination (Join-Path $runtime $exe)}
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot ('config/'+$name)) -Destination (Join-Path $runtime ('config/'+$name))}
 Copy-Item -LiteralPath (Join-Path $sourceBase 'symbols') -Destination (Join-Path $runtime ('bases/'+$server+'/symbols')) -Recurse
 $symbolHash=SymbolDigest (Join-Path $runtime ('bases/'+$server+'/symbols'))
 $destHistory=Join-Path $runtime ('bases/'+$server+'/history/XAUUSD+')
 $destTicks=Join-Path $runtime ('bases/'+$server+'/ticks/XAUUSD+')
 New-Item -ItemType Directory -Path $destHistory,$destTicks -Force|Out-Null
 $cache=@{}
 foreach($entry in $history.GetEnumerator()){Copy-Item -LiteralPath $entry.Value -Destination (Join-Path $destHistory $entry.Key);$cache['history/'+$entry.Key]=Hash (Join-Path $destHistory $entry.Key)}
 foreach($entry in $ticks.GetEnumerator()){Copy-Item -LiteralPath $entry.Value -Destination (Join-Path $destTicks $entry.Key);$cache['ticks/'+$entry.Key]=Hash (Join-Path $destTicks $entry.Key)}
 $binary=Join-Path $runtime 'MQL5/Experts/Wave33H1EfficiencyVerifier.ex5'
 Copy-Item -LiteralPath (Join-Path $repo 'mql/Experts/Wave33H1EfficiencyVerifier.ex5') -Destination $binary
 $preset=Join-Path $repo ('presets/wave33/Wave33H1Efficiency_v192_B_'+$arm.ToUpperInvariant()+'.set')
 $settings=[ordered]@{}
 foreach($line in Get-Content -LiteralPath $preset -Encoding ASCII){if($line -match '^(Inp\w+)=(.*)$'){$settings[$matches[1]]=$matches[2]}}
 $settings.InpDraw='false' # Identical non-visual native comparison; no chart rendering overhead.
 if($settings.Count -ne 54 -or $settings.InpPattern -ne '1' -or $settings.InpScaleOut -ne 'true' -or $settings.InpPartialAtR -ne '1.0' -or $settings.InpStepStartR -ne '1.5' -or $settings.InpStepSizeR -ne '0.5' -or $settings.InpStepLagR -ne '0.5' -or $settings.InpEnableTesterOrders -ne 'true'){throw 'Fixed v191 exits / complete input snapshot required'}
 if($arm -eq 'off'){$firstSettings=$settings;$firstCache=$cache;$firstSymbols=$symbolHash}
 else{
  $delta=@($settings.Keys|Where-Object{$_ -ne 'InpRunTag' -and $settings[$_] -ne $firstSettings[$_]})
  if(($delta -join ',') -ne 'InpSkipH1LowEfficiency'){throw 'More than one decision parameter changed'}
  foreach($key in $cache.Keys){if($cache[$key] -ne $firstCache[$key]){throw ('Cache differs '+$key)}}
  if($symbolHash -ne $firstSymbols){throw 'Symbol specifications differ between arms'}
 }
 $tag='w33h1_'+$batch+'_'+$arm;$settings.InpRunTag=$tag
 $setName=$tag+'.set';$setPath=Join-Path $runtime ('MQL5/Profiles/Tester/'+$setName)
 @($settings.GetEnumerator()|ForEach-Object{$_.Key+'='+$_.Value})|Set-Content -LiteralPath $setPath -Encoding ASCII
 Copy-Item -LiteralPath $setPath -Destination (Join-Path $publicOut 'inputs.set')
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 $common="[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`nProxyEnable=0`r`nCertInstall=0`r`nKeepPrivate=0`r`nNewsEnable=0`r`n"
 ($common+$disabled)|Set-Content -LiteralPath (Join-Path $runtime 'config/common.ini') -Encoding ASCII
 $port=if($arm -eq 'off'){39410}else{39411}
 $public=$disabled+@"
[Tester]
Expert=Wave33H1EfficiencyVerifier.ex5
ExpertParameters=$setName
Symbol=XAUUSD+
Period=M1
Model=4
ExecutionMode=0
Optimization=0
FromDate=2025.01.01
ToDate=2025.02.01
Deposit=5000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=$port
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
 $ini=Join-Path $runtime ($tag+'.ini');($common+$public)|Set-Content -LiteralPath $ini -Encoding ASCII
 $public|Set-Content -LiteralPath (Join-Path $publicOut 'tester_public.ini') -Encoding ASCII
 $artifact=@{'terminal64.exe'=(Hash (Join-Path $runtime 'terminal64.exe'));'metatester64.exe'=(Hash (Join-Path $runtime 'metatester64.exe'));'MQL5/Experts/Wave33H1EfficiencyVerifier.ex5'=(Hash $binary)}
 $artifact['MQL5/Profiles/Tester/'+$setName]=Hash $setPath
 $arms+=[pscustomobject]@{id=$arm;runtime=$runtime;output=$publicOut;tag=$tag;ini=$ini;ini_sha256=(Hash $ini);port=$port;artifact_sha256=$artifact;cache_sha256=$cache;symbols_sha256=$symbolHash;inputs=$settings;native_status='NOT_STARTED'}
}
foreach($p in $deploy.files_sha256.PSObject.Properties){$dest=Join-Path $out ('frozen/'+$p.Name);New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null;Copy-Item -LiteralPath (Join-Path $repo $p.Name) -Destination $dest}
Copy-Item -LiteralPath (Join-Path $repo 'reports/qa/w33_h1eff_20261027/deployment.json') -Destination (Join-Path $out 'deployment.json')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'PLAN.md') -Destination (Join-Path $out 'PLAN.md')
$state=[ordered]@{status='PREPARED';batch=$batch;output=$out;arms=$arms;single_changed_parameter='InpSkipH1LowEfficiency';date_from='2025.01.01';date_to='2025.02.01';symbol='XAUUSD+';lower_tf='M1';requested_tick_model=4;tick_coverage='January tkc present; completeness/fallback and post-run equal bars must be audited';clock='BROKER_SOURCE_TIME';source_server=$server;native_performance='NOT_RUN';stop_after_launch=$true;auto_analysis=$false;decision='BOUNDED_USER_REQUESTED_NATIVE_COMPARISON_NOT_PROMOTION'}
SaveJson $state (Join-Path $out 'status.json');SaveJson $state (Join-Path $PSScriptRoot 'latest.json')
Write-Output ('PREPARED '+$batch+'; two equal-cache arms; only H1 filter differs')
