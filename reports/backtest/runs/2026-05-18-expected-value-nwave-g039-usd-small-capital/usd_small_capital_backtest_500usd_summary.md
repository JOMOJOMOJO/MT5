# USD Small Capital Backtest - 500 USD

500 USD improves free margin but still does not make the 10/5/1 ladder viable. The 5/2/1 ladder is positive in 2025 and 2026 Jan-Apr, but the 2024-2026 reference run is negative and margin-reject heavy. Demo-only for now.

|Pattern|Period|Trades|ExpR|PF|Final USD|Net %|MaxDD %|EffRisk max %|MinLot forced|Margin rejects|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|
|baseline_025|2024_2026|200|-0.1053|0.8394|478.22|-4.36|6.26|0.25|0|0|no|
|baseline_025|2025|60|-0.0660|0.8968|496.06|-0.79|2.61|0.25|0|0|no|
|baseline_025|2026_jan_apr|23|-0.2447|0.6522|493.09|-1.38|2.04|0.25|0|0|no|
|ladder_10_5_1|2024_2026|4|0.1493|1.2454|512.80|+2.56|20.55|9.99|0|3068|small_capital_margin_insufficient_repeated|
|ladder_10_5_1|2025|20|0.3549|1.7605|858.95|+71.79|35.83|9.98|0|1071|small_capital_margin_insufficient_repeated|
|ladder_10_5_1|2026_jan_apr|1|-1.0000|0.0000|451.01|-9.80|12.06|9.80|0|436|small_capital_margin_insufficient_repeated|
|safer_5_2_1|2024_2026|14|-0.5393|0.3551|340.22|-31.96|40.37|4.99|0|423|no|
|safer_5_2_1|2025|95|0.1649|1.3018|1098.29|+119.66|38.57|5.00|0|116|no|
|safer_5_2_1|2026_jan_apr|25|0.2858|1.5889|668.19|+33.64|17.06|4.99|0|62|small_capital_margin_insufficient_repeated|

Evidence source: `usd_small_capital_metrics.csv` and `raw/Strategy_01_NWave_ExpectedValue_USDJPY_<magic>_*.csv` in this run folder.
