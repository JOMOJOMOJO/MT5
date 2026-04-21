# 2026-04-21 - usdjpy-session-box-breakout-validation

## Overview

- Task:
  - close the recent structure / reversal family line
  - choose one simpler breakout family
  - implement and validate only that family
- EA / family:
  - `usdjpy_20260421_tokyo_london_session_box_breakout_engine`
- Verdict:
  - `reject`

## Why This Work Happened

- The recent `Dow HS`, `liquidity sweep / failed acceptance`, and `N-wave third-leg` families all failed as standalone mainlines.
- The next step was to test whether a simpler, more visible price-band family could survive with better inventory and less subtype dependence.

## What Changed

- Added spec:
  - [2026-04-21-usdjpy-tokyo-london-session-box-breakout-engine-spec.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-tokyo-london-session-box-breakout-engine-spec.md)
- Added EA scaffold:
  - [usdjpy_20260421_tokyo_london_session_box_breakout_engine.mq5](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260421_tokyo_london_session_box_breakout_engine.mq5)
- Added presets:
  - [usdjpy_20260421_tokyo_london_session_box_breakout_engine-strict.set](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260421_tokyo_london_session_box_breakout_engine-strict.set)
  - [usdjpy_20260421_tokyo_london_session_box_breakout_engine-broad.set](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/presets/usdjpy_20260421_tokyo_london_session_box_breakout_engine-broad.set)
- Added validator:
  - [usdjpy_tokyo_london_session_box_breakout_validation.py](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/plugins/mt5-company/scripts/usdjpy_tokyo_london_session_box_breakout_validation.py)
- Added validation review:
  - [2026-04-21-usdjpy-session-box-breakout-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-session-box-breakout-validation-review.md)

## Evidence

- Compile:
  - [metaeditor.log](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/metaeditor.log)
- Sweep summary:
  - [summary.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-session-box-validation/results/summary.md)
- Sweep raw rollup:
  - [results.json](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-session-box-validation/results/results.json)
- Prior closure evidence:
  - [2026-04-20-usdjpy-n-wave-third-leg-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-20-usdjpy-n-wave-third-leg-validation-review.md)
  - [2026-04-16-usdjpy-external-liquidity-sweep-failed-acceptance-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-16-usdjpy-external-liquidity-sweep-failed-acceptance-validation-review.md)

## Key Decisions

- Selected `Session High/Low Breakout` before `ORB` or `session-driven continuation breakout`.
  - `ORB` adds opening-window sensitivity too early.
  - session-driven continuation adds directional logic before proving simple breakout edge.
- Fixed the session concept to one idea only:
  - `Tokyo range -> London breakout`
- Kept the family simple:
  - price
  - time
  - high/low box
  - ATR-derived buffer
  - no EMA-led or oscillator-led filter expansion
- Adjusted the initial box-width preset after the first zero-trade pass.
  - This was treated as executable-baseline correction, not as a rescue cycle.

## Outcome

- The family created real inventory.
- OOS had one positive slice:
  - `M15 range x M3 execution x range_close_confirm`
- Actual aggregate stayed below `PF 1` across all pair and trigger aggregates.
- The dominant loss path was `acceptance_back_inside_box`.
- Positive outcome depended too much on `time_stop` rescue.

## Next

- Do not extend this family with rescue filters.
- Treat the result as a cleaner negative than the recent structure families:
  - the family is simple,
  - the inventory is real,
  - the edge still did not survive.
