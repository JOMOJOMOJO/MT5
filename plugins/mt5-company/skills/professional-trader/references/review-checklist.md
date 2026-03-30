# Review Checklist

## 1. Market Fit

- この EA は trend, range, breakout, mean reversion のどれを取りに行っているか
- その前提は対象シンボルと時間足で自然か
- 相場が低ボラに落ちたとき、止まるのか、だましを拾うのか
- spread 拡大時に edge が消える構造ではないか

## 2. Edge Quality

- PF は 1.2 未満ではないか
- expected payoff は costs 込みで正か
- win rate は RR と整合しているか
- total trades は判断に足るか
- long/short の片側だけに依存していないか

## 3. Execution Reality

- 平均 spread と最大 spread は許容か
- stop distance は broker 制約に対して現実的か
- 約定失敗や stops block は出ていないか
- 連敗後に同じ型へすぐ再突入していないか

## 4. Risk

- maximal drawdown と relative drawdown はライブ許容内か
- 1 日で壊れる構造になっていないか
- ロット計算は volatility に対して過大ではないか
- daily stop, consecutive loss stop, cooldown は十分か

## 5. Overfitting Risk

- 1 つの週、1 つのレジームだけで判断していないか
- 調整した変数が多すぎないか
- 改善理由を説明できないまま数字だけ良くなっていないか
- 変更後の勝ち方が前と違いすぎていないか

## 6. MT5 Specific

- tester report は `reports/backtest/runs/` に取り込んだか
- code change と run を対応づけているか
- symbol suffix, spread, tick model の前提を確認したか
- `knowledge/` に残すべき教訓があるか
