---
name: knowledge-capture
description: バックテスト結果、失敗事例、改善仮説、再利用できる運用知識を knowledge/ に蓄積する skill。結果をその場限りで終わらせたくないときに使う。
---

# Knowledge Capture

この skill は、バックテストや実装の知見を「後で効く形」に変換するためのものです。

## 保存先の使い分け

- `knowledge/backtests/`
  単発または特定条件のバックテスト結果。
- `knowledge/experiments/`
  次に検証したい仮説、A/B 比較、途中経過。
- `knowledge/lessons/`
  失敗から得た教訓、再発防止、実装上の注意点。
- `knowledge/patterns/`
  複数ケースで再利用できる勝ち筋や設計パターン。

## ルール

1. 1 ファイル 1 学びを原則にします。
2. 結論だけでなく、前提条件も残します。
3. 単発で再現未確認なら「仮説」と明記します。
4. 効いた条件と効かなかった条件の両方を書きます。
5. 関連 EA、シンボル、時間足、レポートの位置を残します。
6. MT5 レポートは先に `import_backtest_report` で構造化し、その後に `record_knowledge` で補足して構いません。

## 参照

- 知識ベースの方針: `references/knowledge-policy.md`
