# Strategy_01B Forward Demo Prep - Risk Guard ON/OFF

Generated: 2026-05-15. Symbol USDJPY M5, H4/M15/M5, fixed internal 1.5R, `EnableTrading=false`, conservative same-bar exit enabled.

Guard profiles:
- `guard_off`: previous StrategyMode regression shape, `RiskPercent=1.0`, equity guard disabled, no min-bars/one-position guard.
- `guard_on_conservative`: `RiskPercent=0.5`, `MaxTotalOpenRiskPercent=0.5`, daily/weekly/monthly `2R/5R/8R`, `StopTradingAfterMaxDD_R=20`, `MinBarsBetweenEntries=3`, one Strategy_01B position only.
- `guard_on_very_conservative`: `RiskPercent=0.25`, `MaxTotalOpenRiskPercent=0.25`, daily/weekly/monthly `1.5R/4R/6R`, `StopTradingAfterMaxDD_R=15`, `MinBarsBetweenEntries=5`, one Strategy_01B position only.

## Full Window Comparison
|Mode|Guard|Period|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|MaxLoss|TotalR|RG rejects|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|C_SHORT_MODE|guard_off|full|505|45.94|1.4996|-1.0000|0.1484|1.2744|16.0048|14|74.9177|83|
|C_SHORT_MODE|guard_on_conservative|full|377|45.89|1.4997|-1.0000|0.1471|1.2718|15.4988|10|55.4403|354|
|C_SHORT_MODE|guard_on_very_conservative|full|159|40.88|1.4994|-1.0000|0.0218|1.0368|15.5039|10|3.4603|577|
|J_SHORT_MODE|guard_off|full|340|45.88|1.4993|-1.0000|0.1467|1.2711|11.5070|10|49.8865|4|
|J_SHORT_MODE|guard_on_conservative|full|327|46.18|1.4993|-1.0000|0.1541|1.2863|9.5070|9|50.3930|25|
|J_SHORT_MODE|guard_on_very_conservative|full|318|46.23|1.4993|-1.0000|0.1553|1.2889|9.0000|9|49.3988|39|

## Guard ON/OFF Delta - Full Window
|Mode|Guard|Trades delta|Expectancy delta|PF delta|MaxDD delta|RiskGuard rejects|
|---|---|---:|---:|---:|---:|---:|
|C_SHORT_MODE|guard_on_conservative|-128 (-25.35%)|-0.0013|-0.0027|-0.5060|354|
|C_SHORT_MODE|guard_on_very_conservative|-346 (-68.51%)|-0.1266|-0.2376|-0.5009|577|
|J_SHORT_MODE|guard_on_conservative|-13 (-3.82%)|0.0074|0.0152|-2.0000|25|
|J_SHORT_MODE|guard_on_very_conservative|-22 (-6.47%)|0.0086|0.0178|-2.5070|39|

## Positive Year / Quarter Counts
|Mode|Guard|Positive years|Positive quarters|
|---|---|---:|---:|
|C_SHORT_MODE|guard_off|3/3|9/9|
|C_SHORT_MODE|guard_on_conservative|3/3|8/9|
|C_SHORT_MODE|guard_on_very_conservative|3/3|7/9|
|J_SHORT_MODE|guard_off|3/3|8/9|
|J_SHORT_MODE|guard_on_conservative|3/3|8/9|
|J_SHORT_MODE|guard_on_very_conservative|3/3|7/9|

