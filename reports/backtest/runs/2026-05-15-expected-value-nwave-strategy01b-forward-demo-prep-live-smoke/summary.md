# Strategy_01B Forward Demo Prep - EnableTrading=true Smoke

Generated: 2026-05-15. Symbol USDJPY M5, H4/M15/M5, fixed internal 1.5R, `EnableTrading=true`, very conservative risk guard. This is order-path safety evidence, not a direct virtual-expectancy comparison.

Settings: `RiskPercent=0.25`, `MaxTotalOpenRiskPercent=0.25`, daily/weekly/monthly `1.5R/4R/6R`, `StopTradingAfterMaxDD_R=15`, `MinBarsBetweenEntries=5`, `AllowOnlyOnePositionForStrategy01B=true`.

## Smoke Metrics
|Mode|Period|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|MaxLoss|TotalR|RG rejects|
|---|---|---|---|---|---|---|---|---|---|---|---|
|C_SHORT_MODE|2025|99|42.42|1.4990|-1.0409|0.0366|1.0611|15.9134|7|3.6232|159|
|C_SHORT_MODE|2026q1|36|41.67|1.4790|-1.0239|0.0190|1.0318|5.1328|5|0.6833|34|
|C_SHORT_MODE|2025q4|41|41.46|1.5095|-1.0182|0.0298|1.0501|11.2240|7|1.2233|35|
|J_SHORT_MODE|2025|113|48.67|1.5012|-1.0394|0.1972|1.3696|10.0959|9|22.2812|10|
|J_SHORT_MODE|2026q1|29|44.83|1.4710|-1.0222|0.0955|1.1693|5.5422|5|2.7684|2|
|J_SHORT_MODE|2025q4|39|46.15|1.5106|-1.0212|0.1473|1.2680|9.1777|9|5.7464|1|

## Live Path Checks
|Mode|Period|Live entries|Closed tester trades|live_order_send_failed|live_position_tracking_failed|live_sl_tp_invalid|live_lot_invalid|RiskGuard rejects|
|---|---|---:|---:|---:|---:|---:|---:|---:|
|C_SHORT_MODE|2025|99|99|0|0|0|0|159|
|C_SHORT_MODE|2026q1|36|36|0|0|0|0|34|
|C_SHORT_MODE|2025q4|41|41|0|0|0|0|35|
|J_SHORT_MODE|2025|113|113|0|0|0|0|10|
|J_SHORT_MODE|2026q1|29|29|0|0|0|0|2|
|J_SHORT_MODE|2025q4|39|39|0|0|0|0|1|

## RejectReason Counts
### C_SHORT_MODE / 2025
|RejectReason|Count|
|---|---:|
|direction_filter_failed|1861|
|trend_alignment_filter_failed|1288|
|pattern_adx_bucket_filter_failed|339|
|fibo_filter_failed|83|
|total_open_risk_blocked|77|
|max_drawdown_r_blocked|43|
|spread_too_wide|18|
|weekly_loss_r_blocked|14|
|monthly_loss_r_blocked|13|
|daily_loss_r_blocked|12|
|rr_too_low|1|

### C_SHORT_MODE / 2026q1
|RejectReason|Count|
|---|---:|
|direction_filter_failed|453|
|trend_alignment_filter_failed|208|
|pattern_adx_bucket_filter_failed|144|
|total_open_risk_blocked|30|
|fibo_filter_failed|9|
|spread_too_wide|6|
|daily_loss_r_blocked|4|

### C_SHORT_MODE / 2025q4
|RejectReason|Count|
|---|---:|
|direction_filter_failed|489|
|trend_alignment_filter_failed|243|
|pattern_adx_bucket_filter_failed|108|
|total_open_risk_blocked|18|
|monthly_loss_r_blocked|11|
|spread_too_wide|5|
|daily_loss_r_blocked|4|
|weekly_loss_r_blocked|2|
|rr_too_low|1|

### J_SHORT_MODE / 2025
|RejectReason|Count|
|---|---:|
|direction_filter_failed|1861|
|trend_alignment_filter_failed|1288|
|pattern_adx_bucket_filter_failed|339|
|break_candle_strength_filter_failed|87|
|fibo_filter_failed|83|
|entry_open_count_filter_failed|55|
|spread_too_wide|10|
|daily_loss_r_blocked|7|
|weekly_loss_r_blocked|3|
|rr_too_low|1|

### J_SHORT_MODE / 2026q1
|RejectReason|Count|
|---|---:|
|direction_filter_failed|453|
|trend_alignment_filter_failed|208|
|pattern_adx_bucket_filter_failed|144|
|break_candle_strength_filter_failed|26|
|entry_open_count_filter_failed|17|
|fibo_filter_failed|9|
|daily_loss_r_blocked|2|
|spread_too_wide|2|

### J_SHORT_MODE / 2025q4
|RejectReason|Count|
|---|---:|
|direction_filter_failed|489|
|trend_alignment_filter_failed|243|
|pattern_adx_bucket_filter_failed|108|
|break_candle_strength_filter_failed|27|
|entry_open_count_filter_failed|9|
|spread_too_wide|5|
|daily_loss_r_blocked|1|
|rr_too_low|1|

## Interpretation
- Both `C_SHORT_MODE` and `J_SHORT_MODE` completed all requested `EnableTrading=true` smoke runs with SL/TP attached in diagnostics.
- No `live_order_send_failed`, `live_position_tracking_failed`, `live_sl_tp_invalid`, or `live_lot_invalid` events were recorded in the smoke set.
- Tester live-path R differs from virtual R because real tester orders include actual fill/spread/money accounting. Treat this section as execution safety evidence only.
