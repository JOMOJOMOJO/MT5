# 2026-09-08 Tick-shock Step 15O Cross-FX lead-lag

2025年4月をdevelopment期間として事前固定し、他5 USD pairのcausal
as-of情報が急変後のContinuation / Reversal / No Trade判定を改善するかを
調べた。

Phase AではH2/H3にtradeable条件付き方向差があり、事前gateに従って
Phase Bへ進んだ。しかし固定actionも4-fold OOF policyも全て負期待値で、
Cross-FX情報を売買edgeへ変換できなかった。freshness適格は3,967 episode中
388件に限られた。

根拠は[結果](../research/tick_shock/15o_cross_fx_lead_lag_results.md)、
[formal run](../../reports/backtest/runs/20260908_ts15o_cross_fx_lead_lag_r2_202504/summary.md)、
[QA](../../reports/analysis/tick_shock/step15o/qa_checks.csv)を参照する。