## Year Runs
|Mode|Guard|Period|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|MaxLoss|TotalR|RG rejects|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|C_SHORT_MODE|guard_off|2024|284|43.31|1.4996|-1.0000|0.0826|1.1457|16.0024|11|23.4500|50|
|C_SHORT_MODE|guard_off|2025|170|51.18|1.4997|-1.0000|0.2793|1.5720|16.0048|14|47.4740|29|
|C_SHORT_MODE|guard_off|2026q1|50|44.00|1.4997|-1.0000|0.0999|1.1783|5.4976|5|4.9937|4|
|C_SHORT_MODE|guard_on_conservative|2024|201|42.29|1.4996|-1.0000|0.0570|1.0988|15.4988|9|11.4660|205|
|C_SHORT_MODE|guard_on_conservative|2025|137|50.36|1.4997|-1.0000|0.2589|1.5217|11.5031|10|35.4759|118|
|C_SHORT_MODE|guard_on_conservative|2026q1|38|50.00|1.4999|-1.0000|0.2500|1.4999|4.0000|4|9.4984|31|
|C_SHORT_MODE|guard_on_very_conservative|2024|159|40.88|1.4994|-1.0000|0.0218|1.0368|15.5039|10|3.4603|247|
|C_SHORT_MODE|guard_on_very_conservative|2025|130|50.77|1.4997|-1.0000|0.2691|1.5465|11.5014|7|34.9776|126|
|C_SHORT_MODE|guard_on_very_conservative|2026q1|38|50.00|1.4999|-1.0000|0.2500|1.4999|4.0000|4|9.4984|31|
|J_SHORT_MODE|guard_off|2024|191|42.41|1.4992|-1.0000|0.0599|1.1039|11.5070|8|11.4316|2|
|J_SHORT_MODE|guard_off|2025|117|50.43|1.4995|-1.0000|0.2604|1.5254|10.0000|10|30.4707|2|
|J_SHORT_MODE|guard_off|2026q1|31|51.61|1.4990|-1.0000|0.2898|1.5989|4.0046|4|8.9842|0|
|J_SHORT_MODE|guard_on_conservative|2024|181|41.99|1.4992|-1.0000|0.0494|1.0851|9.5070|6|8.9381|18|
|J_SHORT_MODE|guard_on_conservative|2025|115|51.30|1.4995|-1.0000|0.2824|1.5798|9.0000|9|32.4707|5|
|J_SHORT_MODE|guard_on_conservative|2026q1|30|53.33|1.4990|-1.0000|0.3328|1.7132|4.0000|4|9.9842|2|
|J_SHORT_MODE|guard_on_very_conservative|2024|172|41.86|1.4992|-1.0000|0.0462|1.0794|8.0064|8|7.9405|29|
|J_SHORT_MODE|guard_on_very_conservative|2025|115|51.30|1.4996|-1.0000|0.2824|1.5799|9.0000|9|32.4741|8|
|J_SHORT_MODE|guard_on_very_conservative|2026q1|30|53.33|1.4990|-1.0000|0.3328|1.7132|4.0000|4|9.9842|2|

