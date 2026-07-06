# Required-Light M15 Wave2 Adjacent Expansion Validation

## Scope
- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Purpose: decompose the prior required-light winner and test one-neighbor-at-a-time adjacent expansions.
- Tester period M15; presets use H1=`16385`, M15=`15`, M5=`5`.
- M5 ABC/123 was not made a hard gate.
- MT5 HTML reports missing after rerun attempts: full2025_base; EA CSV evidence is present for all runs.

## Key Full-2025 Rows
- baseline c10: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- required-light: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- best all-symbol adjacent row by avg_R: `full2025_fib_deep` trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- one-symbol research fragments: full2025_one_light trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%; full2025_one_best trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%; full2025_one_combine trades=65, PF=0.80, avg_R=-0.0774, net=-119.54, avg_MFE=0.641R, MFE>=1R=30.8%, MFE>=1.3R=18.5%, time_exit=67.7%, TP=21.5%

## Q1 Selection
- selected adjacent modes for combine: fib_deep, breaktype
- Q1 spot check: base trades=107, PF=0.46, avg_R=-0.2217, net=-561.90, avg_MFE=0.567R, MFE>=1R=20.6%, MFE>=1.3R=11.2%, time_exit=72.9%, TP=12.1%; light trades=18, PF=1.16, avg_R=0.0472, net=24.57, avg_MFE=0.755R, MFE>=1R=33.3%, MFE>=1.3R=22.2%, time_exit=61.1%, TP=27.8%; relax_w1 trades=19, PF=1.05, avg_R=0.0111, net=8.00, avg_MFE=0.670R, MFE>=1R=26.3%, MFE>=1.3R=21.1%, time_exit=63.2%, TP=26.3%; relax_w2 trades=19, PF=1.05, avg_R=0.0111, net=8.00, avg_MFE=0.670R, MFE>=1R=26.3%, MFE>=1.3R=21.1%, time_exit=63.2%, TP=26.3%; highq trades=81, PF=0.54, avg_R=-0.1820, net=-352.22, avg_MFE=0.625R, MFE>=1R=24.7%, MFE>=1.3R=11.1%, time_exit=70.4%, TP=14.8%

## Required Findings
1. baseline c10 reproduced: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
2. required-light reproduced: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
3. required-light 50-trade breakdown: see `required_light_trade_breakdown.csv`; top wave2 type=shallow_pullback (28), top fib=preferred_382_618 (32).
4. required-light winning trade common point: top wave2 type=shallow_pullback (12), top pattern=head_and_shoulders (7).
5. required-light losing trade common point: top wave2 type=shallow_pullback (16), top exit=time (24).
6. near-miss good trades existed: 71 of 302 full2025_nearmiss_diag required-light rejects reached MFE>=1R; see `near_miss_required_light_rejects.csv` and `near_miss_mfe_positive.csv`.
7. best all-symbol MFE-preserving adjacent expansion: `fib_deep`; see `adjacent_expansion_comparison.csv`.
8. broad/bad population reintroduction: any adjacent with 200+ trades but negative PF/avg_R is treated as baseline leakage.
9. candidates above 100 trades: full2025_fib_shallow, full2025_highq, full2025_context, full2025_combine.
10. 100+ trades with PF>=1.05 and avg_R>0: none.
11. 200+ trades near shallow gate: full2025_highq.
12. one-symbol rows are research fragments unless they reach 200 trades without concentration dependence: full2025_one_light, full2025_one_best, full2025_one_combine.
13. required-light MFE buckets: MFE>=1R trades=20, MFE>=1.3R trades=12; adjacent comparison is in `mfe_by_adjacent_mode.csv`.
14. time-exit improvement must be read with PF/avg_R; a lower time-exit rate alone is not promotion evidence.
15. TP-rate maintenance is shown in `full2025_comparison.csv`.
16. Tokyo/London/Clean or one-symbol-only dependence is not used for promotion.
17. 2025 shallow gate pass candidates: none.
18. 3-year BT/OOS: not run unless a 2025 shallow gate candidate exists.

## Decision
No candidate is promoted unless the 2025 shallow gate passes.
