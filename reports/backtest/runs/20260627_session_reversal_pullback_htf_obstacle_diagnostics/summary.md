# Session Reversal Pullback HTF Obstacle Diagnostics

## Implementation
- Session labels are not exclusive: Tokyo, London, Overlap, and New York are evaluated as independent UTC session start windows.
- London first60/first120 is evaluated from UTC 07:00 through 08:59 even while Tokyo remains an active session context.
- Tokyo session candidates are restricted to JPY crosses: USDJPY, EURJPY, GBPJPY, AUDJPY; each session candidate map is exported.
- The EA evaluates only the first 60 or 120 minutes after each UTC session start, not the whole session.
- Broker server time is converted to UTC with `InpBrokerUtcOffsetHours`; server/UTC/JST hour and minutes_from_session_start are exported.
- H4/H1 swings use only confirmed fractal-style pivots with `InpSwingDepth`; ZigZag repaint values are not used.
- H4 and H1 confirmed wave3 direction are used as a hard alignment gate by default; only same-direction M15/M5 lower-timeframe wave3 retest entries are allowed.
- Lower-timeframe wave3 entries remain first-pullback/retest entries after H&S/inverse H&S, W top/bottom, sweep reclaim, CHoCH, or BOS confirmation.
- Already-broken neckline, opening range, and session high/low lines are exported as retest reference lines, not target-path obstacles.
- Target path is explicitly defined by `entry_price`, `stop_loss_price`, `initial_risk_price_distance`, `target_reward_multiple`, and `target_price`.
- Hard obstacles are no-trade gates only in clean target path scenarios; soft obstacles remain diagnostic.

## 2025 Shallow BT Result
- Best avg_R scenario: `london_first120_reference` trades=26 PF=2.40 avg_R=0.4674 net=296.49.
- first60 vs first120: better_by_avg_R=first120; first60 avg_R=-0.1011, trades=93; first120 avg_R=-0.0600, trades=116.
- London first120 UTC 07:00-08:59 check: trades=26 PF=2.40 avg_R=0.4674.
- Tokyo first120 JPY-only check: trades=18 PF=1.05 avg_R=0.0227.
- Best session by avg_R across all trades: `london` avg_R=0.4149, trades=146.
- Clean target path effect first120: one_symbol avg_R=-0.0600, trades=116; clean_path avg_R=0.0015, trades=23, obstacle_blocked=269.
- clean_path_to_target split in one_symbol_first120: clean_avg_R=0.0000, dirty_avg_R=-0.0600.
- Best entry pattern by avg_R across all trades: `sweep_low_reclaim` avg_R=1.5396, trades=1.
- Best HTF fractal alignment by avg_R: `H4_LONG_confirmed_break_above_swing_high|H1_LONG_confirmed_break_above_swing_high` avg_R=0.0896, trades=366.
- Best retest reference bucket by avg_R: `neckline_level` avg_R=0.0698, trades=148.
- 2025 shallow gate pass candidates: none.

## Required Checks
1. Session was restricted to first 60/120 minutes, not the whole session.
2. first60/first120 comparison is in `comparison.csv` and `trade_window_breakdown.csv`.
3. Tokyo/London/New York/Overlap comparison is in `session_breakdown.csv`.
4. HTF wave3 alignment, HTF resistance/support, and target path obstacles were recorded in trades/signals CSV.
5. Clean path did not automatically become a pass; gate result is based on PF, avg_R, net, trade count, and concentration.
6. clean_path_to_target=true/false comparison is in `clean_path_to_target_breakdown.csv`.
7. Pattern comparison is in `entry_pattern_breakdown.csv` and `entry_trigger_breakdown.csv`.
8. one session / one symbol / one trade was tested against all-symbol mode.
9. 200+ trade requirement is checked in `comparison.csv`.
10. 2025 shallow gate result is recorded above; no scenario moves to 3-year BT/OOS unless it passes.
11. Session candidate maps are in `session_candidate_map_breakdown.csv`; retest reference behavior is in `retest_reference_breakdown.csv`.
