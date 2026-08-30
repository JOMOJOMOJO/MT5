# Tick-shock Step 15E: medium-horizon response

Step 15E added a bounded, causal 15-minute episode recorder without changing
`TAIL_V1_PERSISTENT`, the four existing strategies, RR, stop grid or order
behavior. The production module uses completed M1 history for its pre-shock
scale and records actual Bid/Ask checkpoints and five causal entry clocks.

March 2025 preserved all Step 15D event/path/cluster identities. Longer holding
increased the fraction of paths that cleared spread, but aggregate executable
means remained negative through 900 seconds. No preregistered hypothesis passed
the stability and cost gates, so no candidate was frozen.

Evidence:

- [results](../research/tick_shock/15e_medium_horizon_results.md)
- [final QA](../research/tick_shock/15e_final_qa.md)
- [analysis tables](../../reports/analysis/tick_shock/step15e/)
- [accepted run](../../reports/backtest/runs/20260830_ts15e_tail_v1_persistent_medium_horizon_202503/summary.md)
