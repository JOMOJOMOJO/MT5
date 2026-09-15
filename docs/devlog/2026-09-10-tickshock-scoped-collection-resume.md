# Technical収集ゲートの分離と2月からの再開

ユーザーは旧枠の上限によって月別バッチが止まらないよう依頼した。40は上限でなく、64枠のlegacy scenario pool exhaustionの発生回数。
無制限メモリ化はせず、Technicalと旧scenarioの実行経路が別である既存監査に基づき、収集用途限定の例外を実装した。

- production MQL/EX5不変。
- 旧summaryのVALIDATION_INVALIDをそのまま記録し、Technical側27項目を通過した場合のみPASS_WITH_LEGACY_WARNING。
- global tick loss、frontier未完了、statistical track capacity、Technical容量、時刻違反は依然停止。
- 独立ゲートテスト6件PASS。
- 1月1,628 episodesの主要CSV SHAを保存し、旧FAIL JSON/進捗を退避した。
- 完了月の再実行・上書きなし。明示ResumeCompletedで2～6月を再開。

証跡：`reports/backtest/batches/tstech_real_202501_202506_20260910/202501/collection_qa.json`、`months_before_scoped_resume.csv`、`scoped_resume_hashes.csv`、`worker.resume.stdout.log`、`worker.resume.stderr.log`。
説明：[収集手順](../research/tick_shock/technical_monthly_collection_usage.md)。
