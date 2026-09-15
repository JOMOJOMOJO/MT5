# Tick-Shock半年収集の4m/2m分析受付

学習を開始する依頼に対し、検証期間の損益を見ないデータQAを先行した。
参照：[受付QA](../../reports/analysis/tick_shock/technical_4m2m_codex/intake_report.md)、[分割計画](../research/tick_shock/technical_4m2m_analysis_plan.md)。

Technicalの17,648 episodes・486特徴量・211,776 outcomeの結合と因果性は整合したが、run自体は旧scenario event poolの上限到達15,097回でVALIDATION_INVALID。
この旧poolはTechnical登録より後の別経路にあり、同数のTechnical欠落を意味しない。スコープを混同せず、runのfail-closed判定も消さない。
正式な学習／検証は追加の影響範囲監査を待つ。ML実行、5～6月の損益集計、MQL修正、MT5再実行は行っていない。
元のCSVとユーザーの削除/変更状態を維持した。今回はユーザー固有のデータ受付であり、外部向け記事seedは追加しない。

## 続行監査

[追加監査](../../reports/analysis/tick_shock/technical_4m2m_codex/provenance_audit/report.md)で対象RunIdのAgent開始journalを確認した。metadataはREAL_TICKSだが、実際は`every tick generating`。
旧poolとTechnical poolは別経路で、read-throughも最終的には回復。しかしtick modeが目的と不一致のため、学習停止を維持する。
EA入力のprovenance自己申告文字列をTesterの実行証拠とみなさないことが今回の修正点。
