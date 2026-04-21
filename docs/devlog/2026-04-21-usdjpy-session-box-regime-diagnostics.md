# 2026-04-21 - usdjpy-session-box-regime-diagnostics

## Overview

- Task:
  - stop trying to improve the Tokyo-London session box breakout family
  - keep the EA logic fixed
  - use telemetry and validator slicing to determine whether any repeatable regime survives
- EA / family:
  - `usdjpy_20260421_tokyo_london_session_box_breakout_engine`
- Verdict:
  - `hard-close`

## Why This Work Happened

- The family already had enough inventory to judge.
- The previous validation showed the core problem clearly:
  - actual aggregate stayed below `PF 1`
  - dominant loss was `acceptance_back_inside_box`
- The right next step was not new logic.
- The right next step was regime diagnostics:
  - which days break cleanly
  - which slices only look good because of rescue exits

## What Changed

- Extended EA telemetry with regime fields:
  - breakout side
  - trigger type
  - box width pips / ATR ratio / bucket
  - breakout close distance pips / ATR / strength bucket
  - London minutes from open / timing bucket
  - previous-day alignment
  - M30 prior swing alignment
  - weekday
  - accepted-outside / failed-back-inside bar counters
  - MFE / MAE before acceptance exit
  - time-stop-after-partial / runner-before-time-stop flags
- Updated validator:
  - new sweep root:
    - [2026-04-21-usdjpy-session-box-regime-diagnostics](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-session-box-regime-diagnostics)
  - new summary sections for:
    - breakout side
    - box width bucket
    - breakout strength bucket
    - breakout timing bucket
    - previous-day alignment
    - M30 prior swing alignment
    - acceptance-heavy regimes
- Added diagnostics review:
  - [2026-04-21-usdjpy-session-box-regime-diagnostics-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-session-box-regime-diagnostics-review.md)

## Evidence

- Compile:
  - [metaeditor.log](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/metaeditor.log)
- Diagnostics summary:
  - [summary.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-session-box-regime-diagnostics/results/summary.md)
- Diagnostics raw rollup:
  - [results.json](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-21-usdjpy-session-box-regime-diagnostics/results/results.json)
- Prior family-level reject:
  - [2026-04-21-usdjpy-session-box-breakout-validation-review.md](C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/knowledge/experiments/2026-04-21-usdjpy-session-box-breakout-validation-review.md)

## Key Decisions

- Kept the breakout family fixed.
  - no entry redesign
  - no rescue filters
  - no new indicators
- Treated the family as a diagnostic instrument only.
- Judged slices by repeatability first, not by best-looking actual-only survivors.

## Outcome

- No family-level recovery appeared.
- `box_width_bucket` had no diagnostic power because all executed trades fell into `wide`.
- The only repeat slice was:
  - `low_breakout x 0_30m x far_prev_day_low`
  - OOS:
    - `9 trades / PF 2.00 / net +16.84`
  - actual:
    - `33 trades / PF 2.65 / net +82.44`
- That slice still failed the practical test:
  - actual runner hits:
    - `0`
  - actual time stops:
    - `15`
  - actual breakeven-after-partial:
    - `7`
  - actual acceptance-back-inside:
    - `7`

Interpretation:

- the slice survives by salvage
- it does not prove clean breakout continuation

## Next

- Do not continue this family as an EA candidate.
- Keep it only as a negative reference:
  - a simple breakout family can create inventory
  - repeat-looking slices still need to be checked for `time_stop` dependence
  - `acceptance_back_inside_box` remained the structural failure even after regime slicing
