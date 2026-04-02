# USDJPY Breakout Followthrough Long Delay-2 Probe

## 目的

- `quality12b` を崩さずに、独立した `long-only` の第2 bucket 候補があるかを見る。
- `M15 round-number breakout` の中で、最もマシだった `delay=2 retest` を切り出す。

## source

- study:
  - `reports/research/2026-04-02-141139-usdjpy-m15-breakout-followthrough-long-study/summary.md`
  - `reports/research/2026-04-02-141139-usdjpy-m15-breakout-followthrough-long-study/events.csv`

## 手動 slice review

- `delay=2` exact:
  - train `12 trades / exp 0.207R / win 58.3%`
  - test `4 trades / exp 0.305R / win 75.0%`
- `delay=2 + depth 3-6 pips` は train では強いが OOS sample が消える。
- したがって、次に actual 化するなら `delay=2` を核にして、depth は詰めすぎない方が良い。

## 実装物

- EA prototype:
  - `mql/Experts/usdjpy_20260402_breakout_followthrough_long.mq5`
- preset:
  - `reports/presets/usdjpy_20260402_breakout_followthrough_long-baseline.set`

## 現在地

- compile は通過。
- actual MT5 は `tester not started because the account is not specified` でこのターンでは未取得。
- したがって、この bucket は `study-backed candidate` であって、まだ promotion candidate ではない。

## 判断

- verdict: `continue`
- reason:
  - study-only では最も筋の良い `second long-only bucket` 候補。
  - ただし actual MT5 がまだ無いので、positive と扱ってはいけない。

## 次

- local tester auth が安定した状態で `9m train / 3m OOS` を actual 化する。
- `quality12b` へ雑に統合するのではなく、まず standalone actual を取る。
