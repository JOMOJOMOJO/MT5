# Tick-shock execution revision experiment

## Hypothesis

The previous zero-outcome result could be caused by post-hoc burst filtering, policy invalidation, and artificial merge delay rather than by market performance.

## Controlled revision

Thresholds were kept unchanged. Execution time was separated from global merge time, immediate and post-burst strategies were split, policy gates became diagnostic bits, stop distance was fixed across spread stress, same-millisecond ticks were grouped, and exits gained gap/slippage rules. Independent 250/500/1,000ms detectors were compared.

## Evidence

The March rerun yielded 19 event rows in 17 clusters and 7,452 broker-feasible barrier outcomes. Therefore the old zero-outcome result was indeed a research-model artifact.

This did not establish an edge. The only selected positive cell was pullback continuation at stop 8x and zero delay, n=5, ExpectancyR +0.250313. It was -0.155529 at 100ms and -0.149880 at 250ms. Other selected continuation/reversal configurations were negative.

Shorter detectors depended heavily on the one-tick robust-scale floor: 95.9511% at 250ms and 83.0885% at 500ms, versus 42.3471% at 1,000ms. GBPUSD had tester-reported generated fallback in 0.5930% of minute bars.

Evidence: [full run report](../../reports/backtest/runs/20260822_tickshock_execution_revision/summary.md).

## Decision

`NO_EDGE_OBSERVED` for the March definition, but `insufficient statistical evidence` globally. Do not relax thresholds, optimize, or start long OOS automatically. At the observed rate, about six similar months would be needed merely to reach 30 pullback-continuation signals.
