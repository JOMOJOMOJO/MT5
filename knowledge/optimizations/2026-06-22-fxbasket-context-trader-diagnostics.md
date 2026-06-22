# 2026-06-22 - FXBasket Context Trader Diagnostics

- Date: 2026-06-22
- EA: `ExpectedValue_MultiCurrency_FXBasket_ContextTrader`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Timeframe: `M15` execution with `H1` context
- Search window: none. Fixed shallow diagnostic only.
- Validation window: 2025-01-01 to 2025-12-31
- Out-of-sample window: not run
- Candidate set: `context_pullback`, `volatility_breakout`, `range_reversion`
- Evidence: `reports/backtest/runs/20260622_fxbasket_context_trader_2025_diagnostics/`

## Goal

Create a backtest-only MT5 multi-currency EA candidate that could clear the first promotion gate without demo/live workflow.

The minimum diagnostic gate was:

- 200 or more trades/year;
- PF >= 1.05;
- positive average R;
- no drawdown stop.

## Search Space

No optimization sweep was run. Three fixed strategy modes were tested:

- H1 trend plus M15 pullback reclaim;
- H1 volatility compression breakout;
- M15 range reversion inside muted H1 structure.

Risk and guard rails were fixed:

- `InpRiskPerTradePercent=0.25`
- `InpDailyMaxLossPercent=3.00`
- `InpMaxDrawdownPercent=15.00`
- `InpRewardR=1.25`

## Result

| Mode | Trades | PF | Avg R | Drawdown stop |
| --- | ---: | ---: | ---: | --- |
| context_pullback | 298 | 0.66 | -0.2120 | true |
| volatility_breakout | 175 | 0.76 | -0.1511 | false |
| range_reversion | 494 | 0.88 | -0.0642 | true |

All three modes failed the expectancy gate.

## Decision

No parameter set was selected. No long-window or OOS test was run.

Park this candidate as a scaffold and reject the strategy thesis for now. Do not continue with symbol exclusions, direction-only promotion, or calendar filters.

## Notes

- The scaffold is reusable: multi-currency scan, per-mode presets, common-file trade logging, MT5 report capture, and R-metric aggregation.
- The strategy modes are not reusable as promotion candidates.
- `range_reversion` was closest by average R, but it still lost money, hit drawdown stop, and relied on uneven symbol/direction behavior.
- The next EA family should improve market-state selection before entry triggers.
