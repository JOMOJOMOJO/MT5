# Supplemental frozen-binary regression, after the canonical v1.80 batch ends.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$RuntimeRoot,[Parameter(Mandatory)][string]$EngineeringBatch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$runtime=[IO.Path]::GetFullPath($RuntimeRoot)
$allowed=[IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'CodexMT5Wave33')).TrimEnd('\')+'\'
if(!$runtime.StartsWith($allowed,[StringComparison]::OrdinalIgnoreCase)){throw 'Use an owned Wave33 sandbox'}
$exe=Join-Path $runtime 'terminal64.exe'
if(@(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $exe}).Count){throw 'Wait for the engineering batch to finish'}
$output=Join-Path $PSScriptRoot 'baseline_native'
if(Test-Path -LiteralPath $output){throw 'Never overwrite an earlier baseline'}
New-Item -ItemType Directory -Path $output -Force|Out-Null
$binary=Join-Path $PSScriptRoot 'base\Wave33VisualVerifier.ex5'
$frozenExpert=Join-Path $runtime 'MQL5\Experts\Wave33Frozen171.ex5'
Copy-Item -LiteralPath $binary -Destination $frozenExpert
$originalHash=(Get-FileHash -LiteralPath $binary).Hash
$commonText=[IO.File]::ReadAllText((Join-Path $runtime 'config\common.ini'))
$privateLogin=[regex]::Match($commonText,'(?m)^Login=(\d+)\s*$').Groups[1].Value
$server=[regex]::Match($commonText,'(?m)^Server=(.+)\r?$').Groups[1].Value.Trim()
if(!$privateLogin -or !$server){throw 'Private identity missing in the owned sandbox'}
function Redact([string]$Text){
 $Text=$Text.Replace($privateLogin,'[ACCOUNT]')
 $Text=[regex]::Replace($Text,'(?im)((?:password|login|account)\s*[=:]\s*)\S+','$1[REDACTED]')
 return [regex]::Replace($Text,"'\d{5,}'","'[ACCOUNT]'")
}
$sourceCommon=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files'
$child=$null
try{
 foreach($arm in @('a','b')){
  $run=Join-Path $output $arm
  New-Item -ItemType Directory -Path $run -Force|Out-Null
  $tag='w33v180_frozen171_'+$arm+'_'+[guid]::NewGuid().ToString('N').Substring(0,8)
  $setName=$tag+'.set'
  $originalSet=Join-Path $EngineeringBatch ('v180_'+$arm+'_base\inputs.set')
  $setLines=@(Get-Content -LiteralPath $originalSet|Where-Object{$_ -notmatch '^Inp(?:CancelConnectedOpposite|ExtendTPToWave1|TPWave1BufferPoints)='}|ForEach-Object{if($_ -match '^InpRunTag='){'InpRunTag='+$tag}else{$_}})
  $setPath=Join-Path $runtime ('MQL5\Profiles\Tester\'+$setName)
  $setLines|Set-Content -LiteralPath $setPath -Encoding ASCII
  Copy-Item -LiteralPath $setPath -Destination (Join-Path $run 'inputs.set')
  $body=Get-Content -LiteralPath (Join-Path $EngineeringBatch ('v180_'+$arm+'_base\tester_public.ini')) -Raw
  $body=[regex]::Replace($body,'(?m)^Expert=.+','Expert=Wave33Frozen171.ex5')
  $body=[regex]::Replace($body,'(?m)^ExpertParameters=.+',('ExpertParameters='+$setName))
  $body=[regex]::Replace($body,'(?m)^Report=.+',('Report='+$tag))
  $body|Set-Content -LiteralPath (Join-Path $run 'tester_public.ini') -Encoding ASCII
  $ini=Join-Path $runtime ($tag+'.ini')
  ("[Common]`r`nLogin=$privateLogin`r`nServer=$server`r`n"+$body)|Set-Content -LiteralPath $ini -Encoding ASCII
  $started=[datetime]::UtcNow
  $child=Start-Process -FilePath $exe -ArgumentList '/portable',('/config:"'+$ini+'"') -WindowStyle Hidden -PassThru
  $timer=[Diagnostics.Stopwatch]::StartNew()
  while(!$child.HasExited -or @(Get-Process terminal64 -ErrorAction SilentlyContinue|Where-Object{$_.Path -eq $exe}).Count){
   if($timer.Elapsed.TotalSeconds -gt 240){throw 'Frozen baseline exceeded 240 seconds'}
   Start-Sleep -Milliseconds 1000
  }
  $child=$null
  $report=Join-Path $runtime ($tag+'.htm')
  if(!(Test-Path -LiteralPath $report) -or (Get-Item -LiteralPath $report).LastWriteTimeUtc -lt $started){throw 'No fresh frozen-binary native report'}
  $reportText=[IO.File]::ReadAllText($report);Redact $reportText|Set-Content -LiteralPath (Join-Path $run 'report.htm') -Encoding UTF8
  foreach($kind in @('events','config','upper_bars','lower_bars','opposite_ticks')){
   Copy-Item -LiteralPath (Join-Path $sourceCommon ($tag+'_'+$kind+'.csv')) -Destination (Join-Path $run ($kind+'.csv'))
  }
  if((Get-FileHash -LiteralPath $frozenExpert).Hash -ne $originalHash){throw 'Frozen EX5 was unexpectedly changed'}
  @{status='COMPLETED';arm=$arm;expert='Wave33Frozen171.ex5';version='1.71';ea_sha256=$originalHash;compared_v180_path=(Join-Path $EngineeringBatch ('v180_'+$arm+'_base'));live_trading=$false;new_strategy_inputs_removed=$true}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $run 'run.json') -Encoding UTF8
  Write-Output "Frozen v1.71 native $arm completed"
 }
}finally{
 if($null -ne $child -and !$child.HasExited){$child.Kill();$child.WaitForExit(10000)|Out-Null}
 foreach($owned in Get-Process terminal64,metatester64 -ErrorAction SilentlyContinue){if($owned.Path -and $owned.Path.StartsWith($runtime+'\',[StringComparison]::OrdinalIgnoreCase)){Stop-Process -InputObject $owned}}
}
