# g039 production guard 2026.01.01-2026.04.30

Period: 2026.01.01-2026.04.30. Production DD% guards and daily/weekly/monthly R guards were enabled. `StopTradingAfterMaxDD_R=999`, so DD% guards are the main production drawdown stop mechanism in this test.

|Metric|Value|
|---|---|
|Closed trades|38|
|WinRate%|47.3684|
|AvgWinR|1.4885|
|AvgLossR|-1.0112|
|ExpectancyR|0.1729|
|PF|1.3249|
|MaxDD_R summary|5.0907|
|MaxDD% summary|1.6717|
|TotalR|6.5698|
|Max consecutive losses|3|
|RiskGuard rejects|1|
|Live errors|0|
|DD% Soft/Hard/Emergency stops|0|
|Daily/Weekly/Monthly R stop events|2|

**Year**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2026|38|47.3684|0.1729|1.3249|5.0907|6.5698|

**Quarter**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2026Q1|31|51.6129|0.2786|1.5686|3.5526|8.6359|
|2026Q2|7|28.5714|-0.2952|0.5898|3.5735|-2.0661|

**Month**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2026-01|9|44.4444|0.1102|1.1959|2.5508|0.9921|
|2026-02|7|71.4286|0.7665|3.6829|1.0000|5.3658|
|2026-03|15|46.6667|0.1519|1.2805|3.5526|2.2779|
|2026-04|7|28.5714|-0.2952|0.5898|3.5735|-2.0661|

## Stop Events

|date|stop_class|stop_reason|drawdown_percent|max_drawdown_percent|realized_profit_r|
|---|---|---|---|---|---|
|20260326|period_r|daily_loss_r_reached|1.0479|1.0479|-2.0534|
|20260422|period_r|daily_loss_r_reached|1.1936|1.1936|-2.0000|

## Stop Reason Counts

|StopReason|Count|
|---|---|
|daily_loss_r_reached|2|

## RejectReason Counts

|RejectReason|Count|
|---|---|
|direction_filter_failed|560|
|trend_alignment_filter_failed|264|
|pattern_adx_bucket_filter_failed|183|
|break_candle_strength_filter_failed|27|
|entry_open_count_filter_failed|22|
|spread_too_wide|8|
|fibo_filter_failed|7|
|daily_loss_r_blocked|1|

## Live Error Rejects

|RejectReason|Count|
|---|---|
|none|0|
