# Tick-shock execution-model revision QA

> Superseded on 2026-08-22 by the REALIZABLE_EA correction. The statements
> `EXECUTION_MODEL_REVISION_VALIDATED_BY_HARNESS`, 8/8 order PASS, and
> diagnostic-only merge time were too strong. See
> [the replacement QA](2026-08-22-tick-shock-realizable-execution.md).

## Decision

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_REVISION_VALIDATED_BY_HARNESS`
- `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- March stage label: `NO_EDGE_OBSERVED`
- Statistical conclusion: `EDGE_UNDETERMINED / insufficient statistical evidence`

The research EA remains intentionally unable to place orders. Its zero MT5 orders and deals are expected. The March rerun produced 7,452 broker-feasible barrier outcomes, but these are correlated stop/delay/spread variants over only 17 independent event clusters.

## Closed audit findings

1. Global merge processing time is diagnostic-only; same-symbol quote time drives execution.
2. Detection-time and post-burst continuation are separated.
3. Research cost/range policies are bitmask columns and cannot invalidate a barrier outcome.
4. The complete broker-feasible 1.0x-12.0x stop grid is evaluated at RR 1.2.
5. Spread 1.25x retains the paired unstressed absolute risk distance.
6. Same-millisecond ticks are grouped before a grid boundary closes.
7. SL gap, adverse exit slippage, time-side price, and configured commission are included.
8. 250/500/1,000ms detectors have independent boundaries and baselines.

## Verification

- Research compile: 0 errors / 0 warnings.
- Research reachability: 18/18 PASS.
- Order harness reachability: 8/8 PASS, with actual Long and Short Strategy Tester order cycles.
- March run: six symbols, 10,587,794 processed ticks, 19 event rows / 17 clusters, 380.828 seconds.
- Global event-order violations: zero.
- Event duplicates: zero.
- Generated tick fallback: GBPUSD 179/30,187 minutes (0.5930%) reported by tester journal.

Evidence: [March revision report](../../reports/backtest/runs/20260822_tickshock_execution_revision/summary.md), [event CSV](../../reports/backtest/runs/20260822_tickshock_execution_revision/events.csv), [summary CSV](../../reports/backtest/runs/20260822_tickshock_execution_revision/summary.csv), [tick quality](../../reports/backtest/runs/20260822_tickshock_execution_revision/tick_quality.csv).

## Remaining gates

The only selected positive cell was pullback continuation, stop 8x, delay 0ms, n=5. It became negative at both 100ms and 250ms. The preliminary 30 continuation-trade sample was not reached. Commission was zero only as observed in the local tester order harness; live broker cost is not thereby proven. Short-window noise-floor use is high.

Do not start long OOS or parameter optimization without a new instruction.
