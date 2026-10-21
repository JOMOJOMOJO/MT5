# エントリー候補研究の成果物

- **正式な初回結果**: [validated_20261014/report.md](validated_20261014/report.md)
- [主要・全HのCSV](validated_20261014/summary.csv)
- [候補件数](validated_20261014/candidate_counts.csv)
- [データ品質](data_20261014/coverage.csv)、[原本・データの来歴](data_20261014/dataset_manifest.json)
- [実装・実行手順](../../../tools/entry_research/README.md)
- [設計と再利用判断](../../../knowledge/experiments/2026-10-14-entry-candidate-platform-design.md)
- [初回の判断](../../../knowledge/experiments/2026-10-15-entry-candidate-platform-initial-review.md)
- [成果物監査](qa/artifact_audit_20261015.json)
- [再現性照合 PASS](qa/reproducibility_20261015.json)、[49テストの結果](qa/tests_20261015.xml)

`initial_20261014/`は初回統合実行の記録。`validated_20261014/`は、約定条件を満たさない18シグナルも候補として保存する修正と、環境別baselineの推定対象・反復件数を明示した版。主要比較母集団とH10結果は同じ。

`reproduced_20261015/`は同一設定・データ・seedの再実行。完了状態は各`status.json`、結果照合は`qa/reproducibility_20261015.json`を参照する。元の成果物には上書きしない。

OHLCデータ、全イベントParquet、HTML、DuckDBはローカルに保持する。CSV・config・来歴・コードhashで出力を追跡する。既存バー原本は別の研究収集器で作られたものを読み取っており、今回の研究では既存EAや原本を変更していない。
