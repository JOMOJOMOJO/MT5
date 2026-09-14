# Two-stage production core: actual Strategy Tester observation

On 2026-09-14 the tester-only `ExpectedValue_TickShockTwoStageCoreHarness`
ran on EURUSD M1, January 2, 2025 (Model 1, synthetic test inputs).
`results.csv`: 8 PASS, 0 FAIL. No orders are implemented in this harness.
This validates production policy and fixed-time observer functions, not fitted
model inference, profitability or real-tick execution. Generated-model parity
is a separate pending gate. Compile evidence is
`reports/compile/tick_shock/two_stage_core_harness.log` (0 errors, 0 warnings).

Independent expected gross R for the six label rows is
`0.2, -0.6, 0.6, -1.0, -0.1, -0.3`:
LONG uses entry Ask 100.02 and exit Bid; SHORT uses entry Bid 100.00
and exit Ask. ATR is 0.10, pip size 0.01. Exit times are
301000, 601001, 901000 ms for entry 1000 ms, each side.
`labels.csv` agrees with those values. This does not include commission.

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/backtest.ps1 -TerminalPath 'C:\Program Files\XMTrading MT5\terminal64.exe' -ConfigPath reports/tests/tick_shock/two_stage_core_20260914/tester_config.ini -TimeoutSeconds 180
```

The only input used its default `InpHarnessFolder=two_stage_core_20260913`;
the observed Common Files output confirms this. Existing output is refused by
the harness, so repeat runs must use a new explicit folder/preset. HTML and
metadata are local-only because they can contain account identifiers.
