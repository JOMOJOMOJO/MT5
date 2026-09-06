# Tick-shock Step 15N delayed-decision study

急変後15/30/60/120秒まで待つ新しいresearch-only経路を、decisionとentryを
別tickにしたcausal clockで実装した。正式March runではOracle上の余地は各delayに
残ったが、training-only thresholdを用いたOOF policyは全delayで負だった。

実装と判断の根拠:

- [事前登録](../research/tick_shock/15n_post_shock_delayed_decision_preanalysis.md)
- [結果](../research/tick_shock/15n_post_shock_delayed_decision_results.md)
- [検証要約](../../reports/tests/tick_shock/step15n_validation_summary.md)
- [Oracle/policy evidence](../../reports/analysis/tick_shock/step15n/checkpoint_policy_results.csv)

Marchの最良値をdelayへ固定せず、`NO_DELAY_CANDIDATE_FOUND`、
`OOS_VALIDATION_NOT_JUSTIFIED`、`PRODUCTION_NOT_ELIGIBLE`とした。
