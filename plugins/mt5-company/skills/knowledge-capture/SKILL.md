---
name: knowledge-capture
description: バックテスト結果、最適化結果、失敗知見、再利用できる判断を knowledge/ に残す skill。結果を会話だけで終わらせたくないときに使う。
---

# Knowledge Capture

会話で終わらせず、次の EA 改善で再利用できる形に落とす。

## 保存先

- `knowledge/backtests/`: 固定パラメータ検証の要約
- `knowledge/optimizations/`: 探索レンジ、候補 pass、採用設定、棄却理由
- `knowledge/experiments/`: 次に試す仮説
- `knowledge/lessons/`: 再発防止や重要な学び
- `knowledge/patterns/`: 複数 EA に効く型

## ルール

1. 1 ファイル 1 学びに寄せる。
2. どの EA、どの通貨、どの期間かを必ず書く。
3. 単なる感想ではなく、証拠と判断を分ける。
4. 最適化は「良かった候補」だけでなく「捨てた候補」も残す。
5. 次に何を試すかを書けるなら `experiments/` に落とす。

## 参照

- `references/knowledge-policy.md`
