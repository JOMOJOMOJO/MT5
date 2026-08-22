# Tick-shock REALIZABLE_EA execution revision: March 2025

## Decision

- Research pipeline: `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- March replay acceptance: `REALIZABLE_EA_MARCH_REPLAY_ACCEPTANCE_PASSED`
- Full execution validation: **not declared**; order-path observations remain incomplete
- Strategy feasibility: `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- Preliminary March label: `NO_EDGE_OBSERVED`
- Statistical conclusion: `EDGE_UNDETERMINED / insufficient statistical evidence`
- Long OOS, optimization, and trading-EA promotion: not started

The research EA remains unable to order by design. Formal research output now uses only `REALIZABLE_EA`; `IDEAL_EVENT_STUDY` is explicitly labeled event-time research and was not used for this March conclusion. The 7,452 attempted scenario labels are correlated variants over only 15 cross-symbol market clusters, so they are not 7,452 independent trades.

## Run identity

| Item | Value |
|---|---:|
| Run ID | `research_v7_realizable_202503_bounded_final` |
| EA | `ExpectedValue_MultiCurrency_TickShockResearch.mq5` v4.00 |
| EA SHA-256 | `976148D017E067728DC8827724516A076E7561C89D8D57BCD850D40DCB54A32C` |
| Execution include SHA-256 | `14577A74598F7974DCDD87097E83A1E1152B02D204C69CD327B8ED61F4EBA660` |
| Tester driver | `EURUSD,M1` |
| Symbols | EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF |
| Period | 2025-03-01 through 2025-04-01 |
| Model | MT5 real ticks, model 4 |
| Deposit / leverage | USD 10,000 / 1:100 |
| MT5 build | 6140, 21 Aug 2026 |
| Broker/server | VantageTradingLtd-Live |
| Strategy Tester runtime | 356.766 seconds |
| EA measured runtime | 350.703 seconds |
| Optimization | none |
| Research orders/deals | 0 / 0, by design |

## P0 execution-clock repair

The production research path now records `signal_event_msc`, `signal_processing_msc`, `entry_eligible_msc`, and `entry_quote_msc`. In `REALIZABLE_EA`:

`entry_eligible_msc = max(signal_event_msc + requested_delay_ms, signal_processing_msc + submit_latency_ms)`

Entry uses the first same-symbol real tick that is strictly later than the signal tick and is at or after both eligibility and processing. A grid quote can detect and arm a signal, but it cannot fill a scenario. Detection rows separately store grid time, underlying quote time, and quote age.

Failed-shock reversal is registered once at the actual continuation-invalidation tick. The following tick can fill it but cannot replace its signal clock. Global merge continues to order events and diagnose cross-symbol state; because the current EA still waits on its watermark, that delay is retained in `signal_processing_msc` and therefore in realizable execution latency.

## P1 definition and broker repair

- 250, 500, and 1,000ms returns use independent exact anchors; missing anchors serialize as blank plus a false valid flag.
- A `market_cluster_id` groups all symbols and detectors within an anchored two-second window. Counts are separately reported as 19 event rows, 17 symbol clusters, and 15 market clusters.
- TP is rounded outward by tick size. Long uses ceiling and Short uses floor; no valid scenario has realized RR below requested RR 1.2.
- StopsLevel feasibility is checked from stressed current Bid for Long and Ask for Short. FreezeLevel is a separate modification diagnostic.
- Spread 1.25x widens Bid/Ask around Mid while the unstressed absolute risk distance remains fixed.
- TP is a limit-barrier fill; SL uses the first tradable side beyond the stop plus adverse exit slippage; time exit uses the current tradable Bid/Ask.
- Cost/range policy bits are columns and do not erase a broker-feasible outcome.

## Deterministic and order-path verification

| Check | Result |
|---|---:|
| Research production-path harness | 18 PASS / 0 FAIL |
| Order harness | 40 observed PASS / 0 FAIL / 4 SKIP / 1 unit-only PASS |
| Research EA compile | 0 errors / 0 warnings |
| Research harness compile | 0 errors / 0 warnings |
| Order harness compile | 0 errors / 0 warnings |

The 18 research cases call the shared production execution functions and cover stale grid quotes, 600ms processing lag, 100/250ms delays, immutable reversal signal time, same-millisecond final quote, merge chronology, independent returns, cross-symbol clusters, outward RR rounding, Bid/Ask broker distance, separate freeze diagnostics, both clock modes, Long/Short reachability, SL gap/slippage, TP limit, and fixed-risk spread stress.

