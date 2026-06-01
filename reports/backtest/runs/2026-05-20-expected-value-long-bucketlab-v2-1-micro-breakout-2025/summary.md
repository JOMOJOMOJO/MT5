# ExpectedValue_LongOnly_BucketLab v2.1 Micro Breakout 2025

## v2.1 Design

v2.1 keeps the v2 guarded `DISCOUNT_RECLAIM_PULLBACK_LONG` and `EXPANSION_PULLBACK_CONTINUATION_LONG` logic intact and adds a third bucket, `MICRO_BREAKOUT_ACCEPTANCE_LONG` / `MICRO_BREAKOUT_ACCEPTANCE`.

The new bucket is not a Spread/ATR relaxation. It requires M1 breakout acceptance, relative range context, pressure confirmation, ATR regime control, R-efficiency checks, and a micro-specific breakout-structure SL. ATR ratio above `1.80` remains disallowed for the bucket.

## Compile

`reports/compile/ExpectedValue_LongOnly_BucketLab_v2_1_compile.log`: 0 errors, 0 warnings.

## 2025 Summary

|metric|value|
|---|---|
|closed_trades|57|
|trades_per_day|0.156|
|wins/losses|31/26|
|win_rate|54.39%|
|expectancy_r|0.1855|
|profit_factor|1.4674|
|total_r|10.5735|
|net_money|12.83|
|max_dd_percent|10.30%|
|max_consecutive_losses|5|
|stop_condition_events|0|

## Gate Check

|criterion|pass|
|---|---|
|closed_trades>=80|FAIL|
|expectancy_r>0|PASS|
|expectancy_r>=0.10 preferred|PASS|
|pf>1.05|PASS|
|pf>=1.20 preferred|PASS|
|max_dd<25|PASS|
|max_losses<=6|PASS|
|no_stop_condition|PASS|

## Bucket Analysis

|bucket_type|trades|winrate|expectancy_r|pf|total_r|
|---|---|---|---|---|---|
|DISCOUNT_RECLAIM|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|50|54.00%|0.1752|1.4463|8.7580|
|MICRO_BREAKOUT_ACCEPTANCE|3|33.33%|-0.2222|0.6667|-0.6667|

## Monthly Analysis

|month|trades|expectancy_r|pf|net_r|net_money|
|---|---|---|---|---|---|
|202501|2|1.3417|0.0000|2.6833|2.16|
|202502|8|-0.2956|0.5334|-2.3644|-3.49|
|202503|4|-0.4330|0.4423|-1.7321|-1.85|
|202504|20|-0.0202|0.9585|-0.4031|1.13|
|202505|9|0.8523|16.0759|7.6705|9.01|
|202506|3|0.8547|22.2661|2.5640|2.38|
|202507|5|-0.0253|0.9392|-0.1264|-0.13|
|202508|2|0.7922|0.0000|1.5844|2.47|
|202509|2|0.1792|1.3541|0.3583|1.01|
|202510|2|0.1695|1.3356|0.3389|0.14|

## Range Position

|range_position|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.25-0.45|4|0.6205|3.4822|75.00%|
|0.55-0.75|11|0.3997|2.0906|63.64%|
|0.75-0.92|30|-0.0090|0.9805|46.67%|
|0.92-1.0|12|0.3304|2.0748|58.33%|

## Risk Distance Pips

|risk_pips|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-12|3|-1.0206|0.0000|0.00%|
|12-15|23|0.4773|2.7367|65.22%|
|15-18|9|-0.2646|0.5678|33.33%|
|18-22|10|0.2617|1.6256|50.00%|
|22-28|12|0.2018|1.6826|66.67%|

## Pressure

|up_pressure|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.52-0.60|18|-0.0296|0.9421|50.00%|
|0.60-0.65|13|0.3203|2.0145|69.23%|
|0.65-0.75|18|0.0990|1.2451|38.89%|
|0.75-1.0|8|0.6452|3.5435|75.00%|

|down_pressure|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-0.25|8|0.6452|3.5435|75.00%|
|0.25-0.35|18|0.0990|1.2451|38.89%|
|0.35-0.40|13|0.3203|2.0145|69.23%|
|0.40-0.48|18|-0.0296|0.9421|50.00%|

## ATR Ratio

|atr_ratio|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.85-1.1|2|1.3706|inf|100.00%|
|1.1-1.2|1|-1.0000|0.0000|0.00%|
|1.2-1.45|24|0.0955|1.2126|54.17%|
|1.45-1.6|18|0.2105|1.5871|55.56%|
|1.6-1.8|12|0.2292|1.6276|50.00%|

## Exit Reason

|exit|trades|expectancy_r|pf|winrate|total_r|
|---|---|---|---|---|---|
|SL|21|-1.0222|0.0000|0.00%|-21.4653|
|TIMEOUT|14|0.1515|2.8340|64.29%|2.1213|
|TP|22|1.3599|inf|100.00%|29.9175|

## SL/TP

|sl_mode|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|HYBRID|54|0.2082|1.5451|55.56%|
|M1_BREAKOUT_STRUCTURE|3|-0.2222|0.6667|33.33%|

|tp_mode|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|FIXED_R|54|0.2082|1.5451|55.56%|
|FIXED_R_MICRO|3|-0.2222|0.6667|33.33%|

## Interpretation

v2.1 remains profitable and non-ruinous in 2025, but it does not solve the frequency target. Closed trades increased only from v2 guarded `54` to `57`. The micro breakout bucket produced too few accepted trades to materially change the system and should not be promoted as-is.

Decision: do not run 2026 Jan-Apr OOS. Continue 2025-only research. The next useful step is not to loosen Spread/ATR or discount reclaim, but to either redesign micro breakout candidate generation with better near-miss diagnostics or test a different third bucket such as volatility compression expansion.
