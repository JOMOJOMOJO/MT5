# Tick-shock Step 15B: matched controls and conversion funnel

Step 15B preserved all Step 15A detector and strategy parameters while adding
bounded non-event controls, an explicit direction schema, and an independent
counterfactual state-machine path. The March replay reproduced every prior event
identity and showed that V1 shocks have larger short-horizon absolute movement
and realized volatility than exact matched controls.

The practical finding is a separation of concerns: the PERSISTENT detector is
supported as an abnormal-movement detector on development data, but the existing
common strategy ingress reduces 21,799 events to 10. Counterfactual pattern
reachability is much larger, yet it is not a net-expectancy result because the
six-symbol commission model and counterfactual execution outcomes remain incomplete.

Evidence:

- [results](../research/tick_shock/15b_control_funnel_results.md)
- [matched-control coverage](../../reports/analysis/tick_shock/step15b/control_match_coverage.csv)
- [multiple testing](../../reports/analysis/tick_shock/step15b/multiple_testing_results.csv)
- [funnel](../../reports/analysis/tick_shock/step15b/strategy_funnel.csv)

