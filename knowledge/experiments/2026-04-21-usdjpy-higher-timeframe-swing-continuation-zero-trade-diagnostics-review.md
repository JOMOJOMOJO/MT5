# USDJPY Higher-Timeframe Swing Continuation Zero-Trade Diagnostics Review

## Scope
- EA: [usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5)
- Pair: `M30 context x M15 pattern x M5 execution`
- Trigger: `EXEC_RECLAIM_CLOSE_CONFIRM`
- Window: `actual` (`2024-11-26` to `2026-04-01`)
- Summary: [summary.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics/results/summary.md)

## Diagnostic Settings
- `TradeBias = BOTH`
- `TierMode = ENTRY_TIER_A_AND_B`
- `MaxManagedPositions = 2`
- `ReentryCooldownBars = 3`
- `AllowSameDirectionReentry = true`
- `MaxTotalRiskPercent = 1.0`
- `Tier A fib = 0.382..0.618`
- `Tier B fib = 0.236..0.786`
- Session restriction disabled with `InpSessionStartHour = 0` and `InpSessionEndHour = 0`

## Result
- The family was not structurally zero-trade under the relaxed diagnostic slice.
- Closed trades appeared: `10`
- Reported PnL was still negative: `PF 0.00 / net -146.80`

## Stage Pass Counts
- `context_valid_count = 23283`
- `pullback_structure_built_count = 23283`
- `tierA_long_eligible_count = 1000`
- `tierB_long_eligible_count = 1876`
- `tierA_short_eligible_count = 1851`
- `tierB_short_eligible_count = 2027`
- `fib_filter_pass_count = 1814`
- `higher_low_formed_count = 35`
- `lower_high_formed_count = 35`
- `reclaim_confirmed_count = 240`
- `setup_valid_count = 10`
- `trigger_fired_count = 10`
- `order_sent_count = 10`

## Bottleneck
- The largest contraction was `fib_filter_pass_count -> higher/lower_low_high structure confirmation`.
- That drop was `1814 -> 70`, which is materially larger than the later `reclaim_confirmed_count -> setup_valid_count` drop `240 -> 10`.
- The original 27-run zero-trade verdict was therefore not caused by execution, order sending, or session guards alone.
- The primary choke point was `pullback structure confirmation`, especially the `higher low / lower high` formation gate on the pattern timeframe.

## Diagnostic Conclusion
- This pass was useful for root-cause isolation only.
- It does not rescue the family. Even after relaxing side, tier, reentry, and risk caps, the slice still produced only `10` losing trades.
- If one restriction is restored next, the most informative first restoration is `TradeBias = LONG_ONLY`, because the diagnostic run already showed the setup assembly bottleneck before any meaningful execution scarcity.
