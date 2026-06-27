# Session Reversal Pullback HTF Pre-Filter and Score Component Diagnostics

## Implementation
- `baseline_current` keeps the existing LTF-candidate then HTF post-filter order and existing time/clean-path score.
- Prefilter modes compute HTF permission first, then search M15 and M5 LTF candidates only in allowed directions.
- Prefilter modes remove the first-60 time score and add `retest_score` plus `target_room_score` as diagnostics/scoring components.
- One-symbol selection can reject non-orderable candidates before consuming the session when `InpFilterOrderableBeforeSessionSelection=true`.
- Break-even comparison is limited to `no_break_even` and `break_even_at_1_1r`.

## Required Answers
1. Trade count: baseline all_symbols no_BE was `all_first120__baseline__no_be` trades=163 PF=0.81 avg_R=-0.1008 net=-381.38 MaxDD=652.00. Best all_symbols prefilter no_BE by count was `all_first120__soft__no_be` trades=749 PF=0.82 avg_R=-0.0902 net=-1501.76 MaxDD=1501.76.
2. PF / avg_R: best gate-scope row was `clean_first120__baseline__be_1_1r` trades=23 PF=1.14 avg_R=0.0551 net=32.63 MaxDD=76.01.
3. Old order issue: baseline all_symbols no_BE produced 0 `htf_permission_rejected` rows after LTF detection; prefilter modes reject HTF first and therefore do not select an opposite LTF candidate before permission.
4. M15/M5 both: PERIOD_M15 trades=7953 avg_R=-0.0956; PERIOD_M5 trades=1632 avg_R=-0.0006.
5. Time score removal: baseline rows retain the time score; prefilter rows set `time_score_removed_flag=true`. Compare `baseline_current` against prefilter rows in `score_component_breakdown.csv`; no fine time-bucket repair was used.
6. Retest score: high retest-score bucket trades=8795 avg_R=-0.0809; see `retest_reference_breakdown.csv` for type-level evidence.
7. Target room score: high target-room bucket trades=44 avg_R=-0.2965; negative bucket trades=8353 avg_R=-0.0710.
8. One-symbol orderable filtering: best one-symbol prefilter row was `one_first120__h4_bias_h1_rev__be_1_1r` trades=271 PF=0.88 avg_R=-0.0550 net=-379.77 MaxDD=588.14 with 0 preselection rejections; reasons are in `preselection_rejection_breakdown.csv`.
9. London edge: best London row was `london_first120__baseline__be_1_1r` trades=26 PF=2.70 avg_R=0.5070 net=319.81 MaxDD=75.16. It remains diagnostic only if trade count is low.
10. NewYork weakness: best NewYork row was `newyork_first120__soft__no_be` trades=245 PF=0.80 avg_R=-0.0687 net=-451.31 MaxDD=738.72.
11. 2025 shallow gate: no candidate passed (`200 trades`, PF>=1.05, avg_R>0, net>0, no stop, no symbol/direction/session dependence).
12. 3-year fixed BT / OOS: advance only 2025 gate-pass candidates; no 3-year/OOS run is created when the 2025 gate has no pass.

## Evidence
- `comparison.csv`
- `htf_permission_mode_breakdown.csv`
- `score_component_breakdown.csv`
- `retest_reference_breakdown.csv`
- `target_room_breakdown.csv`
- `timeframe_breakdown.csv`
- `session_breakdown.csv`
- `symbol_breakdown.csv`
- `direction_breakdown.csv`
- `entry_pattern_breakdown.csv`
- `yearly_breakdown.csv`
- `monthly_breakdown.csv`
- `signal_event_breakdown.csv`
- `preselection_rejection_breakdown.csv`
- `r_metrics.csv`
