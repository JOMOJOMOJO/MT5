# Session One-Shot Target Path Obstacle Filter Diagnostics

## Scope

This cycle tested whether a target-path obstacle filter improves the existing USDJPY Tokyo range / London breakout one-shot family.

The implementation defines the target path from:

- `entry_price`
- `stop_loss_price`
- `initial_risk_price_distance`
- `target_reward_multiple`
- `target_price`

No ambiguous "2R余白" rule is used.

## Result

The filter did not improve expectancy.

| Scenario | Trades | Blocked | PF | avg_R | Net | Decision |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| no obstacle filter | 99 | 0 | 0.77 | -0.0254 | -81.72 | reject |
| 1.5 clean path | 30 | 69 | 0.32 | -0.0752 | -74.46 | reject |
| 2.0 clean path reference | 25 | 74 | 0.37 | -0.0693 | -57.43 | reject |
| 1.2 clean path reference | 36 | 63 | 0.30 | -0.0810 | -97.54 | reject |
| 1.5 soft diagnostics | 30 | 69 | 0.32 | -0.0752 | -74.46 | reject |

## Lessons

- The clean-path label was not an edge label in this family. In the no-filter baseline, clean trades averaged -0.0747R while dirty-path trades averaged -0.0040R.
- Hard obstacles removed many signals, but they did not selectively remove the losing trades.
- The most frequent block reason was `previous_day_level_blocked`.
- The worst obstacle bucket by avg_R in this run was `current_day_high`, but current-day levels were diagnostic soft obstacles, not hard gates.
- The family still has the same structural issue documented in the prior session-box rejection: simple Tokyo range / London breakout inventory exists, but expectancy does not survive the validation window.

## Rejected Rescue Paths

Do not continue this result by:

- optimizing `target_reward_multiple` more finely
- excluding one side or adding Friday stops
- removing inconvenient obstacle types after seeing the result
- promoting soft obstacles to hard gates without a separate new hypothesis

## Evidence

- Summary: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/summary.md`
- Comparison: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/comparison.csv`
- Clean path breakdown: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/clean_path_breakdown.csv`
- Obstacle type breakdown: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/obstacle_type_breakdown.csv`
- Block reason breakdown: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/obstacle_block_reason_breakdown.csv`
