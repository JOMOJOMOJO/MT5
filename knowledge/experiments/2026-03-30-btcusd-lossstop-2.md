# BTCUSD M1: consecutive loss stop を 2 に早めた検証

- Date: 2026-03-30
- EA: btcusd_20260124
- Symbol: BTCUSD
- Timeframe: M1
- Tested range: 2026.02.12 - 2026.02.19

## Hypothesis

BTCUSD M1 の現行ロジックは、同じ日の連敗クラスターで損失を拡大しやすい。
`consecutive loss stop` を 3 から 2 に早めると、trade count は減るが drawdown と損失幅が改善する可能性がある。

## Evidence

- Baseline run:
  `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-020137-586102-btcusd-20260124-week1.json`
- Candidate run:
  `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-104122-169735-btcusd-20260124-week1.json`
- Comparison:
  `reports/backtest/comparisons/2026-03-30-104147-111250-comparison.md`

## Result

- total_net_profit: -1289.38 -> -608.21
- profit_factor: 0.53 -> 0.66
- maximal_drawdown_percent: 14.62 -> 7.95
- win_rate_percent: 26.32 -> 30.77
- total_trades: 38 -> 26

## Interpretation

連敗停止を早めることで、利益化までは届かなかったが、損失の伸び方はかなり抑えられた。
この EA は「もっと仕掛ける」より、「負けが続く日の再突入を減らす」方向の方が相性が良い可能性がある。

## Next

- `loss stop = 1` は過剰に trade count を削るかを確認する
- 連敗回数ではなく、負け後の `cooldown bars` を導入して比較する
- Logic1 と Logic3 のどちらが損失源かを、logic 単位の勝敗集計で切る
