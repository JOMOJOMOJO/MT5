# エントリー候補の抽出と評価を分離した研究基盤

2026-10-15。[Phase 1設計](../../knowledge/experiments/2026-10-14-entry-candidate-platform-design.md)を基に、USDJPY M5・2024〜2025年の3手法を対象とするPhase 2〜4を実装した。既存EA、過去の売買ロジック、原本CSV、過去レポートは変更していない。

新しい[Pythonパッケージと実行手順](../../tools/entry_research/README.md)に、データ取込・MT5取得口、確定足特徴量、独立した3抽出モジュール、共通評価、条件一致ランダム対照、週bootstrap、DuckDB集計、Plotlyチャートを分離した。Parquetを詳細の保存先、CSVとMarkdownを確認用出力とし、入力とコードのhash・設定・seedを各runへ記録する。2026年以降は開発ランナーで拒否する。

[検証済み初回レポート](../../reports/research/entry_candidates/validated_20261014/report.md)では17,409候補中16,818件が共通50本母集団。H10は3手法×2方向のすべてで平均ネットが負、対照差の95%CIはすべて0を含み、Holm補正後p値は0.8811以上だった。詳細な判断・年別確認・制約は[初回レビュー](../../knowledge/experiments/2026-10-15-entry-candidate-platform-initial-review.md)へ集約した。

動作検証は統計テストを含む[基盤テスト](../../tools/entry_research/tests/)の計49件成功。[JUnit結果](../../reports/research/entry_candidates/qa/tests_20261015.xml)を保存。抽出監査と評価Parquetからの独立再集計も一致した。同一設定の全処理再実行は完了し、[再現性QA](../../reports/research/entry_candidates/qa/reproducibility_20261015.json)はPASS。主要CSVは同じSHA256、4種類のParquet内容は完全一致。環境別CSVのみ浮動小数点の差があり、絶対・相対許容値1e-12以内で一致した。

保存BybitバーのUTC対応は未確認、コストは合計1.9pipsの仮定。tick順序hookの存在を実tick検証済みと読み替えず、イベント統計をMT5売買バックテストや資金曲線とも混同しない。今回の作業でgit commit・pushや新規MT5売買テスター実行を完了したとは扱わない。

Plateau reviewの結論は、3手法を利益が出るまで調整せず、入口比較の共通基盤として保持すること。残る7手法はPhase 5で未実装。同じAPI・標準値・未来不変性テストで追加する。外部向けの論点は[記事の種](../../content/seeds/2026-10-15-entry-candidates-before-ea.md)に分けた。
