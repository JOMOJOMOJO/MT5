# BucketLab v2.5 Near-Miss Diagnostic - 2025

## Result

- closed_trades: 76
- ExpectancyR: 0.2612
- PF: 1.9043
- MaxDD%: 8.21
- max_consecutive_losses: 3
- stop_active: daily=false, weekly=false, dd=false, loss_streak=false
- accepted_candidate_rows: 216
- bucket_near_miss_rows: 5408

## Bucket Exit R

- DISCOUNT_RECLAIM: trades=5, expectancy_r=0.4038
- EXPANSION_PULLBACK: trades=60, expectancy_r=0.2175
- SHALLOW_CONTINUATION: trades=11, expectancy_r=0.4348

## Near-Miss Buckets

- DISCOUNT_RECLAIM: 4021
- EXPANSION_PULLBACK: 1387

## Near-Miss Missing Conditions Top 12

- range_position_outside_discount: 3617
- m1_reclaim_missing: 2513
- pressure_not_confirmed: 1920
- close_below_exec_slow: 1230
- lower_wick_missing: 1155
- close_location_low: 594
- close_below_exec_fast: 554
- pullback_depth_outside_expansion: 549
- pressure_weak: 524
- m5_trend_not_constructive: 486
- high_atr_extra_missing: 479
- range_position_below_expansion: 417

## Accepted Candidate Relative Metrics

- atr_ratio: n=216, median=1.529, p25=1.387, p75=1.621
- range_position: n=216, median=0.872, p25=0.802, p75=0.919
- up_pressure: n=216, median=0.658, p25=0.610, p75=0.699
- down_pressure: n=216, median=0.342, p25=0.301, p75=0.390
- pullback_depth_atr: n=216, median=0.617, p25=0.456, p75=0.876
- recent_range_atr: n=216, median=4.570, p25=3.942, p75=5.420
- ema_deviation_atr: n=216, median=0.887, p25=0.610, p75=1.155
- risk_distance_pips: n=216, median=15.542, p25=13.368, p75=19.947

## Near-Miss Relative Metrics

- atr_ratio: n=5408, median=1.544, p25=1.162, p75=1.962
- range_position: n=5408, median=0.757, p25=0.565, p75=0.897
- up_pressure: n=5408, median=0.594, p25=0.513, p75=0.682
- down_pressure: n=5408, median=0.406, p25=0.318, p75=0.487
- pullback_depth_atr: n=5408, median=0.771, p25=0.413, p75=1.233
- recent_range_atr: n=5408, median=4.543, p25=3.874, p75=5.466
- ema_deviation_atr: n=5408, median=0.697, p25=0.319, p75=1.183
- spread_atr: n=5408, median=0.101, p25=0.088, p75=0.111

## Monthly

- 202501: trades=2, net_money=0.2899999999999999, net_r=0.4023809523809523
- 202502: trades=11, net_money=-1.04, net_r=-0.2689100200720751
- 202503: trades=6, net_money=-0.5700000000000001, net_r=-0.5519702357758286
- 202504: trades=22, net_money=7.19, net_r=4.598656134663276
- 202505: trades=12, net_money=8.34, net_r=7.688152309052553
- 202506: trades=5, net_money=3.6100000000000003, net_r=3.763693964856483
- 202507: trades=6, net_money=-0.1399999999999999, net_r=-0.3939151954993658
- 202508: trades=4, net_money=1.43, net_r=1.2041153815429866
- 202509: trades=5, net_money=2.24, net_r=1.9964613635742967
- 202510: trades=3, net_money=1.44, net_r=1.4099956507278637
