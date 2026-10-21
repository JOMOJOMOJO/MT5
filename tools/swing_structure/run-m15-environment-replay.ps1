param([string]$Run='native_parity',[string]$From='2025.01.02',[string]$To='2025.01.03',[switch]$FullRebuild)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$qa=(Get-Content (Join-Path $repo 'reports/qa/usdjpy_hl_fib50/qa_path.txt') -Raw).Trim()
$qa=(Resolve-Path -LiteralPath $qa).Path
if(-not $qa.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Dedicated TEMP terminal required'}
$exe=Join-Path $qa 'terminal64.exe'
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}){throw 'Dedicated terminal already running'}
$out=Join-Path $repo ('reports/qa/three_wave/m15_display_integration/'+$Run)
if(Test-Path $out){throw 'Run directory already exists; preserve prior results'}
New-Item -ItemType Directory -Path $out | Out-Null
Copy-Item (Join-Path $repo 'mql/Experts/M15EnvironmentResearchReplay.ex5') (Join-Path $qa 'MQL5/Experts/M15EnvironmentResearchReplay.ex5') -Force
$preset=@'
InpLowerTF=1
InpHigherTF=5
InpLowerLeftBars=1
InpLowerRightBars=3
InpHigherLeftBars=1
InpHigherRightBars=1
InpHistoryLowerBars=6000
InpHistoryHigherBars=1800
InpMaxSetupMinutes=240
InpFibZoneLow=0.382
InpFibZoneHigh=0.618
InpRequireFibZone=false
InpRequireCloseBreak=true
InpHigherUseClosePivot=true
InpSkipLowerHL=true
InpResearchStopMode=2
InpResearchBufferPoints=10
'@
if($FullRebuild){$preset+="`r`nInpAuditFullRebuild=true`r`n"}
Set-Content (Join-Path $qa 'MQL5/Profiles/Tester/mp_research.set') $preset -Encoding ASCII
Set-Content (Join-Path $out 'inputs.set') $preset -Encoding ASCII
$baseline=[IO.File]::ReadAllText((Join-Path $qa 'test.ini'))
$common=[regex]::Match($baseline,'(?s)\[Common\].*?(?=\[Experts\])').Value
if($common -eq ''){throw 'Authorized isolated account context missing'}
$body=@"
[Experts]
Enabled=0
AllowLiveTrading=0
AllowDllImport=0
[Tester]
Expert=M15EnvironmentResearchReplay.ex5
ExpertParameters=mp_research.set
Symbol=USDJPY
Period=M1
Model=4
ExecutionMode=0
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
Visual=0
ReplaceReport=1
ShutdownTerminal=1
Report=mp_$Run
"@
Set-Content (Join-Path $qa 'mp_test.ini') ($common+$body) -Encoding ASCII
Set-Content (Join-Path $out 'test.ini') $body -Encoding ASCII
$logDate=(Get-Date -Format 'yyyyMMdd')+'.log'
$offsets=@{}
foreach($dir in Get-ChildItem (Join-Path $qa 'Tester') -Directory -Filter 'Agent-*'){
 $path=Join-Path $dir.FullName ('logs/'+$logDate)
 if(Test-Path $path){$offsets[$path]=(Get-Item $path).Length}
}
$start=[DateTime]::UtcNow
$p=Start-Process -FilePath $exe -ArgumentList '/portable',('/config:"'+(Join-Path $qa 'mp_test.ini')+'"') -WindowStyle Hidden -PassThru
Write-Output ('Isolated research PID='+$p.Id+' run='+$Run)
while(-not $p.WaitForExit(30000)){Write-Output ('Elapsed '+[int]([DateTime]::UtcNow-$start).TotalSeconds+' seconds')}
$files=@(Get-ChildItem (Join-Path $qa 'Tester') -Recurse -Filter 'M15EnvParity.csv' | Where-Object {$_.LastWriteTimeUtc -ge $start.AddSeconds(-2)} | Sort-Object LastWriteTimeUtc -Descending)
if($files.Count -eq 0){throw 'No fresh research CSV; inspect isolated terminal journal'}
$agent=$files[0].Directory.Parent.Parent.FullName
foreach($f in Get-ChildItem (Join-Path $agent 'MQL5/Files') -Filter 'M15Env*.csv'){
 if($f.LastWriteTimeUtc -ge $start.AddSeconds(-2)){Copy-Item $f.FullName $out}
}
$log=Join-Path $agent ('logs/'+$logDate)
$offset=if($offsets.ContainsKey($log)){$offsets[$log]}else{0}
$stream=[IO.File]::Open($log,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
try{$null=$stream.Seek($offset,[IO.SeekOrigin]::Begin);$reader=New-Object IO.StreamReader($stream,[Text.Encoding]::Unicode);$text=$reader.ReadToEnd()}finally{$stream.Dispose()}
Set-Content (Join-Path $out 'tester.log') $text -Encoding UTF8
if($text -notmatch 'M15_REPLAY_COMPLETE'){throw 'Research completion marker missing'}
Write-Output ($text -split "`n" | Where-Object {$_ -match 'M15_REPLAY_COMPLETE|ticks,|real ticks absent|real ticks discarded'})
Write-Output ('Finished: '+$out)
