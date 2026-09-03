# Tick-shock Step 15L: causal clean-move prediction study

Step 15L added a bounded, production-path MQL feature snapshot and evaluated whether detection-time information can retain clean post-shock moves at high recall. The change does not add orders or alter detector/strategy thresholds.

The March development evidence shows ranking signal and material OOF compression, but the target is concentrated in USDJPY and only 50 clean positives occur in the pooled OOF windows. The result is therefore a signal-discovery result, not a production model. The next legitimate gate is one untouched OOS interval with frozen features, model parameters, and evaluation rules.

Evidence:

- [Results](../research/tick_shock/15l_clean_move_prediction_results.md)
- [Feature catalog](../research/tick_shock/15l_feature_catalog.md)
- [Formal run](../../reports/backtest/runs/20260903_ts15l_clean_move_ml_r1_202503/summary.md)
- [Model QA](../../reports/analysis/tick_shock/step15l/qa_checks.csv)
- [Independent reconciliation](../../reports/analysis/tick_shock/step15l/independent_recalculation.md)
