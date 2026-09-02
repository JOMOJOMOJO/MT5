# Step 15J: post-shock excursion / TP-SL / holding-time results

## 1. Objective
Measure the causal executable price path after the unchanged persistent-shock confirmation before imposing barriers. This is a March 2025 development study, not a production strategy test.

## 2. Existing geometry audit
Analysis-ready episodes: 2,732 in 2,572 market clusters. The existing SL is spread-dominated in all 2,732 episodes; ATR and broker minimum dominate zero. Median SL is 1.626 ATR and median TP is 1.957 ATR. Continuation records 610 TP-first, 1,413 SL-first and 709 timeouts; reversal records 616, 1,399 and 717. In the dominant `>=1.50 ATR` SL bin, TP-first falls to 13.85% in both directions and timeout is about 45%. The episode and bin evidence are in `existing_sl_tp_geometry_audit.csv` and `existing_sl_tp_geometry_bins.csv`. Verdict: `SPREAD_DOMINATED_SL_CONFIRMED` and `EXISTING_SL_GEOMETRY_NOT_SUPPORTED` for a short-horizon shock trade.

## 3. t0 definition
Statistical time is the detector candidate time, confirmation time is the persistent confirmation grid, processing time is when the global-watermark EA recognized it, and primary t0 is that processing time. Entry/reference is the first valid same-symbol real quote at or after t0 and strictly after the confirmation quote. Median confirmation-to-processing lag is 900 ms (P95 6,755.5 ms); median t0-to-entry-quote lag is 185 ms (P95 2,153 ms). Pre-t0 fills: 0. The statistical detector, persistent confirmation, processing clock and chosen t0 are retained as separate columns.

## 4. Population funnel
Detector rows 21,799 -> episodes 3,151 (2,909 clusters) -> t0 quote 3,151 -> full 60m path 3,148 -> analysis-ready 2,732 (2,572 clusters) -> t0 high-movement 185 (183 clusters). Three end-of-period episodes are censored. GBPUSD's 417 rows remain in raw evidence but are excluded from formal normalized estimates because its interval provenance remains unresolved: the journal reports 179 generated-fallback minutes out of 30,187 tester minute bars.

The unchanged episode rule is symbol-local: a persistent confirmation opens a 900-second episode, additional same- and opposite-direction shocks become repeat annotations, and after the horizon a 60-second quiet cooldown is required. Repeats do not create new episodes. The Step 15J 60-minute recorder is a separate fixed pool and does not alter that episode construction.

## 5. MFE/MAE methodology
Continuation follows shock direction and reversal uses the opposite direction. Long enters Ask/exits Bid; short enters Bid/exits Ask. MFE/MAE are accumulated before barriers and normalized by completed M5 ATR14 frozen at t0.

## 6. Horizon comparison
At 30/60/120 seconds the median executable MFE is zero in both directions because spread has not yet been recovered by at least half the population. At 5/10/15/30/60 minutes, continuation median MFE/ATR is 0.000/0.198/0.343/0.662/1.083; reversal is 0.036/0.205/0.337/0.634/1.102. At 60 minutes median MAE/ATR is 2.074 continuation and 2.060 reversal. Full mean, standard deviation and P10/P25/P50/P75/P90/P95 paths appear in `horizon_excursion_summary.csv`.

## 7. Edge lifetime
Median 15-minute MFE captures only 47.2% of the eventual 60-minute continuation MFE and 46.0% of reversal MFE. At 30 minutes the fractions are 88.7% and 91.8%, but the final 30 minutes still add 0.421 and 0.468 ATR to the median. MAE also continues to grow materially. This is `HOLDING_EDGE_PERSISTS` in the descriptive excursion sense; it is not evidence that a 60-minute position has positive expectancy.

## 8. Distance hit analysis
Either side reaches 0.40 ATR in 98.32% of analysis-ready episodes; median hit time is 329.4s. Direction-specific rates are 70.53% continuation and 70.72% reversal with median times of 518.3 and 521.7 seconds. Even 1.0 ATR is reached by about 52.3% on each individual side, but only over median times near 17 minutes. All 0.10-1.50 ATR distances are in `distance_time_to_hit.csv`.

## 9. Pre-TP MAE analysis
For continuation TP candidates 0.20/0.30/0.40/0.50 ATR, median pre-TP MAE is 0.875/0.893/0.922/0.953 ATR and P75 is 1.441/1.448/1.491/1.517 ATR. Reversal is nearly identical: medians 0.855/0.889/0.925/0.948 and P75 1.449/1.494/1.522/1.558 ATR. A small TP is therefore often reached only after a much larger excursion in the opposite direction; the high either-side hit rate is not directly tradable without direction information.

