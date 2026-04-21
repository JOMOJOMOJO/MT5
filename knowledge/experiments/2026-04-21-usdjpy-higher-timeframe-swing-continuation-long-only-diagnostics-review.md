# USDJPY Higher-Timeframe Swing Continuation Long-Only Diagnostics Review

## Scope
- EA: [usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5)
- Pair: `M30 context x M15 pattern x M5 execution`
- Trigger: `EXEC_RECLAIM_CLOSE_CONFIRM`
- Window: `actual`
- Summary: [summary-a_only-long_only.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics/results/summary-a_only-long_only.md)

## Fixed Settings
- `TradeBias = LONG_ONLY`
- `TierMode = ENTRY_TIER_A_ONLY`
- `SessionStartHour = 0`
- `SessionEndHour = 0`
- `MaxManagedPositions = 2`
- `ReentryCooldownBars = 3`
- `AllowSameDirectionReentry = true`
- `MaxTotalRiskPercent = 1.0`
- `Tier A fib = 0.382..0.618`
- `Tier B fib = 0.236..0.786`

## Stage Pass Counts
- `context_valid_count = 23286`
- `tierA_long_eligible_count = 1000`
- `fib_filter_pass_count = 268`
- `pullback_structure_built_count = 23286`
- `higher_low_formed_count = 2`
- `reclaim_confirmed_count = 24`
- `setup_valid_count = 0`
- `trigger_fired_count = 0`
- `order_sent_count = 0`

## Result
- Closed trades: `0`
- PF: `0.00`
- Net: `0.00`
- Expected payoff: `0.00`

## Comparison vs A_ONLY / BOTH
- `closed trades`: `2 -> 0`
- `PF`: `0.00 -> 0.00`
- `net`: `-28.28 -> 0.00`
- `fib_filter_pass_count`: `1072 -> 268`
- `higher_low_formed_count`: `2 -> 2`
- `reclaim_confirmed_count`: `131 -> 24`
- `setup_valid_count`: `2 -> 0`
- `trigger_fired_count`: `2 -> 0`
- `order_sent_count`: `2 -> 0`

## Interpretation
- The surviving A_ONLY / BOTH inventory was entirely short-side. The previous diagnostic produced `2` entry rows and both were `short`.
- Long-side structure did not disappear immediately at `higher_low_formed_count`; it stayed at `2`.
- The long-side hypothesis died one stage later, at `reclaim_confirmed_count -> setup_valid_count`, where `24 -> 0`.

## Conclusion
- As a long-only continuation family, this slice is effectively dead.
- This does not prove that the pattern finder never detects long pullbacks. It shows that detected long pullbacks do not survive into executable setups under Tier A strictness.
