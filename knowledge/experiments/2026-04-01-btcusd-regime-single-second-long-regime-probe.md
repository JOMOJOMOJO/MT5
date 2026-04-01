# BTCUSD Regime Single Second Long Regime Probe

## Summary

- Searched for a second positive long regime that could complement:
  - `long-ret24-stoch24-h8-s15`
- Focused only on rules the current `btcusd_20260401_regime_single` EA can already express.
- Candidate source was the late-session spread-aware mining pass, then everything was checked in actual MT5.

## Candidates Tested

- `ema50100 + high_break24 filter`
  - preset:
    - `btcusd_20260401_regime_single-long-ema50100-hb24-h8-s15`
- `ema2050 + high_break24 filter`
  - preset:
    - `btcusd_20260401_regime_single-long-ema2050-hb24-h8-s15`
- `ema50100 + stoch24`
  - preset:
    - `btcusd_20260401_regime_single-long-ema50100-stoch24-h8-s15`
- `ema50100 + bb_z`
  - preset:
    - `btcusd_20260401_regime_single-long-ema50100-bbz-h8-s15`

All used:

- late session `20:00-24:00`
- hold `8`
- stop `1.50 ATR`
- no fixed `R` target

## Actual MT5 Results

- `ema50100 + high_break24`
  - net `-5.81`
  - PF `1.00`
  - trades `63`
  - DD `3.29%`
- `ema2050 + high_break24`
  - net `-26.93`
  - PF `0.97`
  - trades `56`
  - DD `3.31%`
- `ema50100 + stoch24`
  - net `-139.07`
  - PF `0.93`
  - trades `114`
  - DD `4.84%`
- `ema50100 + bb_z`
  - net `+10.74`
  - PF `1.15`
  - trades `3`
  - DD `0.40%`

## Interpretation

- The data-mined late-session complements did not survive actual MT5 translation.
- `ema50100 + high_break24` was the closest to neutral, but still not promotable.
- `ema50100 + bb_z` was not a real candidate because the sample collapsed.
- This means the current family still has only one durable branch:
  - `long-ret24-stoch24-h8-s15`

## Verdict

- Reject this first second-long-regime batch as promotion candidates.
- Do not add them as a secondary branch inside the EA.
- Keep them only as rejected lineage.

## Next Step

- Stop searching for more late-session variants inside the same feature neighborhood.
- Open the next cycle from one of these directions:
  - a non-late complementary long regime,
  - or a fresh short-side construction with new filters / new family logic.
