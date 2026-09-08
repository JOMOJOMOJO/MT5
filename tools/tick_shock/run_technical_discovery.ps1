param(
  [int]$TimeoutSeconds=5400,
  [string]$Folder="20260908_tstech_discovery_202504",
  [string]$RunId="tstech_discovery_202504"
)
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$run=Join-Path $root "reports\backtest\runs\$Folder"
$common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\$RunId"
if((Test-Path -LiteralPath $run) -or (Test-Path -LiteralPath $common)){throw "RunId/path already exists: $RunId"}
New-Item -ItemType Directory -Path $run | Out-Null
$source=Join-Path $root "mql\Experts\ExpectedValue_MultiCurrency_TickShockTechnicalResearch.mq5"
$compile=Join-Path $run "compile.log"
& (Join-Path $root 'scripts\compile.ps1') -Source $source -LogPath $compile
$log=Get-Content $compile -Raw
if($log -notmatch '0 errors, 0 warnings'){throw 'Compile gate failed'}
$binary=[IO.Path]::ChangeExtension($source,'.ex5')
$commit=(git -C $root rev-parse HEAD).Trim()
$ex5hash=(Get-FileHash $binary -Algorithm SHA256).Hash
$baseline=Join-Path $root 'reports\backtest\runs\20260908_ts15p_symmetric_oco_micro_profit_202504\symmetric_oco_micro_profit.set'
$preset=Get-Content -LiteralPath $baseline | ForEach-Object {
  if($_ -match '^InpRunId='){"InpRunId=$RunId"}
  elseif($_ -match '^InpLogFolder='){"InpLogFolder=$RunId"}
  elseif($_ -match '^InpSourceCommit='){"InpSourceCommit=$commit"}
  elseif($_ -match '^InpEx5Hash='){"InpEx5Hash=$ex5hash"}
  elseif($_ -match '^InpSchemaVersion='){'InpSchemaVersion=tickshock-event-v1+tail-v1-persistent+technical-discovery-v1'}
  else{$_}
}
[IO.File]::WriteAllLines((Join-Path $run 'technical_discovery.set'),$preset,[Text.UTF8Encoding]::new($false))
$config=@('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]',
'Expert=dev\mql\Experts\ExpectedValue_MultiCurrency_TickShockTechnicalResearch.ex5',
"PresetSource=reports\backtest\runs\$Folder\technical_discovery.set",'PresetName=technical_discovery.set',
'Symbol=EURUSD','Period=M1','Model=4','ExecutionMode=0','Optimization=0','FromDate=2025.04.01','ToDate=2025.05.01',
'Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=1','ShutdownTerminal=1',
"Report=MQL5\Experts\dev\reports\backtest\runs\$Folder\tester_report.html")
[IO.File]::WriteAllLines((Join-Path $run 'tester_config.ini'),$config,[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath $binary -Destination (Join-Path $run 'executed_EA.ex5')
$hashes=@("source_commit=$commit")
$dependencies=@($source,(Join-Path $root 'mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.mq5'))
$dependencies+=Get-ChildItem (Join-Path $root 'mql\Include\TickShock') -Filter '*.mqh' | Select-Object -ExpandProperty FullName
$dependencies+=@((Join-Path $root 'mql\Include\TickShockStateMachine.mqh'),(Join-Path $root 'mql\Include\TickShockResearchExecution.mqh'),$binary,(Join-Path $run 'technical_discovery.set'))
foreach($path in $dependencies){$hashes+="$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)  $path"}
foreach($path in @('C:\Program Files\XMTrading MT5 - 2\terminal64.exe','C:\Program Files\XMTrading MT5 - 2\MetaEditor64.exe')){
if(Test-Path -LiteralPath $path){$hashes+="$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)  $path"}}
[IO.File]::WriteAllLines((Join-Path $run 'source_hashes.txt'),$hashes,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $run 'run_command.txt'),"powershell -NoProfile -ExecutionPolicy Bypass -File tools/tick_shock/run_technical_discovery.ps1 -TimeoutSeconds $TimeoutSeconds -Folder $Folder -RunId $RunId`r`n",[Text.UTF8Encoding]::new($false))
& (Join-Path $root 'scripts\backtest.ps1') -ConfigPath (Join-Path $run 'tester_config.ini') -TimeoutSeconds $TimeoutSeconds -RestartExisting
$prefix="ExpectedValue_MultiCurrency_TickShockResearch_${RunId}_"
foreach($name in @('summary.csv','trades.csv','symbol_specs.csv','detector_features.csv','medium_horizon_episode_summary.csv')){
 $path=Join-Path $common ($prefix+$name);if(-not(Test-Path -LiteralPath $path)){throw "Missing $path"}
 Copy-Item -LiteralPath $path -Destination (Join-Path $run $name)
}
foreach($name in @('features.csv','outcomes.csv')){
 $path=Join-Path $common ('technical_'+$name);if(-not(Test-Path -LiteralPath $path)){throw "Missing $path"}
 Copy-Item -LiteralPath $path -Destination (Join-Path $run $name)
}
& python (Join-Path $root 'tools\tick_shock\prepare_technical_evidence.py') --run-dir $run --run-id $RunId
if($LASTEXITCODE -ne 0){throw 'Evidence preparation failed'}
Write-Host "Completed $run"