The order harness observed Long/Short `OrderCheck`, `OrderSend`, entry fill, deal aggregation, position-field recovery, both time exits, Long/Short server TP, and Short server SL. Long server SL did not occur within the configured barrier window. Actual partial fill and injected process restart were not observed. Those capabilities are `SKIP/NOT_OBSERVED` and are not in the PASS count. The partial-fill tracker passed a separate production-unit path and records requested, filled, and remaining volume, but that is not presented as an actual broker partial fill.

## March acceptance invariants

Both the EA writer and an independent PowerShell CSV parser passed:

| Invariant | Count |
|---|---:|
| entry before eligibility | 0 |
| entry before processing | 0 |
| stale detection-grid fill | 0 |
| reversal signal overwrite | 0 |
| global merge order violation | 0 |
| duplicate event ID | 0 |
| realized RR below requested 1.2 | 0 |
| CSV scenario-group mismatch | 0 of 552 groups |

Independent recount: 7,128 valid, 324 invalid, and all 552 strategy/stop/delay/spread groups match the EA summary to the six-decimal CSV output quantum.

## Event funnel

The event funnel did not change from v6. `true` counts are independent gate truth counts; table values are cumulative passes.

| Detector | Evaluable | Percentile | Robust Z | Efficiency | Intensity | Move/Spread | Spread OK / events |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 250ms | 5,149,702 | 33,487 | 32,674 | 32,637 | 3,641 | 1 | 1 |
| 500ms | 3,489,880 | 23,130 | 22,918 | 22,634 | 14,433 | 12 | 11 |
| 1,000ms | 904,567 | 5,960 | 5,949 | 5,706 | 1,873 | 7 | 7 |
| All | 9,544,149 | 62,577 | 61,541 | 60,977 | 19,947 | 20 | 19 |

Noise-floor use per baseline refresh was 95.9511% at 250ms, 83.0885% at 500ms, and 42.3471% at 1,000ms. This is a material research limitation; thresholds were not changed.

## Events, clusters, and state reachability

| Metric | Count |
|---|---:|
| Raw shock candidates | 62,577 |
| Event rows | 19 |
| Symbol clusters | 17 |
| Market clusters, statistical n | 15 |
| Market-overlap event rows | 4 |
| Long / Short events | 10 / 9 |
| Valid bursts | 19 |
| Valid pullbacks | 14 |
| Reacceleration signals | 5 |
| Detection-time continuation signals | 19 |
| Post-burst continuation signals | 19 |
| Pullback continuation signals | 5 |
| Failed-shock reversal signals | 11 |

Event rows by detector were 1 at 250ms, 11 at 500ms, and 7 at 1,000ms. Symbol event counts were EURUSD 5, GBPUSD 2, USDJPY 4, AUDUSD 0, USDCAD 8, and USDCHF 0. All six symbols delivered ticks.

Sessions were TOKYO 1, LONDON 3, NEW_YORK 9, OVERLAP 3, OTHER 3. HTF alignment was BOTH_ALIGNED 1, M15_ONLY 4, H1_ONLY 3, CONFLICT 5, NEUTRAL 6. Final state reasons were 11 continuation invalidations, 5 completed reaccelerations, 2 no-reacceleration expiries, and 1 shallow-pullback expiry.

Burst/spread distribution: n=19, min 4.444444, p25 4.889881, median 5.300000, p75 7.027778, p95 12.876852, max 14.018519.

## Realizable execution clocks

All 19 detection grid quotes were older than their grid time: quote-age min/median/max 9/107/274ms. None filled at the stale grid boundary. Global merge recognition lag was 412/543/2,388ms min/median/max and is included in the processing clock.

The table uses one fixed stop/spread cell per event because timing is common to the paired stop grid. `signal-to-entry` includes merge recognition; `processing-to-entry` is the residual same-symbol quote wait.

| Strategy | Requested delay | n | Signal-to-entry min/median/max ms | Processing-to-entry min/median/max ms |
|---|---:|---:|---:|---:|
| Detection continuation | 0 | 19 | 528 / 703 / 2,587 | 0 / 79 / 244 |
| Detection continuation | 100 | 19 | 528 / 703 / 2,587 | 0 / 79 / 244 |
| Detection continuation | 250 | 19 | 528 / 703 / 2,587 | 0 / 79 / 244 |
| Post-burst continuation | 0 | 19 | 232 / 519 / 2,157 | 0 / 78 / 206 |
| Post-burst continuation | 100 | 19 | 232 / 519 / 2,157 | 0 / 78 / 206 |
| Post-burst continuation | 250 | 19 | 297 / 519 / 2,157 | 0 / 133 / 233 |
| Pullback continuation | 0/100/250 | 5 | 604 / 732 / 914 | 0 / 46 / 160 |
| Failed-shock reversal | 0 | 11 | 233 / 516 / 568 | 0 / 28 / 204 |
| Failed-shock reversal | 100 | 11 | 233 / 516 / 568 | 0 / 28 / 204 |
| Failed-shock reversal | 250 | 11 | 269 / 516 / 568 | 0 / 138 / 273 |

