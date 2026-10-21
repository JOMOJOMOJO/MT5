# 通常READYのML追加診断を準備

ユーザーから、生成tick許容研究をさらに掘り下げ、長い学習中はターンを終了するよう依頼。売買EAを変更せず、固定した4学習仕様と因果的較正/損益R評価を準備した。

独立監査では未来情報の具体的な混入は検出されず、損失幅が一定でない点・スプレッド年代差・旧bootstrapの時間依存未対応を確認。既存条件を変えずこれらを分離する。前回の4件両到達除外を維持する。

新コードの小規模確認でschema/時系列境界/LightGBM予測/新Entry特徴の有限値/除外候補の占有/クールタイム/未完了占有を確認。学習本体は独立Pythonプロセスに委ね、結果の採用判断は行わない。

[実行前固定計画](../../reports/qa/three_wave/ready_generated_tick_deep_review/plan.md) / [独立監査](../../reports/qa/three_wave/ready_generated_tick_deep_review/feature_label_audit.md) / [起動後状態](../../reports/qa/three_wave/ready_generated_tick_deep_review/status.json)

最終結果・グラフQAはバックグラウンド処理完了後のレビュー待ち。
