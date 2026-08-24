# Tick-shock Step 14 March revalidation

2025年3月のIDEAL／REALIZABLE研究runをStep 12/13後のコードで再実行した。Step 7のevent funnel、event identity、scenario membership、status、policy mask、R、clockは完全一致し、REALIZABLEのcausal clock違反は0だった。

一方、Step 12で導入したfail-closed integrity監視が3 stale symbolsを検出し、両runを`VALIDATION_INVALID / INCOMPLETE_GLOBAL_FRONTIER`にした。このため、diagnostic scenario outcomeは保存するが、feasibility／edge／長期OOSの根拠には昇格しない。

Evidence:

- [Step 14 report](../research/tick_shock/14_march_revalidation.md)
- [Comparison summary](../../reports/backtest/runs/20260823_tickshock_step14_comparison_202503/summary.md)
- [Regression comparison](../../reports/backtest/runs/20260823_tickshock_step14_comparison_202503/regression_comparison.csv)
- [Causal invariants](../../reports/backtest/runs/20260823_tickshock_step14_comparison_202503/causal_invariants.csv)
