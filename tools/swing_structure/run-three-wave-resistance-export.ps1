param([Parameter(Mandatory=$true)][string]$TerminalRoot)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$qa=(Resolve-Path -LiteralPath $TerminalRoot).Path
if(-not $qa.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Dedicated TEMP terminal required'}
$exe=Join-Path $qa 'terminal64.exe'
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $exe}){throw 'Dedicated terminal already running'}
$out=Join-Path $repo 'reports\qa\three_wave\resistance_research'
Copy-Item (Join-Path $repo 'mql\Scripts\tests\ThreeWaveResistanceExport.ex5') (Join-Path $qa 'MQL5\Scripts\ThreeWaveResistanceExport.ex5') -Force
$prior=[IO.File]::ReadAllText((Join-Path $qa 'tw_feature_gap.ini'))
if($prior -notmatch 'Enabled=0' -or $prior -notmatch 'AllowLiveTrading=0'){throw 'Disabled live trading required'}
$config=$prior.Replace('ThreeWaveFeatureGapAudit','ThreeWaveResistanceExport')
$configPath=Join-Path $qa 'tw_resistance_export.ini'
Set-Content $configPath $config -Encoding ASCII
$log=Join-Path $qa ('MQL5\Logs\'+(Get-Date -Format 'yyyyMMdd')+'.log')
$old=if(Test-Path $log){@(Get-Content $log).Count}else{0}
$start=[DateTime]::UtcNow
$p=Start-Process $exe -ArgumentList '/portable',('/config:"'+$configPath+'"') -WindowStyle Hidden -PassThru
while(-not $p.WaitForExit(30000)){Write-Output 'Native resistance data export running'}
Get-Content $log | Select-Object -Skip $old | Where-Object {$_ -match 'ThreeWaveResistanceExport|TW_RESISTANCE_EXPORT'} | Set-Content (Join-Path $out 'export.log') -Encoding UTF8
foreach($name in @('TW_resistance_export.csv','TW_resistance_M1.csv','TW_resistance_M5.csv','TW_resistance_M15.csv','TW_resistance_H1.csv')){
 $f=Join-Path $qa ('MQL5\Files\'+$name)
 if(-not(Test-Path $f) -or (Get-Item $f).LastWriteTimeUtc -lt $start.AddSeconds(-2)){throw ('Missing fresh '+$name)}
 Copy-Item $f $out -Force
}
Get-Content (Join-Path $out 'TW_resistance_export.csv')
