# 2026-06-08 - Nested N-Wave Failure Decomposition

## Summary

- Strategy: `RESEARCH_STRATEGY_NESTED_NWAVE_NECKLINE_BREAK`
- Task: decompose why the short-period Nested branch failed badly in 2026-Q1, without changing strategy logic.
- Scope: diagnostic analysis only. No EA entry logic, order bridge, SL/TP, RewardR, timeframe, spread guard, risk sizing, or parameters were changed.

## Inputs

- Prior short-period Nested runs:
  - `2025-02`
  - `2025-08`
  - `2025-10`
  - `2026-Q1`
- Compared Nested best-only and all-candidates runs against the existing current ThirdWave and v4 short-period context.
- Used existing Nested `trade_diagnostics` / `signal_diagnostics` rows.
- Used MT5 M5 OHLC for post-entry MFE/MAE and R-reach diagnostics.

## Added

- Analysis script:
  - `scripts/analyze_nested_nwave_failure_decomposition.py`
- Reports:
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_failure_decomposition_summary.md`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_failure_decomposition.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_neckline_quality.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_by_failure_type.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_by_winning_type.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_by_label_recheck.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_mfe_mae_r_reach.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_by_setup_layer.csv`
  - `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_v2_gate_candidates.md`

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_failure_decomposition_compile.log`
- Compile result: `0 errors, 0 warnings`
- No annual backtests were run.
- No EA code was changed for this diagnostic pass.

## Findings

- 2026-Q1 collapse was not XAUUSD-only. FX was also materially negative.
- Worst 2026-Q1 contributors included `GBPUSD`, `XAUUSD`, and `USDJPY`.
- LONG was weaker than SHORT in the 2026-Q1 Nested sample.
- The dominant loss class was `false_breakout`: price closed back inside the neckline soon after entry.
- The primary failure layer was `M15_neckline_quality_problem`, not RewardR tuning.
- A secondary issue was `target_too_far`: some trades reached 1R but failed to reach 2R.
- `clean_nested_nwave_entry` is currently only a coded structural pass label. It is not yet a human-grade clean neckline-break label.

## Decision

Nested N-Wave is not ready for annual retest or promotion. A v2 is only worth a small diagnostic branch if it starts with fixed neckline-quality gates, especially:

- breakout close strength
- entry distance from neckline
- false-break/retest behavior
- H4 pullback edge-zone avoidance
- max SL ATR

RewardR or SL retuning should remain secondary until the neckline quality problem is addressed.
