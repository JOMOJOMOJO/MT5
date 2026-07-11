# First M5 Micro-N Relaunch After M15 Anchor Pullback

## Scope
- M15 anchor uses the first close break after a confirmed M15 anchor. Latest-near-entry remains diagnostic only.
- The M5 relaunch requires a confirmed `low-high-lower-low` correction for Long or `high-low-higher-high` correction for Short, then the first close break of the middle micro anchor.
- M5 pivots use closed bars and right-side confirmation bars; no unclosed bar, repaint value, MFE, or result label is used by entry logic.
- Timeframes: H1=`16385`, M15=`15`, M5=`5`; tester period M15, internal scan `PERIOD_M5` closed bars.
- MT5 HTML reports missing: none.

## Full-2025 Comparison
- base: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- light: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- anchor_pullback: trades=73, PF=0.90, avg_R=-0.0365, net=-55.75, avg_MFE=0.577R, MFE>=1R=20.5%, MFE>=1.3R=16.4%, time_exit=82.2%, TP=16.4%
- micro_n_diag: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- micro_n_required: trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%
- micro_n_first: trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%
- micro_n_strong: trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%
- light_or_micro_n: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- light_or_micro_n_first: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- light_or_micro_n_pattern: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- light_or_micro_n_exhaustion: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- one_micro_n_first: trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%
- one_light_or_micro_n_first: trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%

## Required Answers
1. baseline reproduced: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%.
2. required-light reproduced: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%.
3. previous anchor pullback reproduced: trades=73, PF=0.90, avg_R=-0.0365, net=-55.75, avg_MFE=0.577R, MFE>=1R=20.5%, MFE>=1.3R=16.4%, time_exit=82.2%, TP=16.4%.
4. confirmed M5 micro anchors formed: detected rows=4; range/unknown remains diagnostic.
5. relaunch is an anchor break, not a candle label: yes; it requires a confirmed three-pivot corrective N and a close beyond the middle oshiyasu/modoritakane.
6. first-valid-signal-only worked: implementation enforces age<=1, but empirical trade validation was not possible because taken first-mode relaunch trades=0 (observed_age_rule_pass=False).
7. stale signal reuse blocked: the EA reserves the event before portfolio selection/order checks, but empirical duplicate validation was not possible because taken event IDs=0 (observed_unique=False).
8. old vs new diagnostic: old_only=trades=39, PF=0.38, avg_R=-0.2639, net=-231.64, avg_MFE=0.518R, MFE>=1R=15.4%, MFE>=1.3R=10.3%, time_exit=82.1%, TP=10.3%, new_only=trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%, both=trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%.
9. micro-N required: trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%; first-only=trades=0, PF=0.00, avg_R=0.0000, net=0.00, avg_MFE=0.000R, MFE>=1R=0.0%, MFE>=1.3R=0.0%, time_exit=0.0%, TP=0.0%.
10. first-only time exit comparison: required=0.0%, first-only=0.0%.
11. required-light OR first micro-N: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%; this is identical to required-light, so micro-N contributed zero additional trades.
12. one-symbol combination: trades=35, PF=1.74, avg_R=0.2133, net=183.93, avg_MFE=0.800R, MFE>=1R=45.7%, MFE>=1.3R=25.7%, time_exit=54.3%, TP=34.3%; micro-N-only produced zero, so this positive fragment is also required-light selection, not micro-N improvement.
13. dependency for required-light OR first micro-N: symbol=USDJPY:62.0%, session_label=london_newyork_overlap:38.0%, direction=SHORT:72.0%.
14. 100+ trades with PF>=1.05, avg_R>0, net>0: none.
15. 2025 shallow gate pass (200+): none.
16. 3-year BT/OOS candidate: no; 2025 gate was not passed.
17. family decision: park as a research asset; the final structural stop condition was not met.

Research fragments (50-199 positive): full2025_light, full2025_light_or_micro_n, full2025_light_or_micro_n_first, full2025_light_or_micro_n_pattern, full2025_light_or_micro_n_exhaustion.
Final stop-condition candidates with 100+ positive trades and MFE>=1R above baseline: none.
No 3-year or OOS run was executed unless the 2025 shallow gate passed.
