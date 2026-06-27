# 2026-06-27 Session Reversal Pullback HTF Obstacle Diagnostics

## Task

Build a dedicated multi-currency `Session Reversal Pullback` research EA and test whether opening-session reversal pullbacks improve when entries are limited to the first 60/120 minutes and filtered by higher-timeframe target-path obstacles.

## Implementation

- Added `mql/Experts/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader.mq5`.
- The EA monitors `USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD`.
- Sessions are defined in UTC after converting broker server time with `InpBrokerUtcOffsetHours`.
- The EA evaluates only the first 60 or 120 minutes from each session start.
- H4/H1 swing levels use confirmed fractal-style pivots only; ZigZag repaint values are not used.
- Target path is defined explicitly from `entry_price`, `stop_loss_price`, `initial_risk_price_distance`, `target_reward_multiple`, and `target_price`.
- Hard obstacles are previous day/week levels, H4/H1 confirmed swings, session/pre-session/opening-range levels, neckline, and failed breakout level.
- Soft obstacles remain diagnostics: round number, recent equal highs/lows, rejection/wick clusters, consolidation, and congestion.

## Validation

- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_compile.txt`
- Result: `0 errors, 0 warnings`.
- 2025 shallow MT5 backtests were run for all 11 requested scenarios.
- Aggregated evidence: `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/summary.md`

## Result

No scenario passed the 2025 shallow gate.

Key outcomes:

- `session_reversal_pullback_all_symbols_first120`: 761 trades, PF 0.81, avg_R -0.0898, net -1518.66.
- `session_reversal_pullback_one_symbol_first120`: 380 trades, PF 0.70, avg_R -0.1396, net -1243.41.
- `session_reversal_pullback_one_symbol_first60`: same trade set as first120; all selected trades occurred inside first60.
- `session_reversal_pullback_clean_target_path_first120`: 8 trades, PF 0.79, avg_R -0.1012, net -20.45, with 730 obstacle-blocked signals.
- `target_multiple_2_0_reference`: PF 1.72 and avg_R +0.2678, but only 5 trades, so it is not a fixed BT or operating candidate.

## Decision

Do not advance to 3-year fixed BT or OOS.

Reasons:

- The only scenarios with 200+ trades were negative.
- The clean target path filter reduced trade count too aggressively and did not produce a positive fixed candidate.
- One-symbol-per-session did not improve expectancy versus all-symbol mode.
- Session references did not reveal a robust standalone session edge; London produced no trades under the opening-window rules.
- Positive-looking fragments were too small to promote.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/trades_all_scenarios.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/session_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/entry_pattern_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/clean_path_to_target_breakdown.csv`
