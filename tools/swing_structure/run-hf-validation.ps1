param(
    [Parameter(Mandatory=$true)][string]$TerminalRoot,
    [ValidateSet('normal','deferred')][string]$Variant='normal'
)
$ErrorActionPreference='Stop'
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$terminalRootFull=(Resolve-Path -LiteralPath $TerminalRoot).Path
$tempRootFull=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
if(-not $terminalRootFull.StartsWith($tempRootFull,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Use the dedicated temporary terminal, not an operational installation.'
}
$terminalExe=Join-Path $terminalRootFull 'terminal64.exe'
if(Get-Process terminal64 -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq $terminalExe}) {
    throw 'The dedicated terminal is already running.'
}
$runDir=Join-Path $repoRoot ('reports\qa\usdjpy_hl_fib50\'+$Variant)
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$preset=@'
InpMagicNumber=260915501
InpSLBufferPoints=10
InpLowerLeftBars=2
InpLowerRightBars=2
InpHigherLeftBars=2
InpHigherRightBars=2
InpHistoryBars=6000
InpAllowDeferredProtection=true
InpShowMarkers=true
InpWriteCSV=true
InpRewardRisk=1.2
InpPreferServerExpiry=true
InpTestDeferredProtection=false
'@
if($Variant -eq 'deferred') {
    $preset=$preset.Replace('InpPreferServerExpiry=true','InpPreferServerExpiry=false').Replace('InpTestDeferredProtection=false','InpTestDeferredProtection=true')
}
$presetName='hf_'+$Variant+'.set'
Set-Content -LiteralPath (Join-Path $terminalRootFull ('MQL5\Profiles\Tester\'+$presetName)) -Value $preset -Encoding ASCII
Set-Content -LiteralPath (Join-Path $runDir $presetName) -Value $preset -Encoding ASCII
# Use the already authorized account context verbatim. Do not add a login.
$config=[IO.File]::ReadAllText((Join-Path $terminalRootFull 'test.ini'))
if($config -notmatch 'AllowLiveTrading=0' -or $config -notmatch 'Enabled=0' -or $config -match '\[StartUp\]') {
    throw 'Tester-only disabled-live-trading configuration required.'
}
$config=$config.Replace('ExpertParameters=hf_normal.set',('ExpertParameters='+$presetName)).Replace('Report=hf_normal',('Report=hf_'+$Variant))
$configPath=Join-Path $terminalRootFull ('test_'+$Variant+'.ini')
Set-Content -LiteralPath $configPath -Value $config -Encoding ASCII
$exportConfig=[regex]::Replace($config,'(?s)\[Common\].*?\[Experts\]','[Experts]')
Set-Content -LiteralPath (Join-Path $runDir 'test.ini') -Value $exportConfig -Encoding ASCII
$agentRoot=Join-Path $terminalRootFull 'Tester\Agent-127.0.0.1-3000'
$diagnostics=Join-Path $agentRoot 'MQL5\Files\HF_diagnostics_260915501.csv'
$oldRows=if(Test-Path -LiteralPath $diagnostics){@(Import-Csv -LiteralPath $diagnostics).Count}else{0}
$agentLog=Join-Path $agentRoot ('logs\'+(Get-Date -Format 'yyyyMMdd')+'.log')
$oldLines=if(Test-Path -LiteralPath $agentLog){@(Get-Content -LiteralPath $agentLog).Count}else{0}
$runStarted=[DateTime]::UtcNow;
$process=Start-Process -FilePath $terminalExe -ArgumentList '/portable',('/config:"'+$configPath+'"') -WindowStyle Hidden -PassThru
if(-not $process.WaitForExit(45000)){throw ('Tester still running, PID='+$process.Id)}
if(-not(Test-Path -LiteralPath $diagnostics)){throw 'Diagnostics missing'}
$rows=@(Import-Csv -LiteralPath $diagnostics)
# MT5 normally resets its agent file sandbox per test. Support append mode too.
if((Get-Item -LiteralPath $diagnostics).LastWriteTimeUtc -lt $runStarted.AddSeconds(-1)){throw 'Stale diagnostics'}
if($rows.Count -gt $oldRows -and $oldRows -gt 0){$rows=@($rows | Select-Object -Skip $oldRows)}
if($rows.Count -eq 0){throw 'No new diagnostic rows'}
$rows | Export-Csv -LiteralPath (Join-Path $runDir 'diagnostics.csv') -NoTypeInformation -Encoding UTF8
Get-Content -LiteralPath $agentLog | Select-Object -Skip $oldLines | Set-Content -LiteralPath (Join-Path $runDir 'tester.log') -Encoding UTF8
$report=Join-Path $terminalRootFull ('hf_'+$Variant+'.htm')
if(Test-Path -LiteralPath $report){Copy-Item -LiteralPath $report -Destination $runDir -Force}
$orders=@($rows | Where-Object {$_.accepted -eq 'true'})
Write-Output ($Variant+': decisions='+$rows.Count+' orders='+$orders.Count)
