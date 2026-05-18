# g039 production guard 2025.01.01-2025.12.31

Period: 2025.01.01-2025.12.31. Production DD% guards and daily/weekly/monthly R guards were enabled. `StopTradingAfterMaxDD_R=999`, so DD% guards are the main production drawdown stop mechanism in this test.

|Metric|Value|
|---|---|
|Closed trades|92|
|WinRate%|48.9130|
|AvgWinR|1.4965|
|AvgLossR|-1.0385|
|ExpectancyR|0.2014|
|PF|1.3797|
|MaxDD_R summary|11.5745|
|MaxDD% summary|2.9744|
|TotalR|18.5323|
|Max consecutive losses|8|
|RiskGuard rejects|9|
|Live errors|0|
|DD% Soft/Hard/Emergency stops|0|
|Daily/Weekly/Monthly R stop events|10|

**Year**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2025|92|48.9130|0.2014|1.3797|11.5745|18.5323|

**Quarter**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2025Q1|16|50.0000|0.2172|1.4220|4.0530|3.4754|
|2025Q2|20|60.0000|0.4910|2.1773|5.2323|9.8203|
|2025Q3|28|50.0000|0.2141|1.4022|5.2647|5.9942|
|2025Q4|28|39.2857|-0.0271|0.9563|10.7783|-0.7576|

**Month**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2025-01|7|71.4286|0.7573|3.5866|1.0360|5.3012|
|2025-03|9|33.3333|-0.2029|0.7049|4.0530|-1.8258|
|2025-05|11|63.6364|0.5768|2.4927|1.1413|6.3443|
|2025-06|9|55.5556|0.3862|1.8497|4.0910|3.4760|
|2025-07|14|42.8571|0.0432|1.0744|4.5080|0.6046|
|2025-08|6|83.3333|1.0155|4.8133|1.5978|6.0929|
|2025-09|8|37.5000|-0.0879|0.8641|4.1278|-0.7033|
|2025-10|11|18.1818|-0.5587|0.3295|7.6507|-6.1458|
|2025-11|13|46.1538|0.1501|1.2738|3.1276|1.9513|
|2025-12|4|75.0000|0.8592|4.3182|1.0358|3.4370|

## Stop Events

|date|stop_class|stop_reason|drawdown_percent|max_drawdown_percent|realized_profit_r|
|---|---|---|---|---|---|
|20250610|period_r|daily_loss_r_reached|0.8398|1.2379|-2.0629|
|20250611|period_r|daily_loss_r_reached|1.3400|1.3400|-2.0281|
|20250718|period_r|daily_loss_r_reached|1.0218|1.4279|-2.0134|
|20250728|period_r|daily_loss_r_reached|1.1463|1.4279|-2.0031|
|20250828|period_r|daily_loss_r_reached|0.3986|1.5358|-1.5978|
|20251023|period_r|daily_loss_r_reached|1.5650|1.5650|-2.0650|
|20251027|period_r|monthly_loss_r_reached|2.0448|2.0448|-1.0000|
|20251030|period_r|monthly_loss_r_reached|2.0448|2.0448|0.0000|
|20251031|period_r|monthly_loss_r_reached|2.0448|2.0448|0.0000|
|20251104|period_r|daily_loss_r_reached|2.7997|2.7997|-2.1276|

## Stop Reason Counts

|StopReason|Count|
|---|---|
|daily_loss_r_reached|7|
|monthly_loss_r_reached|3|

## RejectReason Counts

|RejectReason|Count|
|---|---|
|direction_filter_failed|1790|
|trend_alignment_filter_failed|1223|
|pattern_adx_bucket_filter_failed|338|
|fibo_filter_failed|75|
|break_candle_strength_filter_failed|71|
|entry_open_count_filter_failed|50|
|spread_too_wide|10|
|daily_loss_r_blocked|5|
|monthly_loss_r_blocked|4|
|rr_too_low|1|

## Live Error Rejects

|RejectReason|Count|
|---|---|
|none|0|
