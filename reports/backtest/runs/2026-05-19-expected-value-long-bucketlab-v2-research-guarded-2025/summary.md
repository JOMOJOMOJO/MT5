# ExpectedValue_LongOnly_BucketLab v2 Research Guarded 2025

## Candidate v1 OOS failure interpretation

candidate_v1 passed the 2025 research gate, but failed 2026 Jan-Apr OOS. I treated that OOS result only as failure diagnosis, not as an optimization target. The conceptual lesson was that the old `M1_PULLBACK_SCORE_LONG` mixed at least two different states: weak discount pullbacks and post-expansion continuation pullbacks. The weak states were vulnerable when range position was low-to-mid, ATR was excessive, pressure was weak, risk distance was wide, and exits clustered in SL/TIMEOUT losses.

## v2 design

- Split legacy pullback score behavior into separate `DISCOUNT_RECLAIM_PULLBACK_LONG` and `EXPANSION_PULLBACK_CONTINUATION_LONG` buckets.
- Keep `HYBRID` SL and `FIXED_R` TP for comparability.
- Use entry gating from R-efficiency: `risk_distance_pips`, `risk_distance_atr`, `spread_to_risk`, and `spread_to_reward`.
- Keep candidate logging for accepted and rejected candidates.
- For the guarded 2025 pass, discount was made stricter on reclaim quality: range position `0.25-0.45`, `up_pressure >= 0.60`, `down_pressure <= 0.40`. Expansion was separated with its own `range_position >= 0.55` and ATR ratio `1.20-1.80`.

## Compile

`reports/compile/ExpectedValue_LongOnly_BucketLab_v2_guarded_compile.log`: 0 errors, 0 warnings.

## 2025 summary

|metric|value|
|---|---|
|closed_trades|54|
|trades_per_day|0.148|
|wins/losses|30/24|
|win_rate|55.56%|
|expectancy_r|0.2082|
|profit_factor|1.5451|
|total_r|11.2401|
|net_money|13.45|
|max_dd_percent|10.41%|
|max_consecutive_losses|5|
|stop_condition_events|0|

## Gate check

|criterion|pass|
|---|---|
|closed_trades>=80|FAIL|
|expectancy_r>0|PASS|
|pf>1.05|PASS|
|max_dd<25|PASS|
|max_losses<=6|PASS|
|no_stop_condition|PASS|

## Monthly result

|month|trades|expectancy_r|pf|net_r|net_money|
|---|---|---|---|---|---|
|202501|1|1.3500|0.0000|1.3500|1.08|
|202502|8|-0.2956|0.5334|-2.3644|-3.49|
|202503|4|-0.4330|0.4423|-1.7321|-1.85|
|202504|18|0.0887|1.2069|1.5969|2.83|
|202505|9|0.8523|16.0759|7.6705|9.01|
|202506|3|0.8547|22.2661|2.5640|2.38|
|202507|5|-0.0253|0.9392|-0.1264|-0.13|
|202508|2|0.7922|0.0000|1.5844|2.47|
|202509|2|0.1792|1.3541|0.3583|1.01|
|202510|2|0.1695|1.3356|0.3389|0.14|

## Bucket analysis

|bucket_type|trades|winrate|expectancy_r|pf|total_r|
|---|---|---|---|---|---|
|DISCOUNT_RECLAIM|4|75.00%|0.6205|3.4822|2.4822|
|EXPANSION_PULLBACK|50|54.00%|0.1752|1.4463|8.7580|

## Exit reason analysis

|exit|trades|winrate|expectancy_r|pf|total_r|
|---|---|---|---|---|---|
|SL|19|0.00%|-1.0245|0.0000|-19.4653|
|TIMEOUT|14|64.29%|0.1515|2.8340|2.1213|
|TP|21|100.00%|1.3612|inf|28.5842|

## Risk distance pips

|risk_pips|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-12|2|-1.0309|0.0000|0.00%|
|12-15|21|0.5069|3.0004|66.67%|
|15-18|9|-0.2646|0.5678|33.33%|
|18-22|10|0.2617|1.6256|50.00%|
|22-28|12|0.2018|1.6826|66.67%|

## ATR ratio

|atr_ratio|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.85-1.1|2|1.3706|inf|100.00%|
|1.1-1.2|1|-1.0000|0.0000|0.00%|
|1.2-1.45|23|0.1431|1.3365|56.52%|
|1.45-1.6|17|0.2818|1.8780|58.82%|
|1.6-1.8|11|0.1288|1.3233|45.45%|

## Up pressure

|up_pressure|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0.52-0.60|18|-0.0296|0.9421|50.00%|
|0.60-0.65|11|0.5603|3.9292|81.82%|
|0.65-0.75|18|0.0990|1.2451|38.89%|
|0.75-1.0|7|0.5468|2.8864|71.43%|

## Down pressure

|down_pressure|trades|expectancy_r|pf|winrate|
|---|---|---|---|---|
|0-0.25|7|0.5468|2.8864|71.43%|
|0.25-0.35|18|0.0990|1.2451|38.89%|
|0.35-0.40|11|0.5603|3.9292|81.82%|
|0.40-0.48|18|-0.0296|0.9421|50.00%|

## Interpretation

The guarded v2 improved quality versus the first v2 split: PF rose to 1.5451, expectancy rose to 0.2082, max DD stayed at 10.41%, and max loss streak fell to 5. However, closed trades fell to 54, below the >=80 research target and below candidate_v1's 119 trades. This means the split corrected the weak discount problem but over-reduced opportunity.

The result should not proceed to 2026 OOS. The next v2 action should be 2025-only research that adds a third, non-overlapping bucket or broadens expansion through a new hypothesis, not by loosening Spread/ATR or reverting weak discount trades. The most reasonable next bucket is a micro breakout acceptance bucket with strict R-efficiency and pressure requirements, because expansion remains the higher-quality family while discount reclaim still needs more evidence.
