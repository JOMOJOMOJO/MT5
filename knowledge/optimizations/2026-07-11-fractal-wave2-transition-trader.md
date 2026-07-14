# Fractal Wave2 Transition Trader Findings

## Hypothesis

M15 parent wave2の内部を構成するM5逆方向trendを開始時点から追跡し、そのactive押し安値・戻り高値が最初に終値breakされた地点をM15 wave3初動として使う。

## Fixed Validation

- Symbols: USDJPY, EURJPY, GBPJPY, AUDJPY, EURUSD, GBPUSD
- Internal timeframes: H1 diagnostic / M15 parent / M5 child
- Tester: M15, Model 4, deposit 10000
- Target: 1.3R
- Signal: one first child flip per parent wave2, consumed before validation/portfolio selection
- No session, required-light, SMA, Fib, pattern, weekday, symbol, or direction filters

Evidence: [full2025_comparison.csv](../../reports/backtest/runs/20260711_fractal_wave2_transition/full2025_comparison.csv), [trades_all_scenarios.csv](../../reports/backtest/runs/20260711_fractal_wave2_transition/trades_all_scenarios.csv).

## Findings

1. Base child-extreme SLは154 trades / PF 0.77 / avg_R -0.0972Rでedgeなし。
2. Parent-wave2 extreme SLは100 trades / PF 1.03 / avg_R +0.0127Rまで改善したが、継続基準PF 1.05未満。
3. Parent-extreme SLはLONG PF 1.38に対してSHORT PF 0.79。USDJPYが64 tradesを占め、汎用性が弱い。
4. MFE>=1Rはparent-extremeで36.0%まで上がったが、固定1.3Rの損益構造を十分にプラス化できない。
5. H1 alignment=trueはPF 0.71、full H4/H1/M15 alignmentはPF 0.65。上位足alignment hard gateは修理案にならない。
6. Base funnelは2839 first flipsのうちspread guard 2344、invalid stop 341、trade 154。signalを再利用せず一度だけ評価した結果である。

## Decision

研究継続条件・2025 shallow gateとも不通過。3年BT/OOSへ進めずfamilyをparkする。parent-extreme SLは将来の別仮説比較用断片としてのみ保持し、閾値最適化や部分市場除外では昇格させない。
