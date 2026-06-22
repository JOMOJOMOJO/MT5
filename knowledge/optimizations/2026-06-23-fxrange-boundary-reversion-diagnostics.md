# 2026-06-23 - FX Range Boundary Reversion Diagnostics

- Date: 2026-06-23
- EA: `ExpectedValue_MultiCurrency_FXRangeBoundaryReversion`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Timeframe: M15 execution, H1 range, H4 context
- Search window: none. Fixed scenario diagnostics only.
- Validation window: 2025-01-01 to 2025-12-31
- Out-of-sample window: not run
- Candidate set: fixed-R, to-mid, to-mid trend-filtered, to-mid boundary-only
- Evidence: `reports/backtest/runs/20260623_fxrange_boundary_diagnostics/`

## Goal

Rebuild range reversion as a dedicated range-boundary strategy rather than retuning the prior broad Z-score/RSI mode.

The diagnostic gate was:

- 200 or more trades;
- PF >= 1.05;
- avg R > 0;
- net > 0;
- no DD stop;
- no severe side imbalance;
- no single-symbol profit dependency.

## Search Space

No optimizer was run. Four fixed scenarios were tested:

- B: fixed-R TP;
- C: H1 range-mid TP;
- D: C plus stronger trend filter;
- E: C plus stricter boundary-only entry zone.

Risk and guard rails were fixed:

- `InpRiskPerTradePercent=0.25`
- `InpDailyMaxLossPercent=3.00`
- `InpMaxDrawdownPercent=15.00`
- `InpMaxSpreadATR=0.20`
- SL outside H1 range boundary with ATR buffer

## Result

| Scenario | Trades | PF | Avg R | Net | DD stop |
| --- | ---: | ---: | ---: | ---: | --- |
| B fixedR | 500 | 0.79 | -0.1056 | -1252.03 | true |
| C to_mid | 298 | 0.73 | -0.1506 | -1097.14 | true |
| D to_mid_trend_filter | 318 | 0.76 | -0.1363 | -1056.77 | false |
| E to_mid_boundary_only | 203 | 0.62 | -0.2657 | -1303.70 | true |

## Decision

No parameter set was selected. No long-window or OOS test was run.

Park this candidate. The range-boundary design solved the "middle entry" issue but did not create positive expectancy.

## Notes

- `range_position_breakdown.csv` confirms all entries were at `lower_boundary` or `upper_boundary`.
- Fixed-R was less bad than range-mid TP, but still failed badly.
- Strong trend filtering removed DD stop in D, but did not fix negative expectancy.
- Boundary-only tightening reduced trade quality rather than improving it.
- GBPUSD and EURUSD weakness should be treated as a market-fit warning, not as permission to exclude symbols for promotion.
