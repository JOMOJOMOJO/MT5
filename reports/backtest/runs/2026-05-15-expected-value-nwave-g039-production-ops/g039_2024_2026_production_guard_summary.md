# g039 production guard 2024.01.01-2026.04.30

Period: 2024.01.01-2026.04.30. Production DD% guards and daily/weekly/monthly R guards were enabled. `StopTradingAfterMaxDD_R=999`, so DD% guards are the main production drawdown stop mechanism in this test.

|Metric|Value|
|---|---|
|Closed trades|277|
|WinRate%|42.2383|
|AvgWinR|1.5177|
|AvgLossR|-1.0334|
|ExpectancyR|0.0441|
|PF|1.0739|
|MaxDD_R summary|24.2826|
|MaxDD% summary|5.8883|
|TotalR|12.2202|
|Max consecutive losses|8|
|RiskGuard rejects|42|
|Live errors|0|
|DD% Soft/Hard/Emergency stops|0|
|Daily/Weekly/Monthly R stop events|39|

**Year**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2024|147|36.7347|-0.0876|0.8662|24.2826|-12.8843|
|2025|92|48.9130|0.2015|1.3797|11.5732|18.5349|
|2026|38|47.3684|0.1729|1.3248|5.0908|6.5695|

**Quarter**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2024Q1|43|46.5116|0.1392|1.2505|6.6747|5.9848|
|2024Q2|43|27.9070|-0.3154|0.5716|16.2602|-13.5637|
|2024Q3|21|38.0952|0.0883|1.1402|4.6312|1.8542|
|2024Q4|40|35.0000|-0.1790|0.7400|10.4547|-7.1595|
|2025Q1|16|50.0000|0.2172|1.4220|4.0530|3.4758|
|2025Q2|20|60.0000|0.4910|2.1773|5.2319|9.8196|
|2025Q3|28|50.0000|0.2141|1.4023|5.2644|5.9949|
|2025Q4|28|39.2857|-0.0270|0.9564|10.7778|-0.7553|
|2026Q1|31|51.6129|0.2786|1.5686|3.5527|8.6356|
|2026Q2|7|28.5714|-0.2952|0.5898|3.5735|-2.0661|

**Month**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2024-01|13|46.1538|0.0993|1.1682|6.6747|1.2912|
|2024-02|22|45.4545|0.1251|1.2252|3.5608|2.7517|
|2024-03|8|50.0000|0.2427|1.4855|3.0000|1.9419|
|2024-04|16|25.0000|-0.4135|0.4524|9.2481|-6.6158|
|2024-05|13|23.0769|-0.4053|0.4881|7.1289|-5.2690|
|2024-06|14|35.7143|-0.1199|0.8192|3.0308|-1.6790|
|2024-07|9|33.3333|0.1649|1.2462|3.0228|1.4843|
|2024-08|2|100.0000|1.5005|inf|0.0000|3.0009|
|2024-09|10|30.0000|-0.2631|0.6343|4.6312|-2.6310|
|2024-10|20|30.0000|-0.3351|0.5567|7.2156|-6.7017|
|2024-11|12|41.6667|0.0144|1.0237|3.5483|0.1725|
|2024-12|8|37.5000|-0.0788|0.8778|4.1564|-0.6303|
|2025-01|7|71.4286|0.7573|3.5866|1.0360|5.3014|
|2025-03|9|33.3333|-0.2028|0.7049|4.0530|-1.8256|
|2025-05|11|63.6364|0.5768|2.4929|1.1408|6.3448|
|2025-06|9|55.5556|0.3861|1.8494|4.0910|3.4748|
|2025-07|14|42.8571|0.0432|1.0744|4.5077|0.6049|
|2025-08|6|83.3333|1.0154|4.8133|1.5978|6.0927|
|2025-09|8|37.5000|-0.0878|0.8642|4.1278|-0.7027|
|2025-10|11|18.1818|-0.5586|0.3296|7.6502|-6.1450|
|2025-11|13|46.1538|0.1502|1.2739|3.1277|1.9521|
|2025-12|4|75.0000|0.8594|4.3194|1.0356|3.4376|
|2026-01|9|44.4444|0.1102|1.1959|2.5508|0.9921|
|2026-02|7|71.4286|0.7665|3.6829|1.0000|5.3658|
|2026-03|15|46.6667|0.1518|1.2804|3.5527|2.2776|
|2026-04|7|28.5714|-0.2952|0.5898|3.5735|-2.0661|

## Stop Events

