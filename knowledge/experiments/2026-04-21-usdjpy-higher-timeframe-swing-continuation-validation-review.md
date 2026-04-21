# USDJPY Higher-Timeframe Swing Continuation Validation Review

Date: 2026-04-21

## 1. Scope

- family: `usdjpy_20260421_higher_timeframe_swing_continuation_engine`
- compile evidence:
  - [usdjpy_20260421_higher_timeframe_swing_continuation_engine.log](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/usdjpy_20260421_higher_timeframe_swing_continuation_engine.log)
- run evidence:
  - [summary.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-validation/results/summary.md)
  - [results.json](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-validation/results/results.json)

## 2. Minimal Matrix

- `H1 x M15 x M5`
- `M30 x M15 x M5`
- `H1 x M30 x M15`
- `Tier A strict`
- `long-only`
- `partial 38.2`
- `final fib 61.8`
- `hold 24`
- triggers:
  - `reclaim_close_confirm`
  - `retest_hold_or_reject`
  - `recent_swing_break`

## 3. Result

The family produced `0 trades` in every run.

- train aggregate: `0`
- OOS aggregate: `0`
- actual aggregate: `0`

No pair, trigger, or pullback-depth bucket generated executable inventory.

## 4. Interpretation

This is not a case of weak profitability after enough trades. It is a stricter failure:

- the combination of `higher-timeframe pullback continuation` plus the chosen `H1/M30 -> M15/M30 -> M5/M15` ladders did not create entries at all
- there is no repeatability question because there is no OOS or actual inventory
- there is no time-stop rescue story because there were no trades to rescue

## 5. Verdict

`Reject`

Reason:

- `OOS 0 trades`
- `actual 0 trades`
- no trigger fired
- no pullback-depth distribution exists
- therefore the family fails the first survival test before expectancy analysis even begins

The result does not justify widening this family through rescue filters. It should be parked with the other rejected standalone searches.
