# FXBasket Context Trader 2025 Diagnostics

- Date: 2026-06-22
- EA: `ExpectedValue_MultiCurrency_FXBasket_ContextTrader`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Test window: 2025-01-01 to 2025-12-31
- Chart/test symbol: `USDJPY`
- Timeframe: `M15`, with `H1` context
- Tester model: `Model=4`
- Risk: `0.25%` per trade, `3.00%` daily loss guard, `15.00%` max drawdown guard
- Compile: 0 errors, 0 warnings. See `compile.log`.

## Gate

This was a shallow diagnostic pass only. A mode needed at least:

- 200 or more closed trades per year;
- PF >= 1.05 before any longer validation;
- positive average R;
- no drawdown stop.

No mode met the minimum expectancy gate, so no long-window or OOS test was promoted.

## Comparison

| Mode | Trades | PF | Net profit | Balance max DD | Recovery | Avg R | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| context_pullback | 298 | 0.66 | -1441.07 | 1485.75 | -0.95 | -0.2120 | Reject |
| volatility_breakout | 175 | 0.76 | -611.06 | 752.90 | -0.79 | -0.1511 | Reject |
| range_reversion | 494 | 0.88 | -823.84 | 1617.94 | -0.51 | -0.0642 | Reject |

## Notes

- `context_pullback` reached the trade count floor, but failed PF and stopped on drawdown.
- `volatility_breakout` failed both the trade count floor and PF.
- `range_reversion` produced the best trade count and least negative average R, but still failed PF and stopped on drawdown.
- The strongest fragment was `range_reversion` long side, but the total strategy was not stable enough to justify direction-only promotion.
- Do not continue this candidate by adding symbol exclusions, direction-only deployment, or calendar filters. Those would repair the report rather than prove a multi-currency edge.

## Artifacts

- `comparison.csv`
- `trades_all_modes.csv`
- `yearly_breakdown.csv`
- `monthly_breakdown.csv`
- `symbol_breakdown.csv`
- `direction_breakdown.csv`
- `r_metrics.csv`
- `compile.log`
- Per-mode MT5 reports and EA CSV logs are stored in sibling run folders:
  - `../20260622_fxbasket_context_pullback_2025/`
  - `../20260622_fxbasket_volatility_breakout_2025/`
  - `../20260622_fxbasket_range_reversion_2025/`
