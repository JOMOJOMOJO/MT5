param([int]$TimeoutSeconds=60)
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\tick_shock_step05"
$fixtures=Join-Path $common "fixtures";$expected=Join-Path $common "expected";$raw=Join-Path $common "raw"
$evidence=Join-Path $root "reports\tests\tick_shock\step15c_green\raw"
foreach($p in @($fixtures,$expected,$raw,$evidence)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
Copy-Item (Join-Path $root "tests\tick_shock\fixtures\TS15C-*") $fixtures -Force
Copy-Item (Join-Path $root "tests\tick_shock\expected\TS15C-*") $expected -Force
$result=Join-Path $raw "event_response.csv";if(Test-Path $result){Remove-Item -LiteralPath $result -Force}
$source=Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_EventResponseHarness.mq5"
$log=Join-Path $root "reports\compile\tick_shock\step15c_EventResponseHarness.log"
& (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $log
$cfg=Join-Path $root "reports\tests\tick_shock\configs\step15c_event_response.ini"
$report="MQL5\Experts\dev\reports\tests\tick_shock\tester\step15c_event_response.html"
$lines=@("[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","","[Tester]","Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_EventResponseHarness.ex5","Symbol=EURUSD","Period=M1","Model=1","ExecutionMode=0","Optimization=0","FromDate=2025.03.03","ToDate=2025.03.04","Deposit=10000","Currency=USD","Leverage=1:100","UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1","ShutdownTerminal=1","Report=$report")
[IO.File]::WriteAllLines($cfg,$lines,[Text.UTF8Encoding]::new($false))
& (Join-Path $root "scripts\backtest.ps1") -ConfigPath $cfg -TimeoutSeconds $TimeoutSeconds -RestartExisting
if(-not(Test-Path $result)){throw "Missing harness result $result"}
Copy-Item $result (Join-Path $evidence "event_response.csv") -Force
python (Join-Path $root "tools\tick_shock\run_step15c_tests.py")
if($LASTEXITCODE-ne 0){throw "Step 15C GREEN tests failed"}
