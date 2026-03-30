# BTCUSD M1: live guard 強化の検証

- Date: 2026-03-30
- EA: btcusd_20260124
- Symbol: BTCUSD
- Timeframe: M1
- Tested range: 2026.02.12 - 2026.02.19

## Hypothesis

この EA はシグナルそのものより、負けた直後の再突入で損失が膨らみやすい。
そのため `daily loss cap`, `loss cooldown`, `effective spread guard`, `max consecutive losses=2` のような live guard を加えると、利益率は据え置きでも drawdown と損失幅が大きく改善する可能性がある。

## Evidence

- Baseline:
  `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-104122-169735-btcusd-20260124-week1.json`
- Candidate:
  `reports/backtest/runs/btcusd-20260124/btcusd/m1/2026-03-30-105601-624827-btcusd-20260124-week1.json`
- Comparison:
  `reports/backtest/comparisons/2026-03-30-105338-615491-comparison.md`

## Result

- total_net_profit: -608.21 -> -75.00
- profit_factor: 0.66 -> 0.96
- expected_payoff: -23.39 -> -2.27
- maximal_drawdown_percent: 7.95 -> 7.90
- win_rate_percent: 30.77 -> 39.39
- total_trades: 26 -> 33

## Interpretation

この週では、ロジックを無理に削るより、負けた後の再突入を抑える方が効いた。
まだ PF は 1.0 未満だが、live 前提の守りを入れたことで「壊れ方」はかなり改善している。

## Next

- `L3 buy` を明示的に抑える条件を、1 要因だけで追加して比較する
- `daily loss cap` を 3.0% にするとさらに改善するか確認する
- 同じ guard を 1 週間ではなく 1 か月レンジで forward 的に確認する
