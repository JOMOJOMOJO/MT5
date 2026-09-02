# Step 15J formal March run

- RunId: `ts15j_post_shock_excursion_r2_202503`
- Period: 2025-03-01 to 2025-04-01
- Driver: EURUSD M1
- Model: real ticks, six symbols
- Execution mode: `REALIZABLE_EA`
- Source commit: `10589ea4abd3f141ecad932c11a233f48af76728`
- Compile: 0 errors / 0 warnings
- Runtime: 11m42.480s
- Reported memory: 502 MB including 40 MB history and 256 MB tick data
- Orders/trades: 0 / 0

The unchanged detector produced 21,799 rows and the unchanged persistent episode engine produced 3,151 episodes in 2,909 market clusters. The Step 15J recorder captured a causal t0 quote for all 3,151; 3,148 reached the 60-minute horizon and three were censored at end of data. Pool capacity hits, invalid paths, duplicate episode IDs, and entry-before-t0 violations were zero.

GBPUSD contains 179 generated-fallback minutes among 30,187 tester-reported minute bars. Its raw 417 episode paths are retained but excluded from the formal normalized analysis because an interval-level map is unavailable.

The primary analysis is under `reports/analysis/tick_shock/step15j/` and the research verdict is in `docs/research/tick_shock/15j_post_shock_excursion_tp_sl_holding_results.md`.
