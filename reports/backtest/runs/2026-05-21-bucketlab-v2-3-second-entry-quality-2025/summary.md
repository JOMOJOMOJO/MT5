# ExpectedValue_LongOnly_BucketLab v2.3 Second-Entry Quality 2025

## Result Review

The prior two-position run was not a complete failure: second entries were slightly positive, but their expectancy was thin and they caused max consecutive losses and stop-condition events to worsen. v2.3 keeps the two-position idea but treats the second entry as a continuation add-on, not as another ordinary signal.

## Improvement Options Considered

- A: pure pyramiding gate: allow a second entry only when the first managed position is already profitable in R terms. This directly blocks averaging-down behavior.
- B: second-entry market-state gate: require expansion ATR, stronger pressure, and avoid extended range unless pressure is exceptional.
- C: drawdown throttle: suppress second entries during loss streaks or when daily equity is already below the allowed intraday tolerance.

Adopted design: A+B+C for second entries only. The underlying bucket signals, Spread/ATR cap, discount reclaim rules, ATR>1.80 cap, SL/TP, and first-entry logic were not intentionally loosened.

## Implementation

- Added `InpAdditionalEntryQualityGate` and related inputs.
- Second entries still require `EXPANSION_PULLBACK`, same bucket, not same M5 bar, no losing managed long, cooldown, total-risk cap, and margin pass.
- New second-entry-only checks: max loss streak, daily equity throttle, open profit R, ATR ratio, up/down pressure, extended range pressure, and wide-risk pressure.

## Compile

`reports/compile/ExpectedValue_LongOnly_BucketLab_second_entry_quality_compile.log`: 0 errors, 0 warnings.

## 2025 Summary

|metric|value|
|---|---:|
|closed_trades|58|
|win_rate_percent|58.6207|
|expectancy_r|0.2926|
|profit_factor|1.8235|
|total_r|16.9681|
|net_money|20.0800|
|max_dd_percent|9.9010|
|max_consecutive_losses|5|
|stop_condition_events|0|

## Three-Way Comparison

|metric|v2.2 one-position|v2.2 two-position|v2.3 second-quality|
|---|---:|---:|---:|
|closed_trades|57|69|58|
|expectancy_r|0.1677|0.1818|0.2926|
|profit_factor|1.4218|1.4386|1.8235|
|max_dd_percent|10.80%|12.03%|9.90%|
|max_consecutive_losses|4|7|5|
|stop_condition_events|0|2|0|

## Gate Check

|criterion|result|
|---|---|
|closed_trades > 57|PASS|
|closed_trades >= 80|FAIL|
|expectancy_r > 0|PASS|
|pf > 1.05|PASS|
|max_dd < 25%|PASS|
|max_consecutive_losses <= 6|PASS|
|no stop condition|PASS|

## Bucket Analysis

|bucket_type|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|DISCOUNT_RECLAIM|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|54|57.41%|0.2683|1.7389|14.4860|

## First vs Second Entry

|entry_open_positions_after|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|1|50|56.00%|0.2094|1.5350|10.4715|
|2|8|75.00%|0.8121|7.2871|6.4967|

|bucket_position|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|DISCOUNT_RECLAIM|pos_after=1|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|pos_after=1|46|54.35%|0.1737|1.4302|7.9893|
|EXPANSION_PULLBACK|pos_after=2|8|75.00%|0.8121|7.2871|6.4967|

## Monthly Analysis

|month|trades|expectancy_r|pf|net_r|net_money|
|---|---:|---:|---:|---:|---:|
|202501|1|1.3500|0.0000|1.3500|1.08|
|202502|8|-0.0012|0.9977|-0.0094|-0.55|
|202503|4|-0.4330|0.4423|-1.7321|-1.85|
|202504|18|0.0887|1.2069|1.5969|2.83|
|202505|11|0.7573|6.5212|8.3304|9.45|
|202506|4|0.9781|33.4497|3.9124|4.47|
|202507|5|-0.0253|0.9392|-0.1264|-0.13|
|202508|3|0.9830|0.0000|2.9491|3.63|
|202509|2|0.1792|1.3541|0.3583|1.01|
|202510|2|0.1695|1.3356|0.3389|0.14|

## Relative Metrics

|risk_pips|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0-12|2|0.00%|-1.0309|0.0000|-2.0617|
|12-15|22|68.18%|0.5863|3.4237|12.8979|
|15-18|9|33.33%|-0.2646|0.5678|-2.3811|
|18-22|11|63.64%|0.5221|2.8140|5.7435|
|22-28|14|64.29%|0.1978|1.6091|2.7695|

|atr_ratio|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0.85-1.1|2|100.00%|1.3706|inf|2.7412|
|1.1-1.2|1|0.00%|-1.0000|0.0000|-1.0000|
|1.2-1.45|22|54.55%|0.1283|1.2884|2.8218|
|1.45-1.6|19|63.16%|0.3946|2.3742|7.4969|
|1.6-1.8|14|57.14%|0.3506|2.1243|4.9082|

|range_position|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0.25-0.45|4|75.00%|0.6205|3.4822|2.4822|
|0.55-0.75|8|75.00%|0.6329|3.4927|5.0633|
|0.75-0.92|33|51.52%|0.1243|1.2951|4.1024|
|0.92-1.0|13|61.54%|0.4092|2.4486|5.3202|

|up_pressure|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0.52-0.60|18|50.00%|-0.0296|0.9421|-0.5336|
|0.60-0.65|11|81.82%|0.5603|3.9292|6.1636|
|0.65-0.75|21|52.38%|0.3639|2.2216|7.6422|
|0.75-1.0|8|62.50%|0.4620|2.2201|3.6959|

|down_pressure|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|0-0.25|8|62.50%|0.4620|2.2201|3.6959|
|0.25-0.35|21|52.38%|0.3639|2.2216|7.6422|
|0.35-0.40|11|81.82%|0.5603|3.9292|6.1636|
|0.40-0.48|18|50.00%|-0.0296|0.9421|-0.5336|

## Exit Reason

|exit_reason|trades|winrate|expectancy_r|pf|total_r|
|---|---:|---:|---:|---:|---:|
|SL|19|0.00%|-1.0236|0.0000|-19.4489|
|TIMEOUT|14|64.29%|0.1730|3.0944|2.4225|
|TP|25|100.00%|1.3598|inf|33.9946|

## Blocks And Margin

|item|count_or_value|
|---|---:|
|margin_reject|0|
|entry_blocked_max_open_positions|10|
|entry_blocked_averaging_down_blocked|22|
|entry_blocked_same_quality_bar|19|
|entry_blocked_additional_loss_streak|18|
|entry_blocked_additional_open_profit_low|13|
|entry_blocked_additional_atr_low|8|
|entry_blocked_additional_wide_risk|3|
|entry_blocked_additional_extended_range|2|
|candidate_risk_distance_pips_too_wide|25|
|min_free_margin_after_entry|81.27|
|max_total_open_risk_percent_at_entry|3.0958|
|lot_used|0.01|

## Interpretation

v2.3 solved the specific quality problem of second entries: second-entry expectancy improved from `+0.0395R` in the raw two-position run to a much stronger positive sample in this run, and the loss-streak stop did not fire. However, the trade-count objective was not solved: total trades increased only from `57` to `58` versus v2.2 one-position.

Decision: do not proceed to 2026 Jan-Apr OOS. This is a useful rule-quality improvement, but not a frequency solution. The next 2025-only study should preserve the second-entry quality gate and look for a separate non-overlapping source of first entries, or make second-entry gating score-based with a controlled sensitivity check rather than adding a third position.