## Quarter Runs
|Mode|Guard|Period|Trades|WinRate|AvgWinR|AvgLossR|ExpR|PF|MaxDD_R|MaxLoss|TotalR|RG rejects|
|---|---|---|---|---|---|---|---|---|---|---|---|---|
|C_SHORT_MODE|guard_off|2024q1|81|46.91|1.4995|-1.0000|0.1726|1.3251|11.5065|6|13.9801|17|
|C_SHORT_MODE|guard_off|2024q2|100|42.00|1.4994|-1.0000|0.0498|1.0858|16.0024|11|4.9751|21|
|C_SHORT_MODE|guard_off|2024q3|27|44.44|1.4994|-1.0000|0.1108|1.1995|3.5000|3|2.9925|2|
|C_SHORT_MODE|guard_off|2024q4|76|40.79|1.5001|-1.0000|0.0198|1.0334|10.4914|7|1.5024|10|
|C_SHORT_MODE|guard_off|2025q1|33|57.58|1.4993|-1.0000|0.4390|2.0348|5.5000|4|14.4871|3|
|C_SHORT_MODE|guard_off|2025q2|37|62.16|1.4999|-1.0000|0.5540|2.4641|6.0000|6|20.4969|15|
|C_SHORT_MODE|guard_off|2025q3|45|48.89|1.4994|-1.0000|0.2219|1.4342|6.0000|6|9.9865|9|
|C_SHORT_MODE|guard_off|2025q4|55|41.82|1.5002|-1.0000|0.0455|1.0782|16.0000|14|2.5036|2|
|C_SHORT_MODE|guard_off|2026q1-quarter|50|44.00|1.4997|-1.0000|0.0999|1.1783|5.4976|5|4.9937|4|
|C_SHORT_MODE|guard_on_conservative|2024q1|62|48.39|1.4993|-1.0000|0.2094|1.4056|7.0065|5|12.9801|57|
|C_SHORT_MODE|guard_on_conservative|2024q2|62|37.10|1.4991|-1.0000|-0.0729|0.8841|10.5024|9|-4.5206|84|
|C_SHORT_MODE|guard_on_conservative|2024q3|22|40.91|1.4998|-1.0000|0.0226|1.0383|4.5000|4|0.4978|13|
|C_SHORT_MODE|guard_on_conservative|2024q4|55|41.82|1.5004|-1.0000|0.0456|1.0784|7.4942|5|2.5087|51|
|C_SHORT_MODE|guard_on_conservative|2025q1|26|61.54|1.4990|-1.0000|0.5378|2.3983|5.0000|5|13.9833|22|
|C_SHORT_MODE|guard_on_conservative|2025q2|27|59.26|1.4994|-1.0000|0.4812|2.1810|4.0000|4|12.9912|34|
|C_SHORT_MODE|guard_on_conservative|2025q3|38|44.74|1.4999|-1.0000|0.1184|1.2142|6.0034|6|4.4979|32|
|C_SHORT_MODE|guard_on_conservative|2025q4|46|43.48|1.5002|-1.0000|0.0870|1.1540|11.0000|10|4.0036|30|
|C_SHORT_MODE|guard_on_conservative|2026q1-quarter|38|50.00|1.4999|-1.0000|0.2500|1.4999|4.0000|4|9.4984|31|
|C_SHORT_MODE|guard_on_very_conservative|2024q1|59|49.15|1.4993|-1.0000|0.2285|1.4493|6.5065|5|13.4801|60|
|C_SHORT_MODE|guard_on_very_conservative|2024q2|57|36.84|1.4991|-1.0000|-0.0793|0.8745|11.5028|10|-4.5182|89|
|C_SHORT_MODE|guard_on_very_conservative|2024q3|22|40.91|1.4998|-1.0000|0.0226|1.0383|4.5000|4|0.4978|13|
|C_SHORT_MODE|guard_on_very_conservative|2024q4|50|40.00|1.4998|-1.0000|-0.0001|0.9999|8.9994|7|-0.0039|56|
|C_SHORT_MODE|guard_on_very_conservative|2025q1|26|61.54|1.4990|-1.0000|0.5378|2.3983|5.0000|5|13.9833|22|
|C_SHORT_MODE|guard_on_very_conservative|2025q2|27|59.26|1.4994|-1.0000|0.4812|2.1810|4.0000|4|12.9912|34|
|C_SHORT_MODE|guard_on_very_conservative|2025q3|36|44.44|1.5000|-1.0000|0.1111|1.2000|6.5034|6|3.9996|34|
|C_SHORT_MODE|guard_on_very_conservative|2025q4|41|43.90|1.5002|-1.0000|0.0976|1.1741|11.0000|7|4.0036|36|
|C_SHORT_MODE|guard_on_very_conservative|2026q1-quarter|38|50.00|1.4999|-1.0000|0.2500|1.4999|4.0000|4|9.4984|31|
|J_SHORT_MODE|guard_off|2024q1|57|47.37|1.4986|-1.0000|0.1835|1.3487|7.0000|5|10.4617|2|
|J_SHORT_MODE|guard_off|2024q2|62|38.71|1.4988|-1.0000|-0.0327|0.9466|11.5070|8|-2.0298|0|
|J_SHORT_MODE|guard_off|2024q3|22|40.91|1.4998|-1.0000|0.0226|1.0383|4.0000|4|0.4978|0|
|J_SHORT_MODE|guard_off|2024q4|50|42.00|1.5001|-1.0000|0.0500|1.0863|5.0000|5|2.5019|0|
|J_SHORT_MODE|guard_off|2025q1|24|58.33|1.4992|-1.0000|0.4579|2.0989|5.0000|5|10.9886|0|
|J_SHORT_MODE|guard_off|2025q2|25|56.00|1.4994|-1.0000|0.3996|1.9083|5.0000|5|9.9911|2|
|J_SHORT_MODE|guard_off|2025q3|28|46.43|1.4995|-1.0000|0.1605|1.2996|5.0000|5|4.4933|0|
|J_SHORT_MODE|guard_off|2025q4|40|45.00|1.4999|-1.0000|0.1249|1.2272|10.0000|10|4.9977|0|
|J_SHORT_MODE|guard_off|2026q1-quarter|31|51.61|1.4990|-1.0000|0.2898|1.5989|4.0046|4|8.9842|0|
|J_SHORT_MODE|guard_on_conservative|2024q1|54|46.30|1.4985|-1.0000|0.1567|1.2918|7.0000|5|8.4617|6|
|J_SHORT_MODE|guard_on_conservative|2024q2|57|38.60|1.4989|-1.0000|-0.0355|0.9422|9.5070|6|-2.0247|7|
|J_SHORT_MODE|guard_on_conservative|2024q3|21|42.86|1.4998|-1.0000|0.0713|1.1248|4.0000|4|1.4978|2|
|J_SHORT_MODE|guard_on_conservative|2024q4|49|40.82|1.5002|-1.0000|0.0205|1.0346|5.0000|5|1.0032|3|
|J_SHORT_MODE|guard_on_conservative|2025q1|24|58.33|1.4992|-1.0000|0.4579|2.0989|5.0000|5|10.9886|0|
|J_SHORT_MODE|guard_on_conservative|2025q2|24|58.33|1.4994|-1.0000|0.4580|2.0991|4.0000|4|10.9911|4|
|J_SHORT_MODE|guard_on_conservative|2025q3|28|46.43|1.4995|-1.0000|0.1605|1.2996|5.0000|5|4.4933|0|
|J_SHORT_MODE|guard_on_conservative|2025q4|39|46.15|1.4999|-1.0000|0.1538|1.2856|9.0000|9|5.9977|1|
|J_SHORT_MODE|guard_on_conservative|2026q1-quarter|30|53.33|1.4990|-1.0000|0.3328|1.7132|4.0000|4|9.9842|2|
|J_SHORT_MODE|guard_on_very_conservative|2024q1|54|46.30|1.4985|-1.0000|0.1567|1.2918|7.0000|5|8.4617|6|
|J_SHORT_MODE|guard_on_very_conservative|2024q2|51|39.22|1.4989|-1.0000|-0.0200|0.9670|8.0046|8|-1.0223|13|
|J_SHORT_MODE|guard_on_very_conservative|2024q3|21|42.86|1.4998|-1.0000|0.0713|1.1248|4.0000|4|1.4978|2|
|J_SHORT_MODE|guard_on_very_conservative|2024q4|46|39.13|1.5002|-1.0000|-0.0217|0.9644|7.0000|7|-0.9968|8|
|J_SHORT_MODE|guard_on_very_conservative|2025q1|24|58.33|1.4992|-1.0000|0.4579|2.0989|5.0000|5|10.9886|0|
|J_SHORT_MODE|guard_on_very_conservative|2025q2|24|58.33|1.4994|-1.0000|0.4580|2.0991|4.0000|4|10.9911|4|
|J_SHORT_MODE|guard_on_very_conservative|2025q3|28|46.43|1.4997|-1.0000|0.1606|1.2998|5.0000|5|4.4967|3|
|J_SHORT_MODE|guard_on_very_conservative|2025q4|39|46.15|1.4999|-1.0000|0.1538|1.2856|9.0000|9|5.9977|1|
|J_SHORT_MODE|guard_on_very_conservative|2026q1-quarter|30|53.33|1.4990|-1.0000|0.3328|1.7132|4.0000|4|9.9842|2|

