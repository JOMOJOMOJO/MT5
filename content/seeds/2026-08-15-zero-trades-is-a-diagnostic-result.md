# 「取引ゼロ」は失敗ではなく、ルールのどこが市場に存在しないかを示す

## Hook

裁量手法をEA化したとき、最初に利益を見ると条件を緩めたくなる。だが本当に価値があるのは、0件でも状態遷移を追える設計だ。

## Evidence-backed point

- H4急変は年40〜80件あった。
- H1成熟は年1〜4件へ減った。
- H1トレンドライン突破は年1〜2件。
- M15継続失敗は3期間すべて0件。

これは「EAが壊れている」と「戦略条件の積が希少すぎる」を分ける。確定足ログ、funnel、reject reason、MT5実注文の照合があれば、無断の条件緩和を避けられる。

## Supporting evidence

- [Initial validation summary](../../reports/backtest/runs/20260815_trendline_wave2_failure/summary.md)
- [Funnel by year](../../reports/backtest/runs/20260815_trendline_wave2_failure/new_bucket_funnel.csv)
- [Internal experiment note](../../knowledge/experiments/2026-08-15-trendline-wave2-failure-initial-validation.md)

## Possible formats

- X thread: 「0 tradeを正しく報告できるEAの5条件」
- note: 「裁量ルールのEA化で、期待値より先にfunnelを作る理由」
