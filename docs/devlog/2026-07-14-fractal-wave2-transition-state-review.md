# Fractal Wave2 Transition State Review

## Decision

`ExpectedValue_MultiCurrency_FractalWave2TransitionTrader` のM15 wave2開始、M5 child trend anchor、signal reservationをレビューし、状態機械を修正した。旧 `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader` は変更していない。

修正前は最初の逆方向M15 closeでwave2をactive化し、M5では最初に成立した3-pivot anchorを保持していた。修正後は `PARENT_WAVE2_PENDING` を追加し、Mode 0/1/2を固定比較する。latest valid M5 anchorを版管理し、そのanchorの最初の確定足breakだけをsignalにする。candidate validation後、portfolio選抜前に `SIGNAL_RESERVED` へ進める。

初回Q1でMode 1が0件になった原因は、pending中のparent eventがterminal pivot確定前に別parentへ置換される状態機械バグだった。pending parentが確認窓を所有するよう直し、全22 runを最終EX5で再実行した。`SIGNAL_CONSUMED -> EXPIRED` と負のwave2 ageもQA中に修正した。

## Evidence

- Compile: [compile.log](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/compile.log)
- Summary: [summary.md](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/summary.md)
- Full 2025: [full2025_comparison.csv](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/full2025_comparison.csv)
- Funnel: [funnel_breakdown.csv](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/funnel_breakdown.csv)
- State transitions: [state_transition_breakdown.csv](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/state_transition_breakdown.csv)
- Anchor comparison: [first_vs_latest_child_anchor.csv](../../reports/backtest/runs/20260714_fractal_wave2_transition_state_review/first_vs_latest_child_anchor.csv)

最終QAはcompile 0 errors / 0 warnings、不正state transition 0、負のparent wave2 age 0、非latest anchor取引 0、非fresh signal取引 0だった。

## Outcome

2025はMode 0が177 trades / PF 0.70 / avg_R -0.1261R、Mode 1が165 / 0.69 / -0.1292R、Mode 2が173 / 0.69 / -0.1313R。Mode 2 parent-stopは31 trades / PF 0.99 / avg_R -0.0068Rだった。

状態機械の欠陥は修正できたが、研究継続条件と2025 shallow gateは全run不通過。3年BT/OOS、demo/live、spread/ATR/SLの細かい最適化へは進めず、このfamilyはparkを維持する。
