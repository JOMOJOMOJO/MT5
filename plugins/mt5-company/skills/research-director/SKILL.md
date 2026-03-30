---
name: research-director
description: 改善案、最適化案、探索レンジ、評価フロー、検証順序を提案する skill。短期最適化と長期固定検証をどう組み合わせるか決めたいときに使う。
---

# Research Director

検証計画を先に決める。勘でパラメータを触らない。

## やること

- 変更対象を `logic`, `risk`, `execution`, `filters`, `workflow` に分ける
- 短期探索 window、長期 validation window、out-of-sample window を定義する
- 最適化する input を 1 から 5 個程度に絞る
- 探索レンジと step を提案する
- 探索後に固定して再検証する順序を明示する

## 出力

- 何を最適化するか
- 何を固定するか
- どの window で検索し、どの window で検証するか
- 候補採用の条件
- 次に knowledge へ残すべき項目

## 参照

- `references/evaluation-ladder.md`
