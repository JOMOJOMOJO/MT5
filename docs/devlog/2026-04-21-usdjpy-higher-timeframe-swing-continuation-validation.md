# 2026-04-21 USDJPY Higher-Timeframe Swing Continuation Validation

## Task

Test a new standalone `Higher-Timeframe Swing Continuation` family after closing the intraday reversal / failed-acceptance / session-breakout branches.

## What Changed

- added [usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260421_higher_timeframe_swing_continuation_engine.mq5)
- added [usdjpy_higher_timeframe_swing_continuation_validation.py](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/plugins/mt5-company/scripts/usdjpy_higher_timeframe_swing_continuation_validation.py)
- added presets:
  - [tierA.set](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260421_higher_timeframe_swing_continuation_engine-tierA.set)
  - [tierAB.set](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260421_higher_timeframe_swing_continuation_engine-tierAB.set)
- added durable notes:
  - [spec](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-higher-timeframe-swing-continuation-engine-spec.md)
  - [review](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-higher-timeframe-swing-continuation-validation-review.md)

## Evidence

- compile:
  - [compile log](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/usdjpy_20260421_higher_timeframe_swing_continuation_engine.log)
- backtest:
  - [summary](/C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-htf-swing-continuation-validation/results/summary.md)

## Outcome

- compile passed
- minimal matrix completed
- all runs produced `0 trades`

## Decision

Reject this family immediately. The issue was not `PF < 1`; the issue was `no executable inventory` across train, OOS, and actual.
