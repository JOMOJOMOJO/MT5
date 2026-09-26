param(
 [Parameter(Mandatory=$true)][string]$TerminalRoot,
 [string]$Run='hl_entry_smoke',
 [ValidateRange(0,2)][int]$HLMode=1,
 [double]$NearFraction=0.25,
 [switch]$DisableEMAFilter,
 [bool]$RequireRising=$true,
 [string]$From='2025.03.03',
 [string]$To='2025.03.08',
 [int]$Model=0,
 [int]$ExecutionDelay=0,
 [double]$RewardRisk=1.2,
 [ValidateSet('USDJPY_3Wave_HLEntryResearch')][string]$ExpertName='USDJPY_3Wave_HLEntryResearch',
 [ValidateRange(0,2)][int]$EntryMode=0,
 [ValidateRange(0,2)][int]$StopMode=1,
 [switch]$Verify,
 [switch]$Deferred,
 [switch]$Visual
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qa=(Resolve-Path -LiteralPath $TerminalRoot).Path
if(-not $qa.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Dedicated TEMP terminal required'}
$exe=Join-Path $qa 'terminal64.exe'
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}){throw 'Dedicated terminal already running'}
$out=Join-Path $repo ('reports\qa\three_wave\'+$Run)
New-Item -ItemType Directory -Force -Path $out | Out-Null
Copy-Item (Join-Path $repo ('mql\Experts\'+$ExpertName+'.ex5')) (Join-Path $qa ('MQL5\Experts\'+$ExpertName+'.ex5')) -Force
Copy-Item (Join-Path $repo 'mql\Indicators\MultiTF_3WaveIn3Wave_Visualizer_Shared.ex5') (Join-Path $qa 'MQL5\Indicators\MultiTF_3WaveIn3Wave_Visualizer_Shared.ex5') -Force
Copy-Item (Join-Path $repo 'mql\Indicators\ThreeWave_EMA_Display.ex5') (Join-Path $qa 'MQL5\Indicators\ThreeWave_EMA_Display.ex5') -Force
$preset=@'
InpLowerTF=1
InpHigherTF=5
InpLowerLeftBars=2
InpLowerRightBars=2
InpHigherLeftBars=2
InpHigherRightBars=2
InpHistoryLowerBars=6000
InpHistoryHigherBars=1800
InpMaxSetupMinutes=240
InpFibZoneLow=0.382
InpFibZoneHigh=0.618
InpRequireFibZone=false
InpRequireCloseBreak=true
InpShowHigherPivots=false
InpShowRelevantM1Pivots=true
InpShowFibZone=false
InpShowStructureLines=true
InpDiagnosticMode=false
InpMaxDrawSetups=12
InpMagicNumber=260922335
InpStopMode=0
InpSLBufferPoints=10
InpRewardRisk=1.2
InpCooldownMinutes=15
InpAllowDeferredProtection=true
InpShowMarkers=true
InpWriteCSV=true
InpVerifyIndicator=false
InpTestDeferredProtection=false
'@
if($Verify){$preset=$preset.Replace('InpVerifyIndicator=false','InpVerifyIndicator=true')}
if($Deferred){$preset=$preset.Replace('InpTestDeferredProtection=false','InpTestDeferredProtection=true')}
$preset=$preset.Replace('InpRewardRisk=1.2','InpRewardRisk='+$RewardRisk.ToString([Globalization.CultureInfo]::InvariantCulture))
$preset=$preset.Replace('InpStopMode=0','InpStopMode='+$StopMode)
$preset+="`r`nInpHLEntryMode=$HLMode`r`nInpHLNearFraction=$($NearFraction.ToString([Globalization.CultureInfo]::InvariantCulture))`r`n"
$preset+="`r`nInpUseEMAFilter=$((!$DisableEMAFilter).ToString().ToLowerInvariant())`r`nInpEMARequireRising=$($RequireRising.ToString().ToLowerInvariant())`r`nInpShowEMAs=false`r`nInpHigherUseClosePivot=false`r`nInpSkipLowerHL=false`r`n"
if($ExpertName -eq 'USDJPY_3Wave_EntryResearch'){
 $preset+="`r`nInpEntryResearchMode=$EntryMode`r`n"
 $preset=$preset.Replace('InpShowMarkers=true','InpShowMarkers=false')
}
Set-Content (Join-Path $qa 'MQL5\Profiles\Tester\tw_default.set') $preset -Encoding ASCII
Set-Content (Join-Path $out 'default.set') $preset -Encoding ASCII
$baseline=[IO.File]::ReadAllText((Join-Path $qa 'test.ini'))
$common=[regex]::Match($baseline,'(?s)\[Common\].*?(?=\[Experts\])').Value
if($common -eq ''){throw 'Previously authorized isolated account context missing'}
$visualFlag=if($Visual){1}else{0}
$body=@"
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[Tester]
Expert=$ExpertName.ex5
ExpertParameters=tw_default.set
Symbol=USDJPY
Period=M1
Model=$Model
ExecutionMode=$ExecutionDelay
Optimization=0
FromDate=$From
ToDate=$To
Deposit=10000
Currency=USD
Leverage=100
UseLocal=1
UseRemote=0
UseCloud=0
Port=3000
Visual=$visualFlag
ReplaceReport=1
ShutdownTerminal=1
Report=tw_$Run
"@
Set-Content (Join-Path $qa 'tw_test.ini') ($common+$body) -Encoding ASCII
Set-Content (Join-Path $out 'test.ini') $body -Encoding ASCII
$logOffsets=@{}
$logDate=(Get-Date -Format 'yyyyMMdd')+'.log'
foreach($dir in Get-ChildItem (Join-Path $qa 'Tester') -Directory -Filter 'Agent-*'){
 $path=Join-Path $dir.FullName ('logs\'+$logDate)
 if(Test-Path $path){$logOffsets[$path]=@(Get-Content $path).Count}
}
$start=[DateTime]::UtcNow
$p=Start-Process -FilePath $exe -ArgumentList '/portable',('/config:"'+(Join-Path $qa 'tw_test.ini')+'"') -WindowStyle Hidden -PassThru
Write-Output ('Isolated tester PID='+$p.Id+' run='+$Run)
while(-not $p.WaitForExit(30000)){Write-Output ('Tester working: elapsed '+[int]([DateTime]::UtcNow-$start).TotalSeconds+' seconds')}
$signalFiles=@(Get-ChildItem (Join-Path $qa 'Tester') -Recurse -Filter 'TW_signals.csv' | Where-Object {$_.LastWriteTimeUtc -ge $start.AddSeconds(-2)} | Sort-Object LastWriteTimeUtc -Descending)
if($signalFiles.Count -eq 0){throw 'No fresh native signal CSV; inspect isolated terminal journal'}
$agent=$signalFiles[0].Directory.Parent.Parent.FullName
$log=Join-Path $agent ('logs\'+$logDate)
$offset=if($logOffsets.ContainsKey($log)){$logOffsets[$log]}else{0}
Get-Content $log | Select-Object -Skip $offset | Set-Content (Join-Path $out 'tester.log') -Encoding UTF8
foreach($file in Get-ChildItem (Join-Path $agent 'MQL5\Files') -Filter 'TW_*.csv'){
 if($file.LastWriteTimeUtc -ge $start.AddSeconds(-2)){Copy-Item $file.FullName $out -Force}
}
if($Visual){
 $commonFiles=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\TW_validation'
 if(Test-Path $commonFiles){Get-ChildItem $commonFiles -Filter 'TW_visual_*.png' | Where-Object {$_.LastWriteTimeUtc -ge $start.AddSeconds(-2)} | Copy-Item -Destination $out -Force}
}
$report=Join-Path $qa ('tw_'+$Run+'.htm')
if(Test-Path $report){Copy-Item $report $out -Force}
Get-ChildItem $qa -Filter ('tw_'+$Run+'*.png') | Copy-Item -Destination $out -Force
Write-Output ('Finished: '+$out)
