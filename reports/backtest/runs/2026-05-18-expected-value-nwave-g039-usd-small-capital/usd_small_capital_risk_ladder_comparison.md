# USD Small Capital Risk Ladder Comparison

## Full Run Table

|Deposit|Pattern|Period|Trades|ExpR|PF|Final USD|Net %|MaxDD %|EffRisk max %|MinLot forced|Margin rejects|Ruin|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|100|baseline_025|2024_2026|1|-1.0000|0.0000|99.77|-0.23|0.23|0.23|0|0|no|
|100|baseline_025|2025|0|0.0000|0.0000|100.00|+0.00|0.00|0.22|0|0|no|
|100|baseline_025|2026_jan_apr|0|0.0000|0.0000|100.00|+0.00|0.00|0.21|0|0|no|
|100|ladder_10_5_1|2024_2026|4|0.1494|1.2454|103.60|+3.60|19.99|9.88|0|2621|small_capital_margin_insufficient_repeated|
|100|ladder_10_5_1|2025|20|0.3548|1.7604|166.97|+66.97|33.70|9.82|0|870|small_capital_margin_insufficient_repeated|
|100|ladder_10_5_1|2026_jan_apr|1|-1.0000|0.0000|91.09|-8.91|10.99|8.91|0|370|small_capital_margin_insufficient_repeated|
|100|safer_5_2_1|2024_2026|51|0.0956|1.1686|117.69|+17.69|39.28|4.99|0|327|small_capital_margin_insufficient_repeated|
|100|safer_5_2_1|2025|78|0.1287|1.2293|125.00|+25.00|40.68|5.31|2|82|no|
|100|safer_5_2_1|2026_jan_apr|25|0.2860|1.5892|137.96|+37.96|17.64|7.48|2|53|small_capital_margin_insufficient_repeated|
|500|baseline_025|2024_2026|200|-0.1053|0.8394|478.22|-4.36|6.26|0.25|0|0|no|
|500|baseline_025|2025|60|-0.0660|0.8968|496.06|-0.79|2.61|0.25|0|0|no|
|500|baseline_025|2026_jan_apr|23|-0.2447|0.6522|493.09|-1.38|2.04|0.25|0|0|no|
|500|ladder_10_5_1|2024_2026|4|0.1493|1.2454|512.80|+2.56|20.55|9.99|0|3068|small_capital_margin_insufficient_repeated|
|500|ladder_10_5_1|2025|20|0.3549|1.7605|858.95|+71.79|35.83|9.98|0|1071|small_capital_margin_insufficient_repeated|
|500|ladder_10_5_1|2026_jan_apr|1|-1.0000|0.0000|451.01|-9.80|12.06|9.80|0|436|small_capital_margin_insufficient_repeated|
|500|safer_5_2_1|2024_2026|14|-0.5393|0.3551|340.22|-31.96|40.37|4.99|0|423|no|
|500|safer_5_2_1|2025|95|0.1649|1.3018|1098.29|+119.66|38.57|5.00|0|116|no|
|500|safer_5_2_1|2026_jan_apr|25|0.2858|1.5889|668.19|+33.64|17.06|4.99|0|62|small_capital_margin_insufficient_repeated|
|1000|baseline_025|2024_2026|295|-0.0299|0.9522|971.32|-2.87|5.32|0.25|0|0|no|
|1000|baseline_025|2025|94|0.0417|1.0700|1004.65|+0.47|3.02|0.25|0|0|no|
|1000|baseline_025|2026_jan_apr|38|0.1033|1.1843|1007.81|+0.78|1.16|0.25|0|0|no|
|1000|ladder_10_5_1|2024_2026|6|-0.2360|0.6816|989.01|-1.10|19.21|9.97|0|632|small_capital_margin_insufficient_repeated|
|1000|ladder_10_5_1|2025|77|0.1128|1.1985|1305.34|+30.53|42.81|5.00|0|118|no|
|1000|ladder_10_5_1|2026_jan_apr|1|-1.0000|0.0000|951.01|-4.90|6.11|4.90|0|82|small_capital_margin_insufficient_repeated|
|1000|safer_5_2_1|2024_2026|82|-0.1104|0.8303|712.04|-28.80|40.13|5.00|0|27|no|
|1000|safer_5_2_1|2025|98|0.1257|1.2239|1202.46|+20.25|28.23|2.00|0|0|no|
|1000|safer_5_2_1|2026_jan_apr|39|0.1413|1.2589|1136.02|+13.60|14.53|4.94|0|0|no|
|10000|baseline_025|2024_2026|303|0.0097|1.0159|10046.57|+0.47|5.58|0.25|0|0|no|
|10000|baseline_025|2025|98|0.1257|1.2240|10269.47|+2.69|3.78|0.25|0|0|no|
|10000|baseline_025|2026_jan_apr|39|0.1413|1.2589|10129.81|+1.30|1.69|0.25|0|0|no|
|10000|ladder_10_5_1|2024_2026|302|0.0131|1.0215|12814.26|+28.14|22.45|5.00|0|2|no|
|10000|ladder_10_5_1|2025|98|0.1257|1.2239|11206.80|+12.07|15.25|1.00|0|0|no|
|10000|ladder_10_5_1|2026_jan_apr|39|0.1413|1.2589|11147.39|+11.47|7.56|4.99|0|0|no|
|10000|safer_5_2_1|2024_2026|303|0.0097|1.0159|10692.87|+6.93|32.92|2.00|0|0|no|
|10000|safer_5_2_1|2025|98|0.1257|1.2239|11206.80|+12.07|15.25|1.00|0|0|no|
|10000|safer_5_2_1|2026_jan_apr|39|0.1413|1.2589|10677.16|+6.77|7.56|2.00|0|0|no|

## Main Findings

- Conservative 0.25% baseline is too small to trade 100 USD reliably and produces negligible growth. At 500/1000/10000 USD it runs, but the long 2024-2026 reference is flat to negative except 10000 USD at a very small +0.47%.
- The aggressive 10/5/1 ladder is not robust for 100, 500, or 1000 USD. It repeatedly hits `small_capital_margin_insufficient_repeated`. It only runs cleanly at 10000 USD in 2025 and 2026 Jan-Apr, but the 2024-2026 reference still has weak expectancy and 22.45% DD.
- The safer 5/2/1 ladder is more realistic. It passes 2025 and 2026 Jan-Apr at 1000 USD without ruin and with positive expectancy, but the 2024-2026 reference is still negative and reaches about 40% DD.
- 100 USD is technically tradable in a tester, but not operationally stable enough for real money. 500 USD is better but still not robust. 1000 USD is the minimum level worth considering for high-risk demo validation.

## Decision

Use the safer 5/2/1 ladder for any small-capital challenge demo. Do not use the 10/5/1 ladder for 100/500/1000 USD live money. Do not treat this mode as production.

Additional safer demo preset: `reports/presets/ExpectedValue_NWave_J_SHORT_g039_usd_small_capital_challenge_demo_safer.set`.
