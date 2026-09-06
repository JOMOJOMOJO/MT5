# Step 15N Post-Shock Feature Catalog

All fields below are computed from real same-symbol quotes no later than the
checkpoint decision quote. `feature_max_source_msc <= decision_processing_msc`
is mandatory. Outcome, exit, remaining excursion, and first-touch fields are
evaluation-only and are never model inputs.

| Group | Field | Unit | Direction treatment | Source bound |
|---|---|---:|---|---|
| Price | `postshock_return_atr` | ATR | multiply by action sign | decision quote |
| Price | `postshock_mfe_to_decision_atr` | ATR | shock-relative, unchanged | decision quote |
| Price | `postshock_mae_to_decision_atr` | ATR | shock-relative, unchanged | decision quote |
| Price | `postshock_range_atr` | ATR | unchanged | decision quote |
| Position | `retracement_from_peak_pct` | ratio | unchanged | decision quote |
| Position | `retracement_from_trough_pct` | ratio | unchanged | decision quote |
| Position | `current_location_in_postshock_range` | ratio | unchanged | decision quote |
| Extremes | `new_extreme_count` | count | unchanged | decision quote |
| Extremes | `origin_recross_count` | count | unchanged | decision quote |
| Extremes | `time_since_last_extreme_ms` | ms | unchanged | decision quote |
| Extremes | `distance_from_last_extreme_atr` | ATR | unchanged | decision quote |
| Path | `net_move_over_path_length` | ratio | unchanged | decision quote |
| Path | `shock_direction_tick_ratio` | ratio | unchanged | decision quote |
| Path | `direction_consistency` | signed ratio | multiply by action sign | decision quote |
| Path | `realized_abs_move_atr` | ATR | unchanged | decision quote |
| Path | `realized_volatility` | ATR | unchanged | decision quote |
| Momentum | `recent_5s_acceleration` | ATR | multiply by action sign | decision quote |
| Momentum | `recent_10s_acceleration` | ATR | multiply by action sign | decision quote |
| Extremes | `peak_update_interval_ms` | ms | unchanged | decision quote |
| Extremes | `extreme_update_rate` | per second | unchanged | decision quote |
| Path | `path_contraction_ratio` | ratio | unchanged | decision quote |
| Path | `path_expansion_ratio` | ratio | unchanged | decision quote |
| Liquidity | `decision_spread_atr` | ATR | unchanged | decision quote |
| Liquidity | `spread_vs_t0_ratio` | ratio | unchanged | decision quote |
| Liquidity | `spread_vs_postshock_mean` | ratio | unchanged | decision quote |
| Liquidity | `spread_contraction_from_t0` | ATR | unchanged | decision quote |
| Activity | `tick_count_postshock` | count | unchanged | decision quote |
| Activity | `tick_rate_recent_5s` | ticks/s | unchanged | decision quote |
| Activity | `tick_rate_recent_10s` | ticks/s | unchanged | decision quote |
| Activity | `tick_activity_vs_t0` | ratio | unchanged | decision quote |
| Activity | `activity_decay` | ratio | unchanged | decision quote |
| Activity | `activity_acceleration` | ticks/s | unchanged | decision quote |
| Execution | `checkpoint_quote_lag_ms` | ms | unchanged | decision quote |

The Step 15L causal t0 feature set is joined by `(symbol,t0_msc)`. Its signed
trend and return fields are multiplied by the action sign; directionless
volatility, spread, activity, and detector-quality fields remain unchanged.

The production module uses a fixed 121-second one-second aggregation ring per
active episode. It does not persist tick- or second-level CSV rows. The ring is
only a bounded causal feature accumulator for the four preregistered
checkpoints.
