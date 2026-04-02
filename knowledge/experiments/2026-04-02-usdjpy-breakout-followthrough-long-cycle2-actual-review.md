# USDJPY Breakout Followthrough Long Cycle 2

## 目的

- `quality12b` を無理に緩めずに、`USDJPY long-only` の第2 bucket になれる候補を actual MT5 で確認する。
- study-only だった `breakout_followthrough_long` を actual まで通して、`delay=2` baseline と `delay=1` quality branch を比較する。

## 実施

- tester config を、実際に通っている `USDJPY M15` 系と同じ `[Tester]` ベースの書式へ揃えた。
- `usdjpy_20260402_breakout_followthrough_long.mq5` に以下を追加した。
  - `InpRetestDelayBars`
  - `InpMaxBreakoutToEma13Pips`
  - `InpMinRetestCloseLocation`
  - `InpMaxRetestDepthPips`
- `delay=2 baseline` に加えて、`delay=1-tight` と `delay=1-mid` を actual MT5 まで回した。

## actual MT5

- `baseline`
  - train `-184.99 / PF 0.91 / 20 trades / DD 9.30%`
  - OOS `+208.23 / PF 1.50 / 5 trades / DD 3.93%`
- `delay1-tight`
  - train `+247.62 / PF 1.53 / 6 trades / DD 2.76%`
  - OOS `+239.47 / 1 trade`
- `delay1-mid`
  - train `+247.62 / PF 1.53 / 6 trades / DD 2.76%`
  - OOS `+298.31 / 2 trades`

## 判断

- verdict: `reject as second bucket`
- 理由:
  - `delay=2 baseline` は OOS は正だが train が負で、第2 bucket として統合するには弱い。
  - `delay=1` は quality は改善したが、trade count がさらに薄くなり、`1 trade/day` どころか月次で意味のある補完にもならない。
  - よって `breakout_followthrough_long` は「actual 済みの quality sidecar」ではあるが、`quality12b` を補完する運用候補にはならない。

## 学び

- `delay=1` の immediate retest は study 通り train quality を押し上げた。
- ただし、`USDJPY M15` のこの thesis は broker friction を払った実行系では sample が薄すぎる。
- 今の目的は `long-only` を live-ready に近づけることなので、この family を統合軸にするより fresh な long-only bucket を開く方が筋が良い。

## 次

- `quality12b` は current best のまま維持する。
- 次の `USDJPY long-only` は以下の fresh thesis から開く。
  - `volatility-state breakout-follow-through long`
  - `round-number continuation long` の別 regime
  - `EMA13/EMA100 continuation` の non-round-number branch
