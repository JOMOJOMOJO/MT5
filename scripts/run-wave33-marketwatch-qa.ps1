# Fixed-input engineering reproduction of MT5's Market Watch symbol batch.
# Optimization=3 is documented by MetaQuotes; this is not a parameter search.
[CmdletBinding()]
param(
 [string]$SourceDataRoot="$env:APPDATA\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675",
 [string]$RuntimeRoot="$env:LOCALAPPDATA\CodexMT5Wave33\20261021_235636_802a6036",
 [string]$OutputRoot='reports\qa\w33mw',
 [string]$DateFrom='2020.10.01',
 [string]$DateTo='2020.10.10',
 [ValidateSet(1,4)][int]$Model=4,
 [ValidateRange(60,3600)][int]$TimeoutSeconds=900,
 [ValidateRange(1,30)][int]$MaxSymbols=20,
 [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$package=if([IO.Path]::IsPathRooted($OutputRoot)){[IO.Path]::GetFullPath($OutputRoot)}else{[IO.Path]::GetFullPath((Join-Path $repo $OutputRoot))}
if(!$package.StartsWith($repo+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'OutputRoot must remain inside the repository'}
$first=[datetime]::ParseExact($DateFrom,'yyyy.MM.dd',[Globalization.CultureInfo]::InvariantCulture)
$last=[datetime]::ParseExact($DateTo,'yyyy.MM.dd',[Globalization.CultureInfo]::InvariantCulture)
if($last -le $first -or ($last-$first).TotalDays -gt 14){throw 'Use one bounded interval of at most 14 days'}
if(!$Execute){Write-Output "PREVIEW: compile a fresh isolated portable runtime; copy active Market Watch and bounded histories; Optimization=3, M15/M5, RR1, 5000USD, Model$Model, fixed inputs; $DateFrom through $DateTo (end exclusive). No installed terminal is changed.";return}
$batch='mw_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$output=Join-Path $package $batch
if((Join-Path $output 'passes\12345678901234567890\opposite_ticks.csv').Length -ge 260){throw 'Choose a shorter OutputRoot to respect Windows path limits'}
New-Item -ItemType Directory -Path $output -Force|Out-Null
$privateTokens=New-Object System.Collections.Generic.List[string]
$terminalRoot='';$child=$null;$lock=$null
$tag='w33mw_'+[guid]::NewGuid().ToString('N').Substring(0,8)
function SaveJson($Value,[string]$Path){$Value|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $Path -Encoding UTF8}
function Hash([string]$Path){if(Test-Path -LiteralPath $Path -PathType Leaf){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash};return $null}
function Redact([string]$Text){
 foreach($token in $privateTokens){if($token){$Text=$Text.Replace($token,'[ACCOUNT]')}}
 $Text=[regex]::Replace($Text,'(?im)((?:password|login|account)\s*[=:]\s*)\S+','$1[REDACTED]')
 return [regex]::Replace($Text,"'\d{5,}'","'[ACCOUNT]'")
}
function ArchiveLogs{
 foreach($folder in @('logs','Tester')){
  $base=Join-Path $terminalRoot $folder
  if(!(Test-Path -LiteralPath $base)){continue}
  foreach($file in Get-ChildItem -LiteralPath $base -Recurse -File -Filter '*.log'){
   $target=Join-Path $output ('journals\'+$file.FullName.Substring($terminalRoot.Length+1))
   New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force|Out-Null
   $stream=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
   $reader=$null
   try{$reader=[IO.StreamReader]::new($stream);$logText=$reader.ReadToEnd();Redact $logText|Set-Content -LiteralPath $target -Encoding UTF8}finally{if($reader){$reader.Dispose()}else{$stream.Dispose()}}
  }
 }
}
function SourceSnapshot{
 return @{market_watch_selected=(Hash $selectedFile);common_ini=(Hash (Join-Path $SourceDataRoot 'config\common.ini'));account_cache=(Hash (Join-Path $SourceDataRoot 'config\accounts.dat'));server_cache=(Hash (Join-Path $SourceDataRoot 'config\servers.dat'))}
}
try{
 $lock=[IO.File]::Open((Join-Path $package 'marketwatch_runner.lock'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 $common=[IO.File]::ReadAllText((Join-Path $SourceDataRoot 'config\common.ini'))
 $privateLogin=[regex]::Match($common,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 $server=[regex]::Match($common,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
 if(!$privateLogin -or $server -ne 'Bybit-Live'){throw 'Expected cached Bybit-Live identity is unavailable; no authentication is attempted'}
 $privateTokens.Add($privateLogin)
 $sourceBase=Join-Path $SourceDataRoot ('bases\'+$server)
 $symbolsRoot=Join-Path $sourceBase 'symbols'
 $selectedFile=Join-Path $symbolsRoot ('selected-'+$privateLogin+'.dat')
 if(!(Test-Path -LiteralPath $selectedFile)){throw 'Active cached Market Watch selection is missing'}
 foreach($file in Get-ChildItem -LiteralPath $symbolsRoot -File){foreach($match in [regex]::Matches($file.Name,'\d{5,}')){$privateTokens.Add($match.Value)}}
 # Intersect UTF-16 symbol records with native history folder names, including
 # empty history folders. This file may also contain conversion-symbol records;
 # its decoded names are an inventory, not an authoritative pass count.
 # The unmodified native selection file determines Optimization=3's targets.
 $historySymbols=@(Get-ChildItem -LiteralPath (Join-Path $sourceBase 'history') -Directory|Select-Object -ExpandProperty Name)
 $decoded=[Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($selectedFile))
 $symbols=@([regex]::Matches($decoded,'[A-Za-z0-9_.#+-]{3,}')|ForEach-Object Value|Where-Object{$_ -in $historySymbols}|Select-Object -Unique)
 if($symbols.Count -lt 2 -or $symbols.Count -gt $MaxSymbols){throw "Market Watch selected-count outside bounded QA limit: $($symbols.Count)"}
 if('XAUUSD+' -notin $symbols){throw 'Expected seed symbol XAUUSD+ is not selected'}
 $before=SourceSnapshot
 SaveJson @{status='COMPILING';output=$output;tag=$tag;cached_selection_symbol_records=$symbols;cache_record_count=$symbols.Count} (Join-Path $output 'status.json')
 $compileMessages=@(& (Join-Path $PSScriptRoot 'run-wave33-visual-qa.ps1') -RuntimeRoot $RuntimeRoot -SourceDataRoot $SourceDataRoot -OutputRoot (Join-Path $output 'compile') -CompileOnly)
 $compileLine=@($compileMessages|Where-Object{$_ -is [string] -and $_.StartsWith('COMPILED ')})
 if($compileLine.Count -ne 1){throw 'Canonical CompileOnly did not identify its fresh runtime'}
 $compiled=$compileLine[0].Substring(9)
 $terminalRoot=Join-Path $env:LOCALAPPDATA ('CodexMT5Wave33\'+(Split-Path -Leaf $compiled))
 $allowed=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33')).TrimEnd('\')+'\'
 if(!$terminalRoot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Fresh runtime escaped its allowed root'}
 $terminalExe=Join-Path $terminalRoot 'terminal64.exe'
 if(!(Test-Path -LiteralPath (Join-Path $terminalRoot 'MQL5\Include\Wave33Visual\TesterRun.mqh'))){throw 'TesterRun.mqh has not been prepared'}
 $main=Get-Content -LiteralPath (Join-Path $terminalRoot 'MQL5\Experts\Wave33VisualVerifier.mq5') -Raw
 if($main -notmatch 'input\s+bool\s+InpAllowTesterBatchRuns\b'){throw 'Batch-compatible main is not ready'}
 foreach($name in @('accounts.dat','servers.dat')){Copy-Item -LiteralPath (Join-Path $SourceDataRoot ('config\'+$name)) -Destination (Join-Path $terminalRoot ('config\'+$name))}
 $targetBase=Join-Path $terminalRoot ('bases\'+$server)
 New-Item -ItemType Directory -Path $targetBase -Force|Out-Null
 Copy-Item -LiteralPath $symbolsRoot -Destination (Join-Path $targetBase 'symbols') -Recurse
 $historyManifest=@()
 $warmup=$first.AddMonths(-1)
 foreach($symbol in $symbols){
  $historyTarget=Join-Path $targetBase ('history\'+$symbol)
  $tickTarget=Join-Path $targetBase ('ticks\'+$symbol)
  New-Item -ItemType Directory -Path $historyTarget,$tickTarget -Force|Out-Null
  $history=@();$ticks=@()
  foreach($year in $warmup.Year..$last.Year){
   $name=$year.ToString()+'.hcc';$source=Join-Path $sourceBase ('history\'+$symbol+'\'+$name)
   if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $historyTarget $name);$history+=@{file=$name;bytes=(Get-Item -LiteralPath $source).Length;sha256=(Hash $source)}}
  }
  for($month=[datetime]::new($warmup.Year,$warmup.Month,1);$month -le $last;$month=$month.AddMonths(1)){
   $name=$month.ToString('yyyyMM')+'.tkc';$source=Join-Path $sourceBase ('ticks\'+$symbol+'\'+$name)
   if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $tickTarget $name);$ticks+=@{file=$name;bytes=(Get-Item -LiteralPath $source).Length;sha256=(Hash $source)}}
  }
  $historyManifest+=@{symbol=$symbol;cached_history_available=($history.Count -gt 0);history=$history;real_tick_cache=$ticks}
 }
 $privateCommon="[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`n"
 $disabled="[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 ($privateCommon+$disabled)|Set-Content -LiteralPath (Join-Path $terminalRoot 'config\common.ini') -Encoding ASCII
 $inputs=[ordered]@{InpRunTag=$tag;InpAllowTesterBatchRuns='true';InpPattern=0;InpTriggerMode=0;InpEnableTesterOrders='true';InpExtendWave1BeforeFib='true';InpExitOnOppositeWave1='true';InpAuditOppositeExitTicks='true';InpRejectDeepFib='false';InpRejectDeepFibClose='true';InpStrictWaveLifecycle='true';InpLowerRecognition=2;InpMinWave1RoomR=0.25;InpRewardR=1.0;InpRiskPercent=1.0;InpMagic='3320261022';InpDraw='false';InpScreenshots='false'}
 $setName=$tag+'.set';$setPath=Join-Path $terminalRoot ('MQL5\Profiles\Tester\'+$setName)
 @($inputs.GetEnumerator()|ForEach-Object{$_.Key+'='+$_.Value})|Set-Content -LiteralPath $setPath -Encoding ASCII
 Copy-Item -LiteralPath $setPath -Destination (Join-Path $output 'inputs.set')
 $port=Get-Random -Minimum 41000 -Maximum 51000
 $body=$disabled+@"
[Tester]
Expert=Wave33VisualVerifier.ex5
ExpertParameters=$setName
Symbol=XAUUSD+
Period=M5
Model=$Model
ExecutionMode=0
Optimization=3
OptimizationCriterion=0
FromDate=$DateFrom
ToDate=$DateTo
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
Report=$tag.xml
"@
 $ini=Join-Path $terminalRoot ($tag+'.ini')
 ($privateCommon+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
 $body|Set-Content -LiteralPath (Join-Path $output 'tester_public.ini') -Encoding ASCII
 $commonFiles=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
 if(@(Get-ChildItem -LiteralPath $commonFiles -File -Filter ($tag+'*')).Count){throw 'Fresh run tag already has outputs'}
 $provenance=@{purpose='MARKETWATCH_BATCH_ENGINEERING_QA_NOT_PARAMETER_SEARCH';official_optimization_reference='https://www.metatrader5.com/en/terminal/help/start_advanced/start';optimization=3;fixed_inputs=$inputs;date_from=$DateFrom;date_to_exclusive=$DateTo;model=$Model;real_ticks_verified=$false;deposit=5000;currency='USD';selected_symbols=$symbols;expected_selected_passes=$symbols.Count;history=$historyManifest;source_selection_sha256=$before.market_watch_selected;source_snapshot_before=$before;compile_output=$compiled;runtime=$terminalRoot;terminal_sha256=(Hash $terminalExe);ea_sha256=(Hash (Join-Path $terminalRoot 'MQL5\Experts\Wave33VisualVerifier.ex5'));runner_sha256=(Hash $PSCommandPath);remote_agents=$false;cloud_agents=$false;normal_chart_trading=$false}
 SaveJson $provenance (Join-Path $output 'provenance.json')
 SaveJson @{status='RUNNING';tag=$tag;output=$output;runtime=$terminalRoot} (Join-Path $output 'status.json')
 $started=[datetime]::UtcNow
 $child=Start-Process -FilePath $terminalExe -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while($true){
  $owned=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $terminalExe})
  if($child.HasExited -and $owned.Count -eq 0){break}
  if($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds){throw 'Owned Market Watch batch exceeded bounded timeout'}
  Start-Sleep -Milliseconds 1000
 }
 $child=$null
 ArchiveLogs
 $reports=@(Get-ChildItem -LiteralPath $terminalRoot -Recurse -File -Filter ($tag+'*.xml')|Where-Object{$_.LastWriteTimeUtc -ge $started})
 foreach($report in $reports){Redact ([IO.File]::ReadAllText($report.FullName))|Set-Content -LiteralPath (Join-Path $output $report.Name) -Encoding UTF8}
 $passes=@();$allEvents=@();$artifactNames=@()
 foreach($eventFile in Get-ChildItem -LiteralPath $commonFiles -File -Filter ($tag+'*_events.csv')){
  $resolved=$eventFile.Name.Substring(0,$eventFile.Name.Length-'_events.csv'.Length)
  $configuration=Join-Path $commonFiles ($resolved+'_config.csv')
  if(!(Test-Path -LiteralPath $configuration)){throw 'An event artifact lacks its configuration snapshot'}
  $config=@{};Import-Csv -LiteralPath $configuration -Delimiter ';'|ForEach-Object{$config[$_.parameter]=$_.value}
  if($config.symbol -notin $symbols -or $config.resolved_run_tag -ne $resolved){throw 'Resolved pass identity does not match selected-symbol configuration'}
  $passDir=Join-Path $output ('passes\'+$config.symbol+'_'+$passes.Count)
  New-Item -ItemType Directory -Path $passDir -Force|Out-Null
  $artifacts=@{}
  foreach($kind in @('events','config','upper_bars','lower_bars','opposite_ticks')){
   $source=Join-Path $commonFiles ($resolved+'_'+$kind+'.csv')
   if(Test-Path -LiteralPath $source){Copy-Item -LiteralPath $source -Destination (Join-Path $passDir ($kind+'.csv'));$artifacts[$kind]=Hash $source;$artifactNames+=[IO.Path]::GetFileName($source)}
  }
  $events=@(Import-Csv -LiteralPath $eventFile.FullName -Delimiter ';')
  $eventSymbols=@($events|Where-Object symbol|Select-Object -ExpandProperty symbol -Unique)
  if($eventSymbols.Count -gt 1 -or ($eventSymbols.Count -eq 1 -and $eventSymbols[0] -ne $config.symbol)){throw 'CSV contains mixed symbols: possible overwrite/collision'}
  $counts=@{};$events|Group-Object event_type|ForEach-Object{$counts[$_.Name]=$_.Count}
  $allEvents+=$events
  $passes+=@{symbol=$config.symbol;resolved_run_tag=$resolved;optimization=$config.optimization;effective_draw=$config.effective_draw;input_hash=$config.input_hash;event_counts=$counts;initialized=(@($events|Where-Object event_type -eq 'INIT').Count -eq 1);event_rows=$events.Count;artifacts=$artifacts;path=$passDir}
 }
 $xmlRows=@()
 foreach($report in $reports){
  try{
   [xml]$document=[IO.File]::ReadAllText((Join-Path $output $report.Name))
   foreach($row in $document.SelectNodes("//*[local-name()='Row']")){
    $cells=@($row.SelectNodes("./*[local-name()='Cell']/*[local-name()='Data']")|ForEach-Object InnerText)
    if($cells.Count){$xmlRows+=,@($cells)}
   }
  }catch{SaveJson @{report=$report.Name;xml_parse_error=(Redact $_.Exception.Message)} (Join-Path $output 'xml_parse_error.json')}
 }
 $reportNames=@($reports|ForEach-Object Name)
 $nativeSymbols=@($xmlRows|ForEach-Object{foreach($cell in $_){if($cell -in $symbols){$cell}}}|Select-Object -Unique)
 SaveJson @{kind='NATIVE_OPTIMIZATION_SPREADSHEET_ROWS';reports=$reportNames;symbol_values=$nativeSymbols;rows=$xmlRows} (Join-Path $output 'native_xml_rows.json')
 $journalText=((Get-ChildItem -LiteralPath (Join-Path $output 'journals') -Recurse -File -Filter '*.log'|ForEach-Object{[IO.File]::ReadAllText($_.FullName)}) -join "`n")
 $rejected=([regex]::Matches($journalText,'does not permit optimization|INIT_BATCH_DISABLED|BATCH_RUN_TAG_RESERVATION_EXHAUSTED|BATCH_RUN_TAG_MARKER_')).Count
 $initFailureMatches=([regex]::Matches($journalText,'INIT_HISTORY_NOT_READY|INIT_CONFIG_OPEN_FAILED|INIT_LEDGER_OPEN_FAILED|INIT_TICK_AUDIT_OPEN_FAILED')).Count
 $initialized=@($passes|Where-Object initialized|Select-Object -ExpandProperty symbol -Unique)
 $missing=@($symbols|Where-Object{$_ -notin $initialized})
 $hasHistory=@($historyManifest|Where-Object cached_history_available|ForEach-Object symbol)
 $missingDespiteCache=@($missing|Where-Object{$_ -in $hasHistory})
 $orders=@($allEvents|Where-Object event_type -eq 'ORDER').Count
 $fills=@($allEvents|Where-Object event_type -eq 'FILL').Count
 $exits=@($allEvents|Where-Object event_type -eq 'EXIT').Count
 $noCollisions=@($passes|ForEach-Object resolved_run_tag|Select-Object -Unique).Count -eq $passes.Count -and @($artifactNames|Select-Object -Unique).Count -eq $artifactNames.Count
 $after=SourceSnapshot
 $snapshotUnchanged=($before.market_watch_selected -eq $after.market_watch_selected -and $before.common_ini -eq $after.common_ini -and $before.account_cache -eq $after.account_cache -and $before.server_cache -eq $after.server_cache)
 $batchContextValid=@($passes|Where-Object{$_.optimization -ne '1' -or $_.effective_draw -notin @('false','0')}).Count -eq 0
 $nativeFinish=[regex]::Match($journalText,'testing on Market Watch symbols finished, total passes (\d+)')
 $nativeTotal=if($nativeFinish.Success){[int]$nativeFinish.Groups[1].Value}else{0}
 $nativeCompleted=([regex]::Matches($journalText,'\t\d+ : passed in ')).Count
 # An initialized CSV is not proof that its pass finished. Require the native
 # terminal total and all agent pass completions to agree with the CSV count.
 $status=if($reports.Count -gt 0 -and $passes.Count -gt 1 -and $orders -gt 0 -and $fills -gt 0 -and $exits -gt 0 -and $noCollisions -and $batchContextValid -and $nativeTotal -eq $passes.Count -and $nativeCompleted -eq $passes.Count -and $rejected -eq 0 -and $initFailureMatches -eq 0 -and $snapshotUnchanged){'PASS_OBSERVED_NATIVE_PASSES'}else{'REVIEW_REQUIRED'}
 $summary=@{status=$status;output=$output;runtime=$terminalRoot;tag=$tag;optimization=3;selected_symbols=$symbols;expected_selected_passes=$symbols.Count;initialized_symbols=$initialized;observed_passes=$passes.Count;passes=$passes;missing_symbols=$missing;cached_history_missing=@($historyManifest|Where-Object{!$_.cached_history_available}|ForEach-Object symbol);missing_despite_cached_history=$missingDespiteCache;native_xml_reports=$reportNames;native_xml_symbols=$nativeSymbols;native_xml_rows=$xmlRows.Count;orders=$orders;fills=$fills;exits=$exits;no_csv_collisions=$noCollisions;optimizer_context_valid=$batchContextValid;optimization_init_rejection_matches=$rejected;other_initialization_failure_matches=$initFailureMatches;source_snapshot_after=$after;source_snapshot_unchanged=$snapshotUnchanged;elapsed_seconds=$timer.Elapsed.TotalSeconds;historical_real_ticks_verified=$false;profitability_assessed=$false;limitations=@('A configured Model4 may fall back to generated ticks; inspect native journals.','The selected cache is read-only input; missing historical data remains a separate symbol-level result.','A positive engineering result does not assess profit or a trading edge.')}
 SaveJson $summary (Join-Path $output 'summary.json')
 SaveJson @{cached_selection_symbol_records=$symbols;cache_records_are_not_authoritative_targets=$true;native_finished=$nativeFinish.Success;native_total_passes=$nativeTotal;native_completed_passes=$nativeCompleted;not_initialized_cache_records=$missing;not_initialized_despite_cache=$missingDespiteCache;scope='Observed native passes only; cache names may include conversion symbols. No claim that every cached record was an optimization target.'} (Join-Path $output 'native_pass_accounting.json')
 SaveJson @{status=$status;output=$output;tag=$tag;runtime=$terminalRoot;initialized_symbols=$initialized;orders=$orders;fills=$fills;exits=$exits;missing_symbols=$missing} (Join-Path $output 'status.json')
 Write-Output "$status $output"
}catch{
 if($terminalRoot -and (Test-Path -LiteralPath $terminalRoot)){ArchiveLogs}
 SaveJson @{status='FAILED';output=$output;runtime=$terminalRoot;tag=$tag;error=(Redact $_.Exception.Message)} (Join-Path $output 'status.json')
 throw (Redact $_.Exception.Message)
}finally{
 if($null -ne $child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 if($terminalRoot -and $terminalRoot.StartsWith((Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33\'),[StringComparison]::OrdinalIgnoreCase)){
  foreach($process in Get-Process terminal64,metatester64,MetaEditor64 -ErrorAction SilentlyContinue){if($process.Path -and $process.Path.StartsWith($terminalRoot+'\',[StringComparison]::OrdinalIgnoreCase)){Stop-Process -InputObject $process}}
 }
 if($null -ne $lock){$lock.Dispose();Remove-Item -LiteralPath (Join-Path $package 'marketwatch_runner.lock')}
}
