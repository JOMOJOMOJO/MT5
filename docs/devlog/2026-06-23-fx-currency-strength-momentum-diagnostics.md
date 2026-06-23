# 2026-06-23 - FX Currency Strength Momentum Diagnostics

## Summary

- Task: build one new multi-currency FX EA from the currency-strength / basket-relative-momentum thesis and run 2025 shallow diagnostics.
- EA: `ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader`
- Scope: MT5 backtest only. No demo, live, operator, heartbeat, or deployment work.
- Result: implemented, compiled, backtested, and rejected at the 2025 shallow gate.

## Changes

- Added `mql/Experts/ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader.mq5`.
- Added five fixed scenario presets and tester configs:
  - `currency_strength_momentum`;
  - `currency_strength_pullback`;
  - `currency_strength_reversal_avoid`;
  - `currency_strength_momentum_room_to_2r`;
  - `currency_strength_pullback_room_to_2r`.
- Added `scripts/analyze-fxstrength-diagnostics.ps1`.
- Archived MT5 reports, EA CSV logs, presets, tester configs, and diagnostics under `reports/backtest/runs/`.

## Validation

- Compile command:
  - `powershell -ExecutionPolicy Bypass -File scripts\compile.ps1 -MetaEditorPath "C:\Program Files\XMTrading MT5\MetaEditor64.exe" -Source mql\Experts\ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader.mq5 -LogPath reports\compile\ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader_compile.txt`
- Compile result: 0 errors, 0 warnings.
- Backtest runner: `scripts/backtest.ps1`
- Terminal path: `C:\Program Files\XMTrading MT5\terminal64.exe`
- Test window: 2025-01-01 to 2025-12-31
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`

## Results

See [summary](../../reports/backtest/runs/20260623_fxstrength_diagnostics/summary.md) and [comparison CSV](../../reports/backtest/runs/20260623_fxstrength_diagnostics/comparison.csv).

| Scenario | Trades | PF | Avg R | Net | DD stop | Decision |
| --- | ---: | ---: | ---: | ---: | --- | --- |
| momentum | 272 | 0.68 | -0.2093 | -1302.77 | true | Reject |
| pullback | 252 | 0.64 | -0.2394 | -1367.16 | true | Reject |
| reversal_avoid | 213 | 0.59 | -0.2767 | -1357.09 | true | Reject |
| momentum_room_to_2r | 225 | 0.57 | -0.2894 | -1500.73 | true | Reject |
| pullback_room_to_2r | 218 | 0.54 | -0.3016 | -1517.05 | true | Reject |

## Decision

No scenario passed the 2025 shallow gate. The candidate is parked and was not advanced to 3-year fixed BT or recent 12-month OOS.

The result should not be repaired with symbol exclusions, direction-only promotion, Friday stops, or narrow threshold additions. Trade count passed, but expectancy and capital survival failed.

## Evidence

- [Diagnostics summary](../../reports/backtest/runs/20260623_fxstrength_diagnostics/summary.md)
- [Comparison CSV](../../reports/backtest/runs/20260623_fxstrength_diagnostics/comparison.csv)
- [Strength-diff bucket breakdown](../../reports/backtest/runs/20260623_fxstrength_diagnostics/strength_diff_bucket.csv)
- [Currency strength breakdown](../../reports/backtest/runs/20260623_fxstrength_diagnostics/currency_strength_breakdown.csv)
- [Failure type breakdown](../../reports/backtest/runs/20260623_fxstrength_diagnostics/failure_type_breakdown.csv)
- [Compile log](../../reports/backtest/runs/20260623_fxstrength_diagnostics/compile.txt)

## Next

Keep the currency-strength diagnostics as reusable context, but do not treat strength-difference alone as a tradable edge. A future EA can use currency strength as a context filter only if the entry edge is separately validated.
