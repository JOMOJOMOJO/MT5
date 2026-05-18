# USD Small Capital Backtest - 100 USD

0.01 lot itself is technically possible in the tester, but both ladders are operationally fragile. The 10/5/1 ladder repeatedly stops from margin insufficiency. The 5/2/1 ladder is better, yet 2026 Jan-Apr and the long 2024-2026 run still hit repeated margin insufficiency. Real-money use is not approved.

|Pattern|Period|Trades|ExpR|PF|Final USD|Net %|MaxDD %|EffRisk max %|MinLot forced|Margin rejects|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|
|baseline_025|2024_2026|1|-1.0000|0.0000|99.77|-0.23|0.23|0.23|0|0|no|
|baseline_025|2025|0|0.0000|0.0000|100.00|+0.00|0.00|0.22|0|0|no|
|baseline_025|2026_jan_apr|0|0.0000|0.0000|100.00|+0.00|0.00|0.21|0|0|no|
|ladder_10_5_1|2024_2026|4|0.1494|1.2454|103.60|+3.60|19.99|9.88|0|2621|small_capital_margin_insufficient_repeated|
|ladder_10_5_1|2025|20|0.3548|1.7604|166.97|+66.97|33.70|9.82|0|870|small_capital_margin_insufficient_repeated|
|ladder_10_5_1|2026_jan_apr|1|-1.0000|0.0000|91.09|-8.91|10.99|8.91|0|370|small_capital_margin_insufficient_repeated|
|safer_5_2_1|2024_2026|51|0.0956|1.1686|117.69|+17.69|39.28|4.99|0|327|small_capital_margin_insufficient_repeated|
|safer_5_2_1|2025|78|0.1287|1.2293|125.00|+25.00|40.68|5.31|2|82|no|
|safer_5_2_1|2026_jan_apr|25|0.2860|1.5892|137.96|+37.96|17.64|7.48|2|53|small_capital_margin_insufficient_repeated|

Evidence source: `usd_small_capital_metrics.csv` and `raw/Strategy_01_NWave_ExpectedValue_USDJPY_<magic>_*.csv` in this run folder.
