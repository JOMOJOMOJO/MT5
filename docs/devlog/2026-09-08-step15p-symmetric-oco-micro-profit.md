# Step 15P symmetric OCO micro-profit study

Step 15P tested a frozen direction-neutral OCO hypothesis on the April 2025
`TAIL_V1_PERSISTENT` population. The production research path now groups
same-millisecond quotes, distinguishes trigger from next-quote entry, evaluates
the complete 3 x 6 x 6 geometry without orders, and writes event-scenario
records rather than tick logs.

The full surface was negative before extra commission stress, so the decision
is `MICRO_PROFIT_FEASIBILITY_NOT_FOUND`. The result closes this fixed geometry
for April rather than inviting a finer in-sample grid.

Evidence:

- [Preregistration](../research/tick_shock/15p_symmetric_oco_micro_profit_preanalysis.md)
- [Results](../research/tick_shock/15p_symmetric_oco_micro_profit_results.md)
- [Formal run](../../reports/backtest/runs/20260908_ts15p_symmetric_oco_micro_profit_202504/)
- [Independent QA](../../reports/analysis/tick_shock/step15p/independent_recalculation.csv)
