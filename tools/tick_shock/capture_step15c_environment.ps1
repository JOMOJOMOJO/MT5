param()
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$out = Join-Path $root "reports\qa\tick_shock\step15c_binaries"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$ea = Join-Path $root "mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.ex5"
$harness = Join-Path $root "mql\Experts\tests\ExpectedValue_TickShock_EventResponseHarness.ex5"
Copy-Item -LiteralPath $ea -Destination (Join-Path $out "ExpectedValue_MultiCurrency_TickShockResearch.ex5") -Force
Copy-Item -LiteralPath $harness -Destination (Join-Path $out "ExpectedValue_TickShock_EventResponseHarness.ex5") -Force
$paths = @(
  (Join-Path $root "mql\Experts\ExpectedValue_MultiCurrency_TickShockResearch.mq5"),
  (Join-Path $root "mql\Include\TickShock\TickShockEventResponse.mqh"),
  $ea,
  $harness,
  "C:\Program Files\XMTrading MT5 - 2\terminal64.exe",
  "C:\Program Files\XMTrading MT5 - 2\MetaEditor64.exe"
)
$lines = foreach ($path in $paths) {
  if (Test-Path -LiteralPath $path) {
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    "$hash  $path"
  } else {
    "MISSING  $path"
  }
}
[IO.File]::WriteAllLines((Join-Path $root "reports\qa\tick_shock\step15c_environment_hashes.txt"),$lines,[Text.UTF8Encoding]::new($false))
