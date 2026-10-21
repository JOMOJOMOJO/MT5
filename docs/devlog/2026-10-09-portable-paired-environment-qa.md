# 汎用化QAを同時期の対照ペアへ修正

ユーザーが提案の実施を依頼。r2は旧レポートとswap計0.05 USDが異なり停止した。
現在条件で旧日足を再実行する対照を追加し、全10runのr3を凍結した。

- [計画・合格条件](../../reports/qa/portable_audit_20261009_r3/plan.md)
- [前回の不一致](../../reports/qa/portable_audit_20261009_r2/review.md)
- [固定ソースと入力](../../reports/qa/portable_audit_20261009_r3/manifest.json)
- [コンパイル](../../reports/qa/portable_audit_20261009_r3/preflight/20261009_162020_9f21c7f6/status.json)
- [入口の定義点検](../../reports/qa/portable_audit_20261009_r3/signal_definition_review.md)

新Includeは仕様の変化と換算試算を観測するだけ。凍結旧/新EAに同じwrapperを付けた。
本番EA・Shared・既存研究ソースを変更せず、売買・費用・環境・履歴・候補を別項目で照合し、総合合格にはすべての一致を要求する。
過去のFAILEDは維持。旧レポートとの費用差も別の診断として残す。

Python15テスト、5ソースcompile 0/0、PowerShell構文、凍結hash確認済み。実行結果はMT5完了後に確認する。
MT5起動後はユーザーの希望に従い待機を続けない。最適化・新フィルター・本番採用は未実施。
再利用可能な示唆は前回の[汎用化seed](../../content/seeds/2026-10-08-trend-definition-and-portability.md)に関連するが、結果未確認のため新しい成功談は作成しない。
