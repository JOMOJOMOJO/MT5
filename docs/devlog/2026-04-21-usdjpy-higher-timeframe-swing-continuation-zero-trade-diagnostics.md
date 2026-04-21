# 2026-04-21 USDJPY Higher-Timeframe Swing Continuation Zero-Trade Diagnostics

## What changed
- Added one-off diagnostic instrumentation to [usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5)
- Added a dedicated single-run validator: [usdjpy_higher_timeframe_swing_continuation_zero_trade_diagnostics.py](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/plugins/mt5-company/scripts/usdjpy_higher_timeframe_swing_continuation_zero_trade_diagnostics.py)

## Why
- The initial validation matrix produced `27/27` zero-trade runs.
- Before discarding the family completely, the user requested one isolation pass to locate where inventory was dying.

## Evidence
- Compile log: [usdjpy_20260421_higher_timeframe_swing_continuation_engine_diagnostics.log](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/usdjpy_20260421_higher_timeframe_swing_continuation_engine_diagnostics.log)
- Diagnostic summary: [summary.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-zero-trade-diagnostics/results/summary.md)
- Diagnostic review: [2026-04-21-usdjpy-higher-timeframe-swing-continuation-zero-trade-diagnostics-review.md](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-higher-timeframe-swing-continuation-zero-trade-diagnostics-review.md)

## Decision
- The family was not inherently zero-trade once `BOTH`, `Tier A+B`, relaxed position guards, and wider Tier B fib were allowed.
- The main bottleneck was the pattern-stage transition from `fib pass` to `higher low / lower high` confirmation, not execution trigger scarcity.
- This was logged as a diagnostic only. It is not a promotion or rescue decision.