## Monthly ProfitR - Full Runs
|Mode|Guard|Month|ProfitR|
|---|---|---|---:|
|C_SHORT_MODE|guard_off|2024-01|-0.9996|
|C_SHORT_MODE|guard_off|2024-02|9.5037|
|C_SHORT_MODE|guard_off|2024-03|5.4760|
|C_SHORT_MODE|guard_off|2024-04|-12.0062|
|C_SHORT_MODE|guard_off|2024-05|15.9907|
|C_SHORT_MODE|guard_off|2024-06|0.9905|
|C_SHORT_MODE|guard_off|2024-07|1.9972|
|C_SHORT_MODE|guard_off|2024-08|2.9986|
|C_SHORT_MODE|guard_off|2024-09|-2.0033|
|C_SHORT_MODE|guard_off|2024-10|-7.4914|
|C_SHORT_MODE|guard_off|2024-11|7.9995|
|C_SHORT_MODE|guard_off|2024-12|0.9943|
|C_SHORT_MODE|guard_off|2025-01|11.4872|
|C_SHORT_MODE|guard_off|2025-03|2.9999|
|C_SHORT_MODE|guard_off|2025-04|1.4961|
|C_SHORT_MODE|guard_off|2025-05|14.5000|
|C_SHORT_MODE|guard_off|2025-06|4.5008|
|C_SHORT_MODE|guard_off|2025-07|-0.5055|
|C_SHORT_MODE|guard_off|2025-08|10.9882|
|C_SHORT_MODE|guard_off|2025-09|-0.4962|
|C_SHORT_MODE|guard_off|2025-10|-9.5000|
|C_SHORT_MODE|guard_off|2025-11|7.5052|
|C_SHORT_MODE|guard_off|2025-12|3.4984|
|C_SHORT_MODE|guard_off|2026-01|1.5002|
|C_SHORT_MODE|guard_off|2026-02|2.4987|
|C_SHORT_MODE|guard_off|2026-03|0.9948|
|C_SHORT_MODE|guard_on_conservative|2024-01|1.5004|
|C_SHORT_MODE|guard_on_conservative|2024-02|5.5037|
|C_SHORT_MODE|guard_on_conservative|2024-03|5.9760|
|C_SHORT_MODE|guard_on_conservative|2024-04|-8.0062|
|C_SHORT_MODE|guard_on_conservative|2024-05|4.4879|
|C_SHORT_MODE|guard_on_conservative|2024-06|-1.0023|
|C_SHORT_MODE|guard_on_conservative|2024-07|0.0000|
|C_SHORT_MODE|guard_on_conservative|2024-08|2.9986|
|C_SHORT_MODE|guard_on_conservative|2024-09|-2.5007|
|C_SHORT_MODE|guard_on_conservative|2024-10|-4.4868|
|C_SHORT_MODE|guard_on_conservative|2024-11|5.5013|
|C_SHORT_MODE|guard_on_conservative|2024-12|1.4943|
|C_SHORT_MODE|guard_on_conservative|2025-01|10.9834|
|C_SHORT_MODE|guard_on_conservative|2025-03|2.9999|
|C_SHORT_MODE|guard_on_conservative|2025-04|1.4961|
|C_SHORT_MODE|guard_on_conservative|2025-05|7.0000|
|C_SHORT_MODE|guard_on_conservative|2025-06|4.4950|
|C_SHORT_MODE|guard_on_conservative|2025-07|-2.5022|
|C_SHORT_MODE|guard_on_conservative|2025-08|7.9946|
|C_SHORT_MODE|guard_on_conservative|2025-09|-0.9945|
|C_SHORT_MODE|guard_on_conservative|2025-10|-6.5000|
|C_SHORT_MODE|guard_on_conservative|2025-11|6.5052|
|C_SHORT_MODE|guard_on_conservative|2025-12|2.9984|
|C_SHORT_MODE|guard_on_conservative|2026-01|2.0002|
|C_SHORT_MODE|guard_on_conservative|2026-02|1.9969|
|C_SHORT_MODE|guard_on_conservative|2026-03|5.5014|
|C_SHORT_MODE|guard_on_very_conservative|2024-01|2.0004|
|C_SHORT_MODE|guard_on_very_conservative|2024-02|5.5037|
|C_SHORT_MODE|guard_on_very_conservative|2024-03|5.9760|
|C_SHORT_MODE|guard_on_very_conservative|2024-04|-6.5038|
|C_SHORT_MODE|guard_on_very_conservative|2024-05|2.9879|
|C_SHORT_MODE|guard_on_very_conservative|2024-06|-1.0023|
|C_SHORT_MODE|guard_on_very_conservative|2024-07|0.0000|
|C_SHORT_MODE|guard_on_very_conservative|2024-08|2.9986|
|C_SHORT_MODE|guard_on_very_conservative|2024-09|-2.5007|
|C_SHORT_MODE|guard_on_very_conservative|2024-10|-5.9994|
|J_SHORT_MODE|guard_off|2024-01|0.0069|
|J_SHORT_MODE|guard_off|2024-02|6.4850|
|J_SHORT_MODE|guard_off|2024-03|3.9698|
|J_SHORT_MODE|guard_off|2024-04|-9.0062|
|J_SHORT_MODE|guard_off|2024-05|5.9879|
|J_SHORT_MODE|guard_off|2024-06|0.9884|
|J_SHORT_MODE|guard_off|2024-07|-1.0000|
|J_SHORT_MODE|guard_off|2024-08|2.9986|
|J_SHORT_MODE|guard_off|2024-09|-1.5007|
|J_SHORT_MODE|guard_off|2024-10|1.5031|
|J_SHORT_MODE|guard_off|2024-11|5.4970|
|J_SHORT_MODE|guard_off|2024-12|-4.4982|
|J_SHORT_MODE|guard_off|2025-01|7.9887|
|J_SHORT_MODE|guard_off|2025-03|2.9999|
|J_SHORT_MODE|guard_off|2025-04|1.4961|
|J_SHORT_MODE|guard_off|2025-05|7.0000|
|J_SHORT_MODE|guard_off|2025-06|1.4950|
|J_SHORT_MODE|guard_off|2025-07|0.9978|
|J_SHORT_MODE|guard_off|2025-08|4.9954|
|J_SHORT_MODE|guard_off|2025-09|-1.4999|
|J_SHORT_MODE|guard_off|2025-10|-4.5000|
|J_SHORT_MODE|guard_off|2025-11|4.4993|
|J_SHORT_MODE|guard_off|2025-12|3.9984|
|J_SHORT_MODE|guard_off|2026-01|3.9923|
|J_SHORT_MODE|guard_off|2026-02|3.9969|
|J_SHORT_MODE|guard_off|2026-03|0.9950|
|J_SHORT_MODE|guard_on_conservative|2024-01|0.0069|
|J_SHORT_MODE|guard_on_conservative|2024-02|4.4850|
|J_SHORT_MODE|guard_on_conservative|2024-03|3.9698|
|J_SHORT_MODE|guard_on_conservative|2024-04|-7.0062|
|J_SHORT_MODE|guard_on_conservative|2024-05|5.9879|
|J_SHORT_MODE|guard_on_conservative|2024-06|-1.0064|
|J_SHORT_MODE|guard_on_conservative|2024-07|0.0000|
|J_SHORT_MODE|guard_on_conservative|2024-08|2.9986|
|J_SHORT_MODE|guard_on_conservative|2024-09|-1.5007|
|J_SHORT_MODE|guard_on_conservative|2024-10|0.0044|
|J_SHORT_MODE|guard_on_conservative|2024-11|5.4970|
|J_SHORT_MODE|guard_on_conservative|2024-12|-4.4982|
|J_SHORT_MODE|guard_on_conservative|2025-01|7.9887|
|J_SHORT_MODE|guard_on_conservative|2025-03|2.9999|
|J_SHORT_MODE|guard_on_conservative|2025-04|1.4961|
|J_SHORT_MODE|guard_on_conservative|2025-05|7.0000|
|J_SHORT_MODE|guard_on_conservative|2025-06|2.4950|
|J_SHORT_MODE|guard_on_conservative|2025-07|0.9978|
|J_SHORT_MODE|guard_on_conservative|2025-08|4.9954|
|J_SHORT_MODE|guard_on_conservative|2025-09|-1.4999|
|J_SHORT_MODE|guard_on_conservative|2025-10|-3.5000|
|J_SHORT_MODE|guard_on_conservative|2025-11|4.4993|
|J_SHORT_MODE|guard_on_conservative|2025-12|3.9984|
|J_SHORT_MODE|guard_on_conservative|2026-01|3.9923|
|J_SHORT_MODE|guard_on_conservative|2026-02|3.9969|
|J_SHORT_MODE|guard_on_conservative|2026-03|1.9950|
|J_SHORT_MODE|guard_on_very_conservative|2024-01|0.0069|
|J_SHORT_MODE|guard_on_very_conservative|2024-02|4.4850|
|J_SHORT_MODE|guard_on_very_conservative|2024-03|3.9698|
|J_SHORT_MODE|guard_on_very_conservative|2024-04|-6.0038|
|J_SHORT_MODE|guard_on_very_conservative|2024-05|5.9879|
|J_SHORT_MODE|guard_on_very_conservative|2024-06|-1.0064|
|J_SHORT_MODE|guard_on_very_conservative|2024-07|0.0000|
|J_SHORT_MODE|guard_on_very_conservative|2024-08|2.9986|
|J_SHORT_MODE|guard_on_very_conservative|2024-09|-1.5007|
|J_SHORT_MODE|guard_on_very_conservative|2024-10|0.0044|
|J_SHORT_MODE|guard_on_very_conservative|2024-11|5.4970|
|J_SHORT_MODE|guard_on_very_conservative|2024-12|-6.4982|
|J_SHORT_MODE|guard_on_very_conservative|2025-01|7.9887|
|J_SHORT_MODE|guard_on_very_conservative|2025-03|2.9999|
|J_SHORT_MODE|guard_on_very_conservative|2025-04|1.4961|
|J_SHORT_MODE|guard_on_very_conservative|2025-05|7.0000|
|J_SHORT_MODE|guard_on_very_conservative|2025-06|2.4950|
|J_SHORT_MODE|guard_on_very_conservative|2025-07|0.9978|
|J_SHORT_MODE|guard_on_very_conservative|2025-08|4.9954|
|J_SHORT_MODE|guard_on_very_conservative|2025-09|-1.4965|
|J_SHORT_MODE|guard_on_very_conservative|2025-10|-3.5000|
|J_SHORT_MODE|guard_on_very_conservative|2025-11|4.4993|
|J_SHORT_MODE|guard_on_very_conservative|2025-12|3.9984|
|J_SHORT_MODE|guard_on_very_conservative|2026-01|3.9923|
|J_SHORT_MODE|guard_on_very_conservative|2026-02|3.9969|
|J_SHORT_MODE|guard_on_very_conservative|2026-03|1.9950|

