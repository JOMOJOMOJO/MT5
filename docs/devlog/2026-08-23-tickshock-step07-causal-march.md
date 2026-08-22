# Tick-shock Step 7 causal March replay

Step 7 reran the unchanged March 2025 detector and scenario grid after the
Step 6 causal-clock fixes. Two separate MT5 model-4 runs were preserved:

- [IDEAL_EVENT_STUDY](../../reports/backtest/runs/20260822_tickshock_causal_ideal_202503/summary.md)
- [REALIZABLE_EA](../../reports/backtest/runs/20260822_tickshock_causal_realizable_202503/summary.md)

The formal comparison is
[summary.md](../../reports/backtest/runs/20260822_tickshock_causal_comparison_202503/summary.md),
with machine-readable
[causal_invariants.csv](../../reports/backtest/runs/20260822_tickshock_causal_comparison_202503/causal_invariants.csv).

The detector funnel remained 62,577 raw candidates and 19 event rows. The new
cross-symbol grouping gives 15 market clusters. REALIZABLE_EA had zero formal
causal invariant violations and 7,128 broker-grid-feasible shadow cells, but
the cells are correlated scenario variants rather than independent trades.
GBPUSD also required generated-tick fallback for 179 of 30,187 minutes, and
commission remains configured as zero with `ORDER_HARNESS_REQUIRED` evidence.

The resulting stance is causal execution validated and shadow feasibility
established, while research pipeline validation remains partial and edge is
undetermined. This cycle does not authorize long OOS, parameter optimization,
strategy-cell selection, or promotion to a trading EA.
