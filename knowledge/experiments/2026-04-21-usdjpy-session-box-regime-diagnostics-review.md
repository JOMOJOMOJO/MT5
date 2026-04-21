# USDJPY Tokyo-London Session Box Breakout Regime Diagnostics Review

Date: 2026-04-21  
Family: `USDJPY Tokyo-London Session Box Breakout Engine`  
Verdict: `hard-close`

## Scope

- family:
  - `Tokyo 00:00-07:00 box -> London 07:00-16:00 breakout`
- fixed exits:
  - `partial 38.2`
  - `final session extension`
  - `hold 24`
  - `EA managed exits`
- compared:
  - pairs:
    - `M15 range x M5 execution`
    - `M30 range x M5 execution`
    - `M15 range x M3 execution`
  - triggers:
    - `range_close_confirm`
    - `range_retest_confirm`
    - `breakout_bar_continuation`
- diagnostic axes:
  - `breakout_side`
  - `trigger_type`
  - `box_width_bucket`
  - `breakout_strength_bucket`
  - `breakout_timing_bucket`
  - `prev_day_alignment_type`
  - `m30_swing_alignment_type`
  - `weekday`

## Aggregate Read

- train:
  - `291 trades / PF 0.55 / net -572.60`
- OOS:
  - `88 trades / PF 0.62 / net -121.67`
- actual:
  - `460 trades / PF 0.68 / net -554.58`

The family still creates real inventory.  
The problem is unchanged:

- dominant loss is still `acceptance_back_inside_box`
- positive-looking paths still lean on `time_stop`
- family aggregate stays below `PF 1` in OOS and actual

## What The Regime Cuts Show

### 1. High breakout only does not rescue the family

- OOS:
  - `high_breakout = 51 trades / PF 0.77 / net -33.86`
- actual:
  - `high_breakout = 273 trades / PF 0.86 / net -137.17`

High breakout is better than low breakout, but it is still not a standalone edge.

### 2. Low breakout is not uniformly dead

- OOS:
  - `low_breakout x 0_30m = 9 trades / PF 2.00 / net +16.84`
- actual:
  - `low_breakout x 0_30m = 42 trades / PF 1.22 / net +24.18`

This is the only slice that repeated directionally in both OOS and actual.

But the mechanism is weak:

- OOS reason mix:
  - `time_stop 4`
  - `acceptance_back_inside_box 3`
  - `breakeven_after_partial 2`
- actual reason mix:
  - `time_stop 15`
  - `acceptance_back_inside_box 16`
  - `breakeven_after_partial 7`
  - `runner_target 0`

Interpretation:

- the slice survives mainly by holding and salvaging
- it does not show clean breakout continuation
- it does not show runner follow-through

### 3. Box width bucket is not informative

- all closed trades landed in `wide`

So box width does not separate good and bad days inside the current executable family.  
That is diagnostic evidence, not a filter proposal.

### 4. Strong close alone is not enough

- OOS:
  - `strong_close = 75 trades / PF 0.93 / net -13.49`
- actual:
  - `strong_close = 288 trades / PF 0.75 / net -254.81`

Strong breakout close helps relative to weak close, but it still does not produce repeatable positive expectancy.

### 5. Breakout timing matters, but not in a durable way

- OOS:
  - `0_30m = 19 trades / PF 1.40 / net +17.93`
  - `30_60m = 21 trades / PF 0.23 / net -66.96`
  - `60m_plus = 48 trades / PF 0.61 / net -72.64`
- actual:
  - `30_60m = 58 trades / PF 2.27 / net +151.91`
  - `0_30m = 101 trades / PF 0.53 / net -171.43`
  - `60m_plus = 301 trades / PF 0.58 / net -535.06`

Timing clearly matters, but the winning timing bucket flips between OOS and actual.  
That is not stable regime behavior.

### 6. Previous-day and M30 alignment do not produce a durable family-level fix

Promising slices:

- `low_breakout x 0_30m x far_prev_day_low`
  - OOS: `9 trades / PF 2.00 / net +16.84`
  - actual: `33 trades / PF 2.65 / net +82.44`
  - reason mix in actual:
    - `time_stop 15`
    - `breakeven_after_partial 7`
    - `acceptance_back_inside_box 7`
    - `runner_target 0`
- `near_m30_prior_swing_high`
  - actual only:
    - `31 trades / PF 2.85 / net +123.11`
  - OOS:
    - no real inventory

Interpretation:

- `far_prev_day_low` improves one early London short slice, but still through rescue behavior
- `near_m30_prior_swing_high` is an actual-only survivor and does not repeat

## Where Acceptance Failures Concentrate

### OOS

- `acceptance_back_inside_box = 33 trades / net -271.55`
- concentrated in:
  - `low_breakout = 20 trades / net -152.03`
  - `exec_breakout_bar_continuation = 13 trades / net -149.80`
  - `60m_plus = 16 trades / net -139.52`

### Actual

- `acceptance_back_inside_box = 264 trades / net -1698.18`
- concentrated in:
  - `high_breakout = 159 trades / net -938.45`
  - `exec_range_retest_confirm = 96 trades / net -569.39`
  - `exec_range_close_confirm = 94 trades / net -532.83`
  - `60m_plus = 189 trades / net -1225.40`

The dominant loss path remains the same after slicing:

- break out of the box
- fail to hold outside it
- get closed on acceptance back inside

## Decision

`Hard-close`.

Reason:

- family aggregate is negative in both OOS and actual
- the only repeat slice is `low_breakout x 0_30m x far_prev_day_low`
- that slice is still driven by `time_stop / breakeven` rather than runner continuation
- strong-looking actual-only slices such as `near_m30_prior_swing_high` do not repeat in OOS
- dominant failure is still `acceptance_back_inside_box`

This means the family is useful as a diagnostic artifact, not as a candidate mainline.
