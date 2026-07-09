# M15 Swing Anchor Bias Validation

## Scope
- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Objective: add M15 oshiyasu/modoritakane anchor-bias state and compare it against M15 wave2 required-light and M5 pattern diagnostics.
- Anchor state uses confirmed M15 pivots and closed M15 bars. MFE/result columns are used only by this analyzer, not by EA entry conditions.
- Timeframe preset check: H1=`16385`, M15=`15`, M5=`5`; tester period remains M15 while EA scans `InpPrimaryEntryTF=PERIOD_M5` closed bars.
- MT5 HTML reports missing: none.

## Full-2025 Comparison
- base: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- light: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- anchor_diag: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- anchor_aligned: trades=222, PF=0.65, avg_R=-0.1327, net=-692.88, avg_MFE=0.630R, MFE>=1R=27.5%, MFE>=1.3R=14.9%, time_exit=71.2%, TP=17.1%
- anchor_flip: trades=122, PF=0.76, avg_R=-0.0869, net=-249.91, avg_MFE=0.606R, MFE>=1R=23.8%, MFE>=1.3R=17.2%, time_exit=74.6%, TP=18.9%
- anchor_flip_pullback: trades=27, PF=0.72, avg_R=-0.1304, net=-78.40, avg_MFE=0.554R, MFE>=1R=22.2%, MFE>=1.3R=18.5%, time_exit=63.0%, TP=22.2%
- light_and_anchor: trades=13, PF=0.46, avg_R=-0.2552, net=-81.49, avg_MFE=0.619R, MFE>=1R=15.4%, MFE>=1.3R=7.7%, time_exit=61.5%, TP=15.4%
- light_or_anchor_flip: trades=145, PF=0.79, avg_R=-0.0760, net=-265.36, avg_MFE=0.623R, MFE>=1R=24.8%, MFE>=1.3R=17.2%, time_exit=71.7%, TP=20.0%
- light_or_anchor_m5pattern: trades=142, PF=0.81, avg_R=-0.0712, net=-241.61, avg_MFE=0.624R, MFE>=1R=25.4%, MFE>=1.3R=17.6%, time_exit=71.1%, TP=20.4%
- light_or_anchor_exhaustion: trades=108, PF=0.77, avg_R=-0.0854, net=-225.83, avg_MFE=0.660R, MFE>=1R=25.9%, MFE>=1.3R=18.5%, time_exit=68.5%, TP=21.3%
- anchor_range_blocked: trades=250, PF=0.51, avg_R=-0.2012, net=-1146.80, avg_MFE=0.551R, MFE>=1R=21.6%, MFE>=1.3R=11.6%, time_exit=75.2%, TP=14.0%
- anchor_range_light_only: trades=257, PF=0.53, avg_R=-0.1939, net=-1134.70, avg_MFE=0.560R, MFE>=1R=22.2%, MFE>=1.3R=11.7%, time_exit=73.9%, TP=14.4%
- one_light_anchor_diag: trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%
- one_anchor_flip_pullback: trades=23, PF=0.79, avg_R=-0.1030, net=-50.85, avg_MFE=0.581R, MFE>=1R=26.1%, MFE>=1.3R=21.7%, time_exit=56.5%, TP=26.1%
- one_light_or_anchor: trades=65, PF=0.79, avg_R=-0.0758, net=-118.91, avg_MFE=0.614R, MFE>=1R=24.6%, MFE>=1.3R=15.4%, time_exit=73.8%, TP=18.5%