|date|stop_class|stop_reason|drawdown_percent|max_drawdown_percent|realized_profit_r|
|---|---|---|---|---|---|
|20240117|period_r|daily_loss_r_reached|1.8057|1.8057|-2.2215|
|20240118|period_r|weekly_loss_r_reached|1.8057|1.8057|0.0000|
|20240119|period_r|weekly_loss_r_reached|1.8057|1.8057|0.0000|
|20240216|period_r|daily_loss_r_reached|0.6509|1.8836|-2.0117|
|20240226|period_r|daily_loss_r_reached|0.6470|1.8836|-2.0000|
|20240325|period_r|daily_loss_r_reached|0.4986|1.8836|-2.0000|
|20240411|period_r|weekly_loss_r_reached|0.9954|1.8836|-1.0071|
|20240412|period_r|weekly_loss_r_reached|0.9954|1.8836|0.0000|
|20240416|period_r|daily_loss_r_reached|1.4859|1.8836|-2.0000|
|20240423|period_r|daily_loss_r_reached|2.2782|2.2782|-2.0406|
|20240425|period_r|monthly_loss_r_reached|2.2782|2.2782|0.0000|
|20240510|period_r|daily_loss_r_reached|2.3147|2.3939|-2.0081|
|20240520|period_r|daily_loss_r_reached|2.7145|2.7145|-2.1313|
|20240527|period_r|daily_loss_r_reached|3.0663|3.0663|-2.1373|
|20240529|period_r|weekly_loss_r_reached|3.5464|3.5464|-1.0172|
|20240530|period_r|weekly_loss_r_reached|3.5464|3.5464|0.0000|
|20240611|period_r|daily_loss_r_reached|3.9341|3.9341|-2.0848|
|20240710|period_r|daily_loss_r_reached|4.6588|4.6588|-2.0000|
|20240920|period_r|daily_loss_r_reached|2.9581|4.8658|-2.0929|
|20240926|period_r|daily_loss_r_reached|3.5678|4.8658|-2.0097|
|20241010|period_r|daily_loss_r_reached|4.3151|4.8658|-2.9268|
|20241022|period_r|daily_loss_r_reached|4.4662|4.8658|-2.0039|
|20241024|period_r|daily_loss_r_reached|4.5847|4.8658|-2.0306|
|20241028|period_r|monthly_loss_r_reached|5.0639|5.0639|-1.0063|
|20241029|period_r|monthly_loss_r_reached|5.0639|5.0639|0.0000|
|20241030|period_r|monthly_loss_r_reached|5.0639|5.0639|0.0000|
|20241114|period_r|daily_loss_r_reached|5.8143|5.8883|-2.0051|
|20250610|period_r|daily_loss_r_reached|3.4516|5.8883|-2.0629|
|20250611|period_r|daily_loss_r_reached|3.9237|5.8883|-2.0281|
|20250718|period_r|daily_loss_r_reached|2.3454|5.8883|-2.0134|
|20250728|period_r|daily_loss_r_reached|2.4589|5.8883|-2.0034|
|20250828|period_r|daily_loss_r_reached|0.6790|5.8883|-1.5978|
|20251023|period_r|daily_loss_r_reached|1.9024|5.8883|-2.0650|
|20251027|period_r|monthly_loss_r_reached|2.3792|5.8883|-1.0000|
|20251030|period_r|monthly_loss_r_reached|2.3792|5.8883|0.0000|
|20251031|period_r|monthly_loss_r_reached|2.3792|5.8883|0.0000|
|20251104|period_r|daily_loss_r_reached|3.1218|5.8883|-2.1277|
|20260326|period_r|daily_loss_r_reached|1.0484|5.8883|-2.0534|
|20260422|period_r|daily_loss_r_reached|1.1929|5.8883|-2.0000|

## Stop Reason Counts

|StopReason|Count|
|---|---|
|daily_loss_r_reached|26|
|monthly_loss_r_reached|7|
|weekly_loss_r_reached|6|

## RejectReason Counts

|RejectReason|Count|
|---|---|
|direction_filter_failed|4071|
|trend_alignment_filter_failed|2214|
|pattern_adx_bucket_filter_failed|1077|
|break_candle_strength_filter_failed|207|
|fibo_filter_failed|168|
|entry_open_count_filter_failed|146|
|spread_too_wide|26|
|daily_loss_r_blocked|17|
|weekly_loss_r_blocked|12|
|monthly_loss_r_blocked|11|
|min_bars_between_entries_blocked|2|
|rr_too_low|1|

## Live Error Rejects

|RejectReason|Count|
|---|---|
|none|0|
