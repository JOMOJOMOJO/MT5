# 最初の下位足転換だけでは期待値にならない

M15の2波中にM5逆方向trendを追跡し、最初の押し安値・戻り高値breakだけを一度限りで使うEAを検証した。未来参照とsignal再利用を排除しても、child-extreme SLは154 trades / PF 0.77だった。

parent-wave2 extreme SLではMFE>=1Rが36%へ上がり、100 trades / PF 1.03まで改善したが、SHORTと一部symbolへの偏りが残った。構造を正しく検出することと、その構造に取引edgeがあることは別問題である。

Evidence: [summary](../../reports/backtest/runs/20260711_fractal_wave2_transition/summary.md), [comparison](../../reports/backtest/runs/20260711_fractal_wave2_transition/full2025_comparison.csv).
