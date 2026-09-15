# Tick-Shock月別収集の起動

ユーザー依頼はスクリプト作成と起動まで。完了待機や学習は行わない。
六回のModel=4設定と固有RunIdを生成し、検証済み無注文Research EX5を固定してbackground workerを起動。
現在のMT5を勝手に強制終了せず、正常終了を待ってから開始する。
詳細：[使用手順](../research/tick_shock/technical_monthly_collection_usage.md)。証跡：`reports/backtest/batches/tstech_real_202501_202506_20260910/`。

旧半年分の削除はユーザー承認済みだがtool policyで拒否。原本が残ることを明記し、小さな監査用metadataだけ別保存した。
プログラムの検証：PowerShell/Python構文検査、六つのconfig/presetの日付・RunId・Model=4・最適化なし・EX5 hash確認。実月runの成功はまだ主張しない。
