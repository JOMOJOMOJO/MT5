# Step 10 module and test-seam mapping

| Responsibility | Production module/function | Research EA call site | Harness/Test IDs | Expected source |
|---|---|---|---|---|
| sample capacity | `TSBaselineRequiredCapacity` | `TSRRequiredSampleCapacity` | capacity/static validation | Step 3/config |
| percentile | `TSEngineLinearPercentile` | `TSRPercentile` | `TS-PCT-001` | expected CSV |
| histogram percentile | `TSEngineHistogramPercentile` | `TSRHistogramPercentile` | baseline integration | expected CSV |
| MAD/noise floor/Z | `TSEngineRobustStatistics` | `TSRRefreshBaseline`, `TSRDetectShock` | `TS-Z-001/002` | expected CSV |
| readiness | `TSEngineBaselineReadiness` | `TSRRefreshBaseline` | `TS-BASE-001/002` | expected CSV |
| efficiency | `TSEngineDirectionalEfficiency` | `TSRPathEfficiency` | `TS-EFF-001/002` | tick fixture + expected CSV |
| six gates | existing `TSEngineEvaluateDetector` | `TSRDetectShock` | detector threshold tests | expected CSV |
| detector counters | `TSObserveDetectorResult` | `TSRDetectShock` | funnel/output comparison | Step 7 evidence |
| ring cursor | `TSRing*` | tick/grid/sample add/find | production integration | Step 7 evidence |
| grid runtime | `TSGrid*` | symbol init and tick/grid advance | same-ms/grid tests | expected CSV + Step 7 |
| event allocation/dedup | `TSEngineRegisterResearchEvent` | `TSRDetectShock` | `TS-DUP-001` | expected CSV |
| symbol/market clusters | same registration | `TSRDetectShock` | `TS-CLUSTER-001/002` | expected CSV |
| pending merge | `TSMerge*` | collector/dispatcher/flush | merge/same-ms/multicurrency tests | expected CSV + Step 7 |
| commission result | `TSEngineCommissionFromKnownLoss` | shared builder under adapter | `TS-COMM-001` | expected CSV |
| one-lot loss adapter | `TSMt5CommissionResult` | `TSRCommissionR` | terminal integration boundary | `OrderCalcProfit`; explicit success flag |

## Production use evidence

The EA directly includes `TickShockEngine.mqh`, which includes
`TickShockResearchEngine.mqh` and the new modules. Concrete call sites are:

- symbol init: `TSRingReset`, `TSGridReset`, `TSResetSymbolClusterClock`,
  `TSResetDetectorCounters`;
- tick/grid/sample path: ring reserve/drop/index and grid observe/advance;
- baseline/detection: all baseline and metric facades plus detector counters;
- event path: event registration, row count and slot release;
- merge path: repository append/sort/release/diagnostics/compaction;
- commission path: `TSMt5CommissionResult`.

No new class/object is uninstantiated, and no new module is a passive wrapper.

## Test result boundary

The Step 10 runner uses phase `step10`, preserving Step 5/6 historical result
files. MQL observations are stored in
`reports/tests/tick_shock/step10_raw/`, and the reconciled registry result is
`reports/tests/tick_shock/step10_post_refactor_results.csv`.

The 55 PASS count comprises the prior 45 plus the ten deterministic seams. The
remaining nine SKIPs are external observation requirements; a future Step must
inject or observe actual server/order/restart lifecycle without modifying their
expected files.
