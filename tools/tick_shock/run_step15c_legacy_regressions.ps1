param([int]$TimeoutSeconds = 60,[switch]$SkipStep15A)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if (-not $SkipStep15A) {
  $step15aRaw = Join-Path $root "reports\tests\tick_shock\step15a_green\raw\detector.csv"
  python (Join-Path $root "tools\tick_shock\run_step15a_detector_tests.py") --phase green --raw $step15aRaw
  if ($LASTEXITCODE -ne 0) { throw "Step 15A detector regression failed" }
}

$common = Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\tick_shock_step05"
$fixtures = Join-Path $common "fixtures"
$expected = Join-Path $common "expected"
$rawRoot = Join-Path $common "raw"
foreach ($path in @($fixtures,$expected,$rawRoot)) { New-Item -ItemType Directory -Force -Path $path | Out-Null }
Copy-Item (Join-Path $root "tests\tick_shock\fixtures\TS15B-*") $fixtures -Force
Copy-Item (Join-Path $root "tests\tick_shock\expected\TS15B-*") $expected -Force

$raw = Join-Path $rawRoot "control_funnel.csv"
if (Test-Path $raw) { Remove-Item -LiteralPath $raw -Force }
$source = Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_ControlFunnelHarness.mq5"
$compileLog = Join-Path $root "reports\compile\tick_shock\step15c_ExpectedValue_TickShock_ControlFunnelHarness.log"
& (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $compileLog
$config = Join-Path $root "reports\tests\tick_shock\configs\step15c_control_funnel.ini"
$report = "MQL5\Experts\dev\reports\tests\tick_shock\tester\step15c_control_funnel.html"
$lines = @("[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","","[Tester]",
  "Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_ControlFunnelHarness.ex5","Symbol=EURUSD","Period=M1",
  "Model=1","ExecutionMode=0","Optimization=0","FromDate=2025.03.03","ToDate=2025.03.04","Deposit=10000",
  "Currency=USD","Leverage=1:100","UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1",
  "ShutdownTerminal=1","Report=$report")
[IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false))
& (Join-Path $root "scripts\backtest.ps1") -ConfigPath $config -TimeoutSeconds $TimeoutSeconds -RestartExisting
if (-not (Test-Path $raw)) { throw "Missing Step 15B result $raw" }
$evidence = Join-Path $root "reports\tests\tick_shock\step15b_green\raw\control_funnel.csv"
Copy-Item $raw $evidence -Force
python (Join-Path $root "tools\tick_shock\run_step15b_control_tests.py") --phase green --raw $evidence --compile-log $compileLog
if ($LASTEXITCODE -ne 0) { throw "Step 15B control regression failed" }
