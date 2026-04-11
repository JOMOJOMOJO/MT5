# USDJPY fractal short session analysis

- Date: `2026-04-11`
- Family: `usdjpy_20260411_fractal_structure_short_guarded`
- Goal:
  - verify whether the new fractal `Method2` can survive as a standalone `short-only` branch,
  - improve it by session and hour selection instead of tightening the price-pattern filters into a sparse sample.

## Baseline Result

- Candidate:
  - `mql/Experts/usdjpy_20260411_fractal_structure_short_guarded.mq5`
- Baseline preset:
  - `reports/presets/usdjpy_20260411_fractal_structure_short_guarded-baseline.set`
- Windows:
  - train `2025-04-01` to `2025-12-31`
  - OOS `2026-01-01` to `2026-04-01`
  - actual `2024-11-26` to `2026-04-01`

### Baseline metrics

- Train:
  - `net -108.58`
  - `PF 0.77`
  - `30 trades`
  - `max balance DD 2.77%`
- OOS:
  - `net +44.79`
  - `PF 9.82`
  - `3 trades`
  - `max balance DD 0.05%`
- Actual 16m:
  - `net -191.75`
  - `PF 0.77`
  - `54 trades`
  - `max balance DD 3.64%`

## Trade-Time Review

The baseline failure was not evenly distributed across the day.

### Actual 16m entry-hour summary

- Positive clusters:
  - `10`
  - `13`
  - `14`
  - `16`
  - `17`
- Clearly negative clusters:
  - `11`
  - `12`
  - `15`
  - `19`
  - `20`
  - `21`
  - `22`
  - `03`
  - `04`

### Session-level read

- `asia` (`00-06`) was negative.
- `europe-open` (`07-12`) was negative because `11-12` dragged the bucket down.
- `london-ny` (`13-16`) was positive.
- `late-us` (`17-23`) was mixed to negative.

### Weekday read

- `Tuesday` was clearly positive.
- `Wednesday` was mildly positive.
- `Friday` and `Thursday` were negative.
- OOS did not confirm a stable weekday edge, so weekday filtering was not promoted.

## Session Variant 1

- Preset:
  - `reports/presets/usdjpy_20260411_fractal_structure_short_guarded-session1018.set`
- Logic:
  - keep the same price-pattern logic,
  - restrict entries to `10-17 JST` through the session window only.

### Metrics

- Train:
  - `net +152.60`
  - `PF 2.00`
  - `14 trades`
  - `max balance DD 0.85%`
- OOS:
  - `net +45.82`
  - `1 trade`
  - no losing trade
- Actual 16m:
  - `net +24.17`
  - `PF 1.06`
  - `28 trades`
  - `max balance DD 1.78%`

### Read

- This proved that time-of-day selection materially matters for the family.
- But the contiguous `10-17` window still kept too much weak inventory.
- It improved quality from `PF 0.77` to `PF 1.06`, but not enough for standalone promotion.

## Hour-Selected Variant

- Preset:
  - `reports/presets/usdjpy_20260411_fractal_structure_short_guarded-hours1013141617.set`
- Logic:
  - same price-pattern logic,
  - keep the session open,
  - allow only the entry hours that stayed positive in the baseline trade review:
    - `10,13,14,16,17`

### Metrics

- Train:
  - `net +266.56`
  - `PF 7.45`
  - `10 trades`
  - `max balance DD 0.35%`
- OOS:
  - `net +45.82`
  - `1 trade`
  - no losing trade
- Actual 16m:
  - `net +233.95`
  - `PF 2.29`
  - `18 trades`
  - `max balance DD 0.75%`

## Verdict

- The new fractal `Method2 short-only` is not dead.
- The baseline all-day branch is rejectable as a standalone route.
- The family improves mainly through `hour selection`, not through stricter candle geometry.
- The best current branch is `hours1013141617`.

## Promotion Decision

- Do not call the baseline all-day branch operational.
- Do not widen the family by loosening sweep or rejection thresholds just to increase count.
- Keep `hours1013141617` as the current best `short-only candidate`.
- Do not yet call it a standalone `demo-forward candidate`:
  - latest OOS has only `1 trade`,
  - recurrence is still too thin for strong standalone promotion language.

## Reusable Lesson

- For this family, the first-order improvement lever is `when` the pattern is allowed to trade.
- The second-order lever is not tighter signal geometry; that only risks shrinking the sample again.
- Session and hour routing should be treated as part of the edge definition for `USDJPY short` families.
