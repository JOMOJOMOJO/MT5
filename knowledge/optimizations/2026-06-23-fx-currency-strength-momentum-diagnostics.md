# 2026-06-23 - FX Currency Strength Momentum Diagnostics

- Date: 2026-06-23
- EA: `ExpectedValue_MultiCurrency_FXCurrencyStrengthTrader`
- Symbols: `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`
- Timeframe: M15 execution, H1/H4 currency-strength context
- Search window: none. Five fixed scenario diagnostics only.
- Validation window: 2025-01-01 to 2025-12-31
- Out-of-sample window: not run
- Evidence: `reports/backtest/runs/20260623_fxstrength_diagnostics/`

## Goal

Test a new family after parking chart-shape and range-boundary families: compute USD, JPY, EUR, GBP, and AUD strength from a multi-pair FX basket, then buy the strong currency and sell the weak currency.

The shallow gate was:

- 200 or more trades;
- PF >= 1.05;
- avg R > 0;
- net > 0;
- no DD stop;
- no severe LONG/SHORT imbalance;
- no single-currency profit dependency.

## Fixed Scenarios

- A: `currency_strength_momentum`
- B: `currency_strength_pullback`
- C: `currency_strength_reversal_avoid`
- D: `currency_strength_momentum_room_to_2r`
- E: `currency_strength_pullback_room_to_2r`

Risk and guard rails were fixed:

- `InpRiskPerTradePercent=0.25`
- `InpDailyMaxLossPercent=3.00`
- `InpMaxDrawdownPercent=15.00`
- `InpRewardR=1.20`
- `InpMinStrengthDiff=0.70`

## Result

| Scenario | Trades | PF | Avg R | Net | DD stop |
| --- | ---: | ---: | ---: | ---: | --- |
| A momentum | 272 | 0.68 | -0.2093 | -1302.77 | true |
| B pullback | 252 | 0.64 | -0.2394 | -1367.16 | true |
| C reversal_avoid | 213 | 0.59 | -0.2767 | -1357.09 | true |
| D momentum_room_to_2r | 225 | 0.57 | -0.2894 | -1500.73 | true |
| E pullback_room_to_2r | 218 | 0.54 | -0.3016 | -1517.05 | true |

## Decision

No parameter set was selected. No 3-year or OOS run was performed.

Park this candidate. The basket currency-strength signal produced enough trades but did not survive friction, direction balance, or the 15% max-drawdown guard.

## Rejected Repair Paths

- Do not exclude USDJPY, JPY crosses, or a single weak currency as a promotion shortcut.
- Do not make the EA direction-only; both LONG and SHORT were negative.
- Do not add Friday stops or narrow calendar filters.
- Do not retune `InpMinStrengthDiff` or room-to-2R thresholds as a rescue without a new thesis; large strength-diff buckets were not the source of edge.

## Reusable Lesson

Currency strength can be useful as context, but in this implementation it was not an entry edge. Large basket agreement often arrived after extension, so losses clustered in `no_follow_through`, `pullback_failed`, and `overextended_entry`. Future work should separate context from trigger: validate the trigger first, then ask whether currency strength improves it.
