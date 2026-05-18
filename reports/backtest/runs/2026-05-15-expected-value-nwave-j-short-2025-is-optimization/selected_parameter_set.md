# Selected Parameter Set

Selected using 2025 in-sample only. 2026 Jan-Apr was not used for selection.

## Selected Set
- StrategyMode: `STRATEGY_01B_J_SHORT`
- `DoubleTopBottomToleranceATR=0.25`
- `NecklineBreakBufferATR=0.07`
- `ADXLowThreshold=20.0`
- `ADXHighThreshold=30.0`
- `TakeProfitRMultiple=1.5`
- `ExitSimulationModeInput=0` (`EXIT_FIXED_R_ONLY`)
- `ConservativeSameBarExit=true`
- `RiskPercent=0.25`
- `MaxTotalOpenRiskPercent=0.25`
- `MaxDailyLossR=1.5`
- `MaxWeeklyLossR=4.0`
- `MaxMonthlyLossR=6.0`
- `StopTradingAfterMaxDD_R=15.0`
- `MinBarsBetweenEntries=5`
- `AllowOnlyOnePositionForStrategy01B=true`
- `UseEquityCurveGuard=true`
- `MaxSpreadPoints=30.0`
- `EnableTrading=false` in preset

## Why This Set
- Best 2025 IS ExpectancyR in the 45-combination grid.
- PF `1.697561` with MaxDD_R `9.000000`.
- All 2025 quarters were positive.
- Neighboring sets around the same neckline/ADX area remained positive, so the result is not a single isolated point.
- OOS 2026 Jan-Apr virtual test remained positive: ExpectancyR `0.097315`, PF `1.173475`, trades `41`.

## Preset
Updated selected preset:
`reports/presets/ExpectedValue_NWave_J_SHORT_demo_conservative_2025IS_selected.set`

The original conservative preset was left intact for traceability.
﻿
