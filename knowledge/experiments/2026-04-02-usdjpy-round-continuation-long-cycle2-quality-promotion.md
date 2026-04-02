# USDJPY Round Continuation Long Cycle 2

## 目的

- `USDJPY` の `long-only` family を actual MT5 で比較し、`current best` を明確にする。
- `followthrough_long` より quality を上げつつ、将来の frequency 拡張の土台にする。

## 比較対象

- `strict`
  - `range>=15`
  - `ema13_dist<=18`
  - `upper_wick>=0.50`
  - `lower_wick<=0.10`
  - `stop 18 / target 1.0R / hold 12`
- `strict-wide`
  - signal は `strict`
  - `stop 22 / target 1.5R / hold 18`
- `quality12b`
  - `range>=15`
  - `ema13_dist<=12`
  - `upper_wick>=0.50`
  - `lower_wick<=0.10`
  - `stop 22 / target 1.5R / hold 18`
- `mid15wide`
  - `range>=15`
  - `ema13_dist<=15`
  - `upper_wick>=0.50`
  - `lower_wick<=0.10`
  - `stop 22 / target 1.5R / hold 18`

## actual MT5

- `strict`
  - train `+1738.39 / PF 1.28 / 81 trades / DD 8.79%`
  - OOS `+399.89 / PF 1.97 / 9 trades / DD 2.01%`
- `strict-wide`
  - train `+686.02 / PF 1.10 / 75 trades / DD 19.05%`
  - OOS `+343.11 / PF 2.13 / 9 trades / DD 2.49%`
- `quality12b`
  - train `+2520.60 / PF 1.46 / 59 trades / DD 9.00%`
  - OOS `+343.11 / PF 2.13 / 9 trades / DD 2.49%`
- `mid15wide`
  - train `+1019.80 / PF 1.15 / 71 trades / DD 17.43%`
  - OOS `+343.11 / PF 2.13 / 9 trades / DD 2.49%`

## 判断

- current best は `quality12b`。
- 理由:
  - train PF が `1.46` まで改善し、現時点の `USDJPY long-only` で最も堅い。
  - OOS も崩れていない。
- reject:
  - `strict-wide` と `mid15wide` は OOS は同等でも train quality が大きく落ちる。

## 残課題

- frequency はまだ不足。
  - train `59 trades / 9 months`
  - OOS `9 trades / 3 months`
- したがって `research-qualified long-only branch` ではあるが、まだ `live-ready` ではない。

## 次アクション

- `quality12b` は current best として残す。
- 次はこの bucket を緩めるのではなく、第2の `long-only bucket` を追加して frequency を上げる。
- 優先順:
  - `round-number continuation long`
  - `volatility-state breakout-follow-through long`
  - `EMA13 touch` とは別構造の `continuation long`
