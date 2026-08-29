param([ValidateSet("red","green")][string]$Phase="green",[int]$TimeoutSeconds=45)
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
if($Phase -eq "red"){python (Join-Path $root "tools\tick_shock\run_step15e_tests.py") --phase red;exit $LASTEXITCODE}
$source=Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_MediumHorizonResponseHarness.mq5"
$log=Join-Path $root "reports\compile\tick_shock\step15e_green_MediumHorizonResponseHarness.log"
$common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\tick_shock_step05";$fixtures=Join-Path $common "fixtures";$expected=Join-Path $common "expected";$rawRoot=Join-Path $common "raw"
foreach($p in @($fixtures,$expected,$rawRoot)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
Copy-Item (Join-Path $root "tests\tick_shock\fixtures\TS15E-*") $fixtures -Force;Copy-Item (Join-Path $root "tests\tick_shock\expected\TS15E-*") $expected -Force
& (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $log
$raw=Join-Path $rawRoot "medium_horizon_response.csv";if(Test-Path $raw){Remove-Item -LiteralPath $raw -Force}
$config=Join-Path $root "reports\tests\tick_shock\configs\step15e_medium_horizon_response.ini";$report="MQL5\Experts\dev\reports\tests\tick_shock\tester\step15e_medium_horizon_response.html"
$lines=@("[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","","[Tester]","Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_MediumHorizonResponseHarness.ex5","Symbol=EURUSD","Period=M1","Model=1","ExecutionMode=0","Optimization=0","FromDate=2025.03.03","ToDate=2025.03.04","Deposit=10000","Currency=USD","Leverage=1:100","UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1","ShutdownTerminal=1","Report=$report")
[IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false));& (Join-Path $root "scripts\backtest.ps1") -ConfigPath $config -TimeoutSeconds $TimeoutSeconds -RestartExisting
if(!(Test-Path $raw)){throw "Missing $raw"};$evidence=Join-Path $root "reports\tests\tick_shock\step15e_green\raw\medium_horizon_response.csv";New-Item -ItemType Directory -Force -Path (Split-Path $evidence)|Out-Null;Copy-Item $raw $evidence -Force
python (Join-Path $root "tools\tick_shock\run_step15e_tests.py") --phase green --raw $evidence --compile-log $log;exit $LASTEXITCODE

