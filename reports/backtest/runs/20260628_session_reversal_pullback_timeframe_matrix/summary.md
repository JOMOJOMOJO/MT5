# Session Reversal Pullback Fractal Timeframe Matrix

## Implementation
- Timeframes are input-parameterized as `InpTopContextTF`, `InpStructureTF`, `InpPrimaryEntryTF`, and `InpSecondaryEntryTF`.
- The default H4/H1/M15/M5 structure is reproduced through inputs, while H1/M15/M5 variants use M5 as the main trigger.
- Primary and secondary entry candidates are both scored when secondary is enabled; the highest score is selected.
- First-60 time score is removed; time is retained as gate and diagnostic bucket only.
- Fib pullback is coarse diagnostic/scoring only, with no fine threshold optimization.

## Required Answers
0. Matrix completion: 0 / 72 runs completed. Missing rows are marked `missing_or_failed` in `comparison.csv`; the MT5 terminal stopped progressing after broker authorization/synchronization failures, so incomplete rows are not interpreted as strategy evidence.
1. London first120 count over 26: current default no_BE was `london_first120__current__no_be` not completed; best H1/M15/M5 London row was `london_first120__h1_m15_m5_strict__no_be` not completed.
2. PF / avg_R with trade count increase: compare the London rows above; low-count London remains diagnostic-only below 200 trades.
3. Better than current_default: best current_default row was `london_first120__current__no_be` not completed; best H1/M15/M5 row was `london_first120__h1_m15_m5_strict__no_be` not completed.
4. M5 trigger: best primary M5 row was `london_first120__h1_m15_m5_strict__no_be` not completed; entry timeframe details are in `entry_timeframe_breakdown.csv`.
5. M15 as structure confirmation: best dual-entry row was `london_first120__h1_m15_m5_dual__no_be` not completed.
6. Fib score: best fib-score row was `london_first120__h1_m15_m5_fib_score__no_be` not completed; fib zone details are in `fib_zone_breakdown.csv`.
7. Fib required: best fib-required row was `london_first120__h1_m15_m5_fib_req__no_be` not completed. If trades remain below 200 it is not promotable.
8. Outside London: best non-London row was `all_first120__current__no_be` not completed.
9. NewYork: best NewYork row was `newyork_first120__current__no_be` not completed.
10. 2025 shallow gate: no candidate passed.
11. 3-year fixed BT / OOS: advance only 2025 gate-pass candidates; no 3-year/OOS run is created when the 2025 gate has no pass.

## Evidence
- `comparison.csv`
- `timeframe_config_breakdown.csv`
- `session_breakdown.csv`
- `symbol_breakdown.csv`
- `direction_breakdown.csv`
- `entry_pattern_breakdown.csv`
- `entry_timeframe_breakdown.csv`
- `fib_zone_breakdown.csv`
- `retest_reference_breakdown.csv`
- `target_room_breakdown.csv`
- `monthly_breakdown.csv`
- `yearly_breakdown.csv`
- `r_metrics.csv`
- `run_matrix.csv`

## Incomplete MT5 Runs
The following run IDs did not produce a fresh MT5 report and are excluded from promotion decisions:

london_first120__current__no_be, london_first120__current__be_1_1r, london_first120__h1_m15_m5_strict__no_be, london_first120__h1_m15_m5_strict__be_1_1r, london_first120__h1_m15_m5_dual__no_be, london_first120__h1_m15_m5_dual__be_1_1r, london_first120__h1_m15_m5_top_notopp__no_be, london_first120__h1_m15_m5_top_notopp__be_1_1r, london_first120__h1_m15_m5_fib_score__no_be, london_first120__h1_m15_m5_fib_score__be_1_1r, london_first120__h1_m15_m5_fib_req__no_be, london_first120__h1_m15_m5_fib_req__be_1_1r, all_first120__current__no_be, all_first120__current__be_1_1r, all_first120__h1_m15_m5_strict__no_be, all_first120__h1_m15_m5_strict__be_1_1r, all_first120__h1_m15_m5_dual__no_be, all_first120__h1_m15_m5_dual__be_1_1r, all_first120__h1_m15_m5_top_notopp__no_be, all_first120__h1_m15_m5_top_notopp__be_1_1r, all_first120__h1_m15_m5_fib_score__no_be, all_first120__h1_m15_m5_fib_score__be_1_1r, all_first120__h1_m15_m5_fib_req__no_be, all_first120__h1_m15_m5_fib_req__be_1_1r, one_first120__current__no_be, one_first120__current__be_1_1r, one_first120__h1_m15_m5_strict__no_be, one_first120__h1_m15_m5_strict__be_1_1r, one_first120__h1_m15_m5_dual__no_be, one_first120__h1_m15_m5_dual__be_1_1r, one_first120__h1_m15_m5_top_notopp__no_be, one_first120__h1_m15_m5_top_notopp__be_1_1r, one_first120__h1_m15_m5_fib_score__no_be, one_first120__h1_m15_m5_fib_score__be_1_1r, one_first120__h1_m15_m5_fib_req__no_be, one_first120__h1_m15_m5_fib_req__be_1_1r, tokyo_first120__current__no_be, tokyo_first120__current__be_1_1r, tokyo_first120__h1_m15_m5_strict__no_be, tokyo_first120__h1_m15_m5_strict__be_1_1r, tokyo_first120__h1_m15_m5_dual__no_be, tokyo_first120__h1_m15_m5_dual__be_1_1r, tokyo_first120__h1_m15_m5_top_notopp__no_be, tokyo_first120__h1_m15_m5_top_notopp__be_1_1r, tokyo_first120__h1_m15_m5_fib_score__no_be, tokyo_first120__h1_m15_m5_fib_score__be_1_1r, tokyo_first120__h1_m15_m5_fib_req__no_be, tokyo_first120__h1_m15_m5_fib_req__be_1_1r, newyork_first120__current__no_be, newyork_first120__current__be_1_1r, newyork_first120__h1_m15_m5_strict__no_be, newyork_first120__h1_m15_m5_strict__be_1_1r, newyork_first120__h1_m15_m5_dual__no_be, newyork_first120__h1_m15_m5_dual__be_1_1r, newyork_first120__h1_m15_m5_top_notopp__no_be, newyork_first120__h1_m15_m5_top_notopp__be_1_1r, newyork_first120__h1_m15_m5_fib_score__no_be, newyork_first120__h1_m15_m5_fib_score__be_1_1r, newyork_first120__h1_m15_m5_fib_req__no_be, newyork_first120__h1_m15_m5_fib_req__be_1_1r, clean_first120__current__no_be, clean_first120__current__be_1_1r, clean_first120__h1_m15_m5_strict__no_be, clean_first120__h1_m15_m5_strict__be_1_1r, clean_first120__h1_m15_m5_dual__no_be, clean_first120__h1_m15_m5_dual__be_1_1r, clean_first120__h1_m15_m5_top_notopp__no_be, clean_first120__h1_m15_m5_top_notopp__be_1_1r, clean_first120__h1_m15_m5_fib_score__no_be, clean_first120__h1_m15_m5_fib_score__be_1_1r, clean_first120__h1_m15_m5_fib_req__no_be, clean_first120__h1_m15_m5_fib_req__be_1_1r
