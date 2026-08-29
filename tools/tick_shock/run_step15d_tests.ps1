param([ValidateSet("red","green")][string]$Phase="green",[int]$TimeoutSeconds=45)
$ErrorActionPreference="Stop"
$root=(Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$log=Join-Path $root "reports\compile\tick_shock\step15d_${Phase}_StateConditionedResponseHarness.log"
$source=Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_StateConditionedResponseHarness.mq5"
if($Phase -eq "red"){
  try { & (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $log } catch {}
  python (Join-Path $root "tools\tick_shock\run_step15d_tests.py") --phase red --compile-log $log
  exit $LASTEXITCODE
}
$common=Join-Path $env:APPDATA "MetaQuotes\Terminal\Common\Files\tick_shock_step05"
$fixtures=Join-Path $common "fixtures";$expected=Join-Path $common "expected";$rawRoot=Join-Path $common "raw"
foreach($p in @($fixtures,$expected,$rawRoot)){New-Item -ItemType Directory -Force -Path $p|Out-Null}
Copy-Item (Join-Path $root "tests\tick_shock\fixtures\TS15D-*") $fixtures -Force
Copy-Item (Join-Path $root "tests\tick_shock\expected\TS15D-*") $expected -Force
& (Join-Path $root "scripts\compile.ps1") -Source $source -LogPath $log
$raw=Join-Path $rawRoot "state_conditioned_response.csv";if(Test-Path $raw){Remove-Item -LiteralPath $raw -Force}
$config=Join-Path $root "reports\tests\tick_shock\configs\step15d_state_conditioned_response.ini"
$report="MQL5\Experts\dev\reports\tests\tick_shock\tester\step15d_state_conditioned_response.html"
$lines=@("[Experts]","Enabled=0","AllowLiveTrading=0","AllowDllImport=0","","[Tester]","Expert=dev\mql\Experts\tests\ExpectedValue_TickShock_StateConditionedResponseHarness.ex5","Symbol=EURUSD","Period=M1","Model=1","ExecutionMode=0","Optimization=0","FromDate=2025.03.03","ToDate=2025.03.04","Deposit=10000","Currency=USD","Leverage=1:100","UseLocal=1","UseRemote=0","UseCloud=0","Visual=0","ReplaceReport=1","ShutdownTerminal=1","Report=$report")
[IO.File]::WriteAllLines($config,$lines,[Text.UTF8Encoding]::new($false))
& (Join-Path $root "scripts\backtest.ps1") -ConfigPath $config -TimeoutSeconds $TimeoutSeconds -RestartExisting
if(!(Test-Path $raw)){throw "Missing $raw"}
$evidence=Join-Path $root "reports\tests\tick_shock\step15d_green\raw\state_conditioned_response.csv";New-Item -ItemType Directory -Force -Path (Split-Path $evidence)|Out-Null;Copy-Item $raw $evidence -Force
python (Join-Path $root "tools\tick_shock\run_step15d_tests.py") --phase green --raw $evidence --compile-log $log
exit $LASTEXITCODE
