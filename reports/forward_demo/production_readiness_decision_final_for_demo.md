# Production Readiness Decision Final For Demo

## Decision

- Controlled demo: approved.
- EnableTrading=true demo: approved with the controlled demo preset only.
- Small live: not approved.
- Full production: not approved.

## Required Preset

`reports/presets/ExpectedValue_NWave_J_SHORT_g039_controlled_demo.set`

Key limits:

- EnableTrading = true
- RiskPercent = 0.10
- MaxTotalOpenRiskPercent = 0.10
- MaxDailyLossR = 1.5
- MaxWeeklyLossR = 4.0
- MaxMonthlyLossR = 6.0
- StopTradingAfterMaxDD_R = 999
- DD% guards ON: 8 / 12 / 15
- Non-demo account block ON

## Tester Baseline

| Baseline | Trades | ExpectancyR | PF | MaxDD% | Live errors |
|---|---:|---:|---:|---:|---:|
| 2025 production guard | 92 | +0.2014 | 1.3797 | 2.9744 | 0 |
| 2026 Jan-Apr production guard | 38 | +0.1729 | 1.3249 | 1.6717 | 0 |


## Minimum Demo Evidence

Review at least 30-50 closed trades. Promotion requires ExpectancyR > 0, PF > 1.05, AvgLossR near -1R, live errors = 0, complete deal-level logs, and explainable guard events.

## Immediate Stop Conditions

- live_position_tracking_failed > 0
- live_sl_tp_invalid > 0
- live_lot_invalid > 0
- repeated live_order_send_failed
- SL/TP-less order
- non-demo account with EnableTrading=true
- HardStopDrawdownPercent reached
- EmergencyStopDrawdownPercent reached
- deal-level logging stops
- unexpected symbol/timeframe
- MagicNumber conflict

## Small Capital Decision

The current 100 USD capital level does not justify bypassing demo protection. Small live can be considered only after controlled demo passes and broker minimum-lot risk is measured. Initial small-live risk remains 0.05%-0.10%; if minimum lot cannot respect that, small live is blocked.
