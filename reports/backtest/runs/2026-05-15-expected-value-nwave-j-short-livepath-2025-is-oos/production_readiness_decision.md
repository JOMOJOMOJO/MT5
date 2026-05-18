# Production Readiness Decision

Generated: 2026-05-15

## Decision
- Production/live operation: **No**.
- Small-lot production: **No**.
- Demo account `EnableTrading=true`: **Yes, only for controlled demo validation of `g039`**, after preflight and with existing hard risk guards.
- Virtual results are no longer accepted as promotion evidence.

## Reason
The evaluation basis has been switched from virtual diagnostics to `EnableTrading=true` tester realized R.

The 2025 live-path IS rank-1 candidate, `g024`, failed OOS:
- 2025 IS: ExpectancyR `0.240004`, PF `1.465090`
- 2026 Jan-Apr OOS: ExpectancyR `-0.084949`, PF `0.866633`

The only preselected top-5 candidate to pass live-path OOS was `g039`:
- 2025 IS: `92` trades, ExpectancyR `0.201438`, PF `1.379684`, MaxDD_R `11.574514`
- 2026 Jan-Apr OOS: `38` trades, ExpectancyR `0.172890`, PF `1.324866`, MaxDD_R `5.090685`
- live order/tracking/SLTP/lot errors: `0`

This is enough for demo-forward validation, not enough for production.

## Conditions Not Yet Met For Small-Lot Production
- At least `2-4` weeks of demo `EnableTrading=true` evidence on the same broker/server.
- At least `30` demo live-path trades after the selected `g039` preset is frozen.
- Demo realized ExpectancyR > `0`, PF > `1.05`, AvgLossR near `-1R`.
- No `live_order_send_failed`, `live_position_tracking_failed`, `live_sl_tp_invalid`, or `live_lot_invalid`.
- Actual deal-level logging must be added or externally verified:
  - actual entry deal price,
  - actual exit deal price,
  - slippage points,
  - commission,
  - swap,
  - realized risk money.
- April 2026 style drawdown must remain within daily/weekly/monthly guards in forward demo.
- Signal frequency must not deviate materially from tester expectations.

## Operating Stance
Use `g039` only as a forward-demo candidate:
- `RiskPercent=0.25`
- `MaxTotalOpenRiskPercent=0.25`
- `MaxDailyLossR=1.5`
- `MaxWeeklyLossR=4.0`
- `MaxMonthlyLossR=6.0`
- `StopTradingAfterMaxDD_R=15.0`
- `AllowOnlyOnePositionForStrategy01B=true`
- `UseEquityCurveGuard=true`
- `MaxSpreadPoints=30.0`

If demo `EnableTrading=true` diverges from live-path tester metrics or any live error appears, stop and diagnose before any further promotion.

## Policy Update
For Strategy_01B_J_SHORT, virtual results may remain useful for signal discovery and diagnostics, but they must not be used for demo/live promotion decisions. Promotion evidence must come from `EnableTrading=true` tester runs and then real demo execution logs.
