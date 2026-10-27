# Dedicated no-order synthetic/parity harness. Never attach to installed terminals.
param([string]$ParityFile='reports/qa/w33chop/parity_input.csv',[switch]$VisualProbe)
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$source=Join-Path $env:LOCALAPPDATA 'CodexMT5WickRebreakR3/20261014_094513_6f6042e2'
$batch=(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$runtime=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33Chop/'+$batch)
$output=Join-Path $PSScriptRoot ('native/'+$batch)
$tag='w33chop_'+$batch
$commonFiles=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$child=$null
function SaveJson($o,$p){$o|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $p -Encoding UTF8}
function Hash($p){$h=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($p);try{return [BitConverter]::ToString($h.ComputeHash($f)).Replace('-','').ToLower()}finally{$f.Dispose();$h.Dispose()}}
try{
 foreach($p in @($runtime,$output,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts/tests'),(Join-Path $runtime 'MQL5/Profiles/Tester'))){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 foreach($name in @('terminal64.exe','metatester64.exe')){Copy-Item -LiteralPath (Join-Path $source $name) -Destination (Join-Path $runtime $name)}
 Copy-Item -LiteralPath (Join-Path $repo 'mql/Experts/tests/Wave33ChopHarness.ex5') -Destination (Join-Path $runtime 'MQL5/Experts/tests/Wave33ChopHarness.ex5')
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
 $parityName=$tag+'_input.csv'
 $resolvedParity=if([IO.Path]::IsPathRooted($ParityFile)){$ParityFile}else{Join-Path $repo $ParityFile}
 Copy-Item -LiteralPath $resolvedParity -Destination (Join-Path $commonFiles $parityName)
 $set="InpOutputTag=$tag`r`nInpParityFile=$parityName`r`n"
 $set|Set-Content -LiteralPath (Join-Path $runtime ('MQL5/Profiles/Tester/'+$tag+'.set')) -Encoding ASCII
 $set|Set-Content -LiteralPath (Join-Path $output 'inputs.set') -Encoding ASCII
 $visual=[int][bool]$VisualProbe
 $body=$disabled+@"
[Tester]
Expert=tests\Wave33ChopHarness.ex5
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
Port=39204
Visual=$visual
ReplaceReport=0
ShutdownTerminal=1
Report=$tag
"@
 $body|Set-Content -LiteralPath (Join-Path $output 'tester_public.ini') -Encoding ASCII
 $ini=Join-Path $runtime ($tag+'.ini');($private+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
 SaveJson @{status='RUNNING';purpose='SYNTHETIC_AND_60_CASE_CORE_PARITY_NO_ORDERS';runtime=$runtime;tag=$tag;ea_sha256=(Hash (Join-Path $repo 'mql/Experts/tests/Wave33ChopHarness.mq5'));ex5_sha256=(Hash (Join-Path $repo 'mql/Experts/tests/Wave33ChopHarness.ex5'));input_sha256=(Hash $resolvedParity)} (Join-Path $output 'status.json')
 $child=Start-Process -FilePath (Join-Path $runtime 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
 $watch=[Diagnostics.Stopwatch]::StartNew()
 while(!$child.WaitForExit(1000)){if($watch.Elapsed.TotalSeconds -gt 180){throw 'Owned no-order harness timeout'}}
 foreach($file in Get-ChildItem -LiteralPath $runtime -Recurse -File -Filter '*.log'){
  $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
  $reader=[IO.StreamReader]::new($stream)
  try{$text=$reader.ReadToEnd().Replace($login,'[ACCOUNT]')}finally{$reader.Dispose()}
  $text=[regex]::Replace($text,"'\d{5,}'","'[ACCOUNT]'")
  $relative=$file.FullName.Substring($runtime.Length+1);$dest=Join-Path $output ('journals/'+$relative)
  New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
  $text|Set-Content -LiteralPath $dest -Encoding UTF8
 }
 foreach($name in @(($tag+'.csv'),($tag+'_parity.csv'))){Copy-Item -LiteralPath (Join-Path $commonFiles $name) -Destination (Join-Path $output $name)}
 $unit=Import-Csv -LiteralPath (Join-Path $output ($tag+'.csv')) -Delimiter ';'
 $parity=Import-Csv -LiteralPath (Join-Path $output ($tag+'_parity.csv')) -Delimiter ';'
 $bad=@($unit|Where-Object result -eq 'FAIL').Count+@($parity|Where-Object result -eq 'FAIL').Count
 $summary=@($unit|Where-Object test -eq 'SUMMARY')
 if($bad -gt 0 -or $parity.Count -ne 60 -or $summary.Count -ne 1 -or $summary[0].result -ne 'PASS'){throw "Native harness assertions failed: $bad failures, $($parity.Count) parity cases"}
 SaveJson @{status='PASS';purpose='SYNTHETIC_AND_60_CASE_CORE_PARITY_NO_ORDERS';runtime=$runtime;tag=$tag;synthetic_checks=($unit.Count-1);parity_checks=$parity.Count;failures=$bad;orders=0;input_sha256=(Hash $resolvedParity)} (Join-Path $output 'result.json')
 SaveJson @{status='PASS';output=$output;tag=$tag} (Join-Path $PSScriptRoot 'native_latest.json')
 Write-Output "PASS synthetic=$($unit.Count-1) parity=$($parity.Count) orders=0 output=$output"
}catch{
 SaveJson @{status='FAIL';reason=$_.Exception.Message;runtime=$runtime;tag=$tag} (Join-Path $output 'result.json')
 throw
}finally{
 if($child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 # Stop only helpers whose executable path is inside this unique owned sandbox.
 Get-Process metatester64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -and $_.Path.StartsWith($runtime+'\',[StringComparison]::OrdinalIgnoreCase)}|Stop-Process
}
