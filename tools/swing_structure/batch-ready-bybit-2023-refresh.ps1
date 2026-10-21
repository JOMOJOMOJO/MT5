$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $repo
$run='bybit_2023_refresh_20261001'
$root=Join-Path $repo 'reports/qa/three_wave/ready_alternate_broker_ml'
$meta=Join-Path $root ($run+'_job')
New-Item -ItemType Directory -Force $meta | Out-Null
function Status($state,$message='') {
 @{state=$state;run=$run;broker='Bybit-Live';updated=(Get-Date).ToString('o');message=$message} | ConvertTo-Json | Set-Content (Join-Path $meta 'status.json') -Encoding UTF8
}
try {
 Status 'PREPARING'
 $src=Split-Path (Split-Path (Split-Path $repo))
 $old=(Get-Content (Join-Path $repo 'reports/qa/usdjpy_hl_fib50/qa_path.txt') -Raw).Trim()
 $qa=Join-Path $env:TEMP ('READY_BYBIT_REFRESH_'+(Get-Date -Format yyyyMMdd_HHmmss))
 if(Test-Path $qa){throw 'Fresh terminal path already exists'}
 foreach($dir in @('config','MQL5/Experts','MQL5/Indicators','MQL5/Profiles/Tester','bases/Bybit-Live/history/USDJPY','bases/Bybit-Live/ticks/USDJPY')) {
  New-Item -ItemType Directory -Force (Join-Path $qa $dir) | Out-Null
 }
 foreach($exe in @('terminal64.exe','metatester64.exe')) {Copy-Item (Join-Path 'C:/Program Files/XMTrading MT5' $exe) $qa}
 foreach($file in @('accounts.dat','servers.dat')) {Copy-Item (Join-Path $old ('config/'+$file)) (Join-Path $qa 'config')}
 Copy-Item (Join-Path $old 'test.ini') (Join-Path $qa 'test.ini')
 Copy-Item (Join-Path $old 'MQL5/Indicators/ThreeWave_EMA_Display.ex5') (Join-Path $qa 'MQL5/Indicators')
 Copy-Item (Join-Path $src 'bases/Bybit-Live/symbols') (Join-Path $qa 'bases/Bybit-Live') -Recurse
 $inventory=@()
 foreach($kind in @('history','ticks')) {
  $folder=Join-Path $src ('bases/Bybit-Live/'+$kind+'/USDJPY')
  foreach($file in Get-ChildItem $folder -File) {
   if($file.Name -notmatch '^202[23](\.|\d)'){continue}
   $dest=Join-Path $qa ('bases/Bybit-Live/'+$kind+'/USDJPY/'+$file.Name)
   $reader=[IO.File]::Open($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
   try {$writer=[IO.File]::Create($dest); try {$reader.CopyTo($writer)} finally {$writer.Dispose()}} finally {$reader.Dispose()}
   $inventory+=@{kind=$kind;name=$file.Name;bytes=$file.Length;modified=$file.LastWriteTimeUtc.ToString('o');sha256=(Get-FileHash $dest -Algorithm SHA256).Hash}
  }
 }
 $inventory | ConvertTo-Json | Set-Content (Join-Path $meta 'source_history_inventory.json') -Encoding UTF8
 Set-Content (Join-Path $meta 'terminal_path.txt') $qa
 Status 'RUNNING'
 & (Join-Path $PSScriptRoot 'run-ready-2024-ml.ps1') -TerminalRoot $qa -ReportGroup ready_alternate_broker_ml -Run $run -From '2023.01.01' -To '2024.01.01' -Model 4 -ExpertName USDJPY_Ready2024MLCollector
 & python (Join-Path $PSScriptRoot 'inspect-ready-collection.py') (Join-Path $root $run)
 if($LASTEXITCODE -ne 0){throw 'Collection quality audit failed'}
 Status 'COLLECTION_COMPLETE_AWAITING_REVIEW'
} catch {Status 'FAILED' $_.Exception.Message; Write-Output $_.Exception.Message; exit 1}