## Full Run RejectReason Counts
### C_SHORT_MODE / guard_off
|RejectReason|Count|
|---|---:|
|direction_filter_failed|4141|
|trend_alignment_filter_failed|2274|
|pattern_adx_bucket_filter_failed|1032|
|fibo_filter_failed|184|
|max_positions_blocked|65|
|spread_too_wide|46|
|consecutive_loss_blocked|18|
|rr_too_low|1|

RiskGuard rejected candidates: 83.
|RiskGuard RejectReason|Count|
|---|---:|
|max_positions_blocked|65|
|consecutive_loss_blocked|18|

### C_SHORT_MODE / guard_on_conservative
|RejectReason|Count|
|---|---:|
|direction_filter_failed|4141|
|trend_alignment_filter_failed|2274|
|pattern_adx_bucket_filter_failed|1032|
|total_open_risk_blocked|295|
|fibo_filter_failed|184|
|daily_loss_r_blocked|46|
|spread_too_wide|46|
|weekly_loss_r_blocked|5|
|monthly_loss_r_blocked|4|
|consecutive_loss_blocked|3|
|min_bars_between_entries_blocked|1|
|rr_too_low|1|

RiskGuard rejected candidates: 354.
|RiskGuard RejectReason|Count|
|---|---:|
|total_open_risk_blocked|295|
|daily_loss_r_blocked|46|
|weekly_loss_r_blocked|5|
|monthly_loss_r_blocked|4|
|consecutive_loss_blocked|3|
|min_bars_between_entries_blocked|1|