## 10. TP reasonable range
The coarse 0.20-0.50 ATR band is reachable by 67.5%-77.4% per direction within 60 minutes, with median first-hit times of roughly 5.5-10 minutes. It is a plausible research band, so `TP_DISTANCE_REASONABLE` applies to this registered 60-minute horizon. The existing median TP of 1.957 ATR is `TP_DISTANCE_TOO_FAR_FOR_REGISTERED_HORIZON` for most episodes. No fine optimum is selected.

## 11. SL reasonable range
The pre-TP distributions imply that retaining half of eventual 0.20-0.50 ATR TP hits requires roughly 0.85-0.95 ATR adverse tolerance, and retaining 75% requires about 1.44-1.56 ATR. These are descriptive bands, not recommended stops: they are too wide relative to the candidate TP to preserve attractive RR. A later conversion study must introduce direction and maximum-hold constraints before freezing an SL.

## 12. RR implications
Combining a 0.20-0.50 ATR TP with the median-success pre-TP MAE band of 0.85-0.95 ATR gives an indicative RR of only about 0.21-0.59; using P75 adverse tolerance is lower. RR 1.2 is not naturally supported by this unconditional, direction-agnostic population. This does not authorize lowering RR: it shows that direction/entry conditioning is required before TP/SL can be frozen. `PARAMETER_FREEZE_NOT_READY`.

## 13. Spread redesign findings
Median entry spread is 0.402 ATR. Because the current rule multiplies it by four, spread determines every formal SL and inflates both SL and its 1.2R TP. The evidence supports treating spread/ATR and spread relative to candidate TP/SL as trade-feasibility diagnostics rather than automatically widening the stop. No production `DO_NOT_TRADE` threshold is selected here.

## 14. Symbol robustness
At 60 minutes median continuation MFE ranges from 0.759 ATR (AUDUSD) to 1.313 (USDJPY); reversal ranges from 0.889 (USDCAD) to 1.377 (EURUSD). Median existing SL ranges from 0.922 ATR (USDJPY) to 2.955 (AUDUSD), despite every symbol being spread-dominated. USDJPY contributes 1,018/2,732 analysis-ready episodes (37.3%) and 92/185 high-movement rows. This is `CROSS_SYMBOL_GEOMETRY_NOT_ROBUST`.

## 15. Session diagnostics
At 0.40 ATR, continuation hit rates range from 58.8% in OTHER to 75.6% in OVERLAP; reversal ranges from 63.2% to 77.0%. The labels use unchanged server-hour definitions. These differences are descriptive and no session filter is created.

## 16. Limitations
March is repeatedly used development data; GBPUSD fallback provenance and six-symbol formal commission remain incomplete. The high-movement population is only 185 rows/183 clusters and is concentrated in USDJPY (92), USDCAD (47), and AUDUSD (36), with only five each in EURUSD and USDCHF. Episode construction compresses repeated same-symbol shocks during the 15-minute episode and 60-second cooldown. A 60-minute research horizon is not a proposed holding time. `INSUFFICIENT_SAMPLE_SIZE` applies to high-movement cross-symbol inference.

## 17. Decision
`EXISTING_SL_GEOMETRY_NOT_SUPPORTED`; `SPREAD_DOMINATED_SL_CONFIRMED`; `TP_DISTANCE_REASONABLE` for the coarse 0.20-0.50 ATR research band; `TP_DISTANCE_TOO_FAR_FOR_REGISTERED_HORIZON` for the existing median 1.957 ATR target; `HOLDING_EDGE_PERSISTS`; `CROSS_SYMBOL_GEOMETRY_NOT_ROBUST`; `INSUFFICIENT_SAMPLE_SIZE`; `PARAMETER_FREEZE_NOT_READY`; `OOS_VALIDATION_REQUIRED`; `PRODUCTION_NOT_ELIGIBLE`.

## 18. Recommended next research step
Do not freeze a stop from this unconditional path. First preregister a direction-conditioned conversion study using the coarse TP range 0.20-0.50 ATR and coarse holding landmarks 10/15/30/60 minutes, then measure barrier outcomes under complete commission and tick-quality evidence. Only after that should one geometry be frozen for a genuinely unused OOS period. Production entry logic remains unchanged in Step 15J.

Formal run: `reports/backtest/runs/20260902_ts15j_post_shock_excursion_r2_202503/`. Analysis: `reports/analysis/tick_shock/step15j/`. Compile is 0 errors / 0 warnings; deterministic regression is 407 PASS, 0 FAIL, 9 terminal-only SKIP; the Step 15J production harness is 6/6 PASS. Causal, duplicate, invalid-path, feature-time, cluster-span, order and trade violations are all zero. Independent oracle: 23/23 PASS. Against Step 15H, all 21,799 detector rows across 52 non-identity columns and all 3,151 episode rows across 39 non-identity columns match exactly. Tester runtime is 11m42.480s and peak reported memory is 502 MB.
