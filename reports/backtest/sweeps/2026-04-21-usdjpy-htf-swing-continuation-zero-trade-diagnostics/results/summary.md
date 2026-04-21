# USDJPY Higher-Timeframe Swing Continuation Zero-Trade Diagnostics

## Scope
- Pair: `M30 context x M15 pattern x M5 execution`
- Trigger: `EXEC_RECLAIM_CLOSE_CONFIRM`
- Window: `actual` (`2024-11-26` to `2026-04-01`)

## Settings
- `InpContextTimeframe = M30`
- `InpPatternTimeframe = M15`
- `InpExecutionTimeframe = M5`
- `InpExecutionTriggerMode = EXEC_RECLAIM_CLOSE_CONFIRM`
- `InpTradeBiasMode = TRADE_BIAS_BOTH`
- `InpTierMode = ENTRY_TIER_A_AND_B`
- `InpSessionStartHour = 0`
- `InpSessionEndHour = 0`
- `InpMaxManagedPositions = 2`
- `InpReentryCooldownBars = 3`
- `InpAllowSameDirectionReentry = True`
- `InpMaxTotalRiskPercent = 1.0`
- `TierA Fib = 0.382..0.618`
- `TierB Fib = 0.236..0.786`

## Backtest Metrics
- Trades: `10`
- Profit factor: `0.00`
- Net profit: `-146.80`
- Expected payoff: `-14.68`
- Win rate: `0.00`
- Max drawdown %: `1.47`

## Stage Pass Counts
- `context_valid_count`: 23283
- `tierA_long_eligible_count`: 1000
- `tierB_long_eligible_count`: 1876
- `tierA_short_eligible_count`: 1851
- `tierB_short_eligible_count`: 2027
- `fib_filter_pass_count`: 1814
- `pullback_structure_built_count`: 23283
- `higher_low_formed_count`: 35
- `lower_high_formed_count`: 35
- `reclaim_confirmed_count`: 240
- `setup_valid_count`: 10
- `trigger_fired_count`: 10
- `order_sent_count`: 10

## Trade Flags
- Entry rows: `10`
- Time stop after partial: `0`
- Runner hit before time stop: `0`

## Bottleneck
- `fib_to_structure_confirmation`
