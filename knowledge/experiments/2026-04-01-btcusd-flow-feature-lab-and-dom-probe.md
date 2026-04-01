# BTCUSD Flow Feature Lab And DOM Probe

## Summary

- Added flow-oriented features to the BTCUSD M5 feature lab:
  - tick-volume change and relative load
  - spread change and acceleration
  - signed tick-flow proxies
  - breakout persistence and follow-through
- Re-ran the latest 12-month rolling lab and saved the current source-of-truth output under:
  - `reports/research/2026-04-01-145500-btcusd-m5-feature-lab-flowfinal/`
- Probed MT5 `MarketBookGet` on the current broker feed for `BTCUSD`.

## Result

- The current broker feed returned an empty market book for all probe samples.
- `MarketBookAdd` succeeded, but `MarketBookGet` returned zero levels.
- Conclusion:
  - DOM-based entry filters are not currently usable for BTCUSD on this broker feed.
  - Do not spend the next serious cycle on order-book imbalance logic in this workspace until a populated feed is confirmed.

## What The New Features Changed

- The core thesis stayed the same:
  - BTCUSD still shows short-horizon overextension fade structure.
- The newer flow features improved how that thesis can be expressed:
  - downside breakout persistence aligns with long fade entries
  - upside breakout persistence aligns with short fade entries
  - tick-volume and short-horizon flow measures help rank more urgent extensions
- The best next prototype is not a DOM filter.
- The best next prototype is a flow-enhanced overextension-fade family with fixed risk doctrine and high-turnover validation.

## Recommended Next Step

- Keep `btcusd_20260330_session_meanrev` as the quality-focused secondary family.
- Build the next mainline family from:
  - `breakout_persist_down_*`
  - `breakout_persist_up_*`
  - `roc_atr_*`
  - `ret_*`
  - `rsi7`
  - selective spread / tick-volume / flow filters
- Treat DOM / order-book bias as deferred until a broker feed returns real book levels.