## Required Answers
1. baseline c10 reproduced: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%.
2. required-light reproduced: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%.
3. M15 anchor bias aligned vs baseline: diagnostic aligned=trades=217, PF=0.64, avg_R=-0.1427, net=-697.23, avg_MFE=0.622R, MFE>=1R=26.3%, MFE>=1.3R=14.7%, time_exit=72.4%, TP=17.5%; baseline=trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%.
4. M15 anchor bias opposite separated bad population: diagnostic opposite=trades=101, PF=0.49, avg_R=-0.1916, net=-447.66, avg_MFE=0.545R, MFE>=1R=20.8%, MFE>=1.3R=7.9%, time_exit=78.2%, TP=10.9%.
5. anchor bias flip in entry direction useful: diagnostic flip=trades=56, PF=0.58, avg_R=-0.1729, net=-216.40, avg_MFE=0.559R, MFE>=1R=19.6%, MFE>=1.3R=14.3%, time_exit=75.0%, TP=16.1%; required run=trades=122, PF=0.76, avg_R=-0.0869, net=-249.91, avg_MFE=0.606R, MFE>=1R=23.8%, MFE>=1.3R=17.2%, time_exit=74.6%, TP=18.9%.
6. anchor flip plus pullback/retest improved: trades=27, PF=0.72, avg_R=-0.1304, net=-78.40, avg_MFE=0.554R, MFE>=1R=22.2%, MFE>=1.3R=18.5%, time_exit=63.0%, TP=22.2%.
7. required-light AND anchor aligned improved required-light: trades=13, PF=0.46, avg_R=-0.2552, net=-81.49, avg_MFE=0.619R, MFE>=1R=15.4%, MFE>=1.3R=7.7%, time_exit=61.5%, TP=15.4% vs trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%.
8. required-light OR anchor flip balanced count and expectancy: trades=145, PF=0.79, avg_R=-0.0760, net=-265.36, avg_MFE=0.623R, MFE>=1R=24.8%, MFE>=1.3R=17.2%, time_exit=71.7%, TP=20.0%.
9. required-light OR anchor flip + M5 pattern useful: trades=142, PF=0.81, avg_R=-0.0712, net=-241.61, avg_MFE=0.624R, MFE>=1R=25.4%, MFE>=1.3R=17.6%, time_exit=71.1%, TP=20.4%.
10. required-light OR anchor flip + corrective exhaustion useful: trades=108, PF=0.77, avg_R=-0.0854, net=-225.83, avg_MFE=0.660R, MFE>=1R=25.9%, MFE>=1.3R=18.5%, time_exit=68.5%, TP=21.3%.
11. range_n exclusion improved: no. Range diagnostic was less bad than non-range, and the actual range-blocked run worsened: range diagnostic=trades=117, PF=0.85, avg_R=-0.0463, net=-126.52, avg_MFE=0.686R, MFE>=1R=30.8%, MFE>=1.3R=15.4%, time_exit=72.6%, TP=18.8%, non-range diagnostic=trades=201, PF=0.47, avg_R=-0.2234, net=-1018.37, avg_MFE=0.545R, MFE>=1R=20.9%, MFE>=1.3R=10.9%, time_exit=75.1%, TP=13.4%, range-blocked run=trades=250, PF=0.51, avg_R=-0.2012, net=-1146.80, avg_MFE=0.551R, MFE>=1R=21.6%, MFE>=1.3R=11.6%, time_exit=75.2%, TP=14.0%.
12. MFE>=1R / MFE>=1.3R vs baseline: baseline=trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%, best positive fragments=full2025_light.
13. time_exit improved: only in small losing or required-light fragments. Baseline=74.2%, required-light=56.0%, OR anchor flip=71.7%; no gate candidate emerged.
14. TP rate improved: only in small fragments. Baseline=15.4%, required-light=30.0%, OR anchor flip=20.0%; no gate candidate emerged.
15. one-symbol combinations useful: one_light_anchor_diag=trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%, one_anchor_flip_pullback=trades=23, PF=0.79, avg_R=-0.1030, net=-50.85, avg_MFE=0.581R, MFE>=1R=26.1%, MFE>=1.3R=21.7%, time_exit=56.5%, TP=26.1%, one_light_or_anchor=trades=65, PF=0.79, avg_R=-0.0758, net=-118.91, avg_MFE=0.614R, MFE>=1R=24.6%, MFE>=1.3R=15.4%, time_exit=73.8%, TP=18.5%.
16. symbol/session/direction dependence: see `symbol_breakdown.csv`, `session_breakdown.csv`, and `direction_breakdown.csv`; promotion still requires no extreme concentration.
17. 100+ trades with PF>=1.05 and avg_R>0: none.
18. 200+ trades near 2025 shallow gate: none.
19. 2025 shallow gate pass: none.
20. 3-year BT/OOS candidate: no; no 2025 shallow-gate candidate was promoted.

Research fragments 50-199 trades with PF>=1.05 and avg_R>0: full2025_light.
