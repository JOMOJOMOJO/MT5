$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$out=Join-Path $root 'reports\tests\tick_shock\technical_discovery'
& python (Join-Path $root 'tools\tick_shock\prepare_technical_model_parity.py') --features (Join-Path $root 'reports\backtest\runs\20260909_tstech_discovery_r2_202504\features.csv') --model (Join-Path $root 'reports\analysis\tick_shock\technical_discovery\candidate_model.json')
if($LASTEXITCODE -ne 0){throw 'Vector preparation failed'}
& (Join-Path $root 'scripts\compile.ps1') -Source (Join-Path $root 'mql\Experts\tests\ExpectedValue_TickShock_TechnicalModelParityHarness.mq5') -LogPath (Join-Path $root 'reports\compile\tick_shock\technical_model_parity.log')
if((Get-Content (Join-Path $root 'reports\compile\tick_shock\technical_model_parity.log') -Raw) -notmatch '0 errors, 0 warnings'){throw 'Compile gate'}
$config=Join-Path $out 'technical_model_parity.ini'
$lines=@('[Experts]','Enabled=0','AllowLiveTrading=0','AllowDllImport=0','','[Tester]','Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_TechnicalModelParityHarness.ex5','Symbol=EURUSD','Period=M1','Model=1','Optimization=0','FromDate=2025.04.01','ToDate=2025.04.02','Deposit=10000','Currency=USD','Leverage=1:100','UseLocal=1','UseRemote=0','UseCloud=0','Visual=0','ReplaceReport=1','ShutdownTerminal=1','Report=MQL5\Experts\dev\reports\tests\tick_shock\technical_discovery\technical_model_parity.html')
[IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false))
$start=[DateTime]::UtcNow
& (Join-Path $root 'scripts\backtest.ps1') -ConfigPath $config -TimeoutSeconds 120 -RestartExisting
$common=Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files\technical_model_parity\results.csv'
if((Get-Item $common).LastWriteTimeUtc -lt $start){throw 'Stale parity results'}
Copy-Item -LiteralPath $common -Destination (Join-Path $out 'technical_model_parity.csv')
$rows=@(Import-Csv $common);if($rows.Count -ne 3967 -or @($rows|Where-Object {$_.status -ne 'PASS'}).Count -gt 0){throw 'Parity failed'}
Write-Host "MQL model parity PASS $($rows.Count)"
