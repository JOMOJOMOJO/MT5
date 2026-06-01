# ExpectedValue LongOnly BucketLab candidate_v1 Fixed Candidate

## Fixed Content

- EA snapshot: `ExpectedValue_LongOnly_BucketLab.candidate_v1.mq5`
- EA version logged by EA: `candidate_v1`
- Compile log: `ExpectedValue_LongOnly_BucketLab_candidate_v1_compile.log` (`0 errors / 0 warnings`)
- 2025 preset: `ExpectedValue_LongOnly_BucketLab_candidate_v1_2025.set`
- 2026 Jan-Apr OOS preset: `ExpectedValue_LongOnly_BucketLab_candidate_v1_2026_jan_apr.set`
- Fixed trading logic: `M1_PULLBACK_SCORE_LONG`; old M1 pullback and breakout buckets disabled.
- Core score settings: threshold `6.00`, `Spread/ATR <= 0.12`, discount range position `0.25-0.45`, deep pullback ATR `>= 0.80` with expansion ATR ratio `1.45-1.80`, `HYBRID` SL, `FIXED_R` TP, target `1.35R`.
- Logging-only additions after 2025 research gate: preset name, EA version, min lot forced, risk distance pips, risk percent of equity, and free margin after entry. No score/entry/SL/TP/risk-stop logic was changed.

## 2025 IS Summary

| metric | value |
| --- | --- |
| closed_trades | 119 |
| win_rate | 51.260504201680675 |
| expectancy_r | 0.1478030496097914 |
| profit_factor | 1.3640060648002315 |
| total_r | 17.588562903565176 |
| net_money | 23.920000000000012 |
| max_dd_percent | 12.456557526980067 |
| max_consecutive_losses | 5 |
| daily_stop_active | false |
| weekly_stop_active | false |
| drawdown_stop_active | false |
| loss_streak_stop_active | false |

## 2026 Jan-Apr OOS Summary

| metric | value |
| --- | --- |
| closed_trades | 9 |
| win_rate | 22.22222222222222 |
| expectancy_r | -0.35677737740611437 |
| profit_factor | 0.455972049002114 |
| total_r | -3.2109963966550295 |
| net_money | -4.85 |
| max_dd_percent | 8.999617444529454 |
| max_consecutive_losses | 7 |
| daily_stop_active | false |
| weekly_stop_active | false |
| drawdown_stop_active | false |
| loss_streak_stop_active | true |

## 2025 vs OOS

| metric | 2025 IS | 2026 Jan-Apr OOS | readout |
| --- | ---: | ---: | --- |
| closed_trades | 119 | 9 | frequency collapsed |
| win_rate | 51.260504201680675 | 22.22222222222222 | win rate did not transfer |
| expectancy_r | 0.1478030496097914 | -0.35677737740611437 | edge did not transfer |
| profit_factor | 1.3640060648002315 | 0.455972049002114 | PF below survival threshold |
| max_dd_percent | 12.456557526980067 | 8.999617444529454 | DD percent stayed below 20%, but sample stopped by loss streak |
| max_consecutive_losses | 5 | 7 | loss streak became the primary failure |

## OOS Breakdown

### Monthly

| month | trades | winrate | expectancy_r | PF | total_r |
| --- | ---: | ---: | ---: | ---: | ---: |
| 202601 | 3 | 66.7% | 0.8741 | 39.023098 | 2.6223 |
| 202602 | 4 | 0.0% | -0.9426 | 0.000000 | -3.7704 |
| 202603 | 1 | 0.0% | -1.0177 | 0.000000 | -1.0177 |
| 202604 | 1 | 0.0% | -1.0452 | 0.000000 | -1.0452 |

### Exit Reason

| exit_reason | trades | winrate | expectancy_r | PF | total_r |
| --- | ---: | ---: | ---: | ---: | ---: |
| SL | 5 | 0.0% | -1.0243 | 0.000000 | -5.1213 |
| TIMEOUT | 2 | 0.0% | -0.3905 | 0.000000 | -0.7810 |
| TP | 2 | 100.0% | 1.3456 | inf | 2.6913 |

### Relative-Metric Failure Points

| metric | bin | trades | winrate | expectancy_r | PF | total_r |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| spread_atr | 0.1-0.12 | 7 | 14.3% | -0.5016 | 0.277058 | -3.5114 |
| atr_ratio | 1.8-99 | 4 | 0.0% | -1.0303 | 0.000000 | -4.1213 |
| range_position | 0.25-0.45 | 7 | 14.3% | -0.5081 | 0.274483 | -3.5567 |
| distance_recent_low_atr | 1-2 | 4 | 0.0% | -0.9426 | 0.000000 | -3.7704 |
| pullback_depth_atr | 0.2-0.5 | 3 | 0.0% | -0.9244 | 0.000000 | -2.7732 |
| up_pressure | -99-0.45 | 7 | 14.3% | -0.5081 | 0.274483 | -3.5567 |
| risk_distance_pips | 15-20 | 5 | 0.0% | -0.9576 | 0.000000 | -4.7881 |

## Cause Analysis

- January worked, but February through April did not. OOS ended with only `9` trades and `7` losses, so the problem is not a single bad trade; the 2025 market-state definition did not transfer.
- The discount range condition (`range_position 0.25-0.45`) was a 2025 positive area, but in OOS it produced `7` trades at `-0.5081R` expectancy. This is the main regime-transfer failure.
- ATR ratio above `1.8` was strongly positive in 2025 but all OOS trades in that bin lost (`4` trades, `-1.0303R` expectancy). The current bucket treats post-expansion pullbacks too optimistically in 2026.
- Low up-pressure (`up_pressure < 0.45`) was damaging in OOS (`7` trades, `-0.5081R`). The bucket can enter discount pullbacks even when the short-term buying pressure is weak.
- Exit reason confirms the failure: `SL` had `5` trades at about `-1R`; `TIMEOUT` was also negative. The issue is entry-state selection, not just TP placement.
- Stop conditions did their job: max DD stayed under `9%`, but loss-streak stop fired. This prevented deeper damage but disqualifies candidate_v1 as a production candidate.

## Decision

Do not promote candidate_v1 to live or demo-live as-is. Return to v2 research. The 2025 research gate passed, but 2026 Jan-Apr OOS failed on expectancy, PF, trade frequency, and max consecutive losses.

Next v2 work should not tune on OOS directly. Use the OOS failure only as a diagnosis: redesign the market-state hypothesis around discount pullbacks that require stronger pressure confirmation or avoid post-expansion continuation after ATR ratio exceeds the fixed 2025 expansion band.
