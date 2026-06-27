# Session Reversal Pullback HTF Pre-Filter / Score Optimization Note

## Hypothesis

The prior version may have reduced trade count because it found LTF reversal candidates first, then rejected them with strict H4/H1 confirmed wave3 alignment. A better order may be:

1. Determine HTF permission first.
2. Search M15/M5 lower-timeframe reversal candidates only in the permitted direction.
3. Remove the simple first60 time score.
4. Compare `retest_score` and `target_room_score` as coarse score components.

## Tested Matrix

- Period: 2025-01-01 to 2025-12-31
- TF/model/deposit: M15 / Model 4 / 10000 USD
- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD
- Runs: 49
- Break-even modes: `no_break_even`, `break_even_at_1_1r`
- No symbol exclusion, direction exclusion, weekday stop, or fine threshold tuning was used.

Matrix:

- `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_prefilter_score_run_matrix_2025.csv`

## Key Findings

- Trade count can be restored by soft pre-filtering, but expectancy does not recover.
  - `all_first120__soft__no_be`: 749 trades / PF 0.82 / avg_R -0.0902.
- Baseline all-symbol result remained weak.
  - `all_first120__baseline__no_be`: 163 trades / PF 0.81 / avg_R -0.1008.
- The best gate-scope row was not tradable due to too few trades.
  - `clean_first120__baseline__be_1_1r`: 23 trades / PF 1.14 / avg_R +0.0551.
- London first120 remained the best fragment, but low count blocks promotion.
  - `london_first120__baseline__be_1_1r`: 26 trades / PF 2.70 / avg_R +0.5070.
- NewYork did not improve enough.
  - Best NewYork: `newyork_first120__soft__no_be`, 245 trades / PF 0.80 / avg_R -0.0687.
- M5 fallback was less bad than M15 overall, but not enough to create a live candidate.
  - PERIOD_M15: 7953 trades / avg_R -0.0956.
  - PERIOD_M5: 1632 trades / avg_R -0.0006.
- Target room score did not improve expectancy in this implementation.
  - High target-room bucket: 44 trades / avg_R -0.2965.

## Decision

No candidate passed the 2025 shallow gate. Do not advance to 3-year fixed BT or OOS. Do not repair this result by symbol exclusion, direction exclusion, weekday stop, London-only promotion, or fine threshold tuning.

## Evidence

- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/htf_permission_mode_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/score_component_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/retest_reference_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/target_room_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/timeframe_breakdown.csv`