### C_SHORT_MODE / guard_on_very_conservative
|RejectReason|Count|
|---|---:|
|direction_filter_failed|4141|
|trend_alignment_filter_failed|2274|
|pattern_adx_bucket_filter_failed|1032|
|max_drawdown_r_blocked|394|
|fibo_filter_failed|184|
|total_open_risk_blocked|134|
|spread_too_wide|46|
|daily_loss_r_blocked|26|
|weekly_loss_r_blocked|20|
|consecutive_loss_blocked|3|
|rr_too_low|1|

RiskGuard rejected candidates: 577.
|RiskGuard RejectReason|Count|
|---|---:|
|max_drawdown_r_blocked|394|
|total_open_risk_blocked|134|
|daily_loss_r_blocked|26|
|weekly_loss_r_blocked|20|
|consecutive_loss_blocked|3|

### J_SHORT_MODE / guard_off
|RejectReason|Count|
|---|---:|
|direction_filter_failed|4141|
|trend_alignment_filter_failed|2274|
|pattern_adx_bucket_filter_failed|1032|
|break_candle_strength_filter_failed|231|
|fibo_filter_failed|184|
|entry_open_count_filter_failed|183|
|spread_too_wide|21|
|consecutive_loss_blocked|4|
|rr_too_low|1|

