# Nested Third-Wave Launch Validation

## Scope

- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Change: added input-switchable `nested third-wave launch` diagnostics, score mode, and required mode.
- Concept: H1 context, M15 wave1/wave2 candidate, M5 corrective 123/invalidation, post-break retest, 75SMA/Granville diagnostics, M5 failure exit.
- Timeframes: tester period M15; EA inputs use `InpTopContextTF=PERIOD_H1(16385)`, `InpStructureTF=PERIOD_M15(15)`, `InpPrimaryEntryTF=PERIOD_M5(5)`.
- M5 scan verification: executed trade rows show `selected_candidate_timeframe=PERIOD_M5`.
- Compile: `compile.log`, result `0 errors, 0 warnings`.

## Runs

- Q1 quick check: 7 variants on `all_symbols_first120`.
- 2025 full-year validation: all-symbols variants `base`, `score`, `score_fibroom`, `req_m5inv`, `req_fibroom`.
- 2025 baseline scenario references: `one`, `ldn`, `tky`, `ny`, `clean`.
- The full matrix contains additional generated scenarios that were not promoted after all-symbols variants failed the 2025 gate.

## Q1 Quick Check

- `base`, `diag`, `score`, `score_fibroom`: 107 trades, PF 0.46, avg_R -0.2217, net -561.90, time exit 72.9%, avg_MFE 0.567R.
- `req_m5inv`: 33 trades, PF 0.31, avg_R -0.2647, net -211.77.
- `req_fibroom`: 47 trades, PF 0.24, avg_R -0.3130, net -350.60.
- `req_m15w2_m5inv` produced no trades in Q1 and was not advanced.

## 2025 All-Symbols

- `base`: 318 trades, PF 0.59, avg_R -0.1582, net -1144.89, time exit 74.2%, full SL 10.4%, TP 15.4%, avg_MFE 0.597R.
- `score`: identical to baseline. Nested score did not change trade selection.
- `score_fibroom`: identical to baseline. Context fib score did not change trade selection.
- `req_m5inv`: 90 trades, PF 0.49, avg_R -0.2073, net -442.32. It reduced count and worsened expectancy.
- `req_fibroom`: 185 trades, PF 0.61, avg_R -0.1415, net -608.50. It improved avg_R slightly but failed trade count and PF.

## Baseline Scenario References

- `tokyo_first120_reference`: 17 trades, PF 2.07, avg_R +0.2464.
- `clean_target_path_first120`: 9 trades, PF 1.68, avg_R +0.1656.
- `london_first120_reference`: 21 trades, PF 1.17, avg_R +0.0646.
- `one_symbol_first120`: 79 trades, PF 1.00, avg_R +0.0045.
- `newyork_first120_reference`: 27 trades, PF 0.86, avg_R -0.0436.
- None qualify for promotion because all are below 200 trades. London/Tokyo/Clean are research fragments only.

## Required Findings

1. c10 baseline improvement: no. All-symbols baseline remains PF 0.59 / avg_R -0.1582.
2. Nested diagnostic separation: partial. `m15_wave1=true` + `m15_wave2=true` bucket was positive in score mode, but only 21 trades.
3. M5 corrective invalidation: not effective as a hard gate. Required mode fell to 90 trades and PF 0.49.
4. M15 wave2 detection: it separates a small positive bucket, but is too sparse for promotion.
5. Post-break acceptance: too sparse. Only 3 score-mode trades and 1 required-mode trade passed.
6. H1 context fib room: `deep_618_786` bucket was positive, but only 26 trades; other room buckets were negative.
7. M15 wave2 fib zone: `room_382_618` was strong in score mode, but only 9 trades.
8. 75SMA / Granville: no robust hard-gate candidate. Positive-looking buckets are fragmented and below scale.
9. M5 failure exit: still reduces full SL, but does not create positive expectancy.
10. Time exit problem: not improved. All-symbols baseline/score time exit remains 74.2%; required modes remain 75-78%.
11. MFE: average MFE is only about 0.60R on all-symbols, below the 1.3R TP target.
12. TP vs entry quality: entry quality is the main issue. Many trades never develop enough MFE to justify TP, so lowering TP alone would not prove edge.
13. London dependency: no promotion. London has only 21 trades; Tokyo/Clean also have very low counts.
14. 2025 shallow gate: no candidates passed.
15. 3-year/OOS: not run. No 2025 gate pass exists.

## Artifacts

- `comparison.csv`
- `full2025_comparison.csv`
- `q1_comparison.csv`
- `trades_all_scenarios.csv`
- `nested_thirdwave_breakdown.csv`
- `m15_wave_breakdown.csv`
- `m5_corrective_invalidation_breakdown.csv`
- `post_break_acceptance_breakdown.csv`
- `context_fib_room_breakdown.csv`
- `m15_wave2_fib_breakdown.csv`
- `sma75_granville_breakdown.csv`
- `entry_pattern_breakdown.csv`
- `entry_timeframe_breakdown.csv`
- `session_breakdown.csv`
- `symbol_breakdown.csv`
- `direction_breakdown.csv`
- `exit_type_breakdown.csv`
- `mfe_mae_breakdown.csv`
- `monthly_breakdown.csv`
- `yearly_breakdown.csv`

## Decision

No operating candidate.

The added nested third-wave launch diagnostics are useful for research because they expose small positive sub-buckets, but the structure is not robust at portfolio scale. Do not promote to 3-year fixed BT or OOS. The next experiment should improve the precision of M15 wave2 completion and M5 invalidation/retest timing rather than adding more coarse score weight.
