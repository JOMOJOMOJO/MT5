# M15 Anchor First-Break And True Pullback Validation

## Scope
- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Objective: fix M15 oshiyasu/modoritakane anchor break search from latest-near-entry to first-after-anchor, then test true post-break pullback/retest.
- Anchor state uses confirmed M15 pivots and closed M15 bars. Entry gates use first-after-anchor break; latest-near-entry is diagnostic only.
- MFE/result columns are used only by this analyzer, not by EA entry conditions.
- Timeframe preset check: H1=`16385`, M15=`15`, M5=`5`; tester period remains M15 while EA scans `InpPrimaryEntryTF=PERIOD_M5` closed bars.
- `range_n` was kept as diagnostic only in this matrix; no range-block candidate was promoted.
- MT5 HTML reports missing: none.

## Full-2025 Comparison
- base: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- light: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- anchor_diag_first_break: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- anchor_flip_first_break: trades=122, PF=0.76, avg_R=-0.0869, net=-249.91, avg_MFE=0.606R, MFE>=1R=23.8%, MFE>=1.3R=17.2%, time_exit=74.6%, TP=18.9%
- anchor_flip_first_break_fresh: trades=122, PF=0.76, avg_R=-0.0869, net=-249.91, avg_MFE=0.606R, MFE>=1R=23.8%, MFE>=1.3R=17.2%, time_exit=74.6%, TP=18.9%
- anchor_pullback_diag: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- anchor_pullback_required: trades=73, PF=0.90, avg_R=-0.0365, net=-55.75, avg_MFE=0.577R, MFE>=1R=20.5%, MFE>=1.3R=16.4%, time_exit=82.2%, TP=16.4%
- anchor_pullback_m5_reconfirm: trades=64, PF=0.75, avg_R=-0.0940, net=-132.02, avg_MFE=0.526R, MFE>=1R=18.8%, MFE>=1.3R=15.6%, time_exit=81.2%, TP=15.6%
- light_or_anchor_pullback: trades=107, PF=0.94, avg_R=-0.0235, net=-53.04, avg_MFE=0.636R, MFE>=1R=25.2%, MFE>=1.3R=17.8%, time_exit=72.0%, TP=20.6%
- light_or_anchor_pullback_m5pattern: trades=104, PF=0.96, avg_R=-0.0155, net=-34.13, avg_MFE=0.637R, MFE>=1R=26.0%, MFE>=1.3R=18.3%, time_exit=71.2%, TP=21.2%
- light_or_anchor_pullback_exhaustion: trades=80, PF=0.89, avg_R=-0.0430, net=-78.89, avg_MFE=0.693R, MFE>=1R=27.5%, MFE>=1.3R=18.8%, time_exit=68.8%, TP=21.2%
- one_anchor_pullback: trades=48, PF=0.87, avg_R=-0.0487, net=-48.59, avg_MFE=0.586R, MFE>=1R=20.8%, MFE>=1.3R=16.7%, time_exit=81.2%, TP=16.7%
- one_light_or_anchor_pullback: trades=60, PF=1.28, avg_R=0.0833, net=123.67, avg_MFE=0.699R, MFE>=1R=33.3%, MFE>=1.3R=20.0%, time_exit=70.0%, TP=25.0%

## Required Answers
1. baseline c10 reproduced: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%.
2. required-light reproduced: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%.
3. FindM15AnchorBreak search-order fix implemented: yes; entry-side break uses `first_after_anchor`, while `m15_anchor_latest_break_time` keeps old/latest diagnostics.
4. old/latest vs first-after-anchor difference in diagnostic trades: n=77, avg_diff=2.8 M15 bars, max_diff=15 M15 bars; old_only=trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%, first_only=trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%, both=trades=56, PF=0.58, avg_R=-0.1729, net=-216.40, avg_MFE=0.559R, MFE>=1R=19.6%, MFE>=1.3R=14.3%, time_exit=75.0%, TP=16.1%.
5. first-break anchor flip vs previous anchor flip: first-break required=trades=122, PF=0.76, avg_R=-0.0869, net=-249.91, avg_MFE=0.606R, MFE>=1R=23.8%, MFE>=1.3R=17.2%, time_exit=74.6%, TP=18.9%; diagnostic flip group=trades=56, PF=0.58, avg_R=-0.1729, net=-216.40, avg_MFE=0.559R, MFE>=1R=19.6%, MFE>=1.3R=14.3%, time_exit=75.0%, TP=16.1%.
6. first break + fresh/normal age useful: trades=122, PF=0.76, avg_R=-0.0869, net=-249.91, avg_MFE=0.606R, MFE>=1R=23.8%, MFE>=1.3R=17.2%, time_exit=74.6%, TP=18.9%.
7. true post-break pullback/retest useful: diagnostic=trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%; required=trades=73, PF=0.90, avg_R=-0.0365, net=-55.75, avg_MFE=0.577R, MFE>=1R=20.5%, MFE>=1.3R=16.4%, time_exit=82.2%, TP=16.4%.
8. true pullback + M5 reconfirm useful: trades=64, PF=0.75, avg_R=-0.0940, net=-132.02, avg_MFE=0.526R, MFE>=1R=18.8%, MFE>=1.3R=15.6%, time_exit=81.2%, TP=15.6%.
9. required-light OR true anchor pullback balanced count and expectancy: trades=107, PF=0.94, avg_R=-0.0235, net=-53.04, avg_MFE=0.636R, MFE>=1R=25.2%, MFE>=1.3R=17.8%, time_exit=72.0%, TP=20.6%.
10. one-symbol combinations useful: one_anchor_pullback=trades=48, PF=0.87, avg_R=-0.0487, net=-48.59, avg_MFE=0.586R, MFE>=1R=20.8%, MFE>=1.3R=16.7%, time_exit=81.2%, TP=16.7%, one_light_or_anchor_pullback=trades=60, PF=1.28, avg_R=0.0833, net=123.67, avg_MFE=0.699R, MFE>=1R=33.3%, MFE>=1.3R=20.0%, time_exit=70.0%, TP=25.0%.
11. range_n hard gate used: no. It remains diagnostic only in this run matrix.
12. MFE>=1R / MFE>=1.3R vs baseline: baseline=trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%, best positive fragments=full2025_light, full2025_one_light_or_anchor_pullback.
13. time_exit improved: baseline=74.2%, required-light=56.0%, true-pullback OR=72.0%.
14. TP rate improved: baseline=15.4%, required-light=30.0%, true-pullback OR=20.6%.
15. symbol/session/direction dependence: see `symbol_breakdown.csv`, `session_breakdown.csv`, and `direction_breakdown.csv`; promotion still requires no extreme concentration.
16. 100+ trades with PF>=1.05 and avg_R>0: none.
17. 200+ trades near 2025 shallow gate: none.
18. 2025 shallow gate pass: none.
19. 3-year BT/OOS candidate: no; no 2025 shallow-gate candidate was promoted.

Research fragments 50-199 trades with PF>=1.05 and avg_R>0: full2025_light, full2025_one_light_or_anchor_pullback.
