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
- `InpTradeBiasMode = TRADE_BIAS_LONG_ONLY`
- `InpTierMode = ENTRY_TIER_A_ONLY`
- `InpSessionStartHour = 0`
- `InpSessionEndHour = 0`
- `InpMaxManagedPositions = 2`
- `InpReentryCooldownBars = 3`
- `InpAllowSameDirectionReentry = True`
- `InpMaxTotalRiskPercent = 1.0`
- `TierA Fib = 0.382..0.618`
- `TierB Fib = 0.236..0.786`

## Backtest Metrics
- Trades: `0`
- Profit factor: `0.00`
- Net profit: `0.00`
- Expected payoff: `0.00`
- Win rate: `0.00`
- Max drawdown %: `0.00`

## Stage Pass Counts
- `context_valid_count`: 23286
- `tierA_long_eligible_count`: 1000
- `tierB_long_eligible_count`: 1879
- `tierA_short_eligible_count`: 1851
- `tierB_short_eligible_count`: 2027
- `fib_filter_pass_count`: 268
- `pullback_structure_built_count`: 23286
- `higher_low_formed_count`: 2
- `lower_high_formed_count`: 0
- `reclaim_confirmed_count`: 24
- `setup_valid_count`: 0
- `trigger_fired_count`: 0
- `order_sent_count`: 0

## Trade Flags
- Entry rows: `0`
- Time stop after partial: `0`
- Runner hit before time stop: `0`

## Bottleneck
- `reclaim_to_setup`
