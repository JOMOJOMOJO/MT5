# 複数年取得のレビューと2025四半期ML検証

## 取得と復旧

2016〜2025の10年で2,091候補を保存。適格ラベルは2024年82・2025年213の295件にとどまった。旧年の生成tick結果を教師あり正解として増量しない。

2016年のログ保存は、agent journalがローテーションした後に以前の行数offsetでskipしたため空になっていた。元UTF-16 journalに一意な2016 run開始マーカーと終了があり、UTF-8へ復旧。runnerは今後、行数差分ではなく正確なexpert/dateの開始マーカーから抽出する。候補・価格CSVの再取得は不要だった。

## 固定比較

既存194特徴/117モデル入力、同じLogistic L2・Tree depth2/3/4・LightGBM設定を維持。2024適格ラベルから始め、2025Q1〜Q4のexpanding walk-forwardを実施。集約AUCはLightGBM0.523、Logistic0.523、TreeD2 0.558。全モデルのBrierはtrain TP率の定数基準より悪化。確率binも非単調。

前回候補だったM5 Wave1 mean CLVは2025Q2〜Q4でTP側が低い方向になり、採用しない判断を維持。M1 Wave2 retraceやhour_sinは複数モデルに現れたが、単変量の方向・時刻意味・検証性能が条件採用を支持しない。

## QA

2025特徴のnative M15一致・prefix/未来改変不変、前研究93Entryの時刻/価格/SL/TP一致、20固定モデル再計算1e-12以内一致、Shared等20ファイルhash保持を確認。pandasのfragmentation警告は明示copyで修正。売買ロジックに変更なし、今回MT5再実行なし。

[summary](../../reports/qa/three_wave/ready_multiyear_ml/summary.md) / [収集レビュー](../../reports/qa/three_wave/ready_multiyear_ml/collection_review.json) / [OOF集約](../../reports/qa/three_wave/ready_multiyear_ml/analysis/pooled_oof_metrics.csv) / [教訓](../../knowledge/experiments/ready-multiyear-20260930.md)
