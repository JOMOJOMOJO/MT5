# Step 15F formal March context run

- RunId: `ts15f_context_r3_202503`
- source commit: `26faf274b87b882745a9a62bfb521fea08d9bf7f`
- period: `2025-03-01` through `2025-04-01`
- driver/model: `EURUSD,M1`, real ticks model 4
- symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- detector: frozen `TAIL_V1_PERSISTENT`
- execution: research-only `REALIZABLE_EA` shadow replay
- production orders: 0
- runtime: 640.500 seconds (tester wall report: 646.655 seconds including preprocessing)
- average/max EA memory: 30.331 / 31 MB
- tester total memory: 501 MB including history/tick data

The run retained 21,799 detector rows, 10,245 market clusters and 3,151
15-minute episodes. Step 15E event, episode, path, funnel and medium-horizon
identities reconcile with zero mismatches. The newly recorded dataset contains
6,302 episode decision rows and 12,508 control decision rows (6,254 unique
control anchors).

F01 availability was repaired before this accepted run. Of the 6,302 episode
decision rows, 3,907 have F01; the remaining rows are excluded because the
decision quote is stale/invalid or history is unavailable. At +60 seconds,
1,965 rows have all 36 features, 3 have a partial feature set and 1,183 have an
invalid/stale quote. At +120 seconds the corresponding counts are 1,937, 2 and
1,212.

The tester reported generated-tick fallback for 179 of 30,187 GBPUSD minute
bars. The EA counted 30,188 observed GBPUSD M1 boundaries. Because affected
interval mapping remains unavailable, all 417 GBPUSD episodes are excluded
from primary inference. Commission beyond the limited tester observation and
additional live slippage remain incomplete; formal net expectancy is not
reported.

Formal run status: `CAUSAL_CONTEXT_FEATURES_CHARACTERIZED_ON_DEVELOPMENT_DATA`,
`COST_MODEL_INCOMPLETE`, `FORMAL_NET_EXPECTANCY_UNAVAILABLE`,
`EDGE_UNDETERMINED`, `PRODUCTION_NOT_ELIGIBLE`.
