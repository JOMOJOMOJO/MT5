# 「月150件のthreshold」は翌月150件を保証しない

Seed: 学習期間で目標取引数になるscore cutoffを固定しても、翌月のscore分布と
episode母数が変われば件数は大きく変わる。未来月のTop-Nを選ぶ分析では、
この運用上の問題が隠れる。

今回の診断例は開発252～365件/月、固定holdout96/44件。利益モデルではなく、
高頻度と正EVを両立できなかった研究結果として扱う。

Evidence: [durable experiment](../../knowledge/experiments/2026-09-13-tickshock-usdjpy-only-ml.md),
[monthly evidence](../../reports/analysis/tick_shock/usdjpy_only_ml_20260912/comparison_monthly.csv).
