# Tick-shock Step 15M direct-action study

Step 15M replaced the intermediate Clean-Move question with the executable
action question: whether continuation or reversal reaches 0.40 ATR before a
0.25 ATR stop within 900 seconds. The frozen Step 15L causal predictors were
expanded into paired action rows without changing production EA logic.

The model ranked rare TP-first actions above their base rate, but did not select
direction reliably and every registered trade frontier remained substantially
negative. This turns the Step 15L direction ambiguity into a concrete stop:
further March threshold selection is not justified and the formulation is not
ready for unused-period OOS.

Evidence:

- [Preregistration](../research/tick_shock/15m_direct_action_prediction_preanalysis.md)
- [Results](../research/tick_shock/15m_direct_action_prediction_results.md)
- [Feature transform](../research/tick_shock/15m_action_feature_catalog.md)
- `reports/analysis/tick_shock/step15m/`
