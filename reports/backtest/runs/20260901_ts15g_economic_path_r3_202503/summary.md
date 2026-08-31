# Step 15G March development run r3

- period: 2025-03-01 through 2025-04-01
- model: MT5 real ticks, EURUSD M1 driver, six monitored symbols
- detector: `TAIL_V1_PERSISTENT`
- execution: shadow research only; orders 0
- source commit: `e9c2968660288c12af03dba770e519c8d012e010`
- compile: 0 errors / 0 warnings
- runtime: 688.156 seconds (tester journal wall time 11:36.630)
- total ticks: 10,587,807 in tester journal; EA summary 10,587,809 processed observations
- raw candidates: 74,415
- statistical events: 21,799
- market clusters: 10,245
- completed 15-minute episodes: 3,151
- economic path rows: 430,224
- duplicate economic path keys: 0
- TP_FIRST / SL_FIRST / TIMEOUT: 5,030 / 20,657 / 67,961
- invalid paths: 336,576
- processing-before-entry violations: 0
- signal-tick/backdated entry violations: 0
- RR-below-requested violations: 0
- average / maximum EA-reported memory: 30.336 / 31 MB
- tester total memory: 501 MB
- event CSV: 10 rows represented by 2,709,093 bytes (event-row count in legacy summary field is strategy-event rows, not detector rows)
- trade CSV: 0 rows, 15 bytes
- tick/grid CSV: disabled

GBPUSD reported 179 generated-tick fallback minutes out of 30,187 tester minutes. All GBPUSD episodes are excluded from the primary Step 15G population because an interval-level fallback map is unavailable.

Formal six-symbol commission evidence is unavailable. Therefore the run supports C0 and diagnostic stress results, but not formal net expectancy.

Status: `ECONOMIC_PATH_LABELS_CHARACTERIZED_ON_DEVELOPMENT_DATA`, `COST_MODEL_INCOMPLETE`, `EDGE_UNDETERMINED`, `PRODUCTION_NOT_ELIGIBLE`.
