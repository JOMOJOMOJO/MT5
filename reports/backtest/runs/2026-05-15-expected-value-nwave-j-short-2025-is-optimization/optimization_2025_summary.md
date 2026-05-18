# Strategy_01B_J_SHORT 2025 In-Sample Optimization Summary

Generated: 2026-05-15

## Scope
- Symbol/timeframe: USDJPY / M5
- Strategy: `STRATEGY_01B_J_SHORT`
- In-sample window: `2025.01.01` - `2025.12.31`
- EnableTrading: `false`
- Exit: fixed internal `1.5R`
- Conservative same-bar exit: `true`
- Risk guard: forward-demo conservative settings on.
- Search size: `45` combinations, intentionally far below the 10k ceiling.

No EA source logic was changed. TP/SL calculation, fixed 1.5R exit, lot calculation, and existing risk guard decision logic were not changed.

## Grid
- `DoubleTopBottomToleranceATR`: `0.20`, `0.25`, `0.30`
- `NecklineBreakBufferATR`: `0.03`, `0.05`, `0.07`
- `ADXLowThreshold/ADXHighThreshold`: `18/28`, `18/30`, `20/30`, `20/32`, `22/32`

## Aggregate
- Total combinations: `45`
- `ExpectancyR > 0` and `PF > 1.2`: `41 / 45`
- ExpectancyR range: `0.017290` to `0.327175`
- PF range: `1.029156` to `1.697561`
- Trades range: `86` to `130`

## Top IS Candidates
|Run|Trades|WinRate|ExpR|PF|MaxDD_R|TotalR|PositiveMonths|PositiveQuarters|
|---|---:|---:|---:|---:|---:|---:|---:|---:|
|g024 `tol0.25 neck0.07 adx20/30`|113|53.0973|0.327175|1.697561|9.000000|36.970721|9|4|
|g027 `tol0.30 neck0.07 adx20/30`|116|52.5862|0.314399|1.663096|9.000000|36.470288|8|4|
|g033 `tol0.25 neck0.07 adx20/32`|128|52.3438|0.308333|1.646993|11.000000|39.466574|9|4|
|g030 `tol0.20 neck0.07 adx20/32`|113|52.2124|0.305050|1.638346|11.000000|34.470686|9|4|
|g039 `tol0.20 neck0.07 adx22/32`|94|52.1277|0.303026|1.632989|11.500000|28.484483|7|3|
|g042 `tol0.25 neck0.07 adx22/32`|102|51.9608|0.298879|1.622157|11.500000|30.485679|8|3|
|g021 `tol0.20 neck0.07 adx20/30`|104|51.9231|0.297872|1.619574|10.000000|30.978709|8|4|
|g022 `tol0.25 neck0.03 adx20/30`|113|51.3274|0.282944|1.581322|9.000000|31.972706|8|4|
|g023 `tol0.25 neck0.05 adx20/30`|115|51.3043|0.282384|1.579895|9.000000|32.474123|9|4|
|g026 `tol0.30 neck0.05 adx20/30`|118|50.8475|0.270963|1.551271|9.501399|31.973690|8|4|

## Selected From IS
Selected parameter set: `g024`

- `DoubleTopBottomToleranceATR=0.25`
- `NecklineBreakBufferATR=0.07`
- `ADXLowThreshold=20.0`
- `ADXHighThreshold=30.0`

Selected IS metrics:
- Trades: `113`
- WinRate: `53.0973%`
- AvgWinR: `1.499512`
- AvgLossR: `-1.000000`
- ExpectancyR: `0.327175`
- PF: `1.697561`
- MaxDD_R: `9.000000`
- MaxLossR: `-1.000000`
- TotalR: `36.970721`
- RiskGuard rejects: `6`
- `spread_too_wide`: `11`
- `daily_loss_r_blocked`: `6`
- live error rejects: `0`

Across the 45-run IS grid, `EnableTrading=false` means live order execution was not used; the live error reject columns remained `0` in the collected metrics.

Monthly ProfitR:
`2025-01:8.989 | 2025-03:3.000 | 2025-04:1.496 | 2025-05:8.000 | 2025-06:2.495 | 2025-07:0.998 | 2025-08:6.495 | 2025-09:-0.500 | 2025-10:-3.500 | 2025-11:4.499 | 2025-12:4.998`

Quarter ProfitR:
`2025-Q1:11.989 | 2025-Q2:11.991 | 2025-Q3:6.993 | 2025-Q4:5.998`

Evidence CSVs:
- `is_2025_grid_metrics.csv`
- `top_2025_candidates.csv`
- `neighbor_plateau_2025.csv`
