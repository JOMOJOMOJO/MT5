# Draw recorded native position lifecycles on isolated, bounded custom symbols.
# This replay expert has no trading code and refuses the strategy tester.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$TerminalRoot,
 [Parameter(Mandatory=$true)][string]$Run,
 [Parameter(Mandatory=$true)][string]$Output,
 [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.#+-]*$')][string]$SourceSymbol='XAUUSD+',
 [ValidateSet('A','B')][string]$Arm='A',
 [ValidateSet('Opposite','Extension')][string]$ReviewMode='Opposite',
 [ValidateRange(60,900)][int]$TimeoutSeconds=240,
 [switch]$Execute
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetRoot=[IO.Path]::GetFullPath($TerminalRoot).TrimEnd('\','/')
$allowed=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33')).TrimEnd('\','/')+'\'
if(!$targetRoot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Only child runtimes under LOCALAPPDATA/CodexMT5Wave33 are allowed'}
if([IO.Path]::IsPathRooted($Output)){throw 'Output must be a short repository-relative path'}
$out=[IO.Path]::GetFullPath((Join-Path $repo $Output))
if(!$out.StartsWith($repo+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Output must stay inside this repository'}
function CheckPath([string]$Path){if($Path.Length -ge 260){throw 'Output path exceeds the Windows 259-character limit; choose a shorter Output'};return $Path}
CheckPath (Join-Path $out 'w33x_12345678A_c0_case0_objects.csv')|Out-Null
$runPath=if([IO.Path]::IsPathRooted($Run)){[IO.Path]::GetFullPath($Run)}else{[IO.Path]::GetFullPath((Join-Path $repo $Run))}
$period=if($Arm -eq 'A'){'M5'}else{'M1'}
if(!$Execute){Write-Output "PREVIEW: $Arm recorded lifecycles, source $SourceSymbol, chart $period; prepare fixtures, compile draw-only replay, and render observed cases. No orders.";return}
$terminalExe=Join-Path $targetRoot 'terminal64.exe'
$editorExe=Join-Path $targetRoot 'MetaEditor64.exe'
foreach($path in @($terminalExe,$editorExe,(Join-Path $runPath 'events.csv'),(Join-Path $targetRoot 'config/common.ini'))){if(!(Test-Path -LiteralPath $path -PathType Leaf)){throw 'Required runtime or native event file is missing'}}
foreach($process in Get-Process terminal64,MetaEditor64,metatester64 -ErrorAction SilentlyContinue){
 if($process.Path -and $process.Path.StartsWith($targetRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Isolated runtime is busy; wait until its current operation ends'}
}
$tag='w33x_'+[guid]::NewGuid().ToString('N').Substring(0,8)+$Arm
$prefix='W33X'+[guid]::NewGuid().ToString('N').Substring(0,8)
$commonFiles=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$ownedProcesses=New-Object 'System.Collections.Generic.Dictionary[int,System.Diagnostics.Process]'
$lock=$null
function SaveJson($Object,[string]$Path){$Object|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (CheckPath $Path) -Encoding UTF8}
function Hash([string]$Path){if(Test-Path -LiteralPath $Path -PathType Leaf){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash};return $null}
function RememberOwned($Process){if(!$ownedProcesses.ContainsKey($Process.Id)){$ownedProcesses.Add($Process.Id,$Process)}}
function RunDrawing([string]$JobTag,[string]$Fixture,[string]$Symbol,[bool]$Prepare,[int]$Case,[bool]$Single){
 $setName=$JobTag+'.set'
 $settings=@(('InpFixtureFile='+$Fixture),('InpRenderTag='+$JobTag),'InpCloseWhenDone=true',('InpPrepareCustom='+$Prepare.ToString().ToLowerInvariant()),('InpSymbolPrefix='+$prefix),('InpSourceSymbol='+$SourceSymbol),('InpStartCase='+$Case),('InpSingleCase='+$Single.ToString().ToLowerInvariant()),'InpShowPanel=false','InpDiagnosticLabels=false','InpSwingPaths=true')
 $settings|Set-Content -LiteralPath (Join-Path $targetRoot ('MQL5/Presets/'+$setName)) -Encoding ASCII
 $ini=$privateCommon+"`r`n[Charts]`r`nMaxBars=10000000`r`n[StartUp]`r`nExpert=tests\Wave33DrawingReplay`r`nExpertParameters=$setName`r`nSymbol=$Symbol`r`nPeriod=$period`r`n"
 $iniPath=Join-Path $targetRoot ($JobTag+'.ini')
 $ini|Set-Content -LiteralPath $iniPath -Encoding ASCII
 $child=Start-Process -FilePath $terminalExe -ArgumentList '/portable',('/config:"'+$iniPath+'"') -WindowStyle Hidden -PassThru
 RememberOwned $child
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while($true){
  $live=@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $terminalExe})
  foreach($process in $live){RememberOwned $process}
  if($child.HasExited -and $live.Count -eq 0){break}
  if($timer.Elapsed.TotalSeconds -gt $TimeoutSeconds){throw 'Owned draw-only terminal timeout'}
  Start-Sleep -Milliseconds 500
 }
 $summary=Join-Path $commonFiles ($JobTag+'_render.csv')
 if(!(Test-Path -LiteralPath $summary -PathType Leaf)){throw 'Draw-only replay did not emit its summary'}
 $rows=@(Import-Csv -LiteralPath $summary -Delimiter ';')
 if($rows.Count -eq 0){throw 'Draw-only replay emitted no summary rows'}
 return $rows
}
try{
 $lock=[IO.File]::Open((Join-Path $targetRoot 'opposite_render.lock'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 New-Item -ItemType Directory -Path $out,(Join-Path $targetRoot 'MQL5/Presets'),(Join-Path $targetRoot 'MQL5/Experts/tests'),(Join-Path $targetRoot 'MQL5/Include/Wave33Visual') -Force|Out-Null
 $fixture=Join-Path $out 'fixture.csv'
 $preparer=if($ReviewMode -eq 'Extension'){'prepare_extension_review.py'}else{'prepare_opposite_review.py'}
 & python (Join-Path $repo ('tools/wave33_visual/'+$preparer)) --run $runPath --out $fixture
 if($LASTEXITCODE -ne 0){throw 'Lifecycle fixture preparation failed'}
 $caseInfo=Get-Content -LiteralPath (Join-Path $out 'fixture_cases.json') -Raw|ConvertFrom-Json
 $cases=@($caseInfo.cases|ForEach-Object{[int]$_.review_index})
 if($cases.Count -eq 0){throw 'No native filled lifecycle is available for rendering'}
 foreach($case in $caseInfo.cases){if(($Arm -eq 'A' -and $case.upper_tf -ne 'PERIOD_M15') -or ($Arm -eq 'B' -and $case.upper_tf -ne 'PERIOD_M5')){throw 'Arm does not match the native run timeframe'}}
 $sources=@{replay=(Join-Path $repo 'mql/Experts/tests/Wave33DrawingReplay.mq5');types=(Join-Path $repo 'mql/Include/Wave33Visual/Types.mqh');display=(Join-Path $repo 'mql/Include/Wave33Visual/Display.mqh')}
 $replayTarget=Join-Path $targetRoot 'MQL5/Experts/tests/Wave33DrawingReplay.mq5'
 Copy-Item -LiteralPath $sources.replay -Destination $replayTarget -Force
 Copy-Item -LiteralPath $sources.types -Destination (Join-Path $targetRoot 'MQL5/Include/Wave33Visual/Types.mqh') -Force
 Copy-Item -LiteralPath $sources.display -Destination (Join-Path $targetRoot 'MQL5/Include/Wave33Visual/Display.mqh') -Force
 $compileLog=Join-Path $out 'replay.compile.log'
 $compiler=Start-Process -FilePath $editorExe -ArgumentList '/portable',('/compile:"'+$replayTarget+'"'),('/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
 RememberOwned $compiler
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(!$compiler.WaitForExit(500)){if($timer.Elapsed.TotalSeconds -gt 180){throw 'Owned replay compiler timeout'}}
 if(!(Test-Path -LiteralPath $compileLog) -or (Get-Content -LiteralPath $compileLog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings'){throw 'Replay compile failed or emitted warnings'}
 $binary=[IO.Path]::ChangeExtension($replayTarget,'.ex5')
 Copy-Item -LiteralPath $binary -Destination (Join-Path $out 'replay.ex5') -Force
 # Keep account/cache fields private. Replace execution/chart/startup sections
 # in the task-owned common.ini; never copy the resulting private INI to reports.
 $privateCommon=Get-Content -LiteralPath (Join-Path $targetRoot 'config/common.ini') -Raw
 $privateCommon=[regex]::Replace($privateCommon,'(?ims)^\[(Experts|StartUp|Charts)\][^\r\n]*\r?\n.*?(?=^\[|\z)','')
 $privateCommon=$privateCommon.TrimEnd()+"`r`n[Experts]`r`nEnabled=0`r`nAllowLiveTrading=0`r`nAllowDllImport=0`r`n"
 $privateCommon|Set-Content -LiteralPath (Join-Path $targetRoot 'config/common.ini') -Encoding ASCII
 Copy-Item -LiteralPath $fixture -Destination (Join-Path $commonFiles ($tag+'.csv')) -Force
 $prepared=@(RunDrawing ($tag+'_p') ($tag+'.csv') $SourceSymbol $true 0 $false)
 if($prepared.Count -ne $cases.Count -or @($prepared|Where-Object saved -ne '1').Count -gt 0){throw 'Bounded custom historical symbol preparation failed'}
 $prepared|Export-Csv -LiteralPath (Join-Path $out 'prepare_summary.csv') -NoTypeInformation -Encoding UTF8
 $results=@()
 foreach($case in $cases){
  $jobTag=$tag+'_c'+$case
  $rendered=@(RunDrawing $jobTag ($tag+'.csv') ($prefix+'_'+$case) $false $case $true)
  if($rendered.Count -ne 1 -or $rendered[0].saved -ne '1'){throw 'A recorded lifecycle PNG was not saved'}
  foreach($row in $rendered){
   if([IO.Path]::GetFileName($row.image) -ne $row.image){throw 'Replay image must be a basename'}
   Copy-Item -LiteralPath (Join-Path $commonFiles $row.image) -Destination (CheckPath (Join-Path $out $row.image)) -Force
   $inventory=Join-Path $commonFiles ($jobTag+'_case'+$case+'_objects.csv')
   if(!(Test-Path -LiteralPath $inventory -PathType Leaf)){throw 'Replay object inventory is missing'}
   Copy-Item -LiteralPath $inventory -Destination (Join-Path $out ('case'+$case+'_objects.csv')) -Force
   $results+=$row
  }
  Copy-Item -LiteralPath (Join-Path $commonFiles ($jobTag+'_render.csv')) -Destination (Join-Path $out ('case'+$case+'_render.csv')) -Force
 }
 $results|Export-Csv -LiteralPath (Join-Path $out 'render_summary.csv') -NoTypeInformation -Encoding UTF8
 if($results.Count -ne $cases.Count){throw 'Observed lifecycle count differs from the rendered count'}
 $sourceHashes=@{}
 foreach($key in $sources.Keys){$sourceHashes[$key]=@{path=$sources[$key];sha256=(Hash $sources[$key])}}
 $nativeHashes=@{}
 foreach($file in @('events.csv','config.csv','run.json','upper_bars.csv','opposite_ticks.csv','report.htm')){$nativeHashes[$file]=Hash (Join-Path $runPath $file)}
 $artifactHashes=@{}
 foreach($file in Get-ChildItem -LiteralPath $out -File){$artifactHashes[$file.Name]=Hash $file.FullName}
 $reviewKind=if($ReviewMode -eq 'Extension'){'NORMAL_CHART_RECORDED_W1_REVISION_LIFECYCLE_REPLAY'}else{'NORMAL_CHART_RECORDED_POSITION_LIFECYCLE_REPLAY'}
 SaveJson @{kind=$reviewKind;review_mode=$ReviewMode;arm=$Arm;source_run=$runPath;source_symbol=$SourceSymbol;chart_tf=$period;terminal_root=$targetRoot;tag=$tag;custom_symbol_prefix=$prefix;observed_cases=$cases.Count;requested_cases=5;shortfall=$caseInfo.shortfall;selected_cases=$cases;custom_symbols='Actual source M1 bars bounded strictly before each recorded lifecycle cutoff';tester_screenshot=$false;signal_recalculation=$false;trading_code_present=$false;normal_chart_algo_trading_enabled=$false;compile='0 errors, 0 warnings';show_panel=$false;source_hashes=$sourceHashes;native_hashes=$nativeHashes;artifact_hashes=$artifactHashes;fixture_manifest='fixture_manifest.json';runner_sha256=(Hash $PSCommandPath);binary_sha256=(Hash $binary)} (Join-Path $out 'provenance.json')
 Write-Output "RENDERED $Arm $($cases.Count) recorded lifecycles: $Output"
}finally{
 # Only process instances launched/adopted after this runtime was confirmed idle.
 foreach($process in $ownedProcesses.Values){
  try{if(!$process.HasExited -and $process.Path -and $process.Path.StartsWith($targetRoot+'\',[StringComparison]::OrdinalIgnoreCase)){$process.Kill();$process.WaitForExit(10000)|Out-Null}}catch{}
 }
 if($null -ne $lock){$lock.Dispose();Remove-Item -LiteralPath (Join-Path $targetRoot 'opposite_render.lock')}
}
