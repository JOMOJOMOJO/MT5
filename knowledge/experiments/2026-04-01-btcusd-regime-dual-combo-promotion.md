# BTCUSD Regime Dual Combo Promotion

## Summary

- Built a fresh `btcusd_20260401_regime_dual` family so the surviving `M5 long` and `M15 short` buckets can run together without forcing one shared timeframe.
- Promoted the first integrated combo:
  - `M5 long ret24 + stoch24 + hold8 + stop1.50ATR`
  - `M15 NY short ema_gap_50_100 + ema_gap_20_50 + hold12 + stop1.50ATR`
- Rejected the first quality-biased variant:
  - same combo but `M5 stoch19` instead of `stoch24`

## Actual MT5 Results

### Promoted Combo

- preset:
  - `btcusd_20260401_regime_dual-m5long-m15short-combo`
- 1-year actual:
  - net `+1117.32`
  - PF `1.18`
  - trades `381`
  - DD `5.33%`
- OOS 2026Q1 actual:
  - net `+997.10`
  - PF `1.51`
  - trades `123`
  - DD `1.97%`

### Rejected Quality-Biased Variant

- preset:
  - `btcusd_20260401_regime_dual-m5long19-m15short-combo`
- 1-year actual:
  - net `+890.24`
  - PF `1.16`
  - trades `338`
  - DD `5.04%`

## Interpretation

- The first real multi-bucket integration is positive on both:
  - the full 1-year actual window,
  - and the latest 3-month OOS actual window.
- This is the best high-turnover family in the repo so far by total annual trade count:
  - about `1.04 trades/day` on the 1-year window.
- It is still below the business objective for a true multi-trade-per-day mainline.
- The integration result matters because the previous best high-turnover branch was only:
  - `M5 long ret24-stoch24-h8-s15`
  with `240` trades/year.
- Tightening the long bucket back to `stoch19` improved nothing important enough and reduced turnover, so the broader `stoch24` long bucket is the right combo partner for now.

## Verdict

- Promote `btcusd_20260401_regime_dual-m5long-m15short-combo` as the current best high-turnover research candidate.
- Reject `btcusd_20260401_regime_dual-m5long19-m15short-combo`.
- Do not discuss live promotion yet.

## Next Step

- The next cycle should do one of these:
  - add one more positive complementary bucket so total turnover clears the floor more convincingly,
  - or redesign exit / execution logic so the current `381 trades/year` family can lift full-year PF without losing too much turnover.
