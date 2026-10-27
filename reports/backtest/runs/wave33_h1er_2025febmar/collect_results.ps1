[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$latest=Join-Path $PSScriptRoot 'latest.json'
$state=Get-Content -LiteralPath $latest -Raw -Encoding UTF8|ConvertFrom-Json
if($state.status -notin @('LAUNCHED_AWAIT_USER_RESUME','RESULTS_COLLECTED')){throw 'Unexpected state'}
$common=Join-Path $env:APPDATA 'MetaQuotes/Terminal/Common/Files'
$manifest=@()
foreach($arm in $state.arms){
 $agent=Join-Path $arm.runtime ('Tester/Agent-127.0.0.1-'+$arm.port+'/logs/20261027.log')
 $text=Get-Content -LiteralPath $agent -Raw
 if($text -notmatch 'Test passed in' -or $text -notmatch '2025\.03\.31'){throw ('Native completion not verified '+$arm.id)}
 $dest=Join-Path $arm.output 'source'
 New-Item -ItemType Directory -Path $dest -Force|Out-Null
 $sources=@(Get-ChildItem -LiteralPath $common -Filter ($arm.tag+'*.csv') -File)
 $sources+=@(Get-ChildItem -LiteralPath $arm.runtime -File|Where-Object{$_.Name -like ($arm.tag+'*') -and $_.Extension -in @('.htm','.html','.png','.gif')})
 if($sources.Count -lt 12){throw ('Missing expected CSV/report '+$arm.id)}
 foreach($file in $sources){
  $target=Join-Path $dest $file.Name
  if(Test-Path -LiteralPath $target){if((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash){throw ('Collected evidence changed '+$file.Name)}}
  else{Copy-Item -LiteralPath $file.FullName -Destination $target}
  $manifest+=[pscustomobject]@{arm=$arm.id;kind='original';source=$file.FullName;file=$target;size=$file.Length;sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()}
 }
 # Do not export cached identity/config files or terminal main logs.
 $private=[IO.File]::ReadAllText($arm.ini)
 $privateLogin=[regex]::Match($private,'(?m)^Login=(\d+)\s*$').Groups[1].Value
 if($privateLogin){$text=$text.Replace($privateLogin,'[REDACTED_ACCOUNT]')}
 $log=Join-Path $dest 'agent_journal.log'
 [IO.File]::WriteAllText($log,$text,[Text.UTF8Encoding]::new($false))
 $manifest+=[pscustomobject]@{arm=$arm.id;kind='account_redacted_utf8';source=$agent;file=$log;size=(Get-Item -LiteralPath $log).Length;sha256=(Get-FileHash -LiteralPath $log -Algorithm SHA256).Hash.ToLowerInvariant()}
 $arm.native_status='COMPLETED_RESULTS_COLLECTED'
}
$manifest|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $state.output 'result_manifest.json') -Encoding UTF8
$state.status='RESULTS_COLLECTED';$state.native_performance='COLLECTED_ANALYSIS_PENDING'
$state|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $state.output 'status.json') -Encoding UTF8
$state|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $latest -Encoding UTF8
Write-Output ('RESULTS_COLLECTED '+$state.batch+' artifacts='+$manifest.Count+'; no tester started')
