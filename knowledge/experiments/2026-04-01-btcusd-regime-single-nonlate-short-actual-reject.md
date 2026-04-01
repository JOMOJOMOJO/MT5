# BTCUSD Regime Single Non-Late / Short Actual Reject

## Summary

- Tested three fresh sidecar candidates around `btcusd_20260401_regime_single`.
- Goal was to add either:
  - a non-late complementary long regime,
  - or a new short branch,
  without touching the surviving `ret24-stoch24-h8-s15` branch.
- All three candidates failed the full 1-year actual MT5 window.

## Candidates

- `short-macd08-ny-h12-s15`
- `short-hb24m05-flow02-ny-h12-s15`
- `long-emagap2050m12-hb24m55-asia-h12-s15`

## Actual MT5 Results

- `short-macd08-ny-h12-s15`
  - net `-926.42`
  - PF `0.82`
  - trades `257`
  - DD `11.70%`
- `short-hb24m05-flow02-ny-h12-s15`
  - net `-1198.50`
  - PF `0.76`
  - trades `263`
  - DD `12.11%`
- `long-emagap2050m12-hb24m55-asia-h12-s15`
  - net `-193.69`
  - PF `0.90`
  - trades `93`
  - DD `6.01%`

## Interpretation

- The first fresh short-side rules looked acceptable in feature mining, but did not survive actual MT5 friction.
- The Asia-side complementary long also failed the broker cost floor on the full-year window.
- This means the current `regime_single` family still has only one durable branch:
  - `long-ret24-stoch24-h8-s15`

## Verdict

- Reject this first non-late / short actual batch.
- Do not promote any of these sidecars into the active family.
- Keep `ret24-stoch24-h8-s15` as the current best high-turnover branch, but not as a live-track candidate.
- Open the next cycle from a fresh behavior thesis, not from more `ema2050`, `ema50100`, `NY short macd`, or `NY short high_break24` variants.
