# Step 15I: direction prediction after the high-movement filter

## 1. Objective

This development study separates two questions: whether a causal state identifies post-shock movement opportunity, and whether information already available at the decision time identifies its direction. It does not add an EA entry rule or place orders.

## 2. Existing evidence

Step 15G found the three proposed movement variables in both successful continuation and successful reversal paths. Against failed paths, F26 spread/ATR had standardized differences of -0.945 for continuation and -0.988 for reversal, F28 tick activity had +0.993 and +0.945, and F16-F18 raw ATR features were about +0.89 to +0.97. In the direct continuation-only versus reversal-only comparison these differences were small. The evidence therefore supported a movement-opportunity hypothesis, not a direction rule. Step 15H did not support a detection-time continuation filter and left formal net expectancy unavailable.

## 3. Population funnel

The formal Step 15G March run supplies 21,799 statistical detector events in 10,245 market clusters and 3,151 persistent episodes in 2,909 clusters. The primary +60s/RR1.2/900s join leaves 1,675 eligible episodes in 1,553 clusters. Exclusions are 1,059 unavailable decision feature rows and 417 GBPUSD episodes affected by the unresolved generated-tick interval map. A further 500 otherwise eligible episodes are warm-up rows with fewer than 100 strictly earlier same-symbol observations. The causal quantile-ready population is 1,175 episodes in 1,108 clusters; the preregistered three-condition intersection selects 48 episodes in 48 clusters.

The selected population is concentrated: USDJPY 29, AUDUSD 12, USDCAD 6, EURUSD 1; GBPUSD and USDCHF 0. By the stated server-hour labeling it contains NEW_YORK 39, OVERLAP 4, OTHER 3, TOKYO 1 and LONDON 1. It spans 11 server days, with no single day above 10 episodes.

## 4. High-movement filter definition

No fixed Step 15G/H trading threshold existed. Before calculating outcomes, `15i_direction_prediction_preanalysis.md` froze a mechanical causal rule per symbol:

- F26 spread/ATR at or below its past-only 30th percentile;
- F28 tick activity at or above its past-only 70th percentile;
- F17 completed-M5 ATR14 at or above its past-only 70th percentile;
- at least 100 strictly earlier eligible same-symbol episodes.

The current row and all future rows are excluded from threshold construction. No alternate percentile was searched.

## 5. High-movement validation

The selected group reaches either action's 1.2R TP in 41.67% of episodes versus 18.81% outside the filter, a +22.86 percentage-point cluster-bootstrap difference (95% CI +9.07 to +37.45 points). Continuation TP is 22.92% versus 10.03%; reversal TP is 18.75% versus 8.78%. Absolute recorded excursion is larger, but pooled price-unit differences are descriptive only because symbols use different price scales.

The interpretation is not uniformly favorable. Maximum excursion divided by M5 ATR is 0.858 in the selected group versus 1.449 elsewhere, with a mean difference of -0.591 (95% cluster-bootstrap CI -0.708 to -0.465). The filter identifies larger absolute-volatility regimes and more registered barrier touches, but not larger movement relative to its already-high ATR denominator. `HIGH_MOVEMENT_FILTER_SUPPORTED` is therefore limited to the registered economic barrier opportunity, not a claim of superior ATR-normalized excursion.

## 6. Direction label definition

The label uses the unchanged Step 15G Bid/Ask first-touch paths at the +60-second causal decision checkpoint, RR 1.2 and the 900-second anchor horizon. If the continuation TP is first, the label is `CONTINUATION`; if the reversal TP is first, it is `REVERSAL`; if neither TP is first, it is `NEUTRAL_TIMEOUT`. Equal first-touch milliseconds would be `AMBIGUOUS_SAME_MSC` and excluded. None occurred.

This is not a detection-time immediate-entry label. It answers direction at the registered +60-second checkpoint and must not be substituted for Step 15H's t0 question.

## 7. Direction counts

Among 48 selected clusters there are 11 Continuation, 9 Reversal and 28 Neutral/Timeout episodes. Thus only 20 directional successes are available. Conditional on either directional TP, continuation is 55% and reversal 45%; this ten-point difference is far too small for a directional claim at n=20.

## 8. Feature analysis

