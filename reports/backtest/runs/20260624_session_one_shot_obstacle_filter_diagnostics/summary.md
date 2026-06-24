# Session One-Shot Target Path Obstacle Filter Diagnostics

## Definitions
- `entry_price` is the planned order entry price.
- `stop_loss_price` is the initial protective stop price.
- `initial_risk_price_distance = abs(entry_price - stop_loss_price)`.
- `target_reward_multiple` default is `1.5`.
- Long `target_price = entry_price + initial_risk_price_distance * target_reward_multiple`.
- Short `target_price = entry_price - initial_risk_price_distance * target_reward_multiple`.
- `obstacle_buffer_r` default is `0.2`; the filter requires the nearest hard obstacle to be at least `target_reward_multiple + obstacle_buffer_r` away in R terms.

## Hard vs Soft Obstacles
- Hard obstacles are previous-day levels, H1/H4 confirmed swings, session high/low, opening-range high/low, and pre-session high/low. These can block entries when `InpUseHardObstacleFilter=true`.
- Soft obstacles are round numbers, recent equal highs/lows, rejection/wick clusters, consolidation, prior breakout failure, failed breakout level, and price congestion. They are logged for diagnostics and are not hard gates unless `InpUseSoftObstacleAsHardFilter=true`.

## 2025 Shallow Comparison
- session_one_shot_no_obstacle_filter: trades=99, blocked=0, PF=0.77, avg_R=-0.0254, net=-81.72, clean_avg_R=-0.0747, dirty_avg_R=-0.0040, passed=False
- session_one_shot_target_1_5_clean_path: trades=30, blocked=69, PF=0.32, avg_R=-0.0752, net=-74.46, clean_avg_R=-0.0752, dirty_avg_R=0.0000, passed=False
- session_one_shot_target_2_0_clean_path_reference: trades=25, blocked=74, PF=0.37, avg_R=-0.0693, net=-57.43, clean_avg_R=-0.0693, dirty_avg_R=0.0000, passed=False
- session_one_shot_target_1_2_clean_path_reference: trades=36, blocked=63, PF=0.30, avg_R=-0.0810, net=-97.54, clean_avg_R=-0.0810, dirty_avg_R=0.0000, passed=False
- session_one_shot_target_1_5_soft_obstacle_diagnostics: trades=30, blocked=69, PF=0.32, avg_R=-0.0752, net=-74.46, clean_avg_R=-0.0752, dirty_avg_R=0.0000, passed=False

## Required Findings
- In the no-filter baseline, clean_path_to_target=true did not improve expectancy: clean_avg_R=-0.0747 over 30 trades, dirty_avg_R=-0.0040 over 69 trades.
- Compared with no filter, the 1.5 clean-path filter changed avg_R from -0.0254 to -0.0752, PF from 0.77 to 0.32, and trades from 99 to 30.
- obstacle_blocked removed 69 candidate signals in the 1.5 clean-path scenario, but it did not improve aggregate expectancy.
- Worst obstacle type by avg_R was `current_day_high` in `session_one_shot_target_1_5_clean_path` with avg_R=-0.1456 over 4 trades.
- Most frequent block reason was `previous_day_level_blocked` with 47 blocked signals.
- Target multiple comparison:
  - target_reward_multiple=1.2: trades=36, blocked=63, PF=0.30, avg_R=-0.0810, net=-97.54
  - target_reward_multiple=1.5: trades=30, blocked=69, PF=0.32, avg_R=-0.0752, net=-74.46
  - target_reward_multiple=2.0: trades=25, blocked=74, PF=0.37, avg_R=-0.0693, net=-57.43
- Best scenario by avg_R was `session_one_shot_no_obstacle_filter` with avg_R=-0.0254, PF=0.77, net=-81.72.
- 2025 shallow gate candidate exists: False.

## Notes
- This implementation does not use the ambiguous phrase `2R余白`; it records explicit target, risk, obstacle distance, and R-normalized obstacle distance.
- The test did not repair results by excluding symbols, limiting direction, adding a Friday stop, or fine-optimizing target multiples.
