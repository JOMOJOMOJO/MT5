# Fractal Wave2 Transition Trader

## Decision

`ExpectedValue_MultiCurrency_FractalWave2TransitionTrader` を旧Session Reversal EAとは別familyとして実装し、Q1と2025通年を固定条件で検証した。旧EAは変更していない。

M15でparent bias flipとwave1/wave2を管理し、wave2開始後のM5 counter-trendをconfirmed pivotだけで追跡する。最初のactive anchor終値breakだけをsignal化し、parent event単位で一度だけ消費する。pivot breakはpivot確定時刻より後のclosed barだけを使うため未来参照はない。

## Evidence

- Compile: [compile.log](../../reports/backtest/runs/20260711_fractal_wave2_transition/compile.log)
- Summary: [summary.md](../../reports/backtest/runs/20260711_fractal_wave2_transition/summary.md)
- Full-year comparison: [full2025_comparison.csv](../../reports/backtest/runs/20260711_fractal_wave2_transition/full2025_comparison.csv)
- Funnel: [funnel_breakdown.csv](../../reports/backtest/runs/20260711_fractal_wave2_transition/funnel_breakdown.csv)
- State transitions: [state_transition_breakdown.csv](../../reports/backtest/runs/20260711_fractal_wave2_transition/state_transition_breakdown.csv)

2025 baseは154 trades、PF 0.77、avg_R -0.0972R、net -365.54、MFE>=1R 23.4%。parent-wave2 extreme SLは100 trades、PF 1.03、avg_R +0.0127R、net +33.83、MFE>=1R 36.0%だった。

parent-extreme SL断片もPF 1.05に届かず、SHORTはPF 0.79、USDJPYが64%を占めた。H1 alignment=trueとfull fractal alignmentも負けを分離できなかった。研究継続条件と2025 shallow gateは全run不通過で、3年BT/OOSは実施しない。

## Outcome

このfamilyはparkする。parent-extreme SLの小さな改善は保存するが、spread/ATR閾値の微調整、通貨除外、方向限定、上位足hard gateでは延命しない。
