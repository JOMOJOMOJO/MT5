# Draw only recorded v1.80 events on individually bounded custom symbols.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$TerminalRoot,
 [string]$Output='reports/qa/w33v180/display/native',
 [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.#+-]*$')][string]$SourceSymbol='XAUUSD+',
 [ValidateRange(60,900)][int]$TimeoutSeconds=240,
 [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$targetRoot=[IO.Path]::GetFullPath($TerminalRoot).TrimEnd('\','/')
$allowed=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33')).TrimEnd('\','/')+'\'
if(!$targetRoot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Only task-owned isolated runtimes are allowed'}
if([IO.Path]::IsPathRooted($Output)){throw 'Output must be repository relative'}
$out=[IO.Path]::GetFullPath((Join-Path $repo $Output))
if(!$out.StartsWith($repo+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Output must stay inside the repository'}
function CheckPath([string]$Path){if($Path.Length -ge 260){throw 'Choose a shorter Output to stay below the Windows path limit'};return $Path}
CheckPath (Join-Path $out 'w33v180_12345678_c0_case0_objects.csv')|Out-Null
if(!$Execute){Write-Output "PREVIEW: compile draw-only replay and render available recorded v1.80 cases at their native lower timeframe. No orders.";return}
$terminalExe=Join-Path $targetRoot 'terminal64.exe';$editorExe=Join-Path $targetRoot 'MetaEditor64.exe'
$fixture=Join-Path $out 'fixture.csv';$caseFile=Join-Path $out 'fixture_cases.json'
foreach($path in @($terminalExe,$editorExe,$fixture,$caseFile,(Join-Path $targetRoot 'config/common.ini'))){if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Required runtime or recorded fixture is missing'}}
foreach($process in Get-Process terminal64,MetaEditor64,metatester64 -ErrorAction SilentlyContinue){
 if($process.Path -and $process.Path.StartsWith($targetRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Owned runtime is busy; wait until the current operation ends'}
}
$info=Get-Content -LiteralPath $caseFile -Raw|ConvertFrom-Json
$cases=@($info.cases)
if($cases.Count -eq 0){throw 'No native recorded v1.80 case is available'}
$tag='w33v180_'+[guid]::NewGuid().ToString('N').Substring(0,8)
$prefix='W33V180'+[guid]::NewGuid().ToString('N').Substring(0,8)
$commonFiles=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$ownedProcesses=New-Object 'System.Collections.Generic.Dictionary[int,System.Diagnostics.Process]'
$lock=$null
function SaveJson($Object,[string]$Path){$Object|ConvertTo-Json -Depth 25|Set-Content -LiteralPath (CheckPath $Path) -Encoding UTF8}
function Hash([string]$Path){if(Test-Path -LiteralPath $Path -PathType Leaf){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash};return $null}
function RememberOwned($Process){if(!$ownedProcesses.ContainsKey($Process.Id)){$ownedProcesses.Add($Process.Id,$Process)}}
function RunDrawing([string]$JobTag,[string]$Symbol,[string]$Period,[bool]$Prepare,[int]$Case,[bool]$Single){
 $setName=$JobTag+'.set'
 @(('InpFixtureFile='+$tag+'.csv'),('InpRenderTag='+$JobTag),'InpCloseWhenDone=true',('InpPrepareCustom='+$Prepare.ToString().ToLowerInvariant()),('InpSymbolPrefix='+$prefix),('InpSourceSymbol='+$SourceSymbol),('InpStartCase='+$Case),('InpSingleCase='+$Single.ToString().ToLowerInvariant()),'InpShowPanel=false','InpDiagnosticLabels=false','InpSwingPaths=true')|Set-Content -LiteralPath (Join-Path $targetRoot ('MQL5/Presets/'+$setName)) -Encoding ASCII
 $ini=$privateCommon+"`r`n[Charts]`r`nMaxBars=10000000`r`n[StartUp]`r`nExpert=tests\Wave33DrawingReplay`r`nExpertParameters=$setName`r`nSymbol=$Symbol`r`nPeriod=$Period`r`n"
 $iniPath=Join-Path $targetRoot ($JobTag+'.ini');$ini|Set-Content -LiteralPath $iniPath -Encoding ASCII
 $child=Start-Process -FilePath $terminalExe -ArgumentList '/portable',('/config:"'+$iniPath+'"') -WindowStyle Hidden -PassThru
 RememberOwned $child;$timer=[Diagnostics.Stopwatch]::StartNew()
 while($true){
  $live=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $terminalExe})
  foreach($process in $live){RememberOwned $process}
  if($child.HasExited -and $live.Count -eq 0){break}
  if($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds){throw 'Owned draw-only terminal timeout'}
  Start-Sleep -Milliseconds 500
 }
 $summary=Join-Path $commonFiles ($JobTag+'_render.csv')
 if(!(Test-Path -LiteralPath $summary -PathType Leaf)){throw 'Draw-only replay did not emit a summary'}
 $rows=@(Import-Csv -LiteralPath $summary -Delimiter ';')
 if($rows.Count -eq 0){throw 'Draw-only replay emitted no rows'}
 return $rows
}
try{
 $lock=[IO.File]::Open((Join-Path $targetRoot 'v180_drawing.lock'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 New-Item -ItemType Directory -Path $out,(Join-Path $targetRoot 'MQL5/Presets'),(Join-Path $targetRoot 'MQL5/Experts/tests'),(Join-Path $targetRoot 'MQL5/Include/Wave33Visual') -Force|Out-Null
 $sources=@{replay=(Join-Path $repo 'mql/Experts/tests/Wave33DrawingReplay.mq5');types=(Join-Path $repo 'mql/Include/Wave33Visual/Types.mqh');display=(Join-Path $repo 'mql/Include/Wave33Visual/Display.mqh')}
 $replayTarget=Join-Path $targetRoot 'MQL5/Experts/tests/Wave33DrawingReplay.mq5'
 Copy-Item -LiteralPath $sources.replay -Destination $replayTarget -Force
 Copy-Item -LiteralPath $sources.types -Destination (Join-Path $targetRoot 'MQL5/Include/Wave33Visual/Types.mqh') -Force
 Copy-Item -LiteralPath $sources.display -Destination (Join-Path $targetRoot 'MQL5/Include/Wave33Visual/Display.mqh') -Force
 $compileLog=Join-Path $out 'replay.compile.log'
 $compiler=Start-Process -FilePath $editorExe -ArgumentList '/portable',('/compile:"'+$replayTarget+'"'),('/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
 RememberOwned $compiler;$timer=[Diagnostics.Stopwatch]::StartNew()
 while(!$compiler.WaitForExit(500)){if($timer.Elapsed.TotalSeconds -gt 180){throw 'Replay compile timeout'}}
 if(!(Test-Path -LiteralPath $compileLog) -or (Get-Content -LiteralPath $compileLog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings'){throw 'Replay compilation failed or emitted warnings'}
 Copy-Item -LiteralPath ([IO.Path]::ChangeExtension($replayTarget,'.ex5')) -Destination (Join-Path $out 'replay.ex5') -Force
 $privateCommon=Get-Content -LiteralPath (Join-Path $targetRoot 'config/common.ini') -Raw
 $privateCommon=[regex]::Replace($privateCommon,'(?ims)^\[(Experts|StartUp|Charts)\][^\r\n]*\r?\n.*?(?=^\[|\z)','')
 $privateCommon=$privateCommon.TrimEnd()+"`r`n[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 $privateCommon|Set-Content -LiteralPath (Join-Path $targetRoot 'config/common.ini') -Encoding ASCII
 Copy-Item -LiteralPath $fixture -Destination (Join-Path $commonFiles ($tag+'.csv')) -Force
 $prepared=@(RunDrawing ($tag+'_p') $SourceSymbol 'M1' $true 0 $false)
 if($prepared.Count -ne $cases.Count -or @($prepared|Where-Object saved -ne '1').Count -gt 0){throw 'Historical custom-symbol preparation failed'}
 $prepared|Export-Csv -LiteralPath (Join-Path $out 'prepare_summary.csv') -NoTypeInformation -Encoding UTF8
 $results=@()
 foreach($case in $cases){
  $index=[int]$case.review_index;$jobTag=$tag+'_c'+$index;$period=([string]$case.lower_tf).Replace('PERIOD_','')
  $rendered=@(RunDrawing $jobTag ($prefix+'_'+$index) $period $false $index $true)
  if($rendered.Count -ne 1 -or $rendered[0].saved -ne '1'){throw 'A recorded PNG was not saved'}
  foreach($row in $rendered){
   if([IO.Path]::GetFileName($row.image) -ne $row.image){throw 'Replay image must be a basename'}
   Copy-Item -LiteralPath (Join-Path $commonFiles $row.image) -Destination (CheckPath (Join-Path $out $row.image)) -Force
   $inventory=Join-Path $commonFiles ($jobTag+'_case'+$index+'_objects.csv')
   if(!(Test-Path -LiteralPath $inventory -PathType Leaf)){throw 'Native object inventory is missing'}
   Copy-Item -LiteralPath $inventory -Destination (Join-Path $out ('case'+$index+'_objects.csv')) -Force
   $results+=$row
  }
  Copy-Item -LiteralPath (Join-Path $commonFiles ($jobTag+'_render.csv')) -Destination (Join-Path $out ('case'+$index+'_render.csv')) -Force
 }
 $results|Export-Csv -LiteralPath (Join-Path $out 'render_summary.csv') -NoTypeInformation -Encoding UTF8
 $sourceHashes=@{};foreach($key in $sources.Keys){$sourceHashes[$key]=Hash $sources[$key]}
 SaveJson @{kind='NORMAL_CHART_RECORDED_NATIVE_EVENT_DRAWING_REPLAY';tag=$tag;source_symbol=$SourceSymbol;custom_symbol_prefix=$prefix;cases=$cases.Count;shortfall=$info.shortfall;tester_screenshot=$false;signal_recalculation=$false;trading_code_present=$false;normal_chart_algo_trading_enabled=$false;compile='0 errors, 0 warnings';source_hashes=$sourceHashes;fixture_sha256=(Hash $fixture);runner_sha256=(Hash $PSCommandPath);runtime=$targetRoot} (Join-Path $out 'provenance.json')
 Write-Output "RENDERED $($cases.Count) recorded v1.80 cases: $Output"
}finally{
 foreach($process in $ownedProcesses.Values){try{if(!$process.HasExited -and $process.Path -and $process.Path.StartsWith($targetRoot+'\',[StringComparison]::OrdinalIgnoreCase)){$process.Kill();$process.WaitForExit(10000)|Out-Null}}catch{}}
 if($null -ne $lock){$lock.Dispose();Remove-Item -LiteralPath (Join-Path $targetRoot 'v180_drawing.lock')}
}
