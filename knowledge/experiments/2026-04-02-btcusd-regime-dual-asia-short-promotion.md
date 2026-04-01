# BTCUSD Regime Dual Asia Short Promotion

## Summary

- Tested whether `btcusd_20260401_regime_dual` still had structural headroom.
- Added a fresh `M15 Asia short` bucket mined from the feature lab:
  - `close_vs_ema50 >= 1.9306`
  - plus `ema_gap_20_50 >= 1.0387`
- Validated it first as a standalone sidecar.
- Then integrated it into the current `M5 long + M15 NY short` combo.

## Standalone Asia Short

- preset:
  - `btcusd_20260401_regime_dual-m15-asia-close50-eg2050-short-h12-s15`

### 1-year actual

- net `+677.81`
- PF `1.33`
- trades `137`
- DD `2.82%`

### OOS 2026Q1 actual

- net `+325.26`
- PF `2.46`
- trades `24`
- DD `0.69%`

## Integrated Combo Plus Asia Short

- preset:
  - `btcusd_20260401_regime_dual-m5long-m15short-asia-combo`

### Previous best combo

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

### New combo plus Asia short

- 1-year actual:
  - net `+1854.27`
  - PF `1.22`
  - trades `518`
  - DD `4.80%`
- OOS 2026Q1 actual:
  - net `+1374.65`
  - PF `1.61`
  - trades `147`
  - DD `2.29%`

## Interpretation

- This family is not fully plateaued yet.
- The third positive bucket improved all of these at once on the full 1-year window:
  - net profit,
  - total trade count,
  - and drawdown,
  while also lifting OOS net and PF.
- The annual PF is still below the repo-wide live gate.
- So the right reading is:
  - `not headroom exhausted`,
  - but `still research, not live`.

## Verdict

- Promote `btcusd_20260401_regime_dual-m5long-m15short-asia-combo` as the current best high-turnover family.
- Park the previous two-bucket combo as a baseline reference.
- Do not call the family `live-ready` yet.

## Next Step

- The next serious cycle should target one of these:
  - a fourth positive bucket,
  - or execution / exit design that lifts the annual PF from `1.22` toward the live gate without breaking the new turnover.
