# BTCUSD Regime Single Spread-Fix Review

## What Changed

- Fixed the feature-lab `spread_atr` calculation so broker cost screening now uses `spread_price / ATR` instead of a point-scale distortion.
- Re-ran the BTCUSD M5 feature lab, the flow-filter probe, and a new spread-aware re-rank.
- Built a new prototype EA:
  - `mql/Experts/btcusd_20260401_regime_single.mq5`

## Corrected Spread Floor

- Analysis window:
  - `2025-04-16 14:10` to `2026-04-01 10:10`
- Broker spread in ATR terms on the OOS split:
  - mean `0.2327 ATR`
  - median `0.1918 ATR`
  - p75 `0.2751 ATR`
  - p90 `0.4012 ATR`

## Spread-Aware Promotable Rules

- Late-session long:
  - `ema_gap_20_50 <= -1.3698`
  - test `7.92/day`, exp `0.5374 ATR`, net after p75 spread `0.3180 ATR`
- NY short:
  - `macd_line_atr >= 0.9665`
  - test `6.63/day`, exp `0.5221 ATR`, net after p75 spread `0.3032 ATR`
- Alternate late-session long:
  - `ret_24 <= -0.0057`
  - test `9.54/day`, exp `0.4041 ATR`, net after p75 spread `0.2391 ATR`

## Actual MT5 Results

### Baseline `regime_single`

- 1-year actual:
  - net `-1084.34`
  - PF `0.70`
  - trades `159`
  - relative DD `11.77%`
- OOS 3-month actual:
  - net `+1012.10`
  - PF `1.27`
  - trades `197`
  - relative DD `4.23%`

### Side Split

- Long-only baseline (`ema_gap_20_50`):
  - 1-year actual net `-250.42`
  - PF `0.95`
  - trades `269`
- Short-only baseline (`macd_line_atr`):
  - 1-year actual net `-1092.36`
  - PF `0.67`
  - trades `143`

### Long Alternatives

- Long `ret_24 <= -0.0057`:
  - 1-year actual net `+143.27`
  - PF `1.02`
  - trades `368`
  - relative DD `10.43%`
- Long `ret_24 <= -0.0057` OOS 3-month:
  - net `+139.62`
  - PF `1.06`
  - trades `135`
  - relative DD `3.23%`
- Long `ema_gap_50_100`:
  - 1-year actual net `-997.57`
  - PF `0.69`
  - trades `136`

## Volume / Flow Judgement

- Volume and flow were useful at the research stage.
- They helped confirm that crowded upside moves are cleaner short-fade contexts than generic overbought prints.
- They did not yet produce a short-side full-year actual candidate on this broker.
- For now, volume/flow remains a filter and ranking tool, not a stand-alone live rule.

## Verdict

- Reject the first combined `regime_single` baseline as a promotion candidate.
- Reject the current short-side branch on the full 1-year actual window.
- Keep `long-ret24` as the best high-turnover sub-branch:
  - it is positive on both 1-year actual and 3-month OOS,
  - but PF is still too weak for promotion.

## Next Step

- Keep the high-turnover mainline inside `btcusd_20260401_regime_single`.
- Focus the next cycle on `long-ret24` only:
  - exit redesign,
  - stop-distance redesign,
  - possibly a light regime filter,
  - no broad parameter sweep until the 1-year PF moves clearly above `1.0`.
