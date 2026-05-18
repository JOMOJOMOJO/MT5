# Live Path Selected Parameter Set

## Selection Rule
The 2025 IS grid was evaluated on `EnableTrading=true` tester realized `ProfitR`. The top 5 IS candidates were preselected before OOS. OOS was then used only as a pass/fail validation.

## Selected Demo Candidate
`g039` is selected as the live-path survivor for demo-forward validation.

Parameters:
- StrategyMode: `STRATEGY_01B_J_SHORT`
- `DoubleTopBottomToleranceATR=0.20`
- `NecklineBreakBufferATR=0.07`
- `ADXLowThreshold=22.0`
- `ADXHighThreshold=32.0`
- `TakeProfitRMultiple=1.5`
- `ExitSimulationModeInput=0`
- `ConservativeSameBarExit=true`
- `RiskPercent=0.25`
- `MaxTotalOpenRiskPercent=0.25`
- `MaxSpreadPoints=30.0`
- `UseEquityCurveGuard=true`
- `AllowOnlyOnePositionForStrategy01B=true`

## 2025 IS Metrics
- Trades: `92`
- WinRate: `48.9130%`
- AvgWinR: `1.496489`
- AvgLossR: `-1.038505`
- ExpectancyR: `0.201438`
- PF: `1.379684`
- MaxDD_R: `11.574514`
- TotalR: `18.532260`
- Positive quarters: `3 / 4`
- live errors: `0`

2025 quarters:
`Q1:+3.475R | Q2:+9.820R | Q3:+5.994R | Q4:-0.758R`

## 2026 Jan-Apr OOS Metrics
- Trades: `38`
- WinRate: `47.3684%`
- AvgWinR: `1.488500`
- AvgLossR: `-1.011159`
- ExpectancyR: `0.172890`
- PF: `1.324866`
- MaxDD_R: `5.090685`
- TotalR: `6.569823`
- live errors: `0`

OOS months:
`2026-01:+0.992R | 2026-02:+5.366R | 2026-03:+2.278R | 2026-04:-2.066R`

## Selection Caveat
`g039` was not the 2025 IS rank-1 candidate. It was the rank-4 candidate and the only top-5 candidate to pass live-path OOS. This makes it a controlled demo candidate, not proof of production readiness.
