# BucketLab v2.5 Near-Miss Diagnostic - 2026 Jan-Apr OOS

## Result

- closed_trades: 1
- ExpectancyR: -1.0000
- PF: 0.0000
- MaxDD%: 1.20
- max_consecutive_losses: 1
- stop_active: daily=false, weekly=false, dd=false, loss_streak=false
- accepted_candidate_rows: 2
- bucket_near_miss_rows: 167

## Bucket Exit R

- SHALLOW_CONTINUATION: trades=1, expectancy_r=-1.0000

## Near-Miss Buckets

- DISCOUNT_RECLAIM: 130
- EXPANSION_PULLBACK: 37

## Near-Miss Missing Conditions Top 12

- range_position_outside_discount: 102
- m1_reclaim_missing: 77
- pressure_not_confirmed: 47
- close_below_exec_slow: 33
- lower_wick_missing: 28
- high_atr_extra_missing: 23
- m5_trend_not_constructive: 19
- exec_fast_below_slow: 14
- pullback_depth_outside_expansion: 11
- close_location_low: 10
- close_below_exec_fast: 9
- pressure_weak: 8

## Accepted Candidate Relative Metrics

- atr_ratio: n=2, median=1.744
- range_position: n=2, median=0.951
- up_pressure: n=2, median=0.733
- down_pressure: n=2, median=0.267
- pullback_depth_atr: n=2, median=0.205
- recent_range_atr: n=2, median=5.770
- ema_deviation_atr: n=2, median=1.197
- risk_distance_pips: n=2, median=15.769

## Near-Miss Relative Metrics

- atr_ratio: n=167, median=1.714, p25=1.192, p75=2.241
- range_position: n=167, median=0.725, p25=0.499, p75=0.848
- up_pressure: n=167, median=0.639, p25=0.524, p75=0.701
- down_pressure: n=167, median=0.361, p25=0.299, p75=0.476
- pullback_depth_atr: n=167, median=0.721, p25=0.351, p75=1.225
- recent_range_atr: n=167, median=5.099, p25=4.214, p75=5.684
- ema_deviation_atr: n=167, median=0.651, p25=0.324, p75=1.123
- spread_atr: n=167, median=0.108, p25=0.099, p75=0.114

## Monthly

- 202601: trades=1, net_money=-1.03, net_r=-1.0