RiskGuard rejected candidates: 4.
|RiskGuard RejectReason|Count|
|---|---:|
|consecutive_loss_blocked|4|

### J_SHORT_MODE / guard_on_conservative
|RejectReason|Count|
|---|---:|
|direction_filter_failed|4141|
|trend_alignment_filter_failed|2274|
|pattern_adx_bucket_filter_failed|1032|
|break_candle_strength_filter_failed|231|
|fibo_filter_failed|184|
|entry_open_count_filter_failed|178|
|daily_loss_r_blocked|22|
|spread_too_wide|21|
|consecutive_loss_blocked|2|
|rr_too_low|1|
|weekly_loss_r_blocked|1|

RiskGuard rejected candidates: 25.
|RiskGuard RejectReason|Count|
|---|---:|
|daily_loss_r_blocked|22|
|consecutive_loss_blocked|2|
|weekly_loss_r_blocked|1|

### J_SHORT_MODE / guard_on_very_conservative
|RejectReason|Count|
|---|---:|
|direction_filter_failed|4141|
|trend_alignment_filter_failed|2274|
|pattern_adx_bucket_filter_failed|1032|
|break_candle_strength_filter_failed|231|
|fibo_filter_failed|184|
|entry_open_count_filter_failed|173|
|daily_loss_r_blocked|22|
|spread_too_wide|21|
|weekly_loss_r_blocked|13|
|consecutive_loss_blocked|2|
|monthly_loss_r_blocked|2|
|rr_too_low|1|

RiskGuard rejected candidates: 39.
|RiskGuard RejectReason|Count|
|---|---:|
|daily_loss_r_blocked|22|
|weekly_loss_r_blocked|13|
|consecutive_loss_blocked|2|
|monthly_loss_r_blocked|2|

## Interpretation
- `J_SHORT_MODE` is the cleaner demo candidate. Guard ON reduced drawdown and kept expectancy: full window `guard_off` 340 trades / +0.1467R / PF 1.2711 / MaxDD 11.5070R; `guard_on_very_conservative` 318 trades / +0.1553R / PF 1.2889 / MaxDD 9.0000R.
- `C_SHORT_MODE` remains valid as a broader reference candidate, but the very conservative full-window run stopped too much after 2024 drawdown: 505 trades became 159 and expectancy fell to +0.0218R. C is less suitable as the first demo setting under the strict guard.
- Risk guards changed opportunity flow as intended; skipped candidates are explicitly explainable through `min_bars_between_entries_blocked`, `strategy01b_one_position_blocked`, `total_open_risk_blocked`, and period loss/drawdown blockers where triggered.
