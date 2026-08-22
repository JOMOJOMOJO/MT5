# Tick-shock execution-model revision: March 2025

## Verdict

- Research pipeline: `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- Execution model revision: `VALIDATED_BY_18_REACHABILITY_TESTS`
- Strategy feasibility: `STRATEGY_FEASIBILITY_NOT_ESTABLISHED`
- Stage-4 provisional label: `NO_EDGE_OBSERVED`
- Statistical qualification: `EDGE_UNDETERMINED / insufficient statistical evidence`
- Long OOS: not started. This run does not justify automatic multi-year validation.

`NO_EDGE_OBSERVED` is scoped to this March 2025 definition and configured stop grid. It is not a claim that no tick-shock edge can exist. The independent evidence is 17 event clusters, not 7,452 scenario outcomes.

## Run identity

| Item | Value |
|---|---:|
| Run ID | `research_v6_execution_revision_202503_final` |
| EA | `ExpectedValue_MultiCurrency_TickShockResearch.mq5` |
| EA SHA-256 | `969AC0350AA64EAA1AFFFFECCA660E8CB2FB3877F4280186215A0E89251455C3` |
| Shared include SHA-256 | `3F943BA650A45A5C4D7CA587C342A1AFF00D9FDF3C5533BE7AFDB5E6E173A6ED` |
| Tester driver | `EURUSD,M1` |
| Symbols | EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF |
| Period | 2025-03-01 through 2025-04-01 (tester actually begins first available market tick) |
| Model | MT5 real ticks, model 4 |
| Deposit / leverage | USD 10,000 / 1:100 |
| MT5 build | 6140, 21 Aug 2026 |
| Broker/server | VantageTradingLtd-Live |
| Runtime | 380.828 seconds |
| Optimization | none |
| Orders/deals from research EA | 0 / 0, by design |

Inputs are preserved in `ExpectedValue_MultiCurrency_TickShockResearch_revision_202503.set`; tester configuration and the generated HTML report are in this directory.

## What was revised

1. Global merge time remains an event-ordering clock only. It no longer floors execution time.
2. Each scenario fills on the first quote of the same symbol at or after `signal_time + requested_delay`.
3. Detection-time continuation uses only the detection-time shock range. Post-burst continuation is a separate strategy.
4. `spread/risk <= 0.20` and `risk/known_range <= 0.45` are diagnostic policy bits. They do not erase a broker-feasible barrier outcome.
5. Every stop from 1.0x through 12.0x the unstressed fill spread, in 0.5x increments, is evaluated at RR 1.2.
6. The absolute risk distance is paired and fixed between spread 1.0x and 1.25x. Only Bid/Ask are widened around Mid.
7. Same-symbol ticks sharing `time_msc` are grouped; the last quote closes the grid boundary.
8. TP is filled at the limit barrier; SL uses the first tradable exit-side quote beyond the stop plus one adverse tick; time exits use the current tradable Bid/Ask.
9. Commission is included through the configured round-turn amount. The local order harness observed commission, fee and swap of zero, so this run used zero and records that evidence source. This is not a universal broker-cost claim.
10. 250, 500 and 1,000ms use independent boundaries, baselines and detectors.

## Deterministic validation

- Research reachability harness: 18/18 PASS.
- Order reachability harness: 8/8 PASS, including actual tester `OrderCheck -> OrderSend -> fill -> close` in both Long and Short directions.
- Research EA compile: 0 errors, 0 warnings.
- Research harness compile: 0 errors, 0 warnings.
- Order harness compile: 0 errors, 0 warnings.

The research harness covers independent detector boundaries, exact-anchor rejection, noise-floor accounting, broker-only feasibility, non-invalidating policy bits, same-millisecond grouping, execution-clock separation, both state directions, TP limit, SL gap/slippage, time exit, and fixed-risk spread stress.

## Detection funnel

Counts in `true` are independent condition truth counts. `cumulative` means all preceding gates also passed. No failed tick is written as a CSV row; these are final summary counters.

| Detector | Evaluable | Percentile cumulative | Z cumulative | Efficiency cumulative | Intensity cumulative | Move/Spread cumulative | Spread OK / events |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 250ms | 5,149,702 | 33,487 | 32,674 | 32,637 | 3,641 | 1 | 1 |
| 500ms | 3,489,880 | 23,130 | 22,918 | 22,634 | 14,433 | 12 | 11 |
| 1,000ms | 904,567 | 5,960 | 5,949 | 5,706 | 1,873 | 7 | 7 |
| All detectors | 9,544,149 | 62,577 | 61,541 | 60,977 | 19,947 | 20 | 19 |

The requested evaluable 1-second sample count is 904,567. The primary cumulative bottleneck is `Move/Spread`, after tick intensity. Across all pre-event evaluations, the most frequent counters were `grid_missing` 88,938,370, `shock_percentile_failed` 9,481,572, `insufficient_baseline` 4,741,371, `efficiency_failed` 4,428,241, `tick_intensity_failed` 41,030, and `move_spread_failed` 19,927. These counters are not event samples and are not logged per tick.

Noise-floor use per baseline refresh was 95.9511% at 250ms, 83.0885% at 500ms, and 42.3471% at 1,000ms. Histogram overflow was zero for all 18 symbol-detector combinations. This high short-window floor rate is a known research limitation, not a reason to alter thresholds in this run.

## Events and state reachability

| Metric | Count |
|---|---:|
| Detector event rows | 19 |
| Independent 2-second symbol clusters | 17 |
| Overlap event rows | 2 |
| Duplicate event rows | 0 |
| Long / Short | 10 / 9 |
| Valid bursts | 19 |
| Valid pullbacks | 14 |
| Reacceleration signals | 5 |
| Detection-time continuation signals | 19 |
| Post-burst continuation signals | 19 |
| Pullback continuation signals | 5 |
| Failed-shock reversal signals | 11 |

Detector events were 1 at 250ms, 11 at 500ms, and 7 at 1,000ms. Symbol counts were EURUSD 5, GBPUSD 2, USDJPY 4, AUDUSD 0, USDCAD 8, and USDCHF 0. All six symbols supplied ticks, but only four produced valid events.

Sessions: TOKYO 1, LONDON 3, NEW_YORK 9, OVERLAP 3, OTHER 3. HTF alignment: BOTH_ALIGNED 1, M15_ONLY 4, H1_ONLY 3, CONFLICT 5, NEUTRAL 6.

State-end reasons were 11 `continuation_invalidated`, 5 pullback reaccelerations, 2 `no_reacceleration`, and 1 `pullback_too_shallow` timeout.

`burst/spread` distribution: n=19, min 4.444444, p25 4.889881, median 5.300000, p75 7.027778, p95 12.876852, max 14.018519.

## Execution clock evidence

The old 465-589ms execution floor is gone. Global merge lag remains visible but diagnostic-only: min 412ms, median 543ms, max 2,388ms.

| Strategy | Requested delay | Signals | Actual quote-delay min / median / max | Detection-to-entry min / median / max |
|---|---:|---:|---:|---:|
| Detection-time continuation | 0ms | 19 | 0 / 0 / 0ms | 0 / 0 / 0ms |
| Detection-time continuation | 100ms | 19 | 103 / 166 / 303ms | 103 / 166 / 303ms |
| Detection-time continuation | 250ms | 19 | 274 / 376 / 523ms | 274 / 376 / 523ms |
| Post-burst continuation | 0ms | 19 | 0 / 0 / 0ms | 325 / 761 / 3,014ms |
| Post-burst continuation | 100ms | 19 | 203 / 254 / 447ms | 610 / 1,035 / 3,246ms |
| Post-burst continuation | 250ms | 19 | 254 / 412 / 486ms | 610 / 1,172 / 3,500ms |
| Pullback continuation | 0ms | 5 | 0 / 0 / 0ms | 1,323 / 4,341 / 9,611ms |
| Pullback continuation | 100ms | 5 | 215 / 238 / 307ms | 1,575 / 4,556 / 9,880ms |
| Pullback continuation | 250ms | 5 | 269 / 416 / 453ms | 1,630 / 4,757 / 9,880ms |
| Failed-shock reversal | 0ms | 11 | 0 / 0 / 0ms | 1,199 / 3,062 / 11,638ms |
| Failed-shock reversal | 100ms | 11 | 212 / 248 / 302ms | 1,472 / 3,299 / 11,932ms |
| Failed-shock reversal | 250ms | 11 | 250 / 469 / 1,289ms | 1,472 / 3,538 / 11,932ms |

Same-millisecond processing observed 4 groups / 8 ticks, maximum group size 2. Global merge order violations were zero; pending capacity was 65,536, maximum observed 319, capacity hits zero.

## Barrier outcomes and policy labels

There were 7,452 broker-feasible scenario outcomes: 1,380 `TP_LIMIT`, 3,111 `SL_GAP`, and 2,961 `TIME_MARKET`; broker-grid invalid outcomes were zero. These outcomes are a correlated grid, not 7,452 independent trades.

Policy mask meaning is bit 1 = cost rule passed and bit 2 = range rule passed. Counts were mask 0: 2,033; mask 1: 4,363; mask 2: 1,045; mask 3: 11. All remained evaluable.

Selected stop-grid results below are net R. Each stop/delay/spread cell reuses the same small event set.

| Strategy | Stop | Delay | Spread | n | ExpectancyR |
|---|---:|---:|---:|---:|---:|
| Detection-time continuation | 12x | 0ms | 1.0x | 19 | -0.226931 |
| Detection-time continuation | 12x | 100ms | 1.0x | 19 | -0.194944 |
| Detection-time continuation | 12x | 250ms | 1.0x | 19 | -0.148270 |
| Post-burst continuation | 12x | 0ms | 1.0x | 19 | -0.067830 |
| Post-burst continuation | 12x | 100ms | 1.0x | 19 | -0.159156 |
| Post-burst continuation | 12x | 250ms | 1.0x | 19 | -0.181541 |
| Pullback continuation | 8x | 0ms | 1.0x | 5 | +0.250313 |
| Pullback continuation | 8x | 100ms | 1.0x | 5 | -0.155529 |
| Pullback continuation | 8x | 250ms | 1.0x | 5 | -0.149880 |
| Failed-shock reversal | 5x | 0ms | 1.0x | 11 | -0.012368 |
| Failed-shock reversal | 5x | 100ms | 1.0x | 11 | -0.132686 |
| Failed-shock reversal | 5x | 250ms | 1.0x | 11 | -0.154070 |

The only selected positive cell is pullback 8x at 0ms with n=5; it turns negative at both 100ms and 250ms. This is not robust positive evidence. The aggregate grid mean (-0.338143R) is diagnostic only and must not be treated as an independent-sample expectancy estimate.

## Tick quality

The tester journal reports generated-tick fallback for GBPUSD: 179 of 30,187 minutes, 0.5930%. No discard warning was observed for the other five symbols. Absence of a warning is not proof of perfect broker tick coverage. See `tick_quality.csv` and `tester-journal-excerpt.txt`.

## Bounded storage and files

- Baseline sample ring capacity: 3,612 samples per detector per symbol. Logical 15-minute-plus-exclusion maxima are approximately 3,608 at 250ms, 1,804 at 500ms, and 902 at 1,000ms.
- Tick ring capacity: 8,192 ticks per symbol.
- Tick discard rule: discard once older than 5,000ms from the processed symbol time, or overwrite the oldest entry at capacity 8,192.
- Active event slots: 64. Events retain aggregate state/MFE/MAE checkpoints up to 120 seconds, not raw 120-second tick history.
- Global pending ring: capacity 65,536; maximum observed 319.
- Tick, 250ms-grid, 500ms-grid, and 1-second series CSV output: disabled.
- Event CSV: 19 data rows, 2,852,152 bytes. One event row contains its checkpoints and compact scenario grid.
- Trade CSV: 0 data rows, 15 bytes (header only), because the research EA cannot order.
- Summary CSV: 208,438 bytes.
- Strategy Tester runtime: 380.828 seconds.
- Average / maximum EA-reported memory: 11 / 11MB.

At this observed event rate and schema width, linear event-CSV growth is about 34.23MB/year or 122.64MB for 43 months. Linear tester runtime is about 76 minutes/year or 4.55 hours for 43 months on this machine. These are planning estimates, not permission to run long OOS.

## Promotion decision and sample estimate

Do not proceed automatically from this month to long OOS. The continuation pullback path has only five signals, below the 30-trade preliminary gate, and its only positive selected cell fails both delay checks. At the observed rate, 30 pullback-continuation signals would require roughly six similar months; 30 detection/post-burst signals roughly two months; 30 reversal signals roughly three months. Five hundred independent clusters would require roughly 30 similar months, while 500 pullback-continuation signals would require roughly 100 months. Market regime and tick availability make these linear estimates uncertain.

No threshold was relaxed, no parameter optimization was run, and no 2023-2026 multi-year test was started.
