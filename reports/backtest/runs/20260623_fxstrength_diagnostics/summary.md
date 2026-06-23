# 2026-06-23 - FX Currency Strength Momentum Diagnostics

## Scope

- EA: `ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader`
- Strategy mode: `RESEARCH_STRATEGY_FX_CURRENCY_STRENGTH_MOMENTUM`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Excluded: XAUUSD
- Validation: MT5 Strategy Tester only
- Window: 2025-01-01 to 2025-12-31
- Risk: 0.25% per trade, 3.00% daily hard-loss budget, 15.00% max drawdown stop
- Compile: 0 errors, 0 warnings

## Decision

Rejected. All five scenarios reached 200 or more trades, but all failed PF, avg R, net profit, drawdown-stop, direction-balance, and currency-concentration gates. Because the shallow 2025 stop condition was hit, no fixed 3-year BT or recent 12-month OOS was run.

## Comparison

See [comparison.csv](comparison.csv), [trades_all_scenarios.csv](trades_all_scenarios.csv), and [r_metrics.csv](r_metrics.csv).

| Scenario | Mode | Trades | Net | PF | Avg R | Recovery | DD stop | Decision |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| A | currency_strength_momentum | 272 | -1302.77 | 0.68 | -0.2093 | -0.85 | true | Reject |
| B | currency_strength_pullback | 252 | -1367.16 | 0.64 | -0.2394 | -0.89 | true | Reject |
| C | currency_strength_reversal_avoid | 213 | -1357.09 | 0.59 | -0.2767 | -0.89 | true | Reject |
| D | currency_strength_momentum_room_to_2r | 225 | -1500.73 | 0.57 | -0.2894 | -0.99 | true | Reject |
| E | currency_strength_pullback_room_to_2r | 218 | -1517.05 | 0.54 | -0.3016 | -1.00 | true | Reject |

## Required Answers

1. Prior individual-pair chart-shape strategies were treated as rejected. Nested structure, sweep/reclaim/retest, FXBasket context modes, and FXRangeBoundaryReversion were not repaired with thresholds or filters.
2. This test used a separate currency-strength thesis: aggregate USD, JPY, EUR, GBP, and AUD strength from the six-symbol basket, buy strong currency, and sell weak currency.
3. `strength_diff` did not improve expectancy. The large-difference buckets were mostly negative; for example A had `>=2.0` at net -571.98 and avg R about -0.42, while small positive buckets were too sparse to promote.
4. Momentum was less bad than pullback. A had PF 0.68 and avg R -0.2093; B had PF 0.64 and avg R -0.2394.
5. Overextended avoidance did not help. C reduced trades to 213 but worsened PF to 0.59 and avg R to -0.2767.
6. `room_to_2r` did not help this currency-strength design. D and E worsened PF to 0.57 and 0.54, with avg R -0.2894 and -0.3016.
7. No scenario passed the 2025 shallow gate.
8. All scenarios failed PF >= 1.05, avg R > 0, net > 0, no DD stop, direction balance, and currency concentration. Trade count alone passed.
9. 3-year fixed BT and recent 12-month OOS were not run because the shallow stop conditions were hit.
10. There is no deployable or promotion candidate.

## Diagnostics

- Direction breakdown: [direction_breakdown.csv](direction_breakdown.csv)
- Symbol breakdown: [symbol_breakdown.csv](symbol_breakdown.csv)
- Currency strength breakdown: [currency_strength_breakdown.csv](currency_strength_breakdown.csv)
- Strength-diff bucket breakdown: [strength_diff_bucket.csv](strength_diff_bucket.csv)
- Failure type breakdown: [failure_type_breakdown.csv](failure_type_breakdown.csv)
- Monthly breakdown: [monthly_breakdown.csv](monthly_breakdown.csv)
- Yearly breakdown: [yearly_breakdown.csv](yearly_breakdown.csv)

Key failure pattern:

- All scenarios stopped by the 15% drawdown guard before the system could produce any later-year recovery.
- LONG and SHORT were both negative; this is not a single-direction fix.
- Losses appeared across the symbol set, with USDJPY and JPY crosses prominent, so symbol exclusion would be a repair attempt rather than validation.
- `failure_type_breakdown.csv` shows losses concentrated in `no_follow_through`, `pullback_failed`, and `overextended_entry`; `strength_reversed` was present but not the main driver.

## Evidence

- A MT5 report: [momentum report](../20260623_fxstrength_momentum_2025/report.html)
- B MT5 report: [pullback report](../20260623_fxstrength_pullback_2025/report.html)
- C MT5 report: [reversal avoid report](../20260623_fxstrength_reversal_avoid_2025/report.html)
- D MT5 report: [momentum room-to-2R report](../20260623_fxstrength_momentum_room2r_2025/report.html)
- E MT5 report: [pullback room-to-2R report](../20260623_fxstrength_pullback_room2r_2025/report.html)
- Compile log: [compile.txt](compile.txt)

## Next

Park this candidate. Do not promote by excluding one currency, forcing one direction, stopping Fridays, or adding narrow thresholds. A new candidate should address whether the basket strength signal is too lagged, whether entry timing should be event/session based, or whether currency-strength should be used only as context for a separate edge rather than as the entry edge itself.
