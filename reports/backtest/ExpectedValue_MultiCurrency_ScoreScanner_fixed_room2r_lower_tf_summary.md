# Fixed Room2R Annual And Lower TF Summary

This validates `RESEARCH_STRATEGY_NESTED_FIXED_ROOM2R` on annual BT and runs the lower timeframe comparison because annual H4-H1-M15 trade counts were below 100 per year.

## H4-H1-M15 Annual Result

- Trades: `120`
- PF: `0.904`
- Avg R: `-0.052`
- Net: `-382.18`
- Max DD: `555.06` / `5.47%`
- FX net: `224.06`
- XAUUSD net: `-606.24`
- LONG net: `-563.31`
- SHORT net: `181.13`
- Clean/acceptable fractal: `100.0%`

## H1-M15-M5 Lower TF Result

- Trades: `199`
- PF: `0.936`
- Avg R: `-0.034`
- Net: `-426.8`
- Max DD: `1021.18` / `9.8%`
- FX net: `-124.77`
- XAUUSD net: `-302.03`
- LONG net: `-244.79`
- SHORT net: `-182.01`
- Clean/acceptable fractal: `100.0%`

## Required Answers

1. Annual H4-H1-M15 effectiveness: fail by gate criteria.
2. Stability across 2024/2025/2026: see by-year CSV; multiple-year stability is not proven.
3. Annual trade count sufficiency: total `120`, by-year counts `2024:45;2025:46;2026:29`.
4. H4-H1-M15 had years below 100 trades: `true`.
5. Lower TF H1-M15-M5 was executed because at least one annual H4-H1-M15 year had fewer than 100 trades.
6. Lower TF trade count changed from `120` to `199`.
7. Lower TF PF/avg_R: PF `0.936`, avg_R `-0.034`.
8. FX only H4 vs Lower: `224.06` vs `-124.77`.
9. XAUUSD dependence H4 vs Lower: `-606.24` vs `-302.03`.
10. LONG/SHORT balance H4: LONG `-563.31`, SHORT `181.13`; Lower: LONG `-244.79`, SHORT `-182.01`.
11. M5 spread/noise proxy: lower TF avg_MAE_R `1.181` and reached_0_5R `67.34%`; inspect lower trades for `spread_atr` and false-BOS labels.
12. FX fit: H4-H1-M15.
13. XAUUSD fit: lower TF.
14. Next research candidate: none by the current gate.
15. Live-candidate promotion remains too early unless the gate passes without XAUUSD/SHORT concentration.

## Gate Decision

- H4-H1-M15 gate: `fail`
- H1-M15-M5 gate: `fail`

## Artifacts

- H4 summary: [annual comparison CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_comparison.csv)
- H4 trades: [annual trades CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_trades.csv)
- H4 fractal audit: [annual fractal audit CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_fractal_audit.csv)
- H4 by session: [annual by session CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_by_session.csv)
- Lower summary: [lower comparison CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_lower_tf_comparison.csv)
- Lower trades: [lower trades CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_lower_tf_trades.csv)
- Lower fractal audit: [lower fractal audit CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_lower_tf_fractal_audit.csv)
- Lower by session: [lower by session CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_lower_tf_by_session.csv)
- TF comparison: [TF comparison markdown](ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_tf_comparison.md)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_fixed_room2r_annual_compile.log)
