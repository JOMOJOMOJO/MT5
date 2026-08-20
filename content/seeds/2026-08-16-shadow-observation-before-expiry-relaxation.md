# Expiryを緩和する前に、非発注shadowで観測する

## Hook

EAの有効期限を延長すれば取引は増える。しかし、期限切れ後のセットアップをすぐ売買対象へ戻す必要はない。

## Evidence-backed point

有効期限切れセットアップを最大240本だけ非発注で追跡すると、2024年の1件は期限切れ30 H1本後にM15 Anchorを形成し、その後にH1起点を破壊した。これはexpiry延長の仮説を作るが、1件だけでは変更の根拠にならない。

## Supporting evidence

- [Internal experiment](../../knowledge/experiments/2026-08-16-trendline-wave2-failure-expiry-shadow.md)
- [Raw validation](../../reports/backtest/runs/20260816_trendline_wave2_failure_execution_shadow/final-report.md)
