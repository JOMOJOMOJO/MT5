# Session Reversal Pullback HTF Pre-Filter / Score Diagnostics

## Task

`ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` のエントリー順序を、LTF候補生成後のHTF filterから、HTF permission pre-filter後のLTF候補生成へ比較できるようにした。

追加した比較軸:

- `baseline_current`
- `prefilter_h1_h4_notopp`
- `prefilter_h4_bias_h1_reversal`
- `prefilter_soft`
- `london_focused_diagnostic`
- `no_break_even`
- `break_even_at_1_1r`

## Code Changes

- `InpHTFPermissionMode` を追加し、HTF permissionを先に決めてからM15/M5候補を探すpre-filter経路を実装した。
- `InpFilterOrderableBeforeSessionSelection` を追加し、1セッション1通貨選択前に注文不可候補を落とせるようにした。
- pre-filter経路ではfirst60 time scoreを外し、`retest_score` と `target_room_score` をscore componentとして記録した。
- trades/signals/summary CSVにHTF permission、candidate direction/timeframe、M15/M5 best pattern、retest/target room score、selection rejection診断列を追加した。
- HTF rejected候補は大量ログ化を避けるため、signals行ではなくsummaryカウンタで記録するようにした。

## Validation

- Compile: `reports/compile/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_prefilter_score_compile.log`
  - `0 errors, 0 warnings`
- 2025 shallow BT matrix: 49 runs
  - `reports/backtest/ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader_prefilter_score_run_matrix_2025.csv`
  - Result bundle: `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/`

## Result

- 2025 shallow gate passed: none.
- `baseline_current` all_symbols no_BE: 163 trades / PF 0.81 / avg_R -0.1008.
- Best all_symbols prefilter count recovery: `all_first120__soft__no_be`, 749 trades / PF 0.82 / avg_R -0.0902.
- Best gate-scope row before trade-count gate: `clean_first120__baseline__be_1_1r`, 23 trades / PF 1.14 / avg_R +0.0551.
- London remains the strongest diagnostic fragment: `london_first120__baseline__be_1_1r`, 26 trades / PF 2.70 / avg_R +0.5070.

## Decision

Do not advance to 3-year fixed BT or OOS. Relaxing HTF order restored trade count in integrated scenarios, but expectancy stayed negative. London remains too low-count to promote.

Evidence:

- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/summary.md`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/comparison.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/score_component_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/timeframe_breakdown.csv`
- `reports/backtest/runs/20260627_session_reversal_pullback_prefilter_score_diagnostics/session_breakdown.csv`
