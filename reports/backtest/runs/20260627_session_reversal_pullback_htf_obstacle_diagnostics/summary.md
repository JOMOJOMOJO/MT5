# Session Reversal Pullback HTF Obstacle Diagnostics

## Implementation
- The EA evaluates only the first 60 or 120 minutes after each UTC session start, not the whole session.
- Broker server time is converted to UTC with `InpBrokerUtcOffsetHours`; server/UTC/JST hour and minutes_from_session_start are exported.
- H4/H1 swings use only confirmed fractal-style pivots with `InpSwingDepth`; ZigZag repaint values are not used.
- Target path is explicitly defined by `entry_price`, `stop_loss_price`, `initial_risk_price_distance`, `target_reward_multiple`, and `target_price`.
- Hard obstacles are no-trade gates only in clean target path scenarios; soft obstacles remain diagnostic.

## 2025 Shallow BT Result
- Best avg_R scenario: `target_multiple_2_0_reference` trades=5 PF=1.72 avg_R=0.2678 net=34.94.
- first60 vs first120: better_by_avg_R=first120; first60 avg_R=-0.1396, trades=380; first120 avg_R=-0.1396, trades=380.
- Best session by avg_R across all trades: `new_york` avg_R=-0.0940, trades=867.
- Clean target path effect first120: one_symbol avg_R=-0.1396, trades=380; clean_path avg_R=-0.1012, trades=8, obstacle_blocked=730.
- clean_path_to_target split in one_symbol_first120: clean_avg_R=0.0000, dirty_avg_R=-0.1396.
- Best entry pattern by avg_R across all trades: `bos_down` avg_R=0.6678, trades=3.
- 2025 shallow gate pass candidates: none.

## Required Checks
1. Session was restricted to first 60/120 minutes, not the whole session.
2. first60/first120 comparison is in `comparison.csv` and `trade_window_breakdown.csv`.
3. Tokyo/London/New York/Overlap comparison is in `session_breakdown.csv`.
4. HTF resistance/support and target path obstacles were recorded in trades/signals CSV.
5. Clean path did not automatically become a pass; gate result is based on PF, avg_R, net, trade count, and concentration.
6. clean_path_to_target=true/false comparison is in `clean_path_to_target_breakdown.csv`.
7. Pattern comparison is in `entry_pattern_breakdown.csv` and `entry_trigger_breakdown.csv`.
8. one session / one symbol / one trade was tested against all-symbol mode.
9. 200+ trade requirement is checked in `comparison.csv`.
10. 2025 shallow gate result is recorded above; no scenario moves to 3-year BT/OOS unless it passes.
