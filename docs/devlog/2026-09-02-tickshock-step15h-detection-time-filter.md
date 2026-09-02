# Tick-shock Step 15H: detection-time continuation filter

TAIL_V1_PERSISTENTの確定を処理できた時点`t0`で、将来情報を使わず即時順張りかNO_TRADEかを選ぶ研究経路を追加した。既存のexecution barrier evaluatorを再利用し、RR 1.2、delay 0/100/250ms、horizon 300/600/900秒を独立記録した。

2025年3月の開発runではprimary 1,818 episodes / 1,709 market clustersでsupport gate未達、UNFILTERED C2 policy valueも負だった。候補は凍結せず、Step 15Hで停止した。

Evidence:

- [results](../research/tick_shock/15h_detection_time_continuation_results.md)
- [formal run](../../reports/backtest/runs/20260902_ts15h_detection_time_continuation_r1_202503/)
- [policy comparison](../../reports/analysis/tick_shock/step15h/filter_policy_comparison.csv)
- [share bundle](../../reports/share/tick_shock/step15h/)
