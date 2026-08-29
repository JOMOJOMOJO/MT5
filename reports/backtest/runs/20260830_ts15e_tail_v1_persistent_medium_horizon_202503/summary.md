# Step 15E March 2025 development run

This run is `DEVELOPMENT_ONLY`. It uses `TAIL_V1_PERSISTENT`,
`REALIZABLE_EA`, six symbols, EURUSD M1 as the tester driver and the real-tick
model for 2025-03-01 through 2025-04-01. It sent no orders.

## Provenance and execution

- RunId: `ts15e_medium_horizon_202503`
- source commit: `ce46a52204dae05dddff680bdc5f6d56907bb08e`
- executed EX5 SHA-256: `B213011CEDA438767831044C3AD792569232A7E2197F92DE13CCE4728B53109E`
- elapsed tester time: 574.985 seconds; journal wall time: 9m43.740s
- total ticks: 10,587,809
- average / maximum reported memory: 29.579 / 30 MB
- event CSV: 10 rows, 2,709,073 bytes (event-level research output)
- trade CSV: 0 rows, 15 bytes (header only)

## Frozen-behavior reconciliation

- detector event rows: 21,799
- market clusters: 10,245
- Step 15D detector identity mismatches: 0
- Step 15D path identity mismatches: 0
- strategy/execution parameter differences: 0
- production orders: 0

The new causal 15-minute state machine created 3,151 episodes. All 3,151
reached the 900-second completion boundary, none was purged, and episode ID
duplicates were zero. It wrote 28,359 checkpoint rows and recorded 1,114
additional shocks during cooldown rather than allocating new episodes.

## Data quality

The tester journal states that GBPUSD discarded real ticks for 179 of 30,187
minute bars (0.5930%) and used generated ticks for those minutes. The EA saw
30,188 GBPUSD M1 boundaries; these counters have different definitions and are
not reconciled by changing either value. Since the journal does not identify
the affected minute intervals, all 417 GBPUSD episodes are excluded from the
primary analysis. The remaining primary population is 2,734 episodes.

The saved timestamps are broker-server timestamps. No verified UTC-offset/DST
mapping was injected, so session tables are explicitly labelled server-hour
diagnostics and are not represented as UTC sessions.

## Interpretation boundary

Commission/slippage evidence is incomplete across all six symbols. Formal net
expectancy is unavailable. Matched controls are `NOT_ESTIMABLE` because this
run did not record a causally eligible 15-minute non-shock control path. The
run supports engineering and development characterization only; it does not
support edge, RR, OOS or production claims.
