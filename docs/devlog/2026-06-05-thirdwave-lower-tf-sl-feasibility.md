# 2026-06-05 - ThirdWave LowerTF SL Feasibility

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: test whether the v4 micro/candle reversal branch works better with actual LowerTF reversal SL and fixed `RewardR` values.
- Scope: feasibility only, not promotion, not parameter optimization.

## Changes

- Added `InpThirdWaveSLMode`.
  - `THIRD_WAVE_SL_CURRENT`
  - `THIRD_WAVE_SL_LOWER_TF_REVERSAL`
- Default remains `THIRD_WAVE_SL_CURRENT`, so existing ThirdWave, v2, v3, v4, Phase2, and score scanner behavior is unchanged.
- LowerTF SL uses the existing shadow stop calculation and only becomes the actual order SL when the new research SL mode is selected.
- LowerTF SL blocks candidates with `invalid_stops`, `sl_too_tight`, or `sl_too_wide`.
- Added LowerTF SL scenario support to `scripts/run_multicurrency_score_scanner_thirdwave_backtests.ps1`.
- Added analyzer:
  - `scripts/analyze_multicurrency_score_scanner_lower_tf_sl_feasibility.py`

## Verification

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_compile.txt`
- Compile result: `0 errors, 0 warnings`
- Short-period actual-order BT completed:
  - 2025-02
  - 2025-08
  - 2025-10
  - 2026-Q1
- Short gate passed for:
  - `v4_micro_or_candle_lower_tf_sl_1_2R`
  - `v4_micro_or_candle_lower_tf_sl_1_3R`
  - `v4_without_weak_lower_tf_sl_1_3R`
- Annual BT completed only for baseline A plus passing C/D/G:
  - 2024
  - 2025
  - 2026YTD

## Evidence

- Short summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_short_summary.md`
- Short comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_comparison.csv`
- Annual summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_annual_summary.md`
- Annual comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_annual_comparison.csv`
- Symbol aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_by_symbol.csv`
- Direction aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_by_direction.csv`
- Reversal signal aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_by_signal.csv`
- Label aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_by_label.csv`
- FX/XAUUSD aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_fx_vs_xauusd.csv`
- Session/month aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_session_month.csv`
- Filter summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_lower_tf_sl_feasibility_filter_summary.csv`

## Result

- Short windows favored `v4_micro_or_candle_lower_tf_sl_1_2R`:
  - `PF 1.741`, `avg_R 0.296`, `net 1966.47`, `FX net 549.08`
- Annual validation did not confirm promotion:
  - 2024 failed for all LowerTF SL branches.
  - `v4_micro_or_candle_lower_tf_sl_1_2R` improved 2025 and 2026YTD FX net, but annual combined `PF 1.075` and `avg_R 0.059` were effectively tied with the current ThirdWave baseline.
  - `v4_without_weak_lower_tf_sl_1_3R` had worse annual combined PF and large FX loss.

## Decision

- LowerTF SL is feasible enough to keep as a parked research branch.
- It is not robust enough for promotion or broader RewardR search.
- Do not move into parameter optimization from this result.
- Next useful work should focus on signal/regime quality, especially why 2024 rejects the LowerTF SL hypothesis.
