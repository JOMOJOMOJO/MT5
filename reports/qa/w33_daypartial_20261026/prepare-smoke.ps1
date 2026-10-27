[CmdletBinding()]
param([string]$SourceDataRoot="$env:LOCALAPPDATA\CodexMT5Wave33ScaleOut\20261026_100045_50909ab6")
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
function Hash([string]$p){return (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
function Json($v,[string]$p){$v|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $p -Encoding UTF8}
$deployment=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'deployment.json') -Raw -Encoding UTF8|ConvertFrom-Json
if($deployment.qa_status -ne 'BUILD_AND_STATIC_PASS_PENDING_NATIVE'){throw 'Build/static gate missing'}
foreach($p in $deployment.files_sha256.PSObject.Properties){if((Hash (Join-Path $repo $p.Name)) -ne $p.Value){throw ('Source changed '+$p.Name)}}
if((Get-PSDrive -Name C).Free -lt 1GB){throw 'Less than 1 GB free; preserve evidence and do not start'}
$batch='20261026_'+[datetime]::UtcNow.ToString('HHmmss')+'_UTC_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$out=Join-Path $PSScriptRoot $batch
$runtime=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33DayPartial/'+$batch)
if((Test-Path -LiteralPath $out) -or (Test-Path -LiteralPath $runtime)){throw 'Unique path already exists'}
foreach($p in @($out,$runtime,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts'),(Join-Path $runtime 'MQL5/Profiles/Tester'))){New-Item -ItemType Directory -Path $p -Force|Out-Null}
foreach($exe in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot $exe) -Destination (Join-Path $runtime $exe)}
$identity=Get-Content -LiteralPath (Join-Path $SourceDataRoot 'config/common.ini') -Raw
$server=[regex]::Match($identity,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
$privateLogin=[regex]::Match($identity,'(?m)^Login=(\d+)\s*$').Groups[1].Value
if(!$server -or !$privateLogin){throw 'Preserved tester identity cache missing'}
foreach($file in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot ('config/'+$file)) -Destination (Join-Path $runtime ('config/'+$file))}
$base=Join-Path $SourceDataRoot ('bases/'+$server)
New-Item -ItemType Directory -Path (Join-Path $runtime ('bases/'+$server)) -Force|Out-Null
Copy-Item -LiteralPath (Join-Path $base 'symbols') -Destination (Join-Path $runtime ('bases/'+$server+'/symbols')) -Recurse
$destHistory=Join-Path $runtime ('bases/'+$server+'/history/XAUUSD+')
New-Item -ItemType Directory -Path $destHistory -Force|Out-Null
$cache=@{}
foreach($year in @(2019,2020)){$name=[string]$year+'.hcc';$p=Join-Path $base ('history/XAUUSD+/'+$name);Copy-Item -LiteralPath $p -Destination (Join-Path $destHistory $name);$cache[$name]=Hash $p}
foreach($name in @('Wave33DayTradePartialVerifier','tests/Wave33DayTradePartialHarness')){
 $p=Join-Path $repo ('mql/Experts/'+$name+'.ex5');Copy-Item -LiteralPath $p -Destination (Join-Path $runtime ('MQL5/Experts/'+[IO.Path]::GetFileName($p)))
}
$tag='w33dtpqa_'+$batch;$inputs=[ordered]@{}
foreach($line in Get-Content -LiteralPath (Join-Path $repo 'presets/wave33/Wave33DayTradePartial_v191_B_Visual.set')){if($line -match '^(Inp\w+)=(.*)$'){$inputs[$matches[1]]=$matches[2]}}
$inputs.InpDraw='false';$inputs.InpRunTag=$tag
$setName=$tag+'.set';$setPath=Join-Path $runtime ('MQL5/Profiles/Tester/'+$setName)
@($inputs.GetEnumerator()|ForEach-Object{$_.Key+'='+$_.Value})|Set-Content -LiteralPath $setPath -Encoding ASCII
Copy-Item -LiteralPath $setPath -Destination (Join-Path $out 'inputs.set')
$disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
$common="[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`nProxyEnable=0`r`nCertInstall=0`r`nKeepPrivate=0`r`nNewsEnable=0`r`n"
($common+$disabled)|Set-Content -LiteralPath (Join-Path $runtime 'config/common.ini') -Encoding ASCII
$public=$disabled+@"
[Tester]
Expert=Wave33DayTradePartialHarness.ex5
ExpertParameters=$setName
Symbol=XAUUSD+
Period=M1
Model=4
ExecutionMode=0
Optimization=0
FromDate=2020.01.02
ToDate=2020.01.04
Deposit=5000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=39391
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
$ini=Join-Path $runtime ($tag+'.ini');($common+$public)|Set-Content -LiteralPath $ini -Encoding ASCII
$public|Set-Content -LiteralPath (Join-Path $out 'tester_public.ini') -Encoding ASCII
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'deployment.json') -Destination (Join-Path $out 'deployment.json')
foreach($p in $deployment.files_sha256.PSObject.Properties){$target=Join-Path $out ('frozen/'+$p.Name);New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null;Copy-Item -LiteralPath (Join-Path $repo $p.Name) -Destination $target}
$artifacts=@{}
foreach($relative in @('metatester64.exe','MQL5/Experts/Wave33DayTradePartialVerifier.ex5','MQL5/Experts/Wave33DayTradePartialHarness.ex5',('MQL5/Profiles/Tester/'+$setName))){$artifacts[$relative]=Hash (Join-Path $runtime $relative)}
$state=@{status='PREPARED';batch=$batch;tag=$tag;runtime=$runtime;ini=$ini;ini_sha256=(Hash $ini);output=$out;terminal_sha256=(Hash (Join-Path $runtime 'terminal64.exe'));tester_sha256=(Hash (Join-Path $runtime 'metatester64.exe'));runtime_artifact_sha256=$artifacts;history_sha256=$cache;purpose='BOUNDED_NATIVE_FIXTURES_NOT_STRATEGY_PERFORMANCE';auto_analysis=$false;user_resume_required=$true;real_ticks='2020 tick cache absent; generated-tick native plumbing QA'}
Json $state (Join-Path $out 'status.json');Json $state (Join-Path $PSScriptRoot 'latest.json')
Write-Output ('Prepared '+$out)
