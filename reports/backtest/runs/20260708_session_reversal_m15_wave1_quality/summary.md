# M15 Wave1 Quality Validation

## Scope
- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Objective: keep M15 wave2 required-light intact and test whether M15 wave1 quality separates third-wave launch candidates.
- MFE/result columns are used only in analyzer grouping, not in EA entry decisions.
- Timeframe preset check: H1=`16385`, M15=`15`, M5=`5`; `InpPrimaryEntryTF=5` and CSV exports `selected_candidate_timeframe` from the selected candidate.
- MT5 HTML reports missing: none.

## Full-2025 Anchors
- baseline c10: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- required-light: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- best wave1-quality row: `full2025_one_light_wave1_diag` trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%
- required-light AND wave1 quality: trades=7, PF=0.39, avg_R=-0.2733, net=-48.65, avg_MFE=0.710R, MFE>=1R=28.6%, MFE>=1.3R=14.3%, time_exit=71.4%, TP=14.3%
- required-light OR wave1 quality: trades=87, PF=0.82, avg_R=-0.0701, net=-144.12, avg_MFE=0.673R, MFE>=1R=29.9%, MFE>=1.3R=18.4%, time_exit=65.5%, TP=20.7%
- wave1 quality only: trades=51, PF=0.46, avg_R=-0.2164, net=-262.10, avg_MFE=0.585R, MFE>=1R=23.5%, MFE>=1.3R=11.8%, time_exit=78.4%, TP=9.8%
- required-light OR wave1 quality + corrective exhaustion: trades=67, PF=1.08, avg_R=0.0274, net=44.15, avg_MFE=0.701R, MFE>=1R=31.3%, MFE>=1.3R=20.9%, time_exit=61.2%, TP=25.4%

## Required Answers
1. baseline c10 reproduced: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%.
2. required-light reproduced: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%.
3. M15 wave1 quality split required-light winners/losers: required-light all=16, required-light+quality-high=2; see `required_light_by_m15_wave1_quality.csv`.
   Diagnostic labels inside `full2025_wave1_diag` do not equal the separate 50-trade required-light run because changing gates changes entry order and session consumption.
4. M15 wave1 quality picked required-light reject near-miss winners: reject quality-high MFE>=1R winners=3; see `near_miss_by_m15_wave1_quality.csv`.
5. wave1 quality-only edge: trades=51, PF=0.46, avg_R=-0.2164, net=-262.10, avg_MFE=0.585R, MFE>=1R=23.5%, MFE>=1.3R=11.8%, time_exit=78.4%, TP=9.8%.
6. required-light OR wave1 quality expanded from 50 trades to 100+: no; trades=87, PF=0.82, avg_R=-0.0701, net=-144.12, avg_MFE=0.673R, MFE>=1R=29.9%, MFE>=1.3R=18.4%, time_exit=65.5%, TP=20.7%.
7. 100+ trades with PF>=1.05 and avg_R>0: none.
8. 200+ trades near 2025 shallow gate: none.
9. wave1 quality + corrective exhaustion useful: trades=67, PF=1.08, avg_R=0.0274, net=44.15, avg_MFE=0.701R, MFE>=1R=31.3%, MFE>=1.3R=20.9%, time_exit=61.2%, TP=25.4%; see `wave1_quality_x_corrective_exhaustion_breakdown.csv`.
10. one-symbol combination useful: trades=53, PF=1.00, avg_R=0.0008, net=1.40, avg_MFE=0.703R, MFE>=1R=34.0%, MFE>=1.3R=18.9%, time_exit=66.0%, TP=22.6%; promotion still requires non-concentrated 200+ trades.
11. MFE>=1R / MFE>=1.3R vs baseline: baseline trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%; best wave1 row trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%.
12. time_exit improved: baseline=74.2%, best_wave1=54.3%.
13. TP rate improved: baseline=15.4%, best_wave1=34.3%.
14. symbol/session/direction dependence: see `symbol_breakdown.csv`, `session_breakdown.csv`, and `direction_breakdown.csv`; gate requires no extreme concentration.
15. 2025 shallow gate pass: none.
16. 3-year BT/OOS candidate: no; no 2025 shallow-gate candidate was promoted.

Research fragments below 200 trades but positive: full2025_light, full2025_light_or_wave1_exhaustion.
