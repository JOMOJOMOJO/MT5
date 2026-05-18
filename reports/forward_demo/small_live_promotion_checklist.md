# Small Live Promotion Checklist

Status: not eligible yet. g039 is controlled-demo eligible only.

- Production guard test passes DD% Soft/Hard/Emergency checks.
- Demo `EnableTrading=true` runs at least 2-4 weeks.
- Demo produces 30-50 or more live-path trades.
- Demo realized ExpectancyR > 0 and PF > 1.05.
- AvgLossR remains near -1R.
- `live_order_send_failed`, `live_position_tracking_failed`, `live_sl_tp_invalid`, `live_lot_invalid` are all zero.
- Deal-level logging explains every trade.
- MaxDD% stays within plan.
- SoftPause/HardStop/EmergencyStop behavior is verified.
- Initial small-live RiskPercent is 0.05%-0.10%; do not raise to 0.25% before at least 30 small-live trades are reviewed.

Immediate block: missing SL/TP, tracking failure, invalid lot, repeated order send failures, unexpected symbol/timeframe, MagicNumber conflict, or absent CSV logs.
