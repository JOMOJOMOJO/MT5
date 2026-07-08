# Near-Miss Winner Separator Validation

## Scope
- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Objective: keep required-light intact and test pre-entry separators for required-light rejects that later reached MFE.
- MFE/result columns are used only in analyzer grouping, not in EA entry decisions.
- Timeframe preset check: H1=`16385`, M15=`15`, M5=`5`; `InpPrimaryEntryTF=5` and CSV exports `selected_candidate_timeframe` from the selected candidate.
- MT5 HTML reports missing: none.

## Full-2025 Anchors
- baseline c10: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%
- required-light: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- best separator row: `full2025_targetroom` trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%
- analyzer-selected next best single: `targetroom`, best_two mask: `40`.

## Required Answers
1. baseline c10 reproduced: trades=318, PF=0.59, avg_R=-0.1582, net=-1144.89, avg_MFE=0.597R, MFE>=1R=24.5%, MFE>=1.3R=12.6%, time_exit=74.2%, TP=15.4%.
2. required-light reproduced: trades=50, PF=1.34, avg_R=0.1099, net=134.29, avg_MFE=0.781R, MFE>=1R=40.0%, MFE>=1.3R=24.0%, time_exit=56.0%, TP=30.0%.
3. broad diagnostic groups: A=16, B=12, C=147, D=25. These are labels inside `full2025_nearmiss_diag`; they do not equal the separate 50-trade required-light run because gating changes entry order and session consumption.
4. required-light pass vs near-miss winners: see `required_light_pass_vs_nearmiss_winners.csv`; top B invalidation=none (10).
5. required-light pass vs near-miss losers: see `required_light_pass_vs_nearmiss_losers.csv`; top C failure bucket=none (101).
6. strong near-miss winners: D=25; see `near_miss_strong_winner_comparison.csv`.
7. M5 invalidation candle quality separated winners/losers: inspect `separator_invalidation_quality_breakdown.csv`; B top=none (10), C top=none (101).
8. no-immediate-failure separated winners/losers: B top=none (10), C top=none (101).
9. retest rejection quality separated winners/losers: B top=none (10), C top=none (101).
10. corrective exhaustion separated winners/losers: B top=strong_exhaustion (5), C top=strong_exhaustion (61).
11. M15 wave2 completion quality separated winners/losers: B top=good (5), C top=good (88).
12. target room separated winners/losers: B top=lt_1_0r (12), C top=lt_1_0r (147).
13. 75SMA/Granville separated winners/losers: B top=reclaim_only (7), C top=expansion (65).
14. separator candidate rows are in `separator_candidate_comparison.csv`.
15. 100+ positive research fragments: none.
16. 200+ shallow-gate candidates: none.
17. one-symbol best rows remain research fragments unless they meet 200+ trades and concentration gates.
18. London/Tokyo/Clean-only promotion is not used in this validation.
19. 3-year fixed BT/OOS is not run unless a 2025 shallow gate candidate exists.
20. Decision: preserve required-light if no separator reaches 200+ trades with positive PF/avg_R; otherwise continue only the gate-passing separator.
