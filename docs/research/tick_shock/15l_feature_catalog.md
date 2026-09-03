# Step 15L causal feature catalog

## Contract

All predictors are available at or before episode `t0_msc`. The MQL snapshot stores a value, an availability flag, and `source_msc` independently; a missing anchor is not converted into an observed zero. `source_msc > t0_msc` makes the snapshot invalid. Price and range distances are normalized by the completed-M5 ATR14 available at t0 unless stated otherwise. Direction-normalized values are multiplied by `+1` for a long shock and `-1` for a short shock.

The one-second ring has a physical capacity of 901 samples (current second plus up to 900 completed seconds). It is memory-only. No tick-level or one-row-per-second CSV is emitted.

## Existing causal predictors

| Feature | Definition / unit | Lookback and availability | Rationale |
|---|---|---|---|
| `spread_atr_t0` | current spread / completed-M5 ATR14 | t0 quote | cost state |
| `tick_activity_ratio` | current detector activity relative to its causal baseline | detector window | flow intensity |
| `atr14_m5` | ATR14 from completed M5 bars | completed bars only | volatility scale |
| `spread_percentile` | causal baseline rank of spread | pre-t0 baseline | relative liquidity |
| `activity_percentile` | causal baseline rank of tick activity | pre-t0 baseline | relative activity |
| `atr_percentile` | causal baseline rank of ATR | completed history | volatility regime |
| `pre_return_5m_dir_atr` | directional five-minute pre-return / ATR | t0-300s to t0 | pre-shock momentum |
| `m5_ema20_slope_dir_atr` | directional completed-M5 EMA20 slope / ATR | completed M5 bars | trend slope |
| `m15_alignment_dir` | signed alignment of completed M15 trend and shock | completed M15 bars | higher-timeframe context |
| `pre_extension_15m_dir_atr` | directional 15-minute extension / ATR | t0-900s to t0 | exhaustion / persistence |
| `day_range_position_dir` | directional location within causal day range | before t0 | session structure |
| `detection_efficiency` | detector net move / path length | detector window | path cleanliness |
| `severity` | frozen detector severity | detector window | shock abnormality |
| `confirmation_retention` | retained shock fraction at causal confirmation | up to t0 | persistence |
| `spread_efficiency_interaction` | spread state x efficiency | t0 | cost/path interaction |
| `flow_efficiency_interaction` | activity state x efficiency | t0 | flow/path interaction |
| `shock_direction` | LONG/SHORT | t0 | direction category |
| `session` | causal server-time session label | t0 | intraday regime |
| `symbol` | instrument identity; only included in the explicit with-symbol ablation | static | identity-dependence diagnostic |

## Production MQL lag features

| Feature(s) | Formula / unit | Lookback | Availability timestamp | Rationale |
|---|---|---:|---|---|
| `return_5s_dir_atr`, `return_10s_dir_atr`, `return_30s_dir_atr`, `return_60s_dir_atr`, `return_120s_dir_atr`, `return_300s_dir_atr`, `return_900s_dir_atr` | `(mid_t0 - anchor_mid) * direction / ATR14_M5` | 5/10/30/60/120/300/900 s | exact latest real quote at or before anchor | directional momentum by horizon |
| `spread_5s_atr`, `spread_10s_atr`, `spread_30s_atr` | anchor spread / ATR14_M5 | 5/10/30 s | anchor quote | lagged transaction cost |
| `spread_change_5s_atr`, `spread_change_10s_atr`, `spread_change_30s_atr` | `(spread_t0 - anchor_spread) / ATR14_M5` | 5/10/30 s | max(anchor quote, t0 quote) | contraction / expansion |
| `ticks_5s`, `ticks_10s`, `ticks_30s`, `ticks_60s`, `ticks_120s` | count of real quotes in `(t0-window,t0]` | 5/10/30/60/120 s | t0 quote | absolute activity |
| `tick_ratio_5s_prev5s` | ticks `(t0-5s,t0]` / ticks `(t0-10s,t0-5s]` | 10 s | t0 quote | short activity acceleration |
| `tick_ratio_30s_prev30s` | ticks `(t0-30s,t0]` / ticks `(t0-60s,t0-30s]` | 60 s | t0 quote | medium activity acceleration |
| `range_30s_atr`, `range_60s_atr`, `range_180s_atr`, `range_300s_atr`, `range_900s_atr` | `(max second-high - min second-low) / ATR14_M5` | 30/60/180/300/900 s | last included real quote | compression / expansion |
| `range_1800s_atr`, `range_3600s_atr` | completed-M1 range including t0 mid / ATR14_M5 | 30/60 min | last completed M1 boundary | longer structure without future bars |
| `realized_abs_30s_atr`, `realized_abs_60s_atr`, `realized_abs_180s_atr`, `realized_abs_300s_atr` | sum of absolute one-second mid changes / ATR14_M5 | 30/60/180/300 s | last included real quote | local path volatility |
| `accel_10s_vs_prev30s` | directional 10s return minus directional return from t0-40s to t0-10s | 40 s | latest required anchor | short acceleration |
| `return_30s_vs_prev30s` | directional recent 30s return minus directional prior 30s return | 60 s | latest required anchor | momentum change |
| `direction_consistency_30s` | positive directional one-second changes / all nonzero one-second changes | 30 s | last included quote | path consistency |
| `range_position_900s_dir` | `(2 * position_in_15m_range - 1) * direction` | 900 s | last included quote | directional range position |
| `distance_high_900s_dir_atr` | `(15m high - mid_t0) * direction / ATR14_M5` | 900 s | last included quote | distance to rolling high |
| `distance_low_900s_dir_atr` | `(mid_t0 - 15m low) * direction / ATR14_M5` | 900 s | last included quote | distance to rolling low |
| `atr14_m5_slope_3bars` | `(ATR14_now - ATR14_at_offset3) / ATR14_at_offset3` | completed M5, three-bar offset | latest completed M5 used | volatility acceleration |

## Analysis-only deterministic transforms

These are calculated solely from the causal columns above and are not future-path inputs.

| Feature | Formula | Purpose |
|---|---|---|
| `abs_return_10s_atr` | `abs(return_10s_dir_atr)` | unsigned short movement |
| `shock_to_range_60s` | `abs(return_5s_dir_atr) / range_60s_atr` | recent displacement vs local range |
| `spread_contraction_activity` | `-spread_change_5s_atr * tick_ratio_5s_prev5s` | liquidity/activity interaction |
| `atr_spread_state` | `atr_percentile * (1 - spread_percentile)` | high-volatility, lower-cost interaction |
| `momentum_efficiency_interaction` | `return_10s_dir_atr * detection_efficiency` | directional momentum/path interaction |

## Ablation groups

- A: existing predictors only.
- B: A plus directional price lags and momentum.
- C: B plus spread and tick dynamics.
- D: C plus range, realized movement, structure, and ATR slope.
- E: D plus the five deterministic interactions.

Not implemented in this iteration are separate past-percentile lags, session-high distance, and distinct M1/M5 swing algorithms. They were not synthesized after the formal run because that would require a new preregistration and evidence run. Existing causal percentiles, day-range position, completed-bar ranges, and rolling 15-minute distances cover the corresponding broad regimes for this feasibility study.
