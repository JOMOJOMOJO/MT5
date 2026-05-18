# USD Small Capital Backtest - 10000 USD

10000 USD is technically cleanest. Both ladders run without ruin in 2025 and 2026 Jan-Apr. The long reference period still has weak expectancy and large DD, so this remains a challenge/demo design rather than production.

|Pattern|Period|Trades|ExpR|PF|Final USD|Net %|MaxDD %|EffRisk max %|MinLot forced|Margin rejects|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|
|baseline_025|2024_2026|303|0.0097|1.0159|10046.57|+0.47|5.58|0.25|0|0|no|
|baseline_025|2025|98|0.1257|1.2240|10269.47|+2.69|3.78|0.25|0|0|no|
|baseline_025|2026_jan_apr|39|0.1413|1.2589|10129.81|+1.30|1.69|0.25|0|0|no|
|ladder_10_5_1|2024_2026|302|0.0131|1.0215|12814.26|+28.14|22.45|5.00|0|2|no|
|ladder_10_5_1|2025|98|0.1257|1.2239|11206.80|+12.07|15.25|1.00|0|0|no|
|ladder_10_5_1|2026_jan_apr|39|0.1413|1.2589|11147.39|+11.47|7.56|4.99|0|0|no|
|safer_5_2_1|2024_2026|303|0.0097|1.0159|10692.87|+6.93|32.92|2.00|0|0|no|
|safer_5_2_1|2025|98|0.1257|1.2239|11206.80|+12.07|15.25|1.00|0|0|no|
|safer_5_2_1|2026_jan_apr|39|0.1413|1.2589|10677.16|+6.77|7.56|2.00|0|0|no|

Evidence source: `usd_small_capital_metrics.csv` and `raw/Strategy_01_NWave_ExpectedValue_USDJPY_<magic>_*.csv` in this run folder.
