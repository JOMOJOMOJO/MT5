# Tick-shock Step 15F context feature discovery

Step 15F added a bounded causal M1/M5/M15 context recorder and deterministic
non-shock controls to the research EA. The detector, episode state, execution
semantics and no-order policy remained frozen.

Post-run coverage QA caught an MQL argument-evaluation-order defect that made
F01 unavailable. A production-path regression test first reproduced
`true != false`; normalization validity was then separated from value
evaluation, and the corrected March run was generated from commit `26faf274`.

Evidence:

- [Step 15F results](../research/tick_shock/15f_context_feature_results.md)
- [F01 RED evidence](../../reports/tests/tick_shock/step15f_f01_red/step15f_f01_red_report.md)
- [GREEN suite](../../reports/tests/tick_shock/step15f_green/suite_results.csv)
- [behavior comparison](../../reports/refactor/tick_shock/step15f_behavior_comparison.csv)
- [formal run](../../reports/backtest/runs/20260831_ts15f_tail_v1_persistent_context_r3_202503/summary.md)

The strongest OOF point estimate has a confidence interval crossing zero and
fails fold/multiplicity gates. Context-only is stronger than context-plus-shock
at that cell, so no candidate is frozen and the work stops before OOS or
strategy conversion.
