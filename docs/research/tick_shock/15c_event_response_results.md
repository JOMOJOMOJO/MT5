# Step 15C event response results

## Scope and verdict

This is a March 2025 development study of the frozen `TAIL_V1_PERSISTENT`
detector. It is not locked OOS, strategy optimization, an order-enabled EA, or
production evidence.

Formal result:

- `EVENT_RESPONSE_PATHS_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- `NO_CONDITIONAL_RESPONSE_BIAS_SUPPORTED`
- `NO_STRATEGY_CANDIDATE_PROMOTED`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

Discovery showed a negative shock-direction return at 10 seconds, but the
effect reversed sign and was not significant in the one-shot internal
confirmation. No positive continuation primary outcome passed in either
partition. No policy candidate was carried forward.

## Population, causality, and regression

| population | event rows | market-cluster representatives | response episodes |
|---|---:|---:|---:|
| Discovery | 16,913 | 7,350 | 2,190 |
| Purge | 1 | 1 | 1 |
| Internal confirmation | 4,885 | 2,894 | 1,095 |
| Total | 21,799 | 10,245 | 3,286 total: 3,285 analyzed + 1 purged |

The split was frozen before response analysis. Candidate registry commit
`db071af4` precedes the first confirmation read. The purge episode separates
the overlapping 120-second windows.

All symbol-level counts reported for Discovery plus Internal confirmation use
the 21,798-row population labelled
`ANALYZED_PARTITIONS_ONLY_EXCLUDING_PURGE`. The single purge row is retained
separately and is not silently assigned to either analyzed partition.

The r5 replay preserved all 21,799 Step 15B detector-feature rows and all
21,799 strategy-funnel rows, excluding only run identity. Representative
reachability remained detection 10,245, post-burst 10,245 (10,244 fills),
pullback 1,033, and failed-shock reversal 7,282 (7,281 fills). Market clusters
remained 10,245. Horizon quote-before-boundary, future read, backdate, drop,
invalid row, and duplicate counts are all zero.

The response recorder is bounded per active event: eleven fixed horizons,
online MFE/MAE, origin recross, and three local-sigma first-passage pairs. It
does not write an all-tick CSV. The legacy detector/funnel state is frozen at
its original first 120-second grid boundary; only response tracking may outlive
that boundary to obtain the first real quote for a stale horizon.

## Where shocks occurred

Event-row counts across the full development month were USDJPY 9,690, USDCAD
3,998, AUDUSD 2,732, GBPUSD 2,114, USDCHF 1,649, and EURUSD 1,615. Long/Short
counts were 10,682 / 11,117. Event rows are not independent samples; inference
uses market-cluster representatives and response episodes.

Discovery was concentrated in server-hour 15 (2,748 rows) and 17 (2,194), and
the largest server-date counts were March 5 (2,202), March 7 (2,038), March 11
(1,947), and March 6 (1,807). These are broker-server labels. UTC/JST mapping
was not independently proved, so timezone conversion remains
`TIMEZONE_MAPPING_NOT_VERIFIED`.

## Price path

Primary effects below are means of market-cluster representatives aggregated
to independent response episodes, with 10,000 stationary-block bootstrap
replicates (mean block 4, seed 20260828) and Holm correction.

| horizon | Discovery effect | Discovery 95% CI | Holm p | Confirmation effect | Confirmation 95% CI | Holm p |
|---:|---:|---:|---:|---:|---:|---:|
| 1s | -1.315e-6 | [-2.399e-6, -0.227e-6] | 0.080 | -0.217e-6 | [-1.609e-6, 1.184e-6] | 1.000 |
| 3s | -1.329e-6 | [-2.996e-6, 0.310e-6] | 0.326 | 1.111e-6 | [-0.790e-6, 3.013e-6] | 1.000 |
| 10s | -4.227e-6 | [-7.140e-6, -1.249e-6] | 0.031 | 0.965e-6 | [-2.022e-6, 4.046e-6] | 1.000 |
| 30s | -3.024e-6 | [-7.463e-6, 1.566e-6] | 0.402 | 1.887e-6 | [-3.059e-6, 6.823e-6] | 1.000 |
| 120s | -10.846e-6 | [-18.966e-6, -2.452e-6] | 0.055 | -3.186e-6 | [-12.054e-6, 5.583e-6] | 1.000 |

The Discovery 10-second negative effect is not internally confirmed: its sign
became positive and its interval crossed zero. The 120-second effect retained a
negative point estimate but also crossed zero in confirmation.

Origin recross occurred for 87.3% of Discovery event rows and 86.6% of
confirmation rows (representative rates 87.28% and 85.90%). Median times to MFE
/ MAE were 44.1s / 49.4s in Discovery and 43.4s / 53.3s in confirmation.

At the one-local-sigma barrier, Discovery representatives were 3,608
continuation-first, 3,737 reversal-first, and 5 timeout. Confirmation was 1,467
continuation-first, 1,423 reversal-first, and 4 timeout. Episode-bootstrap
continuation-minus-reversal effects were -0.00938 (95% CI -0.0443 to 0.0255)
and +0.01922 (-0.0343 to 0.0743), respectively. Neither is supported.

Raw price-unit MFE/MAE must not be compared across JPY and non-JPY symbols.
Representative medians normalized by initial shock were 5.67/5.51 in Discovery
and 5.33/5.00 in confirmation. Large excursions in both directions and the high
recross rate explain why a fixed-horizon mean alone is not an executable edge.

## Conditional features and existing gates

Conditional tables preserve symbol, server hour/day, severity, horizon,
volatility regime, and frozen Discovery quantile boundaries. Confirmation uses
the saved Discovery boundaries; it does not rebucket itself. Secondary rows are
exploratory and do not override the primary family.

Seven Discovery event rows and three confirmation rows passed all recorded
gates. Discovery leave-one-out reach was 22 without activity and 1,694 without
cost feasibility; confirmation was 4 and 526. This describes overlap only. It
does not prove activity or cost is causal, and no gate was removed or relaxed.

## Strategy and RR conclusion

The four reference strategy clocks remain causally recorded, but fixed-horizon
response snapshots cannot determine arbitrary Bid/Ask TP-versus-SL first touch
for every entry/stop/RR/delay/spread cell. All 2,760 research grid labels per
partition are therefore `NOT_EVALUABLE_WITH_FIXED_HORIZON_ONLY`. They are not
counted as trades, losses, or zero-R outcomes.

Consequently gross ExpectancyR, after-spread ExpectancyR, and formal net
ExpectancyR are unavailable for the proposed grid. Commission evidence is not
broker-verified across all six symbols. Break-even commission and a highest-RR
selection are also unavailable. The shortlist contains zero policy rows and
the frozen registry retains only `NO_TRADE`.

An exact RR study would require a separately preregistered, bounded online
Bid/Ask barrier recorder tied to each causal strategy entry. It must be tested
before another March replay; it must not reconstruct first touch from these
fixed snapshots.

## Operational evidence and limitations

- Strategy Tester runtime: 553.156 seconds.
- Average / maximum memory: 28.502 / 29 MB.
- `event_response.csv`: 21,799 rows, 54,326,606 bytes (51.81 MiB).
- Full-tick and one-row-per-second CSV output: absent.
- Compile: 14/14 targets, 0 errors / 0 warnings.
- Step 15C deterministic tests: 42 PASS.
- Step 15B control tests: 29 PASS.
- Current Step 15A detector rerun: 24 PASS / 1 FAIL.
- Existing Step 14R deterministic base: 86 PASS / 9 SKIP.

The sole FAIL is historical provenance test `TS15A-PROV-001`: Step 15B changed
the feature schema label from v1 to v2, while the frozen Step 15A expected file
still says v1. Step 15C did not rewrite the expected value or mislabel the
current schema to force GREEN. This evidence inconsistency prevents claiming a
fully GREEN aggregate even though Step 15C behavior and causal audits pass.

Do not start locked OOS, optimization, or production promotion from this Step.
The next gate is to resolve the schema-provenance specification explicitly and,
if the user wants executable strategy evidence, preregister an online RR/barrier
study with complete spread/commission handling.
