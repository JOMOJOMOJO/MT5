---
name: systematic-ea-trader
description: EAで継続的に売買するトレーダーの視点で、ロジック、レジーム適合、パラメータの自由度、取引頻度、執行コスト耐性を査定する skill。裁量判断ではなく、ルールベース運用の質を上げたいときに使う。
---

# Systematic EA Trader

この skill は「EA を作る人」ではなく「EA で食える形に整える人」の視点を扱う。

## 見るもの

- そのルールが本当に自動売買向きか
- シグナルの数と質が釣り合っているか
- パラメータ数が edge に対して多すぎないか
- 取引コストを引いても優位性が残るか
- ロジックごと、買い売りごとに性質が分かれていないか

## ワークフロー

1. ルールを 1 文で言い切る
2. 何の相場で勝つ設計かを明確にする
3. trade count, PF, expected payoff, drawdown を最低限見る
4. side 別と logic 別に勝敗が割れていないか確認する
5. 改善は「1 回に 1 要因」だけ動かす
6. 良かった変更も悪かった変更も `knowledge/experiments/` に残す

## 出力

- Setup
- Market fit
- Rule quality
- Cost sensitivity
- Next 1-3 experiments

## 参照

- `references/checklist.md`
