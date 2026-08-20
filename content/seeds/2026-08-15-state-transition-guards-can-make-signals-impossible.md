# State-transition guards can make valid signals impossible

## Hook

An EA can compile, backtest, and produce zero trades because its state transitions are logically impossible—not because the market never offered the pattern.

## Evidence-backed point

In this case, pullback activation required a new lower low for Long, while the next failure classification required that same repeatedly selected low pair to be a higher low. Freezing the activation anchor and classifying only later confirmed swings restored six Long/Short paths without changing a single strategy threshold.

## Supporting evidence

- [Internal experiment](../../knowledge/experiments/2026-08-15-trendline-wave2-failure-m15-state-fix.md)
- [2024 locked validation](../../reports/backtest/runs/20260815_trendline_wave2_failure_m15_state_fix_final/final-report.md)

## Caution

Reachable code is not proof of an edge. The 2024 market window still did not form an M15 anchor, so parameter relaxation remains unjustified.
