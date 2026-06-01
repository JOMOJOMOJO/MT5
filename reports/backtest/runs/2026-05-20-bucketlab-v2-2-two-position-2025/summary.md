# ExpectedValue_LongOnly_BucketLab v2.2 Two-Position Research 2025

## Implementation

- Added capped additional-entry controls without changing the bucket entry scoring logic: second entries are allowed only for `EXPANSION_PULLBACK`, only when existing tracked positions have the same bucket type, and never on the same M5 quality bar.
- Existing anti-averaging guard remains active: a new entry is blocked while any managed long position is in floating loss.
- Preset disables `MICRO_BREAKOUT_ACCEPTANCE` and `COMPRESSION_EXPANSION` as trading buckets and keeps them out of production candidate selection.
- Preset uses `InpMaxOpenPositions=2`, `InpMaxTotalOpenRiskPercent=6.0`, `InpCooldownBars=6`, fixed-lot mode for 100 USD / 0.01 lot research.

## Compile

`reports/compile/ExpectedValue_LongOnly_BucketLab_two_position_compile.log`: 0 errors, 0 warnings.

## 2025 Summary

|metric|value|
|---|---:|
|closed_trades|69|
|trades_delta_vs_v2_2|12|
|win_rate_percent|52.1739|
|expectancy_r|0.1818|
|profit_factor|1.4386|
|total_r|12.5475|
|net_money|15.4800|
|max_dd_percent|12.0328|
|max_consecutive_losses|7|
|stop_condition_events|2|

## v2.2 Comparison

|metric|v2.2 one-position|two-position research|delta|
|---|---:|---:|---:|
|closed_trades|57|69|12|
|expectancy_r|0.1677|0.1818|0.0141|
|profit_factor|1.4218|1.4386|0.0168|
|max_dd_percent|10.80%|12.03%|1.23pp|
|max_consecutive_losses|4|7|3|

## Gate Check

|criterion|result|
|---|---|
|closed_trades > 57|PASS|
|closed_trades >= 80|FAIL|
|expectancy_r > 0|PASS|
|pf not collapsed|PASS|
|max_dd < 25%|PASS|
|max_losses <= 6|FAIL|
|no stop condition event|FAIL|

## Bucket Analysis

|bucket_type|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|DISCOUNT_RECLAIM|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|65|50.77%|0.1549|1.3646|10.0654|

## Entry Position Analysis

|entry_open_positions_after|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|1|42|57.14%|0.2733|1.7406|11.4805|
|2|27|44.44%|0.0395|1.0814|1.0671|

## Bucket x Entry Position

|bucket_position|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|DISCOUNT_RECLAIM|pos_after=1|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|pos_after=1|38|55.26%|0.2368|1.6205|8.9983|
|EXPANSION_PULLBACK|pos_after=2|27|44.44%|0.0395|1.0814|1.0671|

## Monthly Analysis

|month|trades|expectancy_r|pf|net_r|net_money|
|---|---:|---:|---:|---:|---:|
|202501|1|1.3500|0.0000|1.3500|1.08|
|202502|12|-0.1421|0.7601|-1.7053|-2.31|
|202503|6|-0.6290|0.2669|-3.7743|-3.88|
|202504|16|-0.0599|0.8785|-0.9578|0.63|
|202505|14|0.8257|8.6613|11.5594|12.09|
|202506|4|0.9781|33.4497|3.9124|4.47|
|202507|7|-0.3100|0.4739|-2.1697|-2.06|
|202508|4|0.5644|4.2657|2.2578|3.07|
|202509|3|0.5787|2.7154|1.7361|2.25|
|202510|2|0.1695|1.3356|0.3389|0.14|

## Risk Distance

|risk_pips|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0-12|4|0.00%|-0.9444|0.0000|-3.7778|
|12-15|28|64.29%|0.5048|2.6833|14.1343|
|15-18|12|25.00%|-0.4554|0.3640|-5.4650|
|18-22|12|58.33%|0.3959|2.1358|4.7506|
|22-28|13|61.54%|0.2235|1.7945|2.9054|