All 36 Step 15F/15G causal context features plus three causal percentile positions were evaluated. The largest direct Continuation-versus-Reversal standardized difference is F14 trend efficiency over 15 minutes (`d=1.02`, rank-biserial 0.556, unadjusted Mann-Whitney p=0.040). It is based on only 11 versus 9 episodes and does not survive family-wise adjustment. F13 pre-shock five-minute momentum points in the opposite direction from the preregistered continuation hypothesis (`d=-0.775`, unadjusted p=0.095). No feature supplies confirmed directional separation.

Requested 30-second, exact 60-second, three-minute and H1 features, session/rolling-high distances, Bollinger position, shock duration, acceleration and staged-shock descriptors are not present in the causal +60-second Step 15G feature record. They were not reconstructed from future paths or silently approximated.

## 9. Bin analysis

Five causal past-only percentile bins were produced for numeric features. Twenty-one feature-bin cells reach 20 clusters, mostly because discrete features tie into one cell or because the selection rule itself concentrates spread/ATR, activity and ATR into their required tails. No feature has five adequately supported bins. Trend efficiency rises descriptively from 25% continuation among directional outcomes in its low bin to 80% in mid-high and 100% in high, but those cells contain only 10, 12 and 7 clusters respectively. The CSV retains counts, Continuation/Reversal/Neutral rates, Wilson intervals and both action R means; this sparse curve is hypothesis material, not edge evidence.

## 10. Continuation versus Reversal

The direct comparison ranks trend efficiency first, followed by negatively signed pre-shock momentum, M1 ATR and spread/ATR. The three high-movement variables themselves do not robustly distinguish the 11 continuation cases from the 9 reversal cases. Neutral remains a separate 28-episode class rather than being assigned to either direction.

## 11. Candidate hypotheses

All four preregistered simple rules fail as economic direction selectors under C2 diagnostic costs:

| Hypothesis | Selected clusters | Directional accuracy | Neutral rate | Selected action mean C2 R |
|---|---:|---:|---:|---:|
| M15 alignment | 48 | 25.0% | 58.3% | -0.392 |
| pre-shock 5m momentum | 48 | 12.5% | 58.3% | -0.562 |
| directional range position | 17 | 17.6% | 58.8% | -0.603 |
| M15 plus momentum agreement | 24 | 8.3% | 75.0% | -0.709 |

The range-position subset also fails the 20-cluster gate. A machine-learning search was not justified after these sparse, unstable univariate results.

## 12. Limitations

- March 2025 is repeatedly reused development data, not OOS.
- The filter leaves 48 clusters and only 20 directional labels.
- USDJPY and NEW_YORK dominate the selected population; two symbols have no selected rows.
- GBPUSD remains excluded due generated-tick fallback provenance.
- The formal six-symbol commission model remains incomplete, so the reported R is Step 15G C2 diagnostic stress, not formal net expectancy.
- The +60-second time base cannot answer immediate detection-time direction.
- Multiple feature comparisons were descriptive; the sole unadjusted p below 0.05 is not confirmatory.

QA completed with research-EA compile 0 errors / 0 warnings and the full deterministic suite at PASS 407, FAIL/XFAIL/XPASS/BLOCKED 0, SKIP 9. The remaining SKIP are terminal-only observations. Step 15I checks report feature/entry causality violations 0, duplicate episode IDs 0, market-cluster spans above two seconds 0, invalid eligible paths 0, ambiguous same-millisecond labels 0 and orders 0. The independent oracle rebuilt every past-only threshold and all headline counts with zero mismatch. The suite initially exposed that Step 15H's suite-level oracle provenance was not recognized by the generic Python integrity test; the test now validates the existing Step 15H oracle/spec pair without altering any fixture or expected value.

## 13. Decision

- `HIGH_MOVEMENT_FILTER_SUPPORTED` for registered barrier opportunity, with the ATR-normalized caveat above.
- `NO_DIRECTIONAL_SIGNAL_FOUND` for the frozen simple rules.
- `INCONCLUSIVE_SAMPLE_SIZE` for feature-level direction discovery.
- `OOS_VALIDATION_REQUIRED` before any directional hypothesis can be promoted.
- `PRODUCTION_NOT_ELIGIBLE`.

## 14. Next step

Do not optimize the 30/70 cutoffs on March. First decide whether the research question should remain at +60 seconds or move back to a separately recorded detection-time symmetric continuation/reversal label. For a future study, freeze one parsimonious hypothesis before opening a genuinely unused period, require broader symbol/session support, and complete commission evidence. The present results do not justify a production EA rule or long OOS sweep.

Primary evidence is under `reports/analysis/tick_shock/step15i/`; the independent oracle reproduces all headline counts and causal thresholds.
