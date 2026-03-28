---
name: mq5-review
description: MQL5 の EA コードをレビューまたは実装するときの skill。注文処理、ブローカー制約、イベントハンドリング、状態管理、リスク制御を重点的に見る。
---

# MQ5 Review

MQL5 の実行ロジック、注文管理、EA の状態遷移を触るときに使います。

## 重点確認

- イベントモデル: `OnInit`, `OnTick`, `OnTimer`, `OnTradeTransaction`, 終了処理
- 注文安全性: 重複エントリー、再送、部分約定、クローズ条件
- ブローカー制約: 最小ロット、最大ロット、ロット刻み、Stops Level、Freeze Level、価格正規化
- 状態管理: magic number、シンボル絞り込み、複数ポジション前提の有無
- リスク制御: スプレッド、時間帯、最大露出、ストップ設定

## 作業ルール

- 同じロジックが増えたら `mql/Include/` に切り出します。
- 暗黙の前提より、明示的なガードを優先します。
- バックテスト結果を根拠に変えるなら、QA ノートやレポートへつなげます。
- 何度も出る教訓は `knowledge/lessons/` に残します。
- 重要な EA 変更では `references/review-checklist.md` を使います。

## 参照

- レビューチェックリスト: `references/review-checklist.md`
