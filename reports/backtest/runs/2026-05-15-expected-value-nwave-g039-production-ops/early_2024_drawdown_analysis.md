# Early 2024 Drawdown Analysis

Purpose: inspect weak 2024 behavior for risk context. This is not an optimization target.

**2024 Monthly Raw Live-Path**

|Period|Trades|WinRate%|ExpectancyR|PF|MaxDD_R|TotalR|
|---|---|---|---|---|---|---|
|2024-01|19|36.8421|-0.1375|0.7944|10.5786|-2.6127|
|2024-02|22|45.4545|0.1251|1.2253|3.5608|2.7519|
|2024-03|9|55.5556|0.3581|1.8058|2.0000|3.2232|
|2024-04|20|25.0000|-0.4080|0.4605|10.7937|-8.1609|
|2024-05|15|26.6667|-0.3178|0.5780|8.1287|-4.7663|
|2024-06|15|40.0000|-0.0103|0.9834|3.0308|-0.1540|
|2024-07|9|33.3333|0.1649|1.2462|3.0228|1.4843|
|2024-08|2|100.0000|1.5005|inf|0.0000|3.0009|
|2024-09|11|36.3636|-0.0924|0.8587|4.6311|-1.0162|
|2024-10|24|29.1667|-0.3410|0.5491|8.6986|-8.1846|
|2024-11|12|41.6667|0.0188|1.0310|3.5483|0.2255|
|2024-12|8|37.5000|-0.0788|0.8778|4.1562|-0.6302|

Worst raw 2024 deal-level drawdown row:

|ExitTime|RealizedR|DrawdownR|DrawdownPercent|ExitReason|SetupId|
|---|---|---|---|---|---|
|2024.11.14 15:30:09|-1.0000|23.6686|5.5814|stop_loss|SHORT_1731595800_155.877|

Conclusion: including 2024 reduces raw full-window expectancy to 0.0099R and raises raw MaxDD_R to 23.6686R. DD% Soft/Hard/Emergency stops did not fire in the production-guard reference run, but 2024 remains the main reason g039 is controlled-demo only.
