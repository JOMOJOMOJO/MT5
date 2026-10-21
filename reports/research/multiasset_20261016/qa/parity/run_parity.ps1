param([ValidateSet('Compile','Run','Collect')][string]$Stage='Compile')
$ErrorActionPreference='Stop'
$taskTerminalRoot='C:\Users\windows\AppData\Local\CodexMT5Multiasset20261016'
$taskTerminal=Join-Path $taskTerminalRoot 'terminal64.exe'
$taskEditor=Join-Path $taskTerminalRoot 'MetaEditor64.exe'
$repoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../../../..')).Path
$source=Join-Path $repoRoot 'mql/Experts/Research/MultiassetResearchParity.mq5'
$binary=[IO.Path]::ChangeExtension($source,'.ex5')
$compileLog=Join-Path $PSScriptRoot 'compile.log'
$testerConfig=Join-Path $PSScriptRoot 'tester.ini'
if($Stage -eq 'Compile') {
    $compile=Start-Process -FilePath $taskEditor -ArgumentList '/portable',('/compile:"'+$source+'"'),('/log:"'+$compileLog+'"') -WindowStyle Hidden -PassThru
    if(-not $compile.WaitForExit(30000)) { Write-Output ('Compiler running PID='+$compile.Id); exit 0 }
    if(-not (Test-Path -LiteralPath $compileLog)) { throw 'Compilation log missing' }
    Get-Content -LiteralPath $compileLog
    if((Get-Content -LiteralPath $compileLog -Raw) -notmatch 'Result:\s+0 errors,\s+0 warnings') { throw 'Compilation did not pass' }
    if(-not (Test-Path -LiteralPath $binary)) { throw 'Compiled EX5 missing' }
    Get-FileHash -LiteralPath $source,$binary -Algorithm SHA256
    exit 0
}
if($Stage -eq 'Run') {
    if(-not (Test-Path -LiteralPath $binary)) { throw 'Compile first' }
    $targetDir=Join-Path $taskTerminalRoot 'MQL5/Experts/Research'
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item -LiteralPath $binary -Destination (Join-Path $targetDir 'MultiassetResearchParity.ex5') -Force
    # Only this task-owned portable executable may be restarted. No user terminal is touched.
    Get-Process -Name terminal64 -ErrorAction SilentlyContinue | ForEach-Object {
        if($_.Path -eq $taskTerminal) { Stop-Process -Id $_.Id -ErrorAction Stop }
    }
    $run=Start-Process -FilePath $taskTerminal -ArgumentList '/portable',('/config:"'+$testerConfig+'"') -WindowStyle Hidden -PassThru
    Write-Output ('Tester launched PID='+$run.Id)
    exit 0
}
$evidence=Get-ChildItem -LiteralPath (Join-Path $taskTerminalRoot 'Tester') -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'MultiassetResearchParity_20261016.csv' }
foreach($fixture in $evidence) { Copy-Item -LiteralPath $fixture.FullName -Destination (Join-Path $PSScriptRoot ('fixture_'+$fixture.Directory.Parent.Name+'.csv')) -Force }
$logs=Get-ChildItem -LiteralPath (Join-Path $taskTerminalRoot 'Tester') -Recurse -Filter '*.log' -File -ErrorAction SilentlyContinue
foreach($log in $logs) {
    $matched=Select-String -LiteralPath $log.FullName -Pattern 'MULTIASSET_PARITY' -ErrorAction SilentlyContinue
    if($matched) { $matched.Line | Set-Content -LiteralPath (Join-Path $PSScriptRoot ('journal_'+$log.Directory.Parent.Name+'.txt')) -Encoding utf8 }
}
Get-ChildItem -LiteralPath $taskTerminalRoot -File -Filter 'MultiassetResearchParity_20261016*' | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $PSScriptRoot $_.Name) -Force
}
Get-ChildItem -LiteralPath $PSScriptRoot | Select-Object Name,Length,LastWriteTimeUtc
