[CmdletBinding()]
param([switch]$Execute)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$latest=Join-Path $PSScriptRoot 'latest.json'
$state=Get-Content -LiteralPath $latest -Raw -Encoding UTF8|ConvertFrom-Json
if($state.status -ne 'PREPARED'){throw 'Fresh PREPARED state required'}
foreach($p in $state.job_sha256.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $PSScriptRoot $p.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $p.Value){throw ('Prepared job script changed '+$p.Name)}}
# Validate BOTH jobs before starting either. No waiting, parsing or rerun after launch.
foreach($arm in $state.arms){
 foreach($p in $arm.artifact_sha256.PSObject.Properties){if((Get-FileHash -LiteralPath (Join-Path $arm.runtime $p.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $p.Value){throw ('Prepared artifact changed '+$p.Name)}}
 if((Get-FileHash -LiteralPath $arm.ini -Algorithm SHA256).Hash.ToLowerInvariant() -ne $arm.ini_sha256){throw 'Private ini changed'}
 $listener=@(Get-NetTCPConnection -LocalPort $arm.port -State Listen -ErrorAction SilentlyContinue)
 if($listener.Count){throw ('Dedicated tester port already in use '+$arm.port)}
}
if(!$Execute){Write-Output ('READY '+$state.batch+' off/on');return}
foreach($arm in $state.arms){
 $child=Start-Process -FilePath (Join-Path $arm.runtime 'terminal64.exe') -ArgumentList '/portable',('/config:"'+$arm.ini+'"') -WindowStyle Hidden -PassThru
 $arm.native_status='LAUNCHED_AWAIT_USER_RESUME'
 $arm|Add-Member -NotePropertyName process_id -NotePropertyValue $child.Id -Force
 $arm|Add-Member -NotePropertyName launched_at_utc -NotePropertyValue ([datetime]::UtcNow.ToString('o')) -Force
}
$state.status='LAUNCHED_AWAIT_USER_RESUME'
$state|ConvertTo-Json -Depth 15|Set-Content -LiteralPath (Join-Path $state.output 'status.json') -Encoding UTF8
$state|ConvertTo-Json -Depth 15|Set-Content -LiteralPath $latest -Encoding UTF8
Write-Output ('LAUNCHED '+$state.batch+' OFF PID='+$state.arms[0].process_id+' ON PID='+$state.arms[1].process_id+'; stop assistant work until user resumes')
