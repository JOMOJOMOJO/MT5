# Run the actual-EA synthetic wrapper in unique owned MT5 sandboxes only.
param()
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$source=Join-Path $env:LOCALAPPDATA 'CodexMT5WickRebreakR3/20261014_094513_6f6042e2'
$batch='run_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$runtime=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33PriorContext/'+$batch)
$output=Join-Path $PSScriptRoot ('native/'+$batch)
$commonFiles=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$child=$null
function SaveJson($o,$p){$o|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $p -Encoding UTF8}
function Hash($p){$h=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($p);try{return [BitConverter]::ToString($h.ComputeHash($f)).Replace('-','').ToLower()}finally{$f.Dispose();$h.Dispose()}}
try{
 foreach($p in @($runtime,$output,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts/tests'),(Join-Path $runtime 'MQL5/Profiles/Tester'))){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 foreach($name in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $runtime $name)}
 Copy-Item -LiteralPath (Join-Path $repo 'mql/Experts/tests/Wave33PriorContextHarness.ex5') -Destination (Join-Path $runtime 'MQL5/Experts/tests/Wave33PriorContextHarness.ex5')
 $identity=Get-Content -LiteralPath (Join-Path $source 'config/common.ini') -Raw
 $server=[regex]::Match($identity,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
 $login=[regex]::Match($identity,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 if(!$server -or !$login){throw 'Cached source identity missing'}
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $source ('config/'+$name)) -Destination (Join-Path $runtime ('config/'+$name))}
 $base=Join-Path $source ('bases/'+$server)
 New-Item -ItemType Directory -Path (Join-Path $runtime ('bases/'+$server)) -Force|Out-Null
 Copy-Item -LiteralPath (Join-Path $base 'symbols') -Destination (Join-Path $runtime ('bases/'+$server+'/symbols')) -Recurse
 $history=Join-Path $runtime ('bases/'+$server+'/history/XAUUSD')
 New-Item -ItemType Directory -Path $history -Force|Out-Null
 foreach($year in @(2024,2025)){Copy-Item -LiteralPath (Join-Path $base ('history/XAUUSD/'+$year+'.hcc')) -Destination (Join-Path $history ($year.ToString()+'.hcc'))}
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 $private="[Common]`r`nLogin=$login`r`nServer=$server`r`n"
 ($private+$disabled)|Set-Content -LiteralPath (Join-Path $runtime 'config/common.ini') -Encoding ASCII
 $cases=@(
  @{name='off_diag_on';filter=$false;diag=$true;orders=$false;fraction=0.05;invalid=$false},
  @{name='off_diag_off';filter=$false;diag=$false;orders=$false;fraction=0.05;invalid=$false},
  @{name='on_diag_on';filter=$true;diag=$true;orders=$false;fraction=0.05;invalid=$false},
  @{name='on_diag_off';filter=$true;diag=$false;orders=$false;fraction=0.05;invalid=$false},
  @{name='on_orders_on';filter=$true;diag=$false;orders=$true;fraction=0.05;invalid=$false},
  @{name='invalid_negative';filter=$false;diag=$true;orders=$false;fraction=-0.01;invalid=$true},
  @{name='invalid_above_one';filter=$false;diag=$true;orders=$false;fraction=1.01;invalid=$true}
 )
 $results=@()
 foreach($case in $cases){
  $tag='pc_'+$batch.Substring(4)+'_'+$results.Count
  $caseOutput=Join-Path $output $case.name
  New-Item -ItemType Directory -Path $caseOutput -Force|Out-Null
  $set="InpRunTag=$tag`r`nInpSkipPriorLevelRetest=$($case.filter.ToString().ToLower())`r`nInpPriorContext=$($case.diag.ToString().ToLower())`r`nInpChopDiagnostic=false`r`nInpSkipChoppyWave1=false`r`nInpPriorContextBandFraction=$($case.fraction)`r`nInpEnableTesterOrders=$($case.orders.ToString().ToLower())`r`nInpDraw=false`r`nInpKeepObjects=false`r`nInpScreenshots=false`r`nInpChopLabels=false`r`n"
  $set|Set-Content -LiteralPath (Join-Path $runtime ('MQL5/Profiles/Tester/'+$tag+'.set')) -Encoding ASCII
  $set|Set-Content -LiteralPath (Join-Path $caseOutput 'inputs.set') -Encoding ASCII
  $body=$disabled+@"
[Tester]
Expert=tests\Wave33PriorContextHarness.ex5
ExpertParameters=$tag.set
Symbol=XAUUSD
Period=M1
Model=2
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
Port=39225
Visual=0
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
  $body|Set-Content -LiteralPath (Join-Path $caseOutput 'tester_public.ini') -Encoding ASCII
  $ini=Join-Path $runtime ($tag+'.ini');($private+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
  $child=Start-Process -FilePath (Join-Path $runtime 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
  $watch=[Diagnostics.Stopwatch]::StartNew()
  while(!$child.WaitForExit(1000)){if($watch.Elapsed.TotalSeconds -gt 100){throw 'Owned synthetic tester timeout'}}
  # MT5 may exit its first launcher for an update and re-launch itself. A
  # successful process exit alone is not evidence of the requested test.
  $assertionsPath=Join-Path $commonFiles ($tag+'_assertions.csv')
  while(!(Test-Path -LiteralPath $assertionsPath)){
   if($watch.Elapsed.TotalSeconds -gt 100){throw 'Owned tester did not publish assertions after launcher exit'}
   Start-Sleep -Milliseconds 500
  }
  while(@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $runtime 'terminal64.exe')}).Count -gt 0){
   if($watch.Elapsed.TotalSeconds -gt 100){throw 'Owned re-launched terminal timeout'}
   Start-Sleep -Milliseconds 500
  }
  foreach($file in Get-ChildItem -LiteralPath $commonFiles -File -Filter ($tag+'*.csv')){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $caseOutput $file.Name)}
  foreach($file in Get-ChildItem -LiteralPath $runtime -Recurse -File -Filter '*.log'|Where-Object{$_.FullName -notmatch '\\temp\\'}){
   $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
   $reader=[IO.StreamReader]::new($stream)
   try{$text=$reader.ReadToEnd().Replace($login,'[ACCOUNT]')}finally{$reader.Dispose()}
   $text=[regex]::Replace($text,"'\d{5,}'","'[ACCOUNT]'")
   $relative=$file.FullName.Substring($runtime.Length+1);$dest=Join-Path $caseOutput ('journals/'+$relative)
   New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
   $text|Set-Content -LiteralPath $dest -Encoding UTF8
  }
  $unit=Import-Csv -LiteralPath (Join-Path $caseOutput ($tag+'_assertions.csv')) -Delimiter ';' -Encoding UTF8
  $bad=@($unit|Where-Object result -eq 'FAIL').Count
  $summary=@($unit|Where-Object test -eq 'SUMMARY')
  $eventPath=Join-Path $caseOutput ($tag+'_events.csv'); $events=if(Test-Path -LiteralPath $eventPath){Import-Csv -LiteralPath $eventPath -Delimiter ';' -Encoding UTF8}else{@()}
  $signals=@($events|Where-Object event_type -eq 'SIGNAL').Count
  $skips=@($events|Where-Object {$_.event_type -eq 'SKIP' -and $_.reason -eq 'PRIOR_LEVEL_RETEST'}).Count
  $disabledOrders=@($events|Where-Object event_type -eq 'ORDER_DISABLED').Count
  $orders=@($events|Where-Object event_type -eq 'ORDER').Count
  $wantedSignals=if($case.invalid){0}elseif($case.orders){4}else{12}
  $wantedSkips=if($case.invalid){0}elseif($case.filter){4}else{0}
  $wantedDisabled=if($case.invalid -or $case.orders){0}elseif($case.filter){8}else{12}
  $ok=$bad -eq 0 -and $summary.Count -eq 1 -and $summary[0].result -eq 'PASS' -and $signals -eq $wantedSignals -and $skips -eq $wantedSkips -and $disabledOrders -eq $wantedDisabled -and $orders -eq 0
  $result=@{case=$case.name;status=$(if($ok){'PASS'}else{'FAIL'});tag=$tag;checks=($unit.Count-1);failures=$bad;signals=$signals;context_skips=$skips;order_disabled=$disabledOrders;order_events=$orders;filter=$case.filter;diagnostic=$case.diag;orders_input=$case.orders;invalid_input=$case.invalid;band_fraction=$case.fraction;output=$caseOutput}
  SaveJson $result (Join-Path $caseOutput 'result.json');$results+=$result
  Write-Output "$($result.status) $($case.name) checks=$($result.checks) failures=$bad signal=$signals skip=$skips disabled=$disabledOrders orders=$orders"
  if(!$ok){throw 'Native assertion or event accounting failed'}
 }
 SaveJson @{status='PASS';purpose='ACTUAL_EA_SIGNAL_GATE_SYNTHETIC_NO_ORDERS';runtime=$runtime;batch=$batch;cases=$results;harness_source_sha256=(Hash (Join-Path $repo 'mql/Experts/tests/Wave33PriorContextHarness.mq5'));ea_source_sha256=(Hash (Join-Path $repo 'mql/Experts/Wave33ChopDiagnostic.mq5'));harness_ex5_sha256=(Hash (Join-Path $repo 'mql/Experts/tests/Wave33PriorContextHarness.ex5'));context_source_sha256=(Hash (Join-Path $repo 'mql/Include/Wave33Visual/PriorContext.mqh'))} (Join-Path $output 'result.json')
 SaveJson @{status='PASS';output=$output;batch=$batch;cases=$results} (Join-Path $PSScriptRoot 'native_latest.json')
}catch{
 SaveJson @{status='FAIL';reason=$_.Exception.Message;runtime=$runtime;batch=$batch} (Join-Path $output 'failure.json');throw
}finally{
 if($child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 Get-Process metatester64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -and $_.Path.StartsWith($runtime+'\',[StringComparison]::OrdinalIgnoreCase)}|Stop-Process
}
