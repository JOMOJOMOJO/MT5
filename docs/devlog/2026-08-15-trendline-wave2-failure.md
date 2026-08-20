# TRENDLINE_WAVE2_FAILURE implementation and initial validation

## What changed

- `ExpectedValue_MultiCurrency_FractalWave2TransitionTrader.mq5` に独立bucketの呼び出しを統合した。
- 新ロジック本体は `mql/Include/TrendlineWave2Failure.mqh` に分離した。
- 既存のみ、新bucketのみ、併用、およびLong/Short/Bothの切替を追加した。
- H4/H1/M15の確定足状態機械、SMA傾きスイング、H4 percentile impulse、H1 trendline、M15 failure分類、3種SL、固定2R、OrderCalcProfit sizing、portfolio/currency/margin/loss stops、再起動可能なrisk anchors、CSVを追加した。

## Why

裁量的な「急変後の第2波内部で旧方向の継続失敗を取る」を、未来参照なしで複数通貨比較できる研究bucketへ変換するため。

## Evidence

- Compile: [MetaEditor log](../../reports/compile/trendline_wave2_failure.log) (`0 errors / 0 warnings`)
- Locked MT5 runs: [summary](../../reports/backtest/runs/20260815_trendline_wave2_failure/summary.md)
- Baseline/New/Combined: [comparison](../../reports/backtest/runs/20260815_trendline_wave2_failure/comparison.csv)
- Funnel: [new bucket funnel](../../reports/backtest/runs/20260815_trendline_wave2_failure/new_bucket_funnel.csv)
- Representative near-miss: [timeline](../../reports/backtest/runs/20260815_trendline_wave2_failure/representative_setup_timeline.csv)
- Durable assessment: [experiment note](../../knowledge/experiments/2026-08-15-trendline-wave2-failure-initial-validation.md)

## Decision

初期固定条件では3期間すべて新bucket注文0件。条件を緩和せず、M15 failure以前のfunnel診断を次工程とする。新bucketはpromotion不可、research statusとする。
