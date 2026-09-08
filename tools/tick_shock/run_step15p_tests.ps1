param([int]$TimeoutSeconds=120)
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$source=Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_SymmetricOcoHarness.mq5"
$compile=Join-Path $root "reports\compile\tick_shock\step15p_symmetric_oco_harness.log"
& (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $compile
$common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\tick_shock_step15p\symmetric_oco_harness.csv"
if(Test-Path -LiteralPath $common){Remove-Item -LiteralPath $common -Force}
$config=Join-Path $root "reports\tests\tick_shock\configs\step15p_symmetric_oco.ini"
$report="MQL5\Experts\dev\reports\tests\tick_shock\tester\step15p_symmetric_oco.html"
$lines=@("[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","","[Tester]","Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_SymmetricOcoHarness.ex5","Symbol=EURUSD","Period=M1","Model=1","ExecutionMode=0","Optimization=0","FromDate=2025.04.01","ToDate=2025.04.02","Deposit=10000","Currency=USD","Leverage=1:100","UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1","ShutdownTerminal=1","Report=$report")
[IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false))
& (Join-Path $root "scripts\backtest.ps1") -ConfigPath $config -TimeoutSeconds $TimeoutSeconds -RestartExisting
if(-not(Test-Path -LiteralPath $common)){throw "Missing harness output: $common"}
$out=Join-Path $root "reports\tests\tick_shock\step15p_symmetric_oco_harness.csv";Copy-Item $common $out -Force
$failed=Import-Csv $out|Where-Object {$_.status -eq "FAIL"};if($failed){throw "Step15P harness failures: $($failed.Count)"}
Write-Host "Step15P deterministic harness PASS"
