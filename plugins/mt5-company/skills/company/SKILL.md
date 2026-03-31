---
name: company
description: MT5 EA 開発リポジトリを会社のように運用する skill。受付、部署振り分け、承認フロー、知識蓄積、役割追加や組織見直しを扱うときに使う。
---

# MT5 Company

このリポジトリでは `.company/secretary/queue.md` を受付キューとして扱う。

## 役割

- `secretary`: 受付、優先度整理、バックログ更新
- `strategy`: 仮説、検証計画、評価基準
- `qa`: backtest、optimization、out-of-sample の検証管理
- `release`: demo/live へ上げる前の確認
- `research`: 新しい改善案、最適化案、検証フロー案
- `critique`: 戦略の弱点を探し、撤退判断も出す
- `people`: trader skill、review skill、部署の増減を管理
- `improvement`: 会社自身の構造、skill 構成、MCP 構成を定期レビューして差分を残す
- `executive`: CEO 承認が必要な変更の記録

## 基本ルール

1. 新しい作業はまず `secretary` で受ける。
2. 変更した戦略や判断は `.company/`、`reports/`、`knowledge/` に痕跡を残す。
3. shared な skill と MCP は `plugins/mt5-company/` の中で管理する。
4. EA ごとの事実は `reports/backtest/runs/` に残し、横断知識は `knowledge/` に昇格させる。
5. 最適化は短期探索、長期固定検証、明示的な out-of-sample の順で扱う。
6. 組織、skill、MCP の見直しは `.company/improvement/` に snapshot と review を残す。
7. 1 skill = 1 primary role を原則とし、責務が重なったら新設より先に統合を検討する。

## CEO 承認が必要な変更

次は社長の承認が出るまで「提案」の扱いに留める。

- shared skill の追加、削除、責務変更
- shared MCP の追加、削除、責務変更
- 部署構成や routing ルールの変更
- `README.md`, `AGENTS.md`, `.company/` の根本方針変更
- live 運用 gate や損失制御の基準変更

承認待ちや承認済みの記録は `.company/executive/ceo-approval-log.md` に残す。

## 参照

- 部署と routing の詳細: `references/departments.md`
- skill の運用図: `references/skill-operating-model.md`
