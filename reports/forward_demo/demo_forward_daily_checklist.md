# Demo Forward Daily Checklist

## Before Market / Session

- Confirm EA is attached only to USDJPY M5.
- Confirm account is demo.
- Confirm MagicNumber is unique.
- Confirm spread is normal for USDJPY M5.
- Confirm preflight file exists and status is PASS.
- Confirm no prior `stop_condition_triggered=true` remains unresolved.

## Daily CSV Review

Open the latest `daily_summary_YYYYMMDD_<magic>.csv` and check:

- closed_trades
- live_entries
- realized_profit_r
- realized_profit_money
- win_rate
- avg_win_r
- avg_loss_r
- pf
- max_daily_dd_r
- max_daily_dd_percent
- consecutive_losses
- spread_too_wide_count
- daily_loss_r_blocked_count
- weekly_loss_r_blocked_count
- monthly_loss_r_blocked_count
- soft_pause_drawdown_percent_count
- hard_stop_drawdown_percent_count
- emergency_stop_drawdown_percent_count
- live_order_send_failed_count
- live_position_tracking_failed_count
- live_sl_tp_invalid_count
- live_lot_invalid_count
- stop_condition_triggered
- stop_reason

## Deal-Level Review

For every closed trade, check deal-level rows:

- actual entry/exit price is present
- realized_r is explainable from actual risk money
- slippage points are not abnormal
- spread at entry and exit are reasonable
- commission and swap are recorded

## Daily Decision

Continue only if live errors are zero, logs are complete, symbol/timeframe are correct, and stop conditions are either false or already reviewed.
