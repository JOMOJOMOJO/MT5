# USD Small Capital Backtest - 1000 USD

1000 USD is the first tier where the safer 5/2/1 ladder works cleanly in 2025 and 2026 Jan-Apr with no ruin flag. The 2024-2026 reference remains negative and reaches about 40% DD, so this is high-risk demo only, not small live yet.

|Pattern|Period|Trades|ExpR|PF|Final USD|Net %|MaxDD %|EffRisk max %|MinLot forced|Margin rejects|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|
|baseline_025|2024_2026|295|-0.0299|0.9522|971.32|-2.87|5.32|0.25|0|0|no|
|baseline_025|2025|94|0.0417|1.0700|1004.65|+0.47|3.02|0.25|0|0|no|
|baseline_025|2026_jan_apr|38|0.1033|1.1843|1007.81|+0.78|1.16|0.25|0|0|no|
|ladder_10_5_1|2024_2026|6|-0.2360|0.6816|989.01|-1.10|19.21|9.97|0|632|small_capital_margin_insufficient_repeated|
|ladder_10_5_1|2025|77|0.1128|1.1985|1305.34|+30.53|42.81|5.00|0|118|no|
|ladder_10_5_1|2026_jan_apr|1|-1.0000|0.0000|951.01|-4.90|6.11|4.90|0|82|small_capital_margin_insufficient_repeated|
|safer_5_2_1|2024_2026|82|-0.1104|0.8303|712.04|-28.80|40.13|5.00|0|27|no|
|safer_5_2_1|2025|98|0.1257|1.2239|1202.46|+20.25|28.23|2.00|0|0|no|
|safer_5_2_1|2026_jan_apr|39|0.1413|1.2589|1136.02|+13.60|14.53|4.94|0|0|no|

Evidence source: `usd_small_capital_metrics.csv` and `raw/Strategy_01_NWave_ExpectedValue_USDJPY_<magic>_*.csv` in this run folder.
