# FX Range Boundary Reversion 2025 Diagnostics

- Date: 2026-06-23
- EA: `ExpectedValue_MultiCurrency_FXRangeBoundaryReversion`
- Strategy thesis: `RESEARCH_STRATEGY_FX_RANGE_BOUNDARY_REVERSION`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- XAUUSD: excluded
- Test window: 2025-01-01 to 2025-12-31
- Chart/test symbol: `USDJPY`
- Timeframe: M15 execution, H1 range, H4 regime context
- Compile: 0 errors, 0 warnings. See `compile.log`.

## Design Notes

The previous three-mode `ExpectedValue_MultiCurrency_FXBasket_ContextTrader` result is treated as rejected evidence:

| Previous mode | Trades | PF | Avg R | Decision |
| --- | ---: | ---: | ---: | --- |
| context_pullback | 298 | 0.66 | -0.2120 | Reject |
| volatility_breakout | 175 | 0.76 | -0.1511 | Reject |
| range_reversion | 494 | 0.88 | -0.0642 | Reject |

This EA is not a minor retune of that range mode. It was rebuilt as a range-boundary-only mean reversion candidate:

- no entry in the range middle;
- entries only near the H1 range upper/lower boundary;
- H1/H4 low-ADX and MA-slope diagnostics;
- recent H1 breakout guard;
- M15 overshoot plus reversal confirmation;
- fixed-R TP versus H1 range-mid TP scenarios.

Risk and execution settings:

- per-trade risk: `0.25%`
- daily loss guard: `3.00%`
- equity drawdown guard: `15.00%`
- spread guard: `0.20 ATR`
- SL model: outside the H1 range boundary with `0.30 ATR` buffer, bounded by `0.45-3.20 ATR`
- fixed-R scenario RewardR: `1.10`
- mid-target scenarios TP: H1 range midpoint
- no Friday stop, no direction limit, no symbol exclusion

## 2025 Shallow Gate

Required to promote:

- 200 or more trades;
- PF >= 1.05;
- avg R > 0;
- net > 0;
- no DD stop;
- LONG/SHORT not extremely imbalanced;
- no single-symbol profit dependency.

No scenario passed. No 3-year fixed BT or recent 12-month OOS was run.

## Comparison

| Scenario | Mode | Trades | PF | Net | Avg R | DD stop | Gate |
| --- | --- | ---: | ---: | ---: | ---: | --- | --- |
| A | previous_range_reversion | 494 | 0.88 | -823.84 | -0.0642 | true | Fail |
| B | new_range_boundary_reversion_fixedR | 500 | 0.79 | -1252.03 | -0.1056 | true | Fail |
| C | new_range_boundary_reversion_to_mid | 298 | 0.73 | -1097.14 | -0.1506 | true | Fail |
| D | new_range_boundary_reversion_to_mid_with_trend_filter | 318 | 0.76 | -1056.77 | -0.1363 | false | Fail |
| E | new_range_boundary_reversion_to_mid_with_boundary_only | 203 | 0.62 | -1303.70 | -0.2657 | true | Fail |

## Required Answers

1. Previous three modes were treated as rejected. Yes.
2. This was a dedicated range-boundary design, not a parameter-only retune. Yes.
3. Middle entries were avoided. Yes: `range_position_breakdown.csv` has only `lower_boundary` and `upper_boundary`.
4. Entries were only near upper/lower boundaries. Yes.
5. Fixed-R TP was better than range-mid TP in this run, but still failed: B PF 0.79 versus C PF 0.73.
6. Trend filter did not create edge. D avoided DD stop, but PF was only 0.76 and avg R was -0.1363.
7. 2025 shallow gate was not passed.
8. All new scenarios failed PF, avg R, and net. B/C/E also hit drawdown stop. D avoided DD stop but still failed expectancy.
9. 3-year fixed BT and recent 12-month OOS were not run because the shallow gate failed.
10. There is no deployable candidate.

## Diagnostics

- Boundary logic worked mechanically: no `middle` trades appeared.
- Boundary-only tightening made expectancy worse, especially on long lower-boundary entries.
- Range-mid TP was worse than fixed-R because target distance produced too many `target_too_far` and stop-hit outcomes.
- The strongest single fragment was not stable enough to promote. New fixed-R had 500 trades but PF 0.79.
- GBPUSD and EURUSD were materially weak across scenarios. This is a failure clue, not a reason to exclude symbols and promote.

## Artifacts

- `comparison.csv`
- `trades_all_scenarios.csv`
- `yearly_breakdown.csv`
- `monthly_breakdown.csv`
- `symbol_breakdown.csv`
- `direction_breakdown.csv`
- `regime_breakdown.csv`
- `range_position_breakdown.csv`
- `failure_type_breakdown.csv`
- `r_metrics.csv`
- `compile.log`

Per-scenario MT5 reports, presets, tester configs, and EA logs:

- `../20260623_fxrange_boundary_fixedR_2025/`
- `../20260623_fxrange_boundary_to_mid_2025/`
- `../20260623_fxrange_boundary_to_mid_trend_filter_2025/`
- `../20260623_fxrange_boundary_to_mid_boundary_only_2025/`

## Decision

Reject this candidate. Do not extend it by excluding symbols, limiting direction, stopping Fridays, or adding more narrow repair filters.

The useful asset is the diagnostic structure: boundary position, regime type, target-distance R, and failure type. The strategy thesis itself did not clear the first expectancy gate.
