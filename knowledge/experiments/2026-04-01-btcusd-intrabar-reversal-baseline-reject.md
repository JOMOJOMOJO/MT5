# BTCUSD Intrabar Reversal Baseline Reject

## Summary

- Opened a fresh family:
  - `btcusd_20260401_intrabar_reversal`
- Thesis:
  - `late downside followthrough -> long`
  - `NY close near high -> short`
- The family was implemented directly in MT5 so the thesis could be checked under actual execution assumptions instead of only on feature-lab outputs.

## Actual MT5 Results

- `long-late-bfd014-h12-s15`
  - net `-1054.11`
  - PF `0.81`
  - trades `277`
  - DD `12.17%`
- `short-ny-cl76-h12-s15`
  - net `-1203.32`
  - PF `0.46`
  - trades `101`
  - DD `12.03%`

## Interpretation

- The feature-lab edge did not survive the full actual MT5 translation.
- This is not a small tuning miss.
- Both sides failed clearly enough that the family should not stay active for more parameter work.

## Verdict

- Kill `btcusd_20260401_intrabar_reversal` at baseline.
- Keep only the lesson:
  - bar-shape edges that look clean in the mined feature table can still collapse once expressed with executable MT5 rules and the broker spread floor.
- The next mainline cycle should start from another fresh thesis, likely around:
  - range compression / breakout behavior,
  - or a new execution-aware family outside the current reversal neighborhoods.
