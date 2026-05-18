# Strategy_01B_J_SHORT g039 Controlled Demo Runbook

## Stage

Stage: controlled demo only. Not small live. Not full production.

Champion: `g039` / `STRATEGY_01B_J_SHORT`.

Frozen parameters:

- DoubleTopBottomToleranceATR = 0.20
- NecklineBreakBufferATR = 0.07
- ADXLowThreshold = 22.0
- ADXHighThreshold = 32.0
- TakeProfitRMultiple = 1.5
- ExitSimulationModeInput = EXIT_FIXED_R_ONLY
- ConservativeSameBarExit = true
- MaxSpreadPoints = 30.0
- UseEquityCurveGuard = true
- AllowOnlyOnePositionForStrategy01B = true

Preset: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_controlled_demo.set`.

## Startup Sequence

1. Attach EA to USDJPY M5 only.
2. Load the controlled demo preset.
3. Confirm the account is a demo account.
4. Confirm preflight CSV is written and `preflight_status=PASS`.
5. Confirm `account_is_demo=true`, `EnableTrading=true`, `RiskPercent=0.10`, `MaxTotalOpenRiskPercent=0.10`.
6. Confirm deal-level and daily summary files are being written in MT5 Common Files.
7. Allow automated execution only after all checks pass.

## Required Runtime Files

- `preflight_*.csv`
- `daily_summary_*.csv`
- `Strategy_01_NWave_ExpectedValue_USDJPY_<magic>_diagnostics.csv`
- `Strategy_01_NWave_ExpectedValue_USDJPY_<magic>_deal_level.csv`

## Tester Baseline

| Baseline | Trades | ExpectancyR | PF | MaxDD% | Live errors |
|---|---:|---:|---:|---:|---:|
| 2025 production guard | 92 | +0.2014 | 1.3797 | 2.9744 | 0 |
| 2026 Jan-Apr production guard | 38 | +0.1729 | 1.3249 | 1.6717 | 0 |


## Demo Promotion Criteria

- 30-50 or more closed demo live-path trades.
- Realized ExpectancyR > 0.
- PF > 1.05.
- AvgLossR remains near -1R.
- MaxDD% remains inside plan.
- live errors = 0.
- Deal-level logging explains actual entry/exit, slippage, spread, commission, and swap.
- Soft/Hard/Emergency DD% stop does not fire under normal conditions.
- Daily/weekly/monthly R guard events are explainable.

## Immediate Stop

Stop immediately if any of the following occur:

- `live_position_tracking_failed > 0`
- `live_sl_tp_invalid > 0`
- `live_lot_invalid > 0`
- repeated `live_order_send_failed`
- any SL/TP-less managed order
- `EnableTrading=true` on a non-demo account
- HardStopDrawdownPercent reached
- EmergencyStopDrawdownPercent reached
- deal-level logging stops
- unexpected symbol/timeframe
- MagicNumber conflict

## Temporary Pause / Review

Pause and review if any of the following occur:

- `daily_loss_r_reached`
- `weekly_loss_r_reached`
- `monthly_loss_r_reached`
- SoftPauseDrawdownPercent reached
- AvgLossR worse than -1.2R
- `spread_too_wide` rises sharply
- signal frequency materially below tester baseline

## 100 USD Capital Note

Do not bypass demo-only protection for controlled demo. For a future small-live account near 100 USD, first confirm broker minimum lot, contract size, stop distance, and whether 0.05%-0.10% risk can place even the minimum lot. If minimum lot forces larger risk than planned, trading is blocked until a nano-lot broker, larger balance, or a separately approved small-capital risk exception exists.
