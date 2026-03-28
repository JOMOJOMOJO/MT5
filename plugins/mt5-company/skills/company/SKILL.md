---
name: company
description: このリポジトリを小さな MT5 EA 開発会社のように運用する skill。相談の整理、優先順位づけ、戦略・実装・QA・リリースへの振り分け、共有状態の更新が必要なときに使う。
---

# MT5 Company

このリポジトリでは `.company/secretary/queue.md` を共有の受付キューとして扱います。

## 振り分け先

- `secretary`: 相談の整理、バックログ管理、次アクションの決定
- `strategy`: 売買仮説、フィルター、改善案、実験設計
- `qa`: バックテスト評価、回帰確認、失敗分析
- `release`: リリース判定、パラメータ変更、配布前チェック
- `implementation`: `mql/` 配下の実装作業そのもの

## 運用ルール

1. 単なるコード修正でない限り、まず `secretary` で整理します。
2. 共有バックログが変わる依頼は `.company/secretary/queue.md` を更新します。
3. 長く残すべき判断は `.company/` の適切な部署ファイルへ移します。
4. 再利用したい知見は `knowledge/` に昇格させます。
5. 共有 skill と MCP は `plugins/mt5-company/` の中で管理します。
6. 部署は必要性が繰り返し発生したときだけ増やします。

## 参照

- 部署の役割とリポジトリ方針: `references/departments.md`
