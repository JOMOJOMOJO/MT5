# Session Reversal Pullback HTF Obstacle Diagnostics

## Hypothesis

Opening-session reversal pullbacks might have better expectancy if:

- trading is limited to the first 60/120 minutes of Tokyo, London, New York, or overlap sessions;
- only one symbol is selected per session;
- entries are skipped when hard HTF obstacles sit before the target price.

## Tested Scenarios

- `session_reversal_pullback_all_symbols_first120`
- `session_reversal_pullback_one_symbol_first120`
- `session_reversal_pullback_one_symbol_first60`
- `session_reversal_pullback_clean_target_path_first120`
- `session_reversal_pullback_clean_target_path_first60`
- `tokyo_first120_reference`
- `london_first120_reference`
- `newyork_first120_reference`
- `overlap_first120_reference`
- `target_multiple_1_2_reference`
- `target_multiple_2_0_reference`

## Outcome

No 2025 shallow gate pass.

Main comparison:

| Scenario | Trades | PF | avg_R | Net |
|---|---:|---:|---:|---:|
| all_symbols_first120 | 761 | 0.81 | -0.0898 | -1518.66 |
| one_symbol_first120 | 380 | 0.70 | -0.1396 | -1243.41 |
| one_symbol_first60 | 380 | 0.70 | -0.1396 | -1243.41 |
| clean_target_path_first120 | 8 | 0.79 | -0.1012 | -20.45 |
| target_multiple_2_0_reference | 5 | 1.72 | +0.2678 | +34.94 |

The target 2.0 reference is too small to promote. It is a diagnostic fragment, not an operating candidate.

## Lessons

- The first 60-minute restriction did not change the selected trade set versus first120; the online selection logic already chose early candidates.
- One-symbol-per-session reduced frequency but worsened expectancy relative to all-symbol mode.
- The HTF hard-obstacle clean-path gate blocked many signals, but the remaining sample was too small and still negative.
- Session-specific references did not show a robust edge. New York was least bad by avg_R across the aggregate, but still negative.
- Pattern fragments such as `bos_down`, `double_bottom`, and `sweep_low_reclaim` had some positive pockets, but sample size was too small or scenario-level expectancy remained negative.

## Rejection Rule Applied

The family is not advanced because the 200+ trade scenarios had PF < 1.05, avg_R < 0, and net < 0. No repair was attempted through symbol exclusion, direction exclusion, Friday stopping, fine session-minute tuning, target multiple fine-tuning, or post-hoc obstacle type exclusion.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/r_metrics.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_htf_obstacle_diagnostics/failure_type_breakdown.csv`
