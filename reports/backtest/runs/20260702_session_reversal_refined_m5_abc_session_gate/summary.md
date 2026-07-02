# Refined M5 ABC Invalidation And Session Gate Diagnostics

## Scope

- EA: `ExpectedValue_MultiCurrency_FXSessionReversalPullbackTrader`
- Change: added session gate modes, refined M15 wave2 context, refined M5 corrective ABC/123, close-break invalidation, post-break acceptance/retest diagnostics, MFE threshold tracking, and coarse exit mode labels.
- Timeframes: tester period M15; EA inputs use `InpTopContextTF=PERIOD_H1(16385)`, `InpStructureTF=PERIOD_M15(15)`, `InpPrimaryEntryTF=PERIOD_M5(5)`.
- M5 scan verification: all 2470 collected trade rows show `selected_candidate_timeframe=PERIOD_M5`.
- Tester safety: generated tester ini files use `Enabled=0` and `AllowLiveTrading=0`.
- Compile: `compile.log`, result `0 errors, 0 warnings`.

## Q1 Quick Check

- `base`: 107 trades, PF 0.46, avg_R -0.2217, avg_MFE 0.567R.
- `no_session_gate_baseline`: 111 trades, PF 0.45, avg_R -0.2236, avg_MFE 0.562R.
- `m5_abc_score`: unchanged from baseline; score did not alter all-symbol selection.
- `m5_abc_invalidation_required`: 3 trades, PF 0.00, avg_R -0.2451.
- `m5_abc_acceptance_required`: 3 trades, PF 2.05, avg_R +0.2271, but too small to promote.
- `m15_wave2_required_light_m5_abc_score`: 18 trades, PF 1.16, avg_R +0.0472, still too small for fixed validation candidacy.

## 2025 All-Symbols

- `baseline_c10`: 318 trades, PF 0.59, avg_R -0.1582, net -1144.89, time exit 74.2%, full SL 10.4%, TP 15.4%, avg_MFE 0.597R, MFE>=1R 24.5%, MFE>=1.3R 12.6%.
- `no_session_gate_baseline`: 324 trades, PF 0.59, avg_R -0.1564, net -1151.16, avg_MFE 0.595R. Removing session gate did not improve expectancy or MFE.
- `m5_abc_score`: unchanged from baseline.
- `m5_abc_invalidation_required`: 18 trades, PF 0.58, avg_R -0.1701, avg_MFE 0.565R. Required close-break invalidation reduced count and worsened expectancy.
- `m5_abc_acceptance_required`: 10 trades, PF 0.88, avg_R -0.0480. Acceptance/retest was too strict and still not profitable.
- `m15_wave2_required_light_m5_abc_score`: 50 trades, PF 1.34, avg_R +0.1099, net +134.29, avg_MFE 0.781R, MFE>=1R 40.0%, MFE>=1.3R 24.0%. This is the best research fragment, but it is below 200 trades.
- `no_session_gate_m5_abc_required`: 27 trades, PF 0.69, avg_R -0.1132.

## Session References

- `tokyo_first120_reference`: 17 trades, PF 2.07, avg_R +0.2464.
- `clean_target_path_first120`: 9 trades, PF 1.68, avg_R +0.1656.
- `london_first120_reference`: 21 trades, PF 1.17, avg_R +0.0646.
- These are research fragments only. They are below 200 trades and cannot support promotion.

## Required Findings

1. Baseline c10 improvement: no robust operating improvement. The only all-symbol positive candidate has 50 trades.
2. Session gate removal: no. Trades rose only from 318 to 324 and PF/avg_R stayed negative.
3. Session first120 distortion: not the primary issue. No-session did not improve MFE or expectancy.
4. M5 ABC/123 corrective detection: weak. Detected buckets were small; required mode produced only 18 trades and PF 0.58.
5. M5 invalidation close break: not effective as a hard gate. Required close-break invalidation worsened expectancy.
6. Post-break acceptance: too strict. It produced 10 full-year trades and did not reach positive expectancy.
7. First retest required: too sparse to promote; it does not fix entry quality at portfolio scale.
8. M15 wave2 context: useful as a research filter. Required-light M15 wave2 improved PF/avg_R/MFE, but reduced trade count to 50.
9. MFE 1R separation: baseline reached 1R in 24.5% of trades; M15-light candidate reached 1R in 40.0%.
10. Time exit problem: not solved for baseline/no-session. M15-light improved time exit to 56.0%, but with only 50 trades.
11. Full SL vs TP/MFE: full SL remains low enough; the problem is still insufficient launch/MFE, not SL management.
12. Tokyo/London/Clean dependency: not used for promotion because all are small samples.
13. 2025 shallow gate: no candidates passed.
14. 3-year/OOS: not run because no 2025 gate pass exists.

## Decision

No operating candidate.

The refined M15 wave2 context is the most useful finding. It improves the quality signal and increases MFE, but it is too selective. The refined M5 ABC/123 invalidation is not yet a reliable definition of "M15 wave2 completed by M5 opposite 123 denial"; as a hard gate it removes too many trades and leaves expectancy negative. The next useful experiment should focus on making the M15 wave2 context less sparse while preserving the MFE lift, rather than tightening the M5 invalidation further.
