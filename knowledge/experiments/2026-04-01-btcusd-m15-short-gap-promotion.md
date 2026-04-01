# BTCUSD M15 Short Gap Promotion

## Summary

- Opened a fresh `M15` research track to reduce M5 microstructure noise while keeping multi-trade-per-week behavior.
- Rejected the first `M15 late long` pair:
  - `late close_vs_ema50 + macd_line_atr`
- Promoted the first positive `M15 short` pair:
  - `NY ema_gap_50_100 <= -1.0353`
  - plus `ema_gap_20_50 <= -0.8779`

## Rejected M15 Long Pair

- preset:
  - `btcusd_20260401_regime_single-m15-late-close50-macd-h12-s15`
- 1-year actual:
  - net `-560.40`
  - PF `0.76`
  - trades `157`
  - DD `8.89%`

Verdict:

- Reject the first `M15 late long` branch.
- The mined pair looked strong offline but did not survive actual MT5 execution.

## Promoted M15 Short Pair

- preset:
  - `btcusd_20260401_regime_single-m15-ny-eg50100-eg2050-short-h12-s15`

### 1-year actual

- net `+573.08`
- PF `1.24`
- trades `139`
- DD `3.91%`

### OOS 2026Q1 actual

- net `+696.44`
- PF `1.75`
- trades `52`
- DD `1.62%`

## Interpretation

- This is the first fresh complementary short branch in the high-turnover research line that survived both:
  - the full 1-year actual MT5 window,
  - and the latest 3-month OOS actual window.
- It is not a standalone high-turnover live candidate yet.
- Trade count is still too low for the business objective:
  - about `0.38 trades/day` on the 1-year window.
- But it is useful because it proves the family can now carry:
  - one positive M5 long branch,
  - and one positive M15 short branch,
  across different regimes.

## Current Family State

- Best M5 turnover branch:
  - `btcusd_20260401_regime_single-long-ret24-stoch24-h8-s15`
- First positive complementary branch:
  - `btcusd_20260401_regime_single-m15-ny-eg50100-eg2050-short-h12-s15`

## Verdict

- Promote the `M15 NY short gap` branch as the first positive complementary sidecar inside `btcusd_20260401_regime_single`.
- Do not treat it as a live-ready branch by itself.
- Next cycle should focus on one of these:
  - integrate the surviving M5 long and M15 short logic into a coherent multi-bucket family,
  - or find one more positive branch so the combined trade count clears the turnover floor.
