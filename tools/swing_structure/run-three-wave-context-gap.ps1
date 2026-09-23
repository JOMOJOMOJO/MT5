param([Parameter(Mandatory=$true)][string]$TerminalRoot)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qa=(Resolve-Path -LiteralPath $TerminalRoot).Path
if(-not $qa.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Dedicated TEMP terminal required'}
$exe=Join-Path $qa 'terminal64.exe'
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}){throw 'Dedicated terminal already running'}
$out=Join-Path $repo 'reports\qa\three_wave\context_research'
Copy-Item (Join-Path $repo 'mql\Scripts\tests\ThreeWaveContextGapAudit.ex5') (Join-Path $qa 'MQL5\Scripts\ThreeWaveContextGapAudit.ex5') -Force
$prior=[IO.File]::ReadAllText((Join-Path $qa 'tw_feature_gap.ini'))
if($prior -notmatch 'Enabled=0' -or $prior -notmatch 'AllowLiveTrading=0'){throw 'Disabled live trading required'}
$config=$prior.Replace('ThreeWaveFeatureGapAudit','ThreeWaveContextGapAudit')
$configPath=Join-Path $qa 'tw_context_gap.ini'
Set-Content $configPath $config -Encoding ASCII
$log=Join-Path $qa ('MQL5\Logs\'+(Get-Date -Format 'yyyyMMdd')+'.log')
$old=if(Test-Path $log){@(Get-Content $log).Count}else{0}
$start=[DateTime]::UtcNow
$p=Start-Process $exe -ArgumentList '/portable',('/config:"'+$configPath+'"') -WindowStyle Hidden -PassThru
while(-not $p.WaitForExit(30000)){Write-Output 'Context gap audit running'}
Get-Content $log | Select-Object -Skip $old | Where-Object {$_ -match 'ThreeWaveContextGapAudit|TW_FEATURE_GAP'} | Set-Content (Join-Path $out 'gap_audit.log') -Encoding UTF8
foreach($name in @('TW_context_gaps.csv','TW_context_gap_result.csv')){
 $f=Join-Path $qa ('MQL5\Files\'+$name)
 if(-not(Test-Path $f) -or (Get-Item $f).LastWriteTimeUtc -lt $start.AddSeconds(-2)){throw ('Missing fresh '+$name)}
 Copy-Item $f $out -Force
}
Get-Content (Join-Path $out 'TW_context_gap_result.csv')
