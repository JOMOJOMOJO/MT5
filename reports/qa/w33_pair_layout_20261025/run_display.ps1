# Normal-chart, draw-only fixture. Synthetic 2025 bars, no strategy or orders.
param()
$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$native=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'native_latest.json') -Raw -Encoding UTF8|ConvertFrom-Json
$source=$native.runtime;$batch='run_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$runtime=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33LabelReplay/'+$batch);$output=Join-Path $PSScriptRoot ('display/'+$batch)
$common=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files';$tag='ld_'+$batch.Substring(4);$child=$null
function SaveJson($o,$p){$o|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $p -Encoding UTF8}
function Hash($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
try{
 foreach($p in @($runtime,$output,(Join-Path $runtime 'config'),(Join-Path $runtime 'MQL5/Experts/tests'),(Join-Path $runtime 'MQL5/Presets'))){New-Item -ItemType Directory -Path $p -Force|Out-Null}
 Copy-Item -LiteralPath (Join-Path $source 'terminal64.exe') -Destination (Join-Path $runtime 'terminal64.exe')
 foreach($name in @('accounts.dat','servers.dat','common.ini')){Copy-Item -LiteralPath (Join-Path $source ('config/'+$name)) -Destination (Join-Path $runtime ('config/'+$name))}
 Copy-Item -LiteralPath (Join-Path $source 'bases') -Destination (Join-Path $runtime 'bases') -Recurse
 Copy-Item -LiteralPath (Join-Path $repo 'mql/Experts/tests/Wave33LabelReplay.ex5') -Destination (Join-Path $runtime 'MQL5/Experts/tests/Wave33LabelReplay.ex5')
 $private=Get-Content -LiteralPath (Join-Path $runtime 'config/common.ini') -Raw;$login=[regex]::Match($private,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 ('InpRunTag='+$tag)|Set-Content -LiteralPath (Join-Path $runtime ('MQL5/Presets/'+$tag+'.set')) -Encoding ASCII
 $startup="`r`n[Charts]`r`nMaxBars=100000`r`n[StartUp]`r`nExpert=tests\Wave33LabelReplay`r`nExpertParameters=$tag.set`r`nSymbol=XAUUSD`r`nPeriod=M1`r`n"
 $ini=Join-Path $runtime ($tag+'.ini');($private+$startup)|Set-Content -LiteralPath $ini -Encoding ASCII
 $startup|Set-Content -LiteralPath (Join-Path $output 'startup_public.ini') -Encoding ASCII
 $child=Start-Process -FilePath (Join-Path $runtime 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
 $clock=[Diagnostics.Stopwatch]::StartNew();$assertion=Join-Path $common ($tag+'_assertions.csv')
 do{
  Start-Sleep -Milliseconds 500;$ready=Test-Path -LiteralPath $assertion
  $owned=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $runtime 'terminal64.exe')})
  if($clock.Elapsed.TotalSeconds -gt 90){throw 'Owned draw-only terminal timeout'}
 }while(!$ready -or $owned.Count -gt 0)
 foreach($file in Get-ChildItem -LiteralPath $common -File -Filter ($tag+'*')){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $output $file.Name)}
 foreach($file in Get-ChildItem -LiteralPath $runtime -File -Recurse -Filter '*.log'){$dest=Join-Path $output ('journals/'+$file.FullName.Substring($runtime.Length+1));New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null;$text=Get-Content -LiteralPath $file.FullName -Raw;$text=$text.Replace($login,'[ACCOUNT]');$text=[regex]::Replace($text,"'\d{5,}'","'[ACCOUNT]'");$text|Set-Content -LiteralPath $dest -Encoding UTF8}
 $rows=Import-Csv -LiteralPath (Join-Path $output ($tag+'_assertions.csv')) -Delimiter ';' -Encoding UTF8;$summary=@($rows|Where-Object test -eq 'SUMMARY');$bad=@($rows|Where-Object {$_.result -eq 'FAIL' -and $_.test -ne 'SUMMARY'}).Count
 $images=@(Get-ChildItem -LiteralPath $output -File -Filter '*_dense_*.png');$ok=$summary.Count -eq 1 -and $summary[0].result -eq 'PASS' -and $bad -eq 0 -and $images.Count -eq 2
 $hashes=@{};foreach($relative in @('mql/Experts/tests/Wave33LabelReplay.mq5','mql/Experts/tests/Wave33LabelReplay.ex5','mql/Include/Wave33Visual/ChopDisplay.mqh','mql/Include/Wave33Visual/LabelLayout.mqh','mql/Include/Wave33Visual/Display.mqh','mql/Include/Wave33Visual/Types.mqh')){$hashes[$relative]=Hash (Join-Path $repo $relative)}
 $result=@{status=$(if($ok){'PASS'}else{'FAIL'});mode='NORMAL_CHART_LAYOUT_FIXTURE';output=$output;runtime=$runtime;tag=$tag;checks=[int][regex]::Match($summary[0].detail,'^(\d+) checks').Groups[1].Value;failures=$bad;screenshots=@($images|ForEach-Object{@{path=$_.FullName;sha256=(Hash $_.FullName)}});source_hashes=$hashes;scope='Synthetic 2025 custom-symbol bars; draw only, no order functions/account queries; not a tester screenshot or strategy performance test'}
 SaveJson $result (Join-Path $output 'result.json');SaveJson $result (Join-Path $PSScriptRoot 'display_latest.json');Write-Output "$($result.status) NORMAL_CHART_LAYOUT_FIXTURE checks=$($result.checks) failures=$bad images=$($images.Count)"
 if(!$ok){throw 'Normal-chart fixture assertion or PNG capture failed'}
}catch{SaveJson @{status='FAIL';runtime=$runtime;output=$output;reason=$_.Exception.Message} (Join-Path $output 'failure.json');throw
}finally{if($child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null};Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq (Join-Path $runtime 'terminal64.exe')}|Stop-Process}
