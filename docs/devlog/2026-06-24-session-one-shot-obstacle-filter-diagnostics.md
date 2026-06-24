# Session One-Shot Target Path Obstacle Filter Diagnostics

## Task

Added a target-path obstacle filter to `usdjpy_20260421_tokyo_london_session_box_breakout_engine`.

The filter defines:

- `entry_price`
- `stop_loss_price`
- `initial_risk_price_distance = abs(entry_price - stop_loss_price)`
- `target_reward_multiple`, default `1.5`
- long `target_price = entry_price + initial_risk_price_distance * target_reward_multiple`
- short `target_price = entry_price - initial_risk_price_distance * target_reward_multiple`

## Implementation Notes

- Hard obstacles can block trades:
  - previous-day high/low
  - H4/H1 confirmed swing high/low
  - session high/low
  - opening-range high/low
  - pre-session high/low
- Soft obstacles are diagnostic only unless `InpUseSoftObstacleAsHardFilter=true`:
  - round number
  - recent equal highs/lows
  - rejection and wick cluster zones
  - consolidation and congestion zones
  - prior breakout failure / failed breakout level
- CSV telemetry now records the requested obstacle fields, including nearest obstacle, distance in price and R, clean-path flag, block reason, and hard/soft obstacle counts.
- The implementation avoids the ambiguous "2R余白" framing and records explicit target/risk/obstacle definitions.

## Evidence

- Compile log: `reports/compile/usdjpy_20260421_tokyo_london_session_box_breakout_engine_obstacle_filter.log`
- Summary: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/summary.md`
- Comparison: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/comparison.csv`
- All trades: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/trades_all_scenarios.csv`
- Blocked signals: `reports/backtest/runs/20260624_session_one_shot_obstacle_filter_diagnostics/blocked_signals.csv`
- MT5 reports: `reports/backtest/usdjpy_20260421_session_one_shot_*_2025_report.html`

## Result

Compile passed with `0 errors, 0 warnings`.

2025 shallow BT results:

- `session_one_shot_no_obstacle_filter`: 99 trades, PF 0.77, avg_R -0.0254, net -81.72.
- `session_one_shot_target_1_5_clean_path`: 30 trades, 69 blocked signals, PF 0.32, avg_R -0.0752, net -74.46.
- `session_one_shot_target_2_0_clean_path_reference`: 25 trades, 74 blocked signals, PF 0.37, avg_R -0.0693, net -57.43.
- `session_one_shot_target_1_2_clean_path_reference`: 36 trades, 63 blocked signals, PF 0.30, avg_R -0.0810, net -97.54.
- `session_one_shot_target_1_5_soft_obstacle_diagnostics`: 30 trades, 69 blocked signals, PF 0.32, avg_R -0.0752, net -74.46.

In the no-filter baseline, `clean_path_to_target=true` did not improve expectancy: clean trades averaged -0.0747R over 30 trades, while dirty-path trades averaged -0.0040R over 69 trades.

## Decision

Do not promote this filter as a live or fixed-BT candidate. It removed many signals, but the remaining trades were worse than the baseline. Do not rescue this result by excluding symbols, limiting direction, adding a Friday stop, or fine-tuning target multiples.
