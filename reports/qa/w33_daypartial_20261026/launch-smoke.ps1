[CmdletBinding()]
param([switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$latest=Join-Path $PSScriptRoot 'latest.json'
$state=Get-Content -LiteralPath $latest -Raw -Encoding UTF8|ConvertFrom-Json
if($state.status -ne 'PREPARED'){throw 'Fresh PREPARED state required; never launch the same QA twice'}
$exe=Join-Path $state.runtime 'terminal64.exe'
if((Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant() -ne $state.terminal_sha256){throw 'Runtime changed'}
foreach($p in $state.runtime_artifact_sha256.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $state.runtime $p.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $p.Value){throw ('Prepared artifact changed '+$p.Name)}}
if((Get-FileHash -LiteralPath $state.ini -Algorithm SHA256).Hash.ToLowerInvariant() -ne $state.ini_sha256){throw 'Prepared private ini changed'}
if(!$Execute){Write-Output ('Ready to start one native fixture QA: '+$state.batch);return}
$child=Start-Process -FilePath $exe -ArgumentList '/portable',('/config:"'+$state.ini+'"') -WindowStyle Hidden -PassThru
$state.status='LAUNCHED_AWAIT_USER_RESUME'
$state|Add-Member -NotePropertyName process_id -NotePropertyValue $child.Id -Force
$state|Add-Member -NotePropertyName launched_at_utc -NotePropertyValue ([datetime]::UtcNow.ToString('o')) -Force
$state|ConvertTo-Json -Depth 12|Set-Content -LiteralPath (Join-Path $state.output 'status.json') -Encoding UTF8
$state|ConvertTo-Json -Depth 12|Set-Content -LiteralPath $latest -Encoding UTF8
# Deliberately no Wait-Process, polling, collection, parsing or analysis.
Write-Output ('LAUNCHED '+$state.batch+' PID='+$child.Id+'; stop assistant work until user resumes')
