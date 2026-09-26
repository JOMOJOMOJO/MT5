# 2026-09-24: 元の3Waveプリセットの復元

[元の表示用プリセット](../../reports/qa/three_wave/default_chart.set)を基準に、[RR1.2版](../../reports/presets/USDJPY_3Wave_Original_RR12_EMA.set)と[RR1.0版](../../reports/presets/USDJPY_3Wave_Original_RR10_EMA.set)を作成。追加済みEMA表示をONにし、古いプリセットで未指定だった5項目を現行デフォルトで明示。全34入力の過不足と最適化OFFを検証。MT5のMQL5/Profiles/Testerにも配置。

ユーザー提示設定との主な差はM1左右1→2、RelevantM1Pivots false→true、FibZone true→false、DiagnosticMode true→false、LowerPivots false→true、PivotLabels true→false、WriteCSV false→true。RR1.2版はRRも1→1.2。売買ロジック・ソース変更なし。読み込み後のMT5実行は未実施。

過去の基準を明示するプリセット復元であり、最適化や収益改善を意味しない。新しい記事seedは不要。