## Pressure

|up_pressure|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0.52-0.60|17|52.94%|0.0640|1.1325|1.0888|
|0.60-0.65|17|52.94%|0.1357|1.3274|2.3067|
|0.65-0.75|26|46.15%|0.1918|1.4834|4.9855|
|0.75-1.0|9|66.67%|0.4629|2.3755|4.1665|

|down_pressure|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0-0.25|9|66.67%|0.4629|2.3755|4.1665|
|0.25-0.35|26|46.15%|0.1918|1.4834|4.9855|
|0.35-0.40|17|52.94%|0.1357|1.3274|2.3067|
|0.40-0.48|17|52.94%|0.0640|1.1325|1.0888|

## ATR Ratio

|atr_ratio|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0.85-1.1|2|100.00%|1.3706|inf|2.7412|
|1.1-1.2|1|0.00%|-1.0000|0.0000|-1.0000|
|1.2-1.45|25|40.00%|-0.1332|0.7625|-3.3292|
|1.45-1.6|26|61.54%|0.3931|2.2453|10.2203|
|1.6-1.8|15|53.33%|0.2610|1.7275|3.9152|

## Range Position

|range_position|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0.25-0.45|4|75.00%|0.6205|3.4822|2.4822|
|0.55-0.75|9|77.78%|0.7140|4.1636|6.4260|
|0.75-0.92|39|43.59%|-0.0319|0.9339|-1.2441|
|0.92-1.0|17|52.94%|0.2873|1.7220|4.8835|

## Exit Reason

|exit_reason|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|SL|26|0.00%|-1.0242|0.0000|-26.6284|
|TIMEOUT|16|56.25%|0.1508|2.2193|2.4126|
|TP|27|100.00%|1.3616|inf|36.7634|

## Blocks and Stops

|item|count|
|---|---:|
|margin_reject|0|
|entry_blocked_max_open_positions|30|
|entry_blocked_averaging_down_blocked|20|
|entry_blocked_same_quality_bar|18|
|entry_blocked_additional_not_expansion|5|
|entry_blocked_max_consecutive_losses|12|
|candidate_risk_distance_pips_too_wide|25|
|candidate_risk_distance_atr_too_wide|1|
|candidate_spread_to_risk_too_high|8|
|candidate_spread_to_reward_too_high|2|
|stop_condition_triggered|2|

100 USD / fixed 0.01 lot margin check:

|item|value|
|---|---:|
|lot_used|0.01|
|min_free_margin_after_entry|72.93|
|max_total_open_risk_percent_at_entry|3.5668|
|margin_reject|0|

Stop condition details:

|time|reason|consecutive_losses|balance|equity|
|---|---|---:|---:|---:|
|2025.04.03 14:18:49|max_consecutive_losses|6|93.99|93.99|
|2025.04.04 05:31:18|max_consecutive_losses|7|93.14|93.14|

## Interpretation

The two-position preset increased closed trades from 57 to 69, but it still missed the 80-trade research target. ExpectancyR and PF slightly improved versus v2.2, and MaxDD stayed controlled, but max consecutive losses rose from 4 to 7 and the max-consecutive-loss stop fired twice in early April.

The added trades came mainly from `EXPANSION_PULLBACK` second entries. `entry_open_positions_after=2` trades were profitable as a group, but they also introduced clustered exposure around the same expansion regime. Because the stop condition fired and the target trade count was still not reached, this preset should not proceed to 2026 Jan-Apr OOS.

Decision: do not run OOS. Do not test 3 positions yet; the 2-position version already hit the loss-streak stop. The next 2025-only study should keep the second-entry concept but add a drawdown-aware throttle or require stronger post-entry confirmation before allowing the second `EXPANSION_PULLBACK` entry.