The equality of several requested-delay rows is expected here: global processing time was already later than event time plus 100/250ms, so the `max(...)` processing branch dominated. It is not a retroactive fill.

## Barrier outcomes

| Outcome | Labels |
|---|---:|
| TP limit | 1,227 |
| SL gap/slippage | 2,820 |
| 120-second market exit | 3,081 |
| Broker-stop invalid | 324 |
| Valid total | 7,128 |

The aggregate valid-label mean was -0.292362R. By strategy: detection continuation -0.319703R, post-burst continuation -0.339913R, pullback continuation -0.218739R, and failed-shock reversal -0.196465R. These are descriptive means over correlated stop/delay/spread labels, not independent trade expectancy estimates.

Delay aggregates were -0.292284R at 0ms, -0.292284R at 100ms, and -0.292518R at 250ms. Spread 1.0x was -0.266128R and spread 1.25x was -0.318595R. USDJPY labels were positive (+0.105327R), while EURUSD, GBPUSD, and USDCAD were negative; this does not establish a USDJPY edge because market-cluster n is only 15 and variants are correlated.

The local order harness observed commission, fee, and swap as zero. Spread, entry/exit slippage, SL gaps, and time-side Bid/Ask are included; zero commission must not be generalized to another account or live execution.

## v6 versus final REALIZABLE_EA

| Metric | v6 | Final |
|---|---:|---:|
| Raw candidates | 62,577 | 62,577 |
| Event rows | 19 | 19 |
| Symbol clusters | 17 | 17 |
| Market clusters | not reported | 15 |
| Valid scenario labels | 7,452 | 7,128 |
| Invalid broker labels | 0 | 324 |
| Aggregate label mean R | -0.338143 | -0.292362 |
| Event CSV bytes | 2,852,152 | 5,149,647 |
| EA runtime seconds | 380.828 | 350.703 |

The funnel is unchanged; outcome differences come from the corrected clock, next-real-tick rule, broker quote-side feasibility, and added diagnostic fields. The two expectancy numbers are not directly comparable strategy estimates.

## Data volume and memory

- Allocated sample ring per symbol/detector: 3,610 at 250ms, 1,806 at 500ms, and 904 at 1,000ms. The 1-second series is therefore approximately the requested 900 samples, with exclusion/update guard cells.
- Tick ring per symbol: hard cap 8,192; a tick is discarded when it is older than 5,000ms from the newest tick, or overwritten at capacity.
- Grid ring per symbol: 64 points. Active event slots: 64. MFE/MAE tracking ends at 120 seconds.
- Global merge pending cap: 65,536; maximum observed 319; capacity hits 0.
- Same-millisecond groups: 4 groups / 8 ticks, maximum group size 2.
- EA-reported average/max memory: 10/10MB. Tester process reported 513MB total including 40MB history and 256MB tick data.
- Raw tick, detector-grid, timer, and per-second time-series CSV output: disabled.
- Event CSV: 19 rows, 5,149,647 bytes. Trade CSV: 0 rows, 15 bytes.
- Summary CSV: 217,833 bytes; symbol specs: 1,455 bytes.
- At this March event rate and the current 552-cell compact event grid, projected research CSV volume is about 64.4MB per 12 months and about 231MB per 43 months. This is only a linear storage estimate, not authority to run a multi-year test.

## Tick quality

The tester reported generated-tick fallback for GBPUSD in 179 of 30,187 minutes (0.5930%). No discarded-real-tick warning was observed for the other five symbols. This fallback matters for sub-second conclusions and remains a limitation.

## Conclusion and next gate

The March `REALIZABLE_EA` replay passes the requested chronology and CSV acceptance checks. It does **not** justify `EXECUTION_MODEL_VALIDATED`: Long server SL, actual partial fill, and injected process restart remain unobserved, and real live dispatcher latency has not been forward-demonstrated.

There is no present basis to start long OOS. Only 15 market clusters were observed, the correlated outcome grid was negative overall, and order-path evidence is incomplete. The next useful gate is targeted demo/tester observation of the skipped order lifecycle cases and explicit approval for any further period. Thresholds were not relaxed and no optimization was run.
