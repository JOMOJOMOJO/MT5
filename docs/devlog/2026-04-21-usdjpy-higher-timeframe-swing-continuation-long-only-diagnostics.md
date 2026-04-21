# 2026-04-21 USDJPY Higher-Timeframe Swing Continuation Long-Only Diagnostics

## What changed
- Extended the single-run diagnostics script to accept `TradeBias` as a runtime override
- Re-ran the fixed diagnostic slice with:
  - `M30 x M15 x M5`
  - `EXEC_RECLAIM_CLOSE_CONFIRM`
  - `ENTRY_TIER_A_ONLY`
  - `TRADE_BIAS_LONG_ONLY`

## Why
- The prior `A_ONLY / BOTH` pass still produced `2` trades.
- Before discarding the long-side continuation thesis, the next isolated question was whether those residual trades came from the short side.

## Evidence
- Compile log: [usdjpy_20260421_higher_timeframe_swing_continuation_engine_long_only_diagnostics.log](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/usdjpy_20260421_higher_timeframe_swing_continuation_engine_long_only_diagnostics.log)
- Summary: [summary-a_only-long_only.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics/results/summary-a_only-long_only.md)
- Review: [2026-04-21-usdjpy-higher-timeframe-swing-continuation-long-only-diagnostics-review.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-higher-timeframe-swing-continuation-long-only-diagnostics-review.md)

## Decision
- `A_ONLY / BOTH` surviving inventory was short-only.
- `A_ONLY / LONG_ONLY` returned to `0` trades.
- The long-side hypothesis is not merely weak. Under Tier A strictness on this slice, it does not produce executable inventory.
