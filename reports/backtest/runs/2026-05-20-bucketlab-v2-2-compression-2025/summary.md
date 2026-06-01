# ExpectedValue_LongOnly_BucketLab v2.2 Compression Expansion 2025

## v2.2 Design

v2.2 keeps `DISCOUNT_RECLAIM_PULLBACK_LONG` and `EXPANSION_PULLBACK_CONTINUATION_LONG` intact and turns `MICRO_BREAKOUT_ACCEPTANCE_LONG` off as a trading bucket. Micro breakout is retained only as near-miss diagnostics. The new research bucket is `VOLATILITY_COMPRESSION_EXPANSION_LONG` / `COMPRESSION_EXPANSION`.

The compression bucket targets M1 short-range compression followed by upside expansion while keeping Spread/ATR unchanged, discount reclaim guarded, and ATR ratio capped below or equal to `1.80`. For compression trades, the existing event columns are reused as follows: `recent_range_atr` = compression range/ATR, `body_atr` = M1 expansion body/ATR, and `breakout_acceptance_atr` = compression breakout/ATR.

## Compile

`reports/compile/ExpectedValue_LongOnly_BucketLab_v2_2_compile.log`: 0 errors, 0 warnings.

## 2025 Summary

|metric|value|
|---|---|
|closed_trades|57|
|trades_per_day|0.156|
|wins/losses|31/26|
|win_rate|54.39%|
|expectancy_r|0.1677|
|profit_factor|1.4218|
|total_r|9.5568|
|net_money|11.85|
|max_dd_percent|10.80%|
|max_consecutive_losses|4|
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
|COMPRESSION_EXPANSION|3|33.33%|-0.5611|0.1723|-1.6833|
|DISCOUNT_RECLAIM|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|50|54.00%|0.1752|1.4463|8.7580|

## Monthly Analysis

|month|trades|expectancy_r|pf|net_r|net_money|
|---|---|---|---|---|---|
|202501|1|1.3500|0.0000|1.3500|1.08|
|202502|9|-0.3766|0.4436|-3.3897|-4.30|
|202503|5|-0.2763|0.5552|-1.3816|-1.44|
|202504|19|0.0310|1.0675|0.5885|1.63|
|202505|9|0.8523|16.0759|7.6705|9.01|
|202506|3|0.8547|22.2661|2.5640|2.38|
|202507|5|-0.0253|0.9392|-0.1264|-0.13|
|202508|2|0.7922|0.0000|1.5844|2.47|
|202509|2|0.1792|1.3541|0.3583|1.01|
|202510|2|0.1695|1.3356|0.3389|0.14|

## Compression Metrics

The following tables are filtered to `COMPRESSION_EXPANSION` trades only.

|compression_range_atr|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-0.8|1|-1.0253|0.0000|0.00%|
|0.8-1.2|2|-0.3290|0.3475|50.00%|

|compression_body_atr|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.12-0.30|2|-0.3290|0.3475|50.00%|
|0.30-0.75|1|-1.0253|0.0000|0.00%|

|compression_breakout_atr|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.03-0.10|2|-1.0169|0.0000|0.00%|
|0.10-0.25|1|0.3504|inf|100.00%|

## Range Position

|range_position|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.25-0.45|4|0.6205|3.4822|75.00%|
|0.55-0.75|9|0.4487|2.3211|66.67%|
|0.75-0.92|32|-0.0290|0.9377|46.88%|
|0.92-1.0|12|0.3304|2.0748|58.33%|

## Risk Distance

|risk_pips|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-12|3|-1.0290|0.0000|0.00%|
|12-15|21|0.5069|3.0004|66.67%|
|15-18|11|-0.2763|0.5337|36.36%|
|18-22|10|0.2617|1.6256|50.00%|
|22-28|12|0.2018|1.6826|66.67%|

## Pressure

|up_pressure|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.52-0.60|18|-0.0296|0.9421|50.00%|
|0.60-0.65|12|0.4282|2.6419|75.00%|
|0.65-0.75|19|0.1122|1.2932|42.11%|
|0.75-1.0|8|0.3524|1.9282|62.50%|

|down_pressure|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-0.25|8|0.3524|1.9282|62.50%|
|0.25-0.35|19|0.1122|1.2932|42.11%|
|0.35-0.40|12|0.4282|2.6419|75.00%|
|0.40-0.48|18|-0.0296|0.9421|50.00%|

## ATR Ratio

|atr_ratio|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.85-1.1|4|0.5208|3.0659|75.00%|
|1.1-1.2|1|-1.0000|0.0000|0.00%|
|1.2-1.45|24|0.0945|1.2097|54.17%|
|1.45-1.6|17|0.2818|1.8780|58.82%|
|1.6-1.8|11|0.1288|1.3233|45.45%|

## Exit Reason

|exit|trades|expectancy_r|pf|winrate|total_r|
|---|---|---|---|---|---|
|SL|21|-1.0238|0.0000|0.00%|-21.4991|
|TIMEOUT|15|0.1648|3.1369|66.67%|2.4717|
|TP|21|1.3612|inf|100.00%|28.5842|

## Micro Near-Miss Diagnostics

|bucket_type|event|reason|count|
|---|---|---|---|
|MICRO_BREAKOUT_ACCEPTANCE|candidate_score|micro_breakout_diagnostic_only|3|
|MICRO_BREAKOUT_ACCEPTANCE|candidate_score|micro_wide_risk_requires_extra_confirmation|1|
|MICRO_BREAKOUT_ACCEPTANCE|candidate_score|spread_to_risk_too_high|6|
|MICRO_BREAKOUT_ACCEPTANCE|micro_near_miss_exit|VIRTUAL_SL_FIRST|7|
|MICRO_BREAKOUT_ACCEPTANCE|micro_near_miss_exit|VIRTUAL_TP_FIRST|3|

## Interpretation

v2.2 stayed profitable and non-ruinous in 2025, but it did not solve the frequency target. Closed trades were `57`, still below the `>=80` research gate. `COMPRESSION_EXPANSION` produced only `3` closed trades and was negative as a standalone bucket, so it should be considered OFF or redesigned before any OOS check.

Decision: do not run 2026 Jan-Apr OOS. Continue 2025-only research. The current bottleneck is not Spread/ATR but candidate generation plus `max_open_positions` blocking many expansion signals. Any next study should explicitly decide whether to keep one-position-only execution or test a capped two-position research preset under total-risk limits.
