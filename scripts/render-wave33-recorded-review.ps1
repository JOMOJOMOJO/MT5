# Draw-only fallback for a tester build that accepts ChartScreenShot but emits no PNG.
param(
 [string]$TerminalRoot="$env:LOCALAPPDATA\CodexMT5Wave33\20261020_134635_b2cb2b0b",
 [string]$EvidenceBatch='reports/qa/wave33_visual_20261020/20261020_134635_b2cb2b0b',
 [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9_.#-]*$')][string]$SourceSymbol='XAUUSD',
 [string]$Output='reports/qa/wave33_visual_20261020/recorded_drawing_review_final',
 [ValidateSet('A','B')][string[]]$Arms=@('A','B'),
 [ValidateRange(0,4)][int[]]$Cases=@(0,1,2,3,4),
 [switch]$Execute
)
$ErrorActionPreference='Stop'
if($null -eq $Arms -or $Arms.Count -eq 0){throw 'Select at least one arm (A or B)'}
if($null -eq $Cases -or $Cases.Count -eq 0){throw 'Select at least one case (0 through 4)'}
$Arms=@($Arms|ForEach-Object{$_.ToUpperInvariant()})
if(@($Arms|Select-Object -Unique).Count -ne $Arms.Count){throw 'Duplicate arms are not supported'}
if(@($Cases|Select-Object -Unique).Count -ne $Cases.Count){throw 'Duplicate cases are not supported'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$targetRoot=[IO.Path]::GetFullPath($TerminalRoot)
$allowed=Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33\'
if(!$targetRoot.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Only task-owned isolated terminals are allowed'}
$batch=Join-Path $repo $EvidenceBatch;$out=Join-Path $repo $Output
if(!$Execute){Write-Output "Draw-only replay of cases $($Cases -join ',') for arms $($Arms -join ','); never recalculates signals or sends orders.";return}
$ownedLeaf=Split-Path -Leaf $targetRoot
if(@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -like ('*CodexMT5Wave33*'+$ownedLeaf+'*terminal64.exe')}).Count -gt 0){throw 'Task terminal is busy; finish its current operation before rendering'}
New-Item -ItemType Directory -Path $out,(Join-Path $targetRoot 'MQL5/Presets') -Force|Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'mql/Experts/tests/Wave33DrawingReplay.mq5') -Destination (Join-Path $targetRoot 'MQL5/Experts/tests/Wave33DrawingReplay.mq5') -Force
foreach($file in @('Types.mqh','Display.mqh')){Copy-Item -LiteralPath (Join-Path $repo ('mql/Include/Wave33Visual/'+$file)) -Destination (Join-Path $targetRoot ('MQL5/Include/Wave33Visual/'+$file)) -Force}
$compileLog=Join-Path $out 'Wave33DrawingReplay.compile.log'
$p=Start-Process -FilePath (Join-Path $targetRoot 'MetaEditor64.exe') -ArgumentList '/portable',('/compile:"'+(Join-Path $targetRoot 'MQL5/Experts/tests/Wave33DrawingReplay.mq5')+'"'),('/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
if(!$p.WaitForExit(180000)){throw 'Replay compiler timeout'}
if((Get-Content -LiteralPath $compileLog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings'){throw 'Replay compile failed'}
$commonFiles=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$privateCommon=Get-Content -LiteralPath (Join-Path $targetRoot 'config/common.ini') -Raw
function RunDrawing([string]$Tag,[string]$Fixture,[string]$Symbol,[string]$Period,[bool]$Prepare,[string]$Prefix,[int]$Case,[bool]$Single){
 $setName=$Tag+'.set'
 $settings=@(('InpFixtureFile='+$Fixture),('InpRenderTag='+$Tag),'InpCloseWhenDone=true',('InpPrepareCustom='+$Prepare.ToString().ToLowerInvariant()),('InpSymbolPrefix='+$Prefix),('InpSourceSymbol='+$SourceSymbol),('InpStartCase='+$Case),('InpSingleCase='+$Single.ToString().ToLowerInvariant()),'InpShowPanel=false','InpDiagnosticLabels=false','InpSwingPaths=true')
 $settings|Set-Content -LiteralPath (Join-Path $targetRoot ('MQL5/Presets/'+$setName)) -Encoding ASCII
 # M1 observations from 2016 are beyond one million bars from the live chart.
 $ini=$privateCommon+"`r`n[Charts]`r`nMaxBars=10000000`r`n[StartUp]`r`nExpert=tests\Wave33DrawingReplay`r`nExpertParameters=$setName`r`nSymbol=$Symbol`r`nPeriod=$Period`r`n"
 $iniPath=Join-Path $targetRoot ($Tag+'.ini');$ini|Set-Content -LiteralPath $iniPath -Encoding ASCII
 $child=Start-Process -FilePath (Join-Path $targetRoot 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$iniPath+'"') -WindowStyle Hidden -PassThru
 $timer=[Diagnostics.Stopwatch]::StartNew()
 while(!$child.WaitForExit(1000)){if($timer.Elapsed.TotalSeconds -gt 180){$child.Kill();throw 'Owned draw-only terminal timeout'}}
 $summary=Join-Path $commonFiles ($Tag+'_render.csv')
 if(!(Test-Path -LiteralPath $summary)){throw 'Replay EA did not emit its summary'}
 return @(Import-Csv -LiteralPath $summary -Delimiter ';')
}
foreach($arm in $Arms){
 $run=if($arm -eq 'A'){'a_pivot_diagnostic'}else{'b_pivot_diagnostic'}
 $period=if($arm -eq 'A'){'M5'}else{'M1'}
 $tag='wave33_recorded_'+(Get-Date -Format yyyyMMdd_HHmmss)+'_'+$arm
 $fixture=Join-Path $out ($arm+'_fixture.csv')
 & python (Join-Path $repo 'tools/wave33_visual/prepare_render_review.py') --run (Join-Path $batch $run) --out $fixture
 if($LASTEXITCODE -ne 0){throw 'Fixture preparation failed'}
 Copy-Item -LiteralPath $fixture -Destination (Join-Path $commonFiles ($tag+'.csv'))
 $armOut=Join-Path $out $arm;New-Item -ItemType Directory -Path $armOut -Force|Out-Null
 $prefix='W33R_'+(Get-Date -Format HHmmss)+'_'+$arm
 Write-Output "Preparing $arm isolated custom symbols from actual $SourceSymbol M1 bars ending at each recorded decision"
 $prepared=@(RunDrawing ($tag+'_prepare') ($tag+'.csv') $SourceSymbol $period $true $prefix 0 $false)
 if($prepared.Count -lt 5 -or @($prepared|Where-Object saved -ne '1').Count -gt 0){throw 'Custom historical symbol preparation failed'}
 $results=@()
 foreach($case in $Cases){
  $caseTag=$tag+'_case'+$case
  $result=@(RunDrawing $caseTag ($tag+'.csv') ($prefix+'_'+$case) $period $false $prefix $case $true)
  foreach($row in $result){
   if($row.saved -ne '1'){throw ('Replay PNG missing for case '+$row.case)}
   Copy-Item -LiteralPath (Join-Path $commonFiles $row.image) -Destination (Join-Path $armOut $row.image)
   $results+=$row
  }
 }
 foreach($file in Get-ChildItem -LiteralPath $commonFiles -File -Filter ($tag+'*')){Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $armOut $file.Name)}
 $results|Export-Csv -LiteralPath (Join-Path $armOut 'render_summary.csv') -NoTypeInformation -Encoding UTF8
 if($results.Count -ne $Cases.Count){throw "Expected $($Cases.Count) recorded cases, received $($results.Count)"}
 Write-Output "Rendered $arm $($results.Count) cases"
}
@{kind='NORMAL_CHART_RECORDED_EVENT_REPLAY';custom_symbols=('Actual '+$SourceSymbol+' M1 bars, separately bounded at each case decision, no later bars');tester_screenshot=$false;signal_recalculation=$false;trading_code_present=$false;source_batch=$EvidenceBatch;arms=$Arms;selected_cases=$Cases;cases_per_arm=$Cases.Count;show_panel=$false;diagnostic_labels=$false;swing_paths=$true}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'provenance.json') -Encoding UTF8
