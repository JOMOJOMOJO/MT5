# Short native execution checks in a task-owned portable MT5. Existing terminals are untouched.
param()
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$source=Join-Path $env:LOCALAPPDATA 'CodexMT5WickRebreakR3/20261014_094513_6f6042e2'
$batch='r'+[guid]::NewGuid().ToString('N').Substring(0,7)
$runtime=Join-Path $env:LOCALAPPDATA ('W33SO/'+$batch)
$output=Join-Path $PSScriptRoot ('native/'+$batch)
$common=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$child=$null
function SaveJson($value,$path){$value|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $path -Encoding UTF8}
function Hash($path){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()}
$frozen=@{}
foreach($relative in @('mql/Experts/Wave33ChopDiagnostic.mq5','mql/Include/Wave33Visual/ScaleOut.mqh','mql/Include/Wave33Visual/ScaleOutExecution.mqh','mql/Include/Wave33Visual/LabelLayout.mqh','mql/Experts/tests/Wave33ScaleOutHarness.mq5','mql/Experts/tests/Wave33ScaleOutHarness.ex5')){$frozen[$relative]=Hash (Join-Path $repo $relative)}
try{
 foreach($p in @($runtime,$output,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts/tests'),(Join-Path $runtime 'MQL5/Profiles/Tester'))){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 foreach($name in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $runtime $name)}
 Copy-Item -LiteralPath (Join-Path $repo 'mql/Experts/tests/Wave33ScaleOutHarness.ex5') -Destination (Join-Path $runtime 'MQL5/Experts/tests/Wave33ScaleOutHarness.ex5')
 $identity=Get-Content -LiteralPath (Join-Path $source 'config/common.ini') -Raw
 $server=[regex]::Match($identity,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim();$login=[regex]::Match($identity,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 if(!$server -or !$login){throw 'Cached source identity missing'}
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $source ('config/'+$name)) -Destination (Join-Path $runtime ('config/'+$name))}
 $base=Join-Path $source ('bases/'+$server);New-Item -ItemType Directory -Path (Join-Path $runtime ('bases/'+$server)) -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $base 'symbols') -Destination (Join-Path $runtime ('bases/'+$server+'/symbols')) -Recurse
 $history=Join-Path $runtime ('bases/'+$server+'/history/XAUUSD');New-Item -ItemType Directory -Path $history -Force|Out-Null
 foreach($year in @(2024,2025)){Copy-Item -LiteralPath (Join-Path $base ('history/XAUUSD/'+$year+'.hcc')) -Destination (Join-Path $history ($year.ToString()+'.hcc'))}
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n";$private="[Common]`r`nLogin=$login`r`nServer=$server`r`n"
 ($private+$disabled)|Set-Content -LiteralPath (Join-Path $runtime 'config/common.ini') -Encoding ASCII
 $cases=@(@{name='long';direction=1;enabled=$true;w1=$false;single=$false;rr=0.02;risk=1},@{name='short';direction=-1;enabled=$true;w1=$false;single=$false;rr=0.02;risk=1},@{name='w1long';direction=1;enabled=$true;w1=$true;single=$false;rr=1;risk=1},@{name='w1short';direction=-1;enabled=$true;w1=$true;single=$false;rr=1;risk=1},@{name='minlot';direction=1;enabled=$true;w1=$false;single=$true;rr=0.02;risk=0.15},@{name='off';direction=1;enabled=$false;w1=$false;single=$false;rr=0.02;risk=1})
 $results=@()
 foreach($case in $cases){
  $tag='so_'+$batch+'_'+$case.name;$out=Join-Path $output $case.name;New-Item -ItemType Directory -Path $out -Force|Out-Null
  $set="InpRunTag=$tag`r`nInpPattern=$([int]$case.w1)`r`nInpQADirection=$($case.direction)`r`nInpQAW1First=$($case.w1.ToString().ToLower())`r`nInpQAExpectSingle=$($case.single.ToString().ToLower())`r`nInpQAInjectErrors=$(([bool]($case.name -eq 'long')).ToString().ToLower())`r`nInpRewardR=$($case.rr)`r`nInpRiskPercent=$($case.risk)`r`nInpMinWave1RoomR=0`r`nInpScaleOut=$($case.enabled.ToString().ToLower())`r`nInpEnableTesterOrders=true`r`nInpDraw=false`r`nInpKeepObjects=true`r`nInpPriorContext=false`r`nInpSkipPriorLevelRetest=false`r`nInpChopDiagnostic=false`r`nInpChopLabels=false`r`nInpSkipChoppyWave1=false`r`nInpScreenshots=false`r`nInpAuditOppositeExitTicks=true`r`n"
  $set|Set-Content -LiteralPath (Join-Path $runtime ('MQL5/Profiles/Tester/'+$tag+'.set')) -Encoding ASCII;$set|Set-Content -LiteralPath (Join-Path $out 'inputs.set') -Encoding ASCII
  $body=$disabled+@"
[Tester]
Expert=tests\Wave33ScaleOutHarness.ex5
ExpertParameters=$tag.set
Symbol=XAUUSD
Period=M1
Model=0
ExecutionMode=0
Optimization=0
FromDate=2025.01.06
ToDate=2025.01.07
Deposit=10000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=39228
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
  $body|Set-Content -LiteralPath (Join-Path $out 'tester_public.ini') -Encoding ASCII;$ini=Join-Path $runtime ($tag+'.ini');($private+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
  $child=Start-Process -FilePath (Join-Path $runtime 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
  $watch=[Diagnostics.Stopwatch]::StartNew();while(!$child.WaitForExit(500)){if($watch.Elapsed.TotalSeconds -gt 180){throw 'Owned native tester timeout'}}
  $assertions=Join-Path $common ($tag+'_assertions.csv');while(!(Test-Path -LiteralPath $assertions)){if($watch.Elapsed.TotalSeconds -gt 180){throw 'Tester assertions not found'};Start-Sleep -Milliseconds 500}
  while(@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $runtime 'terminal64.exe')}).Count -gt 0){if($watch.Elapsed.TotalSeconds -gt 180){throw 'Owned relaunched terminal timeout'};Start-Sleep -Milliseconds 500}
  foreach($file in Get-ChildItem -LiteralPath $common -File -Filter ($tag+'*')){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $out $file.Name)}
  $artifacts=@();$artifactIndex=0
  foreach($file in Get-ChildItem -LiteralPath $runtime -Recurse -File|Where-Object{$_.Extension -in @('.log','.htm') -and $_.FullName -notmatch '\\temp\\'}){
   $relative=$file.FullName.Substring($runtime.Length+1);$flat=('{0:D2}' -f $artifactIndex)+'_'+$file.Name;$artifactIndex++;$dest=Join-Path $out ('artifacts/'+$flat);$artifacts+=@{source_relative=$relative;saved_relative=('artifacts/'+$flat)};New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
   $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);$reader=[IO.StreamReader]::new($stream);try{$text=$reader.ReadToEnd().Replace($login,'[ACCOUNT]')}finally{$reader.Dispose()};$text=[regex]::Replace($text,"'\d{5,}'","'[ACCOUNT]'");$text|Set-Content -LiteralPath $dest -Encoding UTF8
  }
  SaveJson $artifacts (Join-Path $out 'artifacts_index.json')
  $rows=Import-Csv -LiteralPath (Join-Path $out ($tag+'_assertions.csv')) -Delimiter ';' -Encoding UTF8;$bad=@($rows|Where-Object {$_.result -eq 'FAIL' -and $_.test -ne 'SUMMARY'}).Count;$summary=@($rows|Where-Object test -eq 'SUMMARY')
  $ok=$bad -eq 0 -and $summary.Count -eq 1 -and $summary[0].result -eq 'PASS';$checks=if($summary.Count -eq 1){[int][regex]::Match($summary[0].detail,'^(\d+) checks').Groups[1].Value}else{0}
  $result=@{case=$case.name;status=$(if($ok){'PASS'}else{'FAIL'});tag=$tag;checks=$checks;failures=$bad;scaleout=$case.enabled;w1_first=$case.w1;single_fallback=$case.single;direction=$case.direction;output=$out};SaveJson $result (Join-Path $out 'result.json');$results+=$result;Write-Output "$($result.status) $($case.name) checks=$checks failures=$bad"
  if(!$ok){throw 'Native assertion failed'}
 }
 foreach($relative in $frozen.Keys){if($frozen[$relative] -ne (Hash (Join-Path $repo $relative))){throw ('Source changed during native QA: '+$relative)}}
 $result=@{status='PASS';purpose='NATIVE_REAL_ORDER_SCALEOUT_CALLBACK_ACCOUNTING';batch=$batch;runtime=$runtime;cases=$results;source_hashes=$frozen;harness_source_sha256=$frozen['mql/Experts/tests/Wave33ScaleOutHarness.mq5'];ea_source_sha256=$frozen['mql/Experts/Wave33ChopDiagnostic.mq5'];policy_sha256=$frozen['mql/Include/Wave33Visual/ScaleOut.mqh'];execution_source_sha256=$frozen['mql/Include/Wave33Visual/ScaleOutExecution.mqh'];harness_ex5_sha256=$frozen['mql/Experts/tests/Wave33ScaleOutHarness.ex5']};SaveJson $result (Join-Path $output 'result.json');SaveJson $result (Join-Path $PSScriptRoot 'native_latest.json')
}catch{SaveJson @{status='FAIL';reason=$_.Exception.Message;batch=$batch;runtime=$runtime} (Join-Path $output 'failure.json');throw
}finally{if($child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null};Get-Process metatester64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -and $_.Path.StartsWith($runtime+'\',[StringComparison]::OrdinalIgnoreCase)}|Stop-Process}
