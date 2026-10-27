# Dedicated tester sandbox. This runner never changes or stops installed terminals.
[CmdletBinding()]
param(
 [string]$SourceDataRoot="$env:LOCALAPPDATA\CodexMT5WickRebreakR3\20261014_094513_6f6042e2",
 [string]$RuntimeRoot='',
 [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.#+-]*$')][string]$Symbol='XAUUSD',
 [ValidateRange(0,4)][int]$Model=4,
 [ValidateRange(1,100000000)][double]$Deposit=10000,
 [string]$OutputRoot='reports\qa\wave33_visual_20261020',
 [string]$DateFrom='2025.01.06',
 [string]$DateTo='2025.01.18',
 [ValidateRange(60,86400)][int]$TimeoutSecondsPerRun=1200,
 [string[]]$OnlyRuns=@(),
 [switch]$CompileOnly,
 [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if(!$RuntimeRoot){$RuntimeRoot=$SourceDataRoot}
$package=if([IO.Path]::IsPathRooted($OutputRoot)){[IO.Path]::GetFullPath($OutputRoot)}else{Join-Path $repo $OutputRoot}
$runs=@(
 [pscustomobject]@{id='engine_harness';expert='Wave33EngineHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='display_harness';expert='Wave33DisplayHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='lifecycle_harness';expert='Wave33LifecycleHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='recognition_harness';expert='Wave33RecognitionHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='room_harness';expert='Wave33RoomHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='fib_close_harness';expert='Wave33FibCloseHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='opposite_exit_harness';expert='Wave33OppositeExitHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='extension_harness';expert='Wave33ExtensionHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='tester_run_harness';expert='Wave33TesterRunHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='connected_harness';expert='Wave33ConnectedHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='target_harness';expert='Wave33TargetHarness';period='M1';inputs=@{}},
 [pscustomobject]@{id='a_extension_off';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpExtendWave1BeforeFib='false';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261022';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='a_extension_on';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpExtendWave1BeforeFib='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261022';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='b_extension_off';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true';InpExtendWave1BeforeFib='false';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261022';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='b_extension_on';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true';InpExtendWave1BeforeFib='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261022';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='a_opposite_exit_off';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='false';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='a_opposite_exit_on';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='b_opposite_exit_off';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='false';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='b_opposite_exit_on';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true'}},
 [pscustomobject]@{id='a_fib_close_off';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='false';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0}},
 [pscustomobject]@{id='a_fib_close_on';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0}},
 [pscustomobject]@{id='b_fib_close_off';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='false';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0}},
 [pscustomobject]@{id='b_fib_close_on';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0}},
 [pscustomobject]@{id='a_pivot_diagnostic';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='false'}},
 [pscustomobject]@{id='b_pivot_diagnostic';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='false'}},
 [pscustomobject]@{id='b_trendline_diagnostic';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=1;InpEnableTesterOrders='false'}},
 [pscustomobject]@{id='b_first_diagnostic';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=2;InpEnableTesterOrders='false'}},
 [pscustomobject]@{id='a_orders_smoke';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true'}},
 [pscustomobject]@{id='b_orders_smoke';expert='Wave33VisualVerifier';period='M1';inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='true'}},
 [pscustomobject]@{id='a_legacy_orders';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpStrictWaveLifecycle='false';InpMagic='3320261021';InpLowerRecognition=0;InpMinWave1RoomR=0}},
 [pscustomobject]@{id='a_strict_orders';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=0;InpMinWave1RoomR=0}},
 [pscustomobject]@{id='a_v130_control';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=0;InpMinWave1RoomR=0}},
 [pscustomobject]@{id='a_recognition_only';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0}},
 [pscustomobject]@{id='a_room_only';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=0;InpMinWave1RoomR=0.25}},
 [pscustomobject]@{id='a_v140_full';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpStrictWaveLifecycle='true';InpMagic='3320261021';InpLowerRecognition=2;InpMinWave1RoomR=0.25}},
 [pscustomobject]@{id='a_obstacle_skip';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='false';InpObstacleMode=1}},
 [pscustomobject]@{id='a_obstacle_cap';expert='Wave33VisualVerifier';period='M5';inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='false';InpObstacleMode=2}},
 [pscustomobject]@{id='a_visual';expert='Wave33VisualVerifier';period='M5';visual=1;inputs=@{InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='false'}},
 [pscustomobject]@{id='b_visual';expert='Wave33VisualVerifier';period='M1';visual=1;inputs=@{InpPattern=1;InpTriggerMode=0;InpEnableTesterOrders='false'}}
)
foreach($waveArm in @('a','b')){
 foreach($wavePolicy in @('base','cancel','target','both')){
  $waveInputs=@{InpPattern=([int]($waveArm -eq 'b'));InpTriggerMode=0;InpEnableTesterOrders='true';InpExtendWave1BeforeFib='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpMagic='3320261022';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpRiskPercent=1.0;InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true';InpCancelConnectedOpposite=(@{base='false';cancel='true';target='false';both='true'}[$wavePolicy]);InpExtendTPToWave1=(@{base='false';cancel='false';target='true';both='true'}[$wavePolicy]);InpTPWave1BufferPoints=10.0}
  $runs+=[pscustomobject]@{id=('v180_'+$waveArm+'_'+$wavePolicy);expert='Wave33VisualVerifier';period=(@{a='M5';b='M1'}[$waveArm]);inputs=$waveInputs}
 }
}
foreach($run in $runs){
 if($run.expert -eq 'Wave33VisualVerifier' -and !$run.inputs.ContainsKey('InpCancelConnectedOpposite')){
  $run.inputs.InpCancelConnectedOpposite='false';$run.inputs.InpExtendTPToWave1='false'
 }
 if($run.expert -eq 'Wave33VisualVerifier' -and !$run.inputs.ContainsKey('InpExtendWave1BeforeFib')){
  $run.inputs.InpExtendWave1BeforeFib='false'
 }
 # Existing QA arms retain their original exits despite the v1.60 user default.
 if($run.expert -eq 'Wave33VisualVerifier' -and !$run.inputs.ContainsKey('InpExitOnOppositeWave1')){
  $run.inputs.InpExitOnOppositeWave1='false'
 }
 if($run.id -in @('a_legacy_orders','a_strict_orders','a_v130_control','a_recognition_only','a_room_only','a_v140_full')){
  $run.inputs.InpRejectDeepFibClose='false'
 }
}
if($OnlyRuns.Count -gt 0){
 foreach($requested in $OnlyRuns){if($requested -notin $runs.id){throw "Unknown run: $requested"}}
 $runs=@($runs|Where-Object{$_.id -in $OnlyRuns})
}
if(!$Execute -and !$CompileOnly){$runs|Select-Object id,expert,period;return}
$batch=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$terminalRoot=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33\'+$batch)
$output=Join-Path $package $batch
$privateTokens=New-Object System.Collections.Generic.List[string]
$lock=$null;$child=$null;$runId='compile'
function SaveJson($Object,[string]$Path){$Object|ConvertTo-Json -Depth 16|Set-Content -LiteralPath $Path -Encoding UTF8}
function Redact([string]$Text){
 foreach($token in $privateTokens){if($token){$Text=$Text.Replace($token,'[ACCOUNT]')}}
 $Text=[regex]::Replace($Text,'(?im)((?:password|login|account)\s*[=:]\s*)\S+','$1[REDACTED]')
 return [regex]::Replace($Text,"'\d{5,}'","'[ACCOUNT]'")
}
function Log([string]$Message){Add-Content -LiteralPath (Join-Path $output 'runner.log') -Value ((Get-Date -Format s)+' '+(Redact $Message)) -Encoding UTF8}
function ArchiveLogs([string]$Destination){
 foreach($folder in @('logs','Tester')){
  $base=Join-Path $terminalRoot $folder
  if(Test-Path -LiteralPath $base){
   foreach($file in Get-ChildItem -LiteralPath $base -Recurse -File -Filter '*.log'){
    $relative=$file.FullName.Substring($terminalRoot.Length+1)
    $target=Join-Path $Destination ('journals\'+$relative)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
    $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try{$reader=[IO.StreamReader]::new($stream);$logText=$reader.ReadToEnd();Redact $logText|Set-Content -LiteralPath $target -Encoding UTF8}finally{if($reader){$reader.Dispose()}else{$stream.Dispose()}}
   }
  }
 }
}
function WaitOwned($Process,[int]$Seconds){
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(!$Process.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt $Seconds){throw 'Owned compile process timeout'}}
}
function WaitReport($Process,[string]$Report,[datetime]$Started,[int]$Seconds){
 $timer=[Diagnostics.Stopwatch]::StartNew();$idle=[Diagnostics.Stopwatch]::StartNew()
 $exe=Join-Path $terminalRoot 'terminal64.exe'
 while($timer.Elapsed.TotalSeconds -le $Seconds){
  $owned=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $exe})
  if(!$Process.HasExited -or $owned.Count -gt 0){$idle.Restart()}
  else{
   if((Test-Path -LiteralPath $Report) -and (Get-Item -LiteralPath $Report).LastWriteTimeUtc -ge $Started){return}
   if($idle.Elapsed.TotalSeconds -gt 120){throw 'Dedicated tester exited without a fresh report'}
  }
  Start-Sleep -Milliseconds 1000
 }
 throw 'Dedicated tester timeout'
}
try{
 New-Item -ItemType Directory -Path $package -Force|Out-Null
 $lock=[IO.File]::Open((Join-Path $package 'runner.lock'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 if(Test-Path -LiteralPath $terminalRoot){throw 'Dedicated path already exists'}
 New-Item -ItemType Directory -Path $output -Force|Out-Null
 foreach($folder in @('config','MQL5\Experts\tests','MQL5\Profiles\Tester','MQL5\Include')){New-Item -ItemType Directory -Path (Join-Path $terminalRoot $folder) -Force|Out-Null}
 foreach($name in @('terminal64.exe','MetaEditor64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $RuntimeRoot $name) -Destination (Join-Path $terminalRoot $name)}
 Get-ChildItem -LiteralPath (Join-Path $RuntimeRoot 'MQL5\Include')|Copy-Item -Destination (Join-Path $terminalRoot 'MQL5\Include') -Recurse
 # New family headers only: existing repository EAs/shared logic remain untouched.
 $headerHashes=@{}
 foreach($header in Get-ChildItem -LiteralPath (Join-Path $repo 'mql\Include') -Recurse -File|Where-Object{$_.FullName -match 'Wave33'}){
  $relative=$header.FullName.Substring((Join-Path $repo 'mql\Include').Length+1)
  $target=Join-Path $terminalRoot ('MQL5\Include\'+$relative)
  New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
  Copy-Item -LiteralPath $header.FullName -Destination $target -Force
  $headerHashes[$relative]=(Get-FileHash -LiteralPath $header.FullName).Hash
 }
 SaveJson @{status='COMPILING';batch_id=$batch;output=$output;terminal_root=$terminalRoot} (Join-Path $output 'status.json')
 $sourceHashes=@{}
 foreach($name in @('Wave33EngineHarness','Wave33DisplayHarness','Wave33LifecycleHarness','Wave33RecognitionHarness','Wave33RoomHarness','Wave33FibCloseHarness','Wave33OppositeExitHarness','Wave33ExtensionHarness','Wave33TesterRunHarness','Wave33ConnectedHarness','Wave33TargetHarness','Wave33VisualVerifier')){
  $source=if($name.EndsWith('Harness')){Join-Path $repo ('mql\Experts\tests\'+$name+'.mq5')}else{Join-Path $repo ('mql\Experts\'+$name+'.mq5')}
  $expertRelative=if($name.EndsWith('Harness')){'tests\'+$name}else{$name}
  $target=Join-Path $terminalRoot ('MQL5\Experts\'+$expertRelative+'.mq5')
  Copy-Item -LiteralPath $source -Destination $target
  $sourceHashes[$name]=(Get-FileHash -LiteralPath $source).Hash
  $compileLog=Join-Path $output ($name+'.compile.log')
  $child=Start-Process -FilePath (Join-Path $terminalRoot 'MetaEditor64.exe') -ArgumentList '/portable',('/compile:"'+$target+'"'),('/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
  WaitOwned $child 180;$child=$null
  if(!(Test-Path -LiteralPath $compileLog) -or (Get-Content -LiteralPath $compileLog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings'){throw "Compile failed: $name"}
  Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($target,'.ex5')) -Destination (Join-Path $output ($name+'.ex5'))
 }
 if($CompileOnly){SaveJson @{status='COMPILED';batch_id=$batch;output=$output;source_sha256=$sourceHashes} (Join-Path $output 'status.json');Write-Output "COMPILED $output";return}
 $common=Get-Content -LiteralPath (Join-Path $SourceDataRoot 'config\common.ini') -Raw
 $server=[regex]::Match($common,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
 $privateLogin=[regex]::Match($common,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 if(!$server -or !$privateLogin){throw 'Source identity cache missing'}
 $privateTokens.Add($privateLogin)
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot ('config\'+$name)) -Destination (Join-Path $terminalRoot ('config\'+$name))}
 $base=Join-Path $SourceDataRoot ('bases\'+$server)
 foreach($file in Get-ChildItem -LiteralPath (Join-Path $base 'symbols') -File){
  foreach($m in [regex]::Matches($file.Name,'\d{5,}')){$privateTokens.Add($m.Value)}
 }
 New-Item -ItemType Directory -Path (Join-Path $terminalRoot ('bases\'+$server)) -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $base 'symbols') -Destination (Join-Path $terminalRoot ('bases\'+$server+'\symbols')) -Recurse
 $firstDate=[datetime]::ParseExact($DateFrom,'yyyy.MM.dd',[Globalization.CultureInfo]::InvariantCulture)
 $lastDate=[datetime]::ParseExact($DateTo,'yyyy.MM.dd',[Globalization.CultureInfo]::InvariantCulture)
 if($lastDate -le $firstDate){throw 'DateTo must be after DateFrom'}
 $warmup=$firstDate.AddMonths(-1)
 $historyDest=Join-Path $terminalRoot ('bases\'+$server+'\history\'+$Symbol)
 $ticksDest=Join-Path $terminalRoot ('bases\'+$server+'\ticks\'+$Symbol)
 New-Item -ItemType Directory -Path $historyDest,$ticksDest -Force|Out-Null
 $copiedHistory=@();$copiedTicks=@()
 foreach($year in $warmup.Year..$lastDate.Year){
  $name=$year.ToString()+'.hcc';$source=Join-Path $base ('history\'+$Symbol+'\'+$name)
  if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $historyDest $name);$copiedHistory+=$name}
 }
 for($month=[datetime]::new($warmup.Year,$warmup.Month,1);$month -le $lastDate;$month=$month.AddMonths(1)){
  $name=$month.ToString('yyyyMM')+'.tkc';$source=Join-Path $base ('ticks\'+$Symbol+'\'+$name)
  if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $ticksDest $name);$copiedTicks+=$name}
 }
 $privateCommon="[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`n"
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 ($privateCommon+$disabled)|Set-Content -LiteralPath (Join-Path $terminalRoot 'config\common.ini') -Encoding ASCII
 SaveJson @{batch_id=$batch;terminal_root=$terminalRoot;source_data_root=$SourceDataRoot;runtime_root=$RuntimeRoot;server=$server;symbol=$Symbol;date_from=$DateFrom;date_to=$DateTo;model=$Model;deposit=$Deposit;copied_history=$copiedHistory;copied_ticks=$copiedTicks;source_sha256=$sourceHashes;header_sha256=$headerHashes;run_order=@($runs.id);purpose='VISUAL_RECONSTRUCTION_QA_NOT_PROFITABILITY';terminal_live_trading_enabled=$false} (Join-Path $output 'provenance.json')
 $python=(Get-Command python).Source
 foreach($run in $runs){
  $runId=$run.id;$runOut=Join-Path $output $runId
  $visual=if($run.PSObject.Properties['visual']){[int]$run.visual}else{0}
  $expertRelative=if($run.expert.EndsWith('Harness')){'tests\'+$run.expert}else{$run.expert}
  New-Item -ItemType Directory -Path $runOut -Force|Out-Null
  $tag='wave33_'+$batch+'_'+$runId
  $inputs=[ordered]@{InpRunTag=$tag}
  if($run.expert -eq 'Wave33VisualVerifier'){$inputs.InpDraw='true';$inputs.InpScreenshots='true'}
  if($visual){$inputs.InpScreenshotLimit=100}
  foreach($key in $run.inputs.Keys){$inputs[$key]=$run.inputs[$key]}
  $setName=$tag+'.set';$setPath=Join-Path $terminalRoot ('MQL5\Profiles\Tester\'+$setName)
  @($inputs.GetEnumerator()|ForEach-Object{$_.Key+'='+$_.Value})|Set-Content -LiteralPath $setPath -Encoding ASCII
  Copy-Item -LiteralPath $setPath -Destination (Join-Path $runOut 'inputs.set')
  $body=$disabled+@"
[Tester]
Expert=$expertRelative.ex5
ExpertParameters=$setName
Symbol=$Symbol
Period=$($run.period)
Model=$Model
ExecutionMode=0
Optimization=0
FromDate=$DateFrom
ToDate=$DateTo
Deposit=$Deposit
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=39193
Visual=$visual
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
  $ini=Join-Path $terminalRoot ($tag+'.ini')
  ($privateCommon+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
  $body|Set-Content -LiteralPath (Join-Path $runOut 'tester_public.ini') -Encoding ASCII
  SaveJson @{run_id=$runId;tag=$tag;expert=$run.expert;inputs=$inputs;symbol=$Symbol;date_from=$DateFrom;date_to=$DateTo;chart_period=$run.period;visual_mode=[bool]$visual;model=$Model} (Join-Path $runOut 'run.json')
  SaveJson @{status='RUNNING';batch_id=$batch;run_id=$runId;output=$output} (Join-Path $output 'status.json')
  Log "Starting $runId"
  SaveJson @{terminal_sha256=(Get-FileHash -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).Hash;terminal_version=(Get-Item -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).VersionInfo.FileVersion} (Join-Path $runOut 'runtime_before.json')
  $started=[datetime]::UtcNow;$report=Join-Path $terminalRoot ($tag+'.htm')
  $windowStyle=if($visual){'Normal'}else{'Hidden'}
  $child=Start-Process -FilePath (Join-Path $terminalRoot 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle $windowStyle -PassThru
  WaitReport $child $report $started $TimeoutSecondsPerRun;$child=$null
  SaveJson @{terminal_sha256=(Get-FileHash -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).Hash;terminal_version=(Get-Item -LiteralPath (Join-Path $terminalRoot 'terminal64.exe')).VersionInfo.FileVersion} (Join-Path $runOut 'runtime_after.json')
  ArchiveLogs $runOut
  $reportText=Redact ([IO.File]::ReadAllText($report))
  $reportText|Set-Content -LiteralPath (Join-Path $runOut 'report.htm') -Encoding UTF8
  foreach($image in Get-ChildItem -LiteralPath $terminalRoot -File -Filter ($tag+'*.png')){Copy-Item -LiteralPath $image.FullName -Destination (Join-Path $runOut $image.Name)}
  $commonFiles=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
  foreach($artifact in Get-ChildItem -LiteralPath $commonFiles -File -Filter ($tag+'*')){Copy-Item -LiteralPath $artifact.FullName -Destination (Join-Path $runOut $artifact.Name.Substring($tag.Length).TrimStart('_'))}
  $harness=Join-Path $commonFiles ('W33Harness_'+$tag+'.csv')
  if(Test-Path -LiteralPath $harness){Copy-Item -LiteralPath $harness -Destination (Join-Path $runOut 'harness.csv')}
  foreach($artifact in Get-ChildItem -LiteralPath $terminalRoot -Recurse -File -Filter ($tag+'*.png')){
   $imageDir=Join-Path $runOut 'images';New-Item -ItemType Directory -Path $imageDir -Force|Out-Null
   Copy-Item -LiteralPath $artifact.FullName -Destination (Join-Path $imageDir $artifact.Name)
  }
  $eventCsv=Join-Path $runOut 'events.csv'
  if(Test-Path -LiteralPath $eventCsv){
   $imageNames=@(Import-Csv -LiteralPath $eventCsv -Delimiter ';' -Encoding UTF8|Where-Object{$_.event_type -eq 'DRAWING_CAPTURE' -and $_.reason -match '\.png$'}|Select-Object -ExpandProperty reason -Unique)
   foreach($imageName in $imageNames){
    if([IO.Path]::GetFileName($imageName) -ne $imageName){throw 'Screenshot filename must be a basename'}
    foreach($image in Get-ChildItem -LiteralPath $terminalRoot -Recurse -File -Filter $imageName){
     $imageDir=Join-Path $runOut 'images';New-Item -ItemType Directory -Path $imageDir -Force|Out-Null
     Copy-Item -LiteralPath $image.FullName -Destination (Join-Path $imageDir $image.Name)
    }
   }
  }
  & $python (Join-Path $repo 'tools\wave33_visual\analyze.py') --run $runOut
  if($LASTEXITCODE -ne 0){throw "Analysis failed: $runId"}
  Log "Completed $runId"
 }
 & $python (Join-Path $repo 'tools\wave33_visual\analyze.py') --batch $output
 if($LASTEXITCODE -ne 0){throw 'Aggregate analysis failed'}
 SaveJson @{status='COMPLETED';batch_id=$batch;completed_runs=$runs.Count;output=$output;promotion='NOT_ASSESSED';visual_human_review='PENDING'} (Join-Path $output 'status.json')
 Write-Output "COMPLETED $output"
}catch{
 if(Test-Path -LiteralPath $terminalRoot){ArchiveLogs (Join-Path $output $runId)}
 if(Test-Path -LiteralPath $output){SaveJson @{status='FAILED';run_id=$runId;reason=(Redact $_.Exception.Message);output=$output} (Join-Path $output 'status.json');Log $_.Exception.Message}
 throw
}finally{
 # Exact unique executable paths are the sole process ownership boundary.
 if($null -ne $child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 if($terminalRoot -and $terminalRoot.StartsWith((Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33\'),[StringComparison]::OrdinalIgnoreCase)){
  Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $terminalRoot 'terminal64.exe')}|Stop-Process
  Get-Process metatester64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -and $_.Path.StartsWith($terminalRoot+'\',[StringComparison]::OrdinalIgnoreCase)}|Stop-Process
 }
 if($null -ne $lock){$lock.Dispose();Remove-Item -LiteralPath (Join-Path $package 'runner.lock')}
}
