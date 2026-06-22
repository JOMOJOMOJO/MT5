# 2026-06-22 - FXBasket Context Trader Diagnostics

## Summary

- Task: build and test a backtest-only multi-currency FX EA candidate for MT5.
- EA / family: `ExpectedValue_MultiCurrency_FXBasket_ContextTrader`.
- Scope: six-symbol FX basket, 2025 fixed-parameter MT5 Strategy Tester diagnostics.
- Result: implemented and compiled successfully, but no mode met the expectancy gate.

## Changes

- Added `mql/Experts/ExpectedValue_MultiCurrency_FXBasket_ContextTrader.mq5`.
- Added three fixed presets under `reports/presets/`.
- Added three tester configs under `reports/backtest/`.
- Added `scripts/analyze-fxbasket-diagnostics.ps1` for comparison and R-metric CSV generation.

## Validation

- Compile command:
  - `powershell -ExecutionPolicy Bypass -File scripts/compile.ps1 -Source mql\Experts\ExpectedValue_MultiCurrency_FXBasket_ContextTrader.mq5 -LogPath reports\compile\ExpectedValue_MultiCurrency_FXBasket_ContextTrader_compile.txt`
- Compile result: 0 errors, 0 warnings.
- Backtest runner: `scripts/backtest.ps1`
- Explicit terminal path was required:
  - `C:\Program Files\XMTrading MT5\terminal64.exe`
- The default terminal path pointed at another MT5 data folder and failed with `tester EX5 not found`.

## Results

See [summary](../../reports/backtest/runs/20260622_fxbasket_context_trader_2025_diagnostics/summary.md) and [comparison CSV](../../reports/backtest/runs/20260622_fxbasket_context_trader_2025_diagnostics/comparison.csv).

| Mode | Trades | PF | Avg R | Decision |
| --- | ---: | ---: | ---: | --- |
| context_pullback | 298 | 0.66 | -0.2120 | Reject |
| volatility_breakout | 175 | 0.76 | -0.1511 | Reject |
| range_reversion | 494 | 0.88 | -0.0642 | Reject |

## Decision

Do not promote this EA to long-window or OOS testing. The candidate is useful as a scaffold for MT5 multi-currency logging and diagnostics, but the three strategy modes did not show positive expectancy.

Avoid repairing this result with symbol exclusions, direction-only filters, or calendar filters. The next cycle should start a new family with stronger market-state selection before entry logic.

## Evidence

- [Diagnostics summary](../../reports/backtest/runs/20260622_fxbasket_context_trader_2025_diagnostics/summary.md)
- [Comparison CSV](../../reports/backtest/runs/20260622_fxbasket_context_trader_2025_diagnostics/comparison.csv)
- [Compile log](../../reports/backtest/runs/20260622_fxbasket_context_trader_2025_diagnostics/compile.log)
- [Research closure](../research/multicurrency_score_scanner_research_closure_2026-06-22.md)
- [Reusable lessons](../../knowledge/lessons/multicurrency_structure_research_lessons_2026-06-22.md)

## Next

- Start a new family rather than retuning these modes.
- Keep the multi-currency scan/log/report scaffold.
- Test the next thesis with the same initial gate: 200 trades/year, PF >= 1.05, positive average R, no drawdown stop.
