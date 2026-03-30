---
name: continuous-improvement-office
description: 会社自身を改善するための skill。部署構成、shared skill 構成、MCP 構成を定期レビューし、前回との差分、追加削除履歴、改善提案を残したいときに使う。
---

# Continuous Improvement Office

会社を固定物として扱わない。EA だけでなく、会社の構造も改善対象にする。

## やること

- 現在の departments, shared skills, shared MCP servers を snapshot する
- 前回 snapshot と比較して差分を出す
- 追加、削除、統合、責務変更の候補を整理する
- 変更理由と期待効果を review note に残す
- root policy 変更は CEO 承認対象として `.company/executive/ceo-approval-log.md` に送る

## トリガー

- shared skill を追加または削除した直後
- shared MCP を追加または削除した直後
- 会社構造や routing を変えた直後
- live 運用へ上げる前
- 定期 review をしたいとき

## 出力

- snapshot JSON
- 前回との差分
- review note
- CEO 承認が必要な変更一覧

## 参照

- `references/review-cadence.md`
- `references/change-policy.md`
