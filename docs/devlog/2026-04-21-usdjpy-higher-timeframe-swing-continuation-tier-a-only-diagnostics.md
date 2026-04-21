# 2026-04-21 USDJPY Higher-Timeframe Swing Continuation Tier A Only Diagnostics

## What changed
- Re-ran the single-slice diagnostics with `TierMode` restored from `ENTRY_TIER_A_AND_B` to `ENTRY_TIER_A_ONLY`
- Kept the other diagnostic relaxations fixed:
  - `TradeBias = BOTH`
  - `M30 x M15 x M5`
  - `EXEC_RECLAIM_CLOSE_CONFIRM`
  - no session restriction
  - `MaxManagedPositions = 2`
  - `ReentryCooldownBars = 3`
  - `AllowSameDirectionReentry = true`
  - `MaxTotalRiskPercent = 1.0`

## Why
- The prior relaxed pass showed that zero-trade was not caused by execution.
- The next isolation step was to check whether removing Tier B collapses setup assembly back toward zero.

## Evidence
- Compile log: [usdjpy_20260421_higher_timeframe_swing_continuation_engine_tier_a_only_diagnostics.log](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/usdjpy_20260421_higher_timeframe_swing_continuation_engine_tier_a_only_diagnostics.log)
- Summary: [summary-a_only.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics/results/summary-a_only.md)
- Review: [2026-04-21-usdjpy-higher-timeframe-swing-continuation-tier-a-only-diagnostics-review.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-higher-timeframe-swing-continuation-tier-a-only-diagnostics-review.md)

## Decision
- A only did not return to hard zero. It still produced `2` trades.
- The family remained weak, and the main bottleneck stayed inside pattern setup assembly rather than execution trigger firing.
