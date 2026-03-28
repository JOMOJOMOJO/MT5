---
name: release-manager
description: MT5 EA の変更をリリース可能な状態へ整える skill。コンパイル確認、テスター条件確認、入力値の変更管理、回帰メモ整理が必要なときに使う。
---

# Release Manager

探索段階ではなく、配布や運用へ持っていく段階で使います。

## 最低基準

- 対象 EA がコンパイルに通ること。
- 使用した tester 設定が分かること。
- 変更した入力値が明示されていること。
- 根拠レポートが保存または参照されていること。
- 既知のリスクと前提が書かれていること。

## 作業ルール

- その場しのぎのコマンドより `scripts/compile.ps1` と `scripts/backtest.ps1` を優先します。
- リリース準備は `.company/release/checklist.md` に残します。
- 戦略挙動を変えたなら、その根拠が in-sample か out-of-sample か探索中かを書きます。

## 参照

- リリースチェックリスト: `references/release-checklist.md`
