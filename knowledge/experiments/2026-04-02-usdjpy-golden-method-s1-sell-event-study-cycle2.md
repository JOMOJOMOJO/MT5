# USDJPY Golden Method S1 Sell Event Study Cycle 2

- Date: 2026-04-02
- Family: `usdjpy_20260402_golden_method`
- Scope: `Strategy 1 sell-only`
- Objective: event study で抽出した `NY strict` / `NY-open loose` の shape rule を actual MT5 で検証する

## Event Study Source

- `reports/research/2026-04-02-015031-usdjpy-m5-golden-s1-event-study/summary.md`

## Candidate Rules

### NY Strict

- Session: `13:00-22:00`
- `max_countertrend_bodies <= 2`
- `min_transition_distance_pips >= 3.0`
- `max_pullback_to_impulse_ratio <= 0.35`
- `min_rejection_close_location >= 0.75`
- `min_impulse_pips >= 8.0`

### NY-Open Loose

- Session: `13:00-18:00`
- `max_countertrend_bodies <= 1`
- `min_transition_distance_pips >= 0.0`
- `max_pullback_to_impulse_ratio <= 0.70`
- `min_rejection_close_location >= 0.60`
- `min_impulse_pips >= 12.0`

## Actual MT5 Results

### Baseline S1 Sell-Only

- Train 9m: `net -1153.11 / PF 0.54 / trades 19 / DD 15.88%`
- OOS 3m: `net +32.32 / PF 1.15 / trades 2 / DD 2.06%`

### NY Strict

- Train 9m: `net +52.61 / PF 1.12 / trades 4 / DD 2.11%`
- OOS 3m: `net -205.54 / PF 0.00 / trades 1 / DD 2.06%`

### NY-Open Loose

- Train 9m: `net -177.60 / PF 0.58 / trades 3 / DD 4.10%`
- OOS 3m: `net +0.00 / PF - / trades 0 / DD 0.00%`

## Evidence

- `reports/backtest/imported/usdjpy_20260402_golden_method-s1-sell-only-train-9m-m5.htm`
- `reports/backtest/imported/usdjpy_20260402_golden_method-s1-sell-only-oos-3m-m5.htm`
- `reports/backtest/imported/usdjpy_20260402_golden_method-s1-sell-only-ny-strict-train-9m-m5.htm`
- `reports/backtest/imported/usdjpy_20260402_golden_method-s1-sell-only-ny-strict-oos-3m-m5.htm`
- `reports/backtest/imported/usdjpy_20260402_golden_method-s1-sell-only-ny-open-loose-train-9m-m5.htm`
- `reports/backtest/imported/usdjpy_20260402_golden_method-s1-sell-only-ny-open-loose-oos-3m-m5.htm`

## Verdict

- `NY strict` は train ではじめて黒字になったが、`3 months OOS` は `1 trade` で即失敗した。
- `NY-open loose` は quality も turnover も改善できなかった。
- `S1 sell-only` は quality を上げるほど turnover が消え、turnover を戻すと expectancy が壊れる傾向が強い。
- したがって、現時点の `S1 sell-only` は research only 維持で、`1 trade/day minimum` の目標には届いていない。

## Decision

- `S1 sell-only` をこのまま閾値の微調整で伸ばす優先度は下げる。
- 次 cycle は fresh `Strategy 2` round-number breakout study を優先する。
- breakout 側でも signal が出ない場合は、Golden Method family 自体を plateau review に進める。
