# 2026-06-18 - Broad FX-only 8-Condition Factorial

## Summary

- Task: evaluate 8 ON/OFF diagnostic conditions against the 2025 FX-only broad candidate pool.
- Scope: Python post-processing only. No EA entry logic, RewardR, SL/TP, risk, spread guard, CTrade, symbol list, or direction mode was changed.
- Source baseline: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_trades.csv`, `scenario == B_broad_hard_gate_reduced`.

## Data Integrity Fix

- The broad candidate aggregate had been overwritten after raw MT5 diagnostics were removed, leaving `result_R` and condition flags at zero/false.
- Re-ran the FX-only 2025 broad candidate MT5 diagnostic run to restore raw trade diagnostics.
- Updated `scripts/analyze_broad_fx_only_2025_entry_candidates.py` to fail if matched raw diagnostics are missing.
- Re-derived key condition flags from diagnostic fields before writing the broad candidate CSV.
- `cond_h4_fib_382_618` is derived from `h4_fib_zone == valid_h4_pullback_zone`; the numeric `h4_fib_retracement_pct` field is `0.0` for all broad rows in this diagnostic file.

## Results

- Baseline candidate count: `3999`.
- Factorial combinations evaluated: `256`.
- Fixed-BT candidates meeting the 100-700 trade gate: `0`.
- Best 100-700 trade row: `cond_h4_fib_382_618;cond_h1_counter_wave_atr;cond_round_or_major_obstacle_clear`, `231 trades`, `PF 0.943`, `avg_R -0.189`, `net -156.88`.
- Best 20-50 reference row: `cond_h4_ma_bias;cond_m15_close_bos`, `33 trades`, `PF 0.997`, `avg_R 0.269`, `net -0.85`; diagnostic only, not enough for fixed BT.

## Evidence

- Summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_summary.md`
- All combinations: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_all_combinations.csv`
- Single effects: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_single_effects.csv`
- Trade-count impact: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_trade_count_impact.csv`
- Expectancy impact: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_expectancy_impact.csv`
- Top by trade band: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_top_by_trade_band.csv`
- Balanced candidates: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_balanced_candidates.csv`
- LONG improvement: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_long_improvement.csv`

## Decision

- No fixed MT5 BT branch should be promoted from this 8-condition factorial pass.
- `cond_m15_close_bos` improves average R but reduces the sample to 88 trades and remains PF-negative in net-money terms.
- H4 MA, H4 fib zone, H1 counter N-wave, H1 ATR size, and room-to-2R are useful diagnostic labels, but none creates a robust FX-only 2025 fixed branch by itself or in the tested combinations.
