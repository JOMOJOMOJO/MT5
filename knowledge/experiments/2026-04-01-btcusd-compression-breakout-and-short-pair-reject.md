# BTCUSD Compression Breakout And Short Pair Reject

## Summary

- Tested a fresh `compression_breakout` family from the spread-aware feature lab.
- Extended `btcusd_20260401_regime_single` so new short pair rules could be checked directly in MT5.
- Also checked the last spread-aware single-feature survivor:
  - `late breakout_persist_down_6`
- None of these branches cleared the 1-year actual MT5 baseline.

## Compression Breakout Family

Actual MT5 1-year results:

- `long-london-rc24-012-bfup03-h12-s20`
  - net `+143.26`
  - PF `1.03`
  - trades `261`
  - DD `11.60%`
- `long-london-rc24-012-bfup03-h12-s30`
  - net `+127.64`
  - PF `1.03`
  - trades `292`
  - DD `9.24%`
- `long-london-rc24-0145-bfup03-h12-s20`
  - net `+92.65`
  - PF `1.02`
  - trades `266`
  - DD `11.76%`

Verdict:

- Reject `btcusd_20260401_compression_breakout` at baseline.
- The family was not dead on raw PnL, but PF stayed too close to `1.0` while drawdown stayed too high.
- This is not a promotion candidate and not a useful secondary branch.

## New Short Pair Extensions Inside `regime_single`

Actual MT5 1-year results:

- `short-rsi7-ret6-h6-s12`
  - net `-1018.76`
  - PF `0.44`
  - trades `87`
  - DD `11.96%`
- `short-rsi7-high12-h6-s12`
  - net `-1081.58`
  - PF `0.45`
  - trades `98`
  - DD `11.83%`

Verdict:

- Reject both new short pair branches immediately.
- The feature-lab short pairs did not survive executable MT5 entry path and broker friction.
- Keep the short side in research only.

## Last Spread-Aware Single-Feature Survivor

Actual MT5 1-year result:

- `long-bpd6-late-h12-s15`
  - net `-815.29`
  - PF `0.84`
  - trades `249`
  - DD `11.91%`

Verdict:

- Reject the late-session `breakout_persist_down_6` sidecar too.
- Even the one single-feature rule that still looked positive after spread-aware screening did not survive actual MT5.

## Current State

- Current high-turnover best is still:
  - `btcusd_20260401_regime_single-long-ret24-stoch24-h8-s15`
- Current quality reference inside the high-turnover family is still:
  - `btcusd_20260401_regime_single-long-ret24-stoch19-h8`
- No new family or sidecar in this cycle beat the surviving `ret24` branch.

## Interpretation

- The false-positive rate from mined M5 features is still high on this broker.
- Feature-lab tables are useful for ranking where to look next, but not for promotion.
- The correct use of mined rules in this repo is:
  - screen quickly,
  - express one executable MT5 baseline,
  - kill it fast if the 1-year actual stays near or below PF `1.0`.

## Next Step

- Do not spend another cycle on:
  - `compression breakout`,
  - `short rsi7 pair`,
  - or `late breakout_persist_down_6`.
- The next high-turnover cycle should start from a fresh market-behavior thesis outside these neighborhoods.
