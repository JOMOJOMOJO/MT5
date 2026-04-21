# USDJPY Tokyo-London Session Box Breakout Validation Review

Date: 2026-04-21
Family: `USDJPY Tokyo-London Session Box Breakout Engine`
Verdict: `reject`

## Scope

- session concept:
  - `Tokyo range -> London breakout`
- fixed slice:
  - `both directions`
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

## Important Implementation Note

- The first strict preset was too restrictive on Tokyo box width and produced `0 trades`.
- That was treated as an executable-baseline issue, not as a rescue cycle.
- The strict baseline was widened to:
  - `min range 4 pips`
  - `max range 40 pips`
  - smaller breakout confirmation buffer
- After that adjustment, the family produced stable inventory and could be judged.

## What Happened

### Inventory

- inventory was real, unlike the recent structure families:
  - OOS total: `88 trades`
  - actual total: `460 trades`
- the family did not collapse into a single sparse survivor immediately.
- `session_high_breakout` carried more quality than `session_low_breakout`, but both sides traded.

### Best OOS Slice

- `M15 range x M3 execution x range_close_confirm`
  - `12 trades`
  - `PF 3.72`
  - `net +38.96`

### Actual Reality

- actual pair aggregates all stayed below `PF 1`:
  - `M15 range x M5 execution`: `153 trades / PF 0.70 / net -177.79`
  - `M30 range x M5 execution`: `153 trades / PF 0.70 / net -177.55`
  - `M15 range x M3 execution`: `154 trades / PF 0.65 / net -199.24`
- actual trigger aggregates all stayed below `PF 1`:
  - `range_close_confirm`: `164 trades / PF 0.72 / net -153.56`
  - `breakout_bar_continuation`: `156 trades / PF 0.74 / net -163.83`
  - `range_retest_confirm`: `140 trades / PF 0.58 / net -237.19`

## Telemetry Read

### Main Failure Path

- dominant exit reason in every window was `acceptance_back_inside_box`.
- actual:
  - `264 exits`
  - `net -1698.18`
- OOS:
  - `33 exits`
  - `net -271.55`

### Rescue Path

- `time_stop` was positive and acted as the main rescue bucket:
  - actual:
    - `95 exits`
    - `net +687.43`
  - OOS:
    - `30 exits`
    - `net +75.30`
- `runner_target` and `breakeven_after_partial` were also positive, but smaller.

Interpretation:

- the family often created movement after entry,
- but the move was not accepted enough outside the Tokyo box,
- so exits were carried by hold-and-rescue behavior rather than clean breakout continuation.

## Structural Read

- `M15 x M5` and `M30 x M5` were nearly identical.
  - This means the Tokyo box itself is not very sensitive to `M15` vs `M30`.
  - That is good for simplicity.
- The only clearly positive OOS slice was `M15 x M3 x close confirm`.
  - It did not repeat in actual.
- `session_high_breakout` was materially better than `session_low_breakout`.
  - actual:
    - high break: `273 trades / PF 0.86 / net -137.17`
    - low break: `187 trades / PF 0.46 / net -417.41`
- Even the better long-side breakout bucket did not cross `PF 1`.

## Conclusion

- This family is simpler and more inventory-rich than the recent structure families.
- That makes the result informative.
- The result is still `reject` because:
  - OOS positive behavior did not repeat in actual
  - actual aggregate remained below `PF 1` despite enough trades
  - the family depended too much on `time_stop` rescue
  - the dominant failure path was repeated acceptance back inside the Tokyo box

## Reusable Lesson

- For USDJPY, a plain `Tokyo box -> London breakout` is a valid inventory generator.
- That alone is not enough to prove durable edge.
- If the main positive bucket is `time_stop` while the dominant negative bucket is acceptance back inside the box, the breakout family is still not strong enough as a standalone mainline.
