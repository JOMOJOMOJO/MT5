# USDJPY Higher-Timeframe Swing Continuation Tier A Only Diagnostics Review

## Scope
- EA: [usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5)
- Pair: `M30 context x M15 pattern x M5 execution`
- Trigger: `EXEC_RECLAIM_CLOSE_CONFIRM`
- Window: `actual`
- Summary: [summary-a_only.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics/results/summary-a_only.md)

## Fixed Settings
- `TradeBias = BOTH`
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
- `tierA_short_eligible_count = 1851`
- `fib_filter_pass_count = 1072`
- `pullback_structure_built_count = 23286`
- `higher_low_formed_count = 2`
- `lower_high_formed_count = 32`
- `reclaim_confirmed_count = 131`
- `setup_valid_count = 2`
- `trigger_fired_count = 2`
- `order_sent_count = 2`

## Result
- Closed trades: `2`
- PF: `0.00`
- Net: `-28.28`
- Expected payoff: `-14.14`

## Comparison vs A+B
- A+B had `10` trades; A only dropped to `2`.
- A+B had `setup_valid_count = 10`; A only dropped to `2`.
- A+B had `trigger_fired_count = 10`; A only dropped to `2`.
- A+B had `order_sent_count = 10`; A only dropped to `2`.
- The main contraction moved from `fib -> structure confirmation` under A+B to `reclaim -> setup` under A only, because the long-side setup pool shrank sharply once Tier B was removed.

## Conclusion
- Tier strictness is a major part of the original zero-trade outcome.
- Even so, the family is still weak after entry relaxation is removed back toward Tier A only.
- The residual bottleneck is not execution. It remains pattern setup quality, especially on the bullish side where only `2` higher-low confirmations survived.
