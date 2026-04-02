# USDJPY Downpersist Long Cycle 1 Reject

## 目的

- `USDJPY long-only` の第2 bucket 候補として、`M5 downside-persist + spread_z + ema_up` を actual MT5 で検証する。
- `quality12b` を無理に緩めず、独立した long-only bucket で頻度を足せるか確認する。

## study で選んだ baseline

- source:
  - `reports/research/2026-04-02-142556-usdjpy-m5-downpersist-long-study/summary.md`
- baseline:
  - `london_ny`
  - `ema_up`
  - `persist>=2`
  - `spread_z>=0.0`
  - `spread<=2.0`
  - `cooldown=0`
  - `stop 15 pips`
  - `target 1.20R`
  - `hold 12`
- study result:
  - train `150 trades / 0.39 per day / exp 0.053R`
  - test `77 trades / 0.89 per day / exp 0.020R`

## actual MT5

### baseline

- EA:
  - `mql/Experts/usdjpy_20260402_downpersist_long.mq5`
- preset:
  - `reports/presets/usdjpy_20260402_downpersist_long-baseline.set`
- train 9m:
  - `net -1292.27 / PF 0.86 / 132 trades / DD 26.35%`
  - run: `reports/backtest/runs/usdjpy-20260402-downpersist-long/usdjpy/m5/2026-04-02-143537-493824-usdjpy-20260402-downpersist-long.json`
- OOS 3m:
  - `net -1618.61 / PF 0.42 / 31 trades / DD 16.19%`
  - run: `reports/backtest/runs/usdjpy-20260402-downpersist-long/usdjpy/m5/2026-04-02-143537-593116-usdjpy-20260402-downpersist-long.json`

### V-pullback variant

- preset:
  - `reports/presets/usdjpy_20260402_downpersist_long-vpullback.set`
- train 9m:
  - `net -1365.37 / PF 0.84 / 119 trades / DD 25.90%`
  - run: `reports/backtest/runs/usdjpy-20260402-downpersist-long/usdjpy/m5/2026-04-02-143631-513075-usdjpy-20260402-downpersist-long.json`
- OOS 3m:
  - `net -1455.57 / PF 0.45 / 30 trades / DD 14.56%`
  - run: `reports/backtest/runs/usdjpy-20260402-downpersist-long/usdjpy/m5/2026-04-02-143631-500999-usdjpy-20260402-downpersist-long.json`

## 判断

- verdict: `reject`
- reason:
  - study では薄く正だったが、actual MT5 friction を払うと baseline も variant も明確に負ける。
  - `quality12b` を補完する第2 bucket にはならない。
  - この family は `signal frequency` より `signal quality mismatch` が問題。

## 学び

- `feature-lab positive` はそのまま EA baseline に昇格させない。
- `M5 intrabar-downpersist` は `USDJPY` の現行 broker friction では edge が潰れやすい。
- `quality12b` の frequency 問題を解くには、同じ M5 dip-buy neighborhood を触るより別 morph の long-only bucket を探す方が筋がいい。

## 次

- `usdjpy_20260402_round_continuation_long-quality12b.set` を current best のまま維持する。
- 次の第2 bucket 候補は `M15 breakout-followthrough long` の `delay=2` slice から actual 化する。
