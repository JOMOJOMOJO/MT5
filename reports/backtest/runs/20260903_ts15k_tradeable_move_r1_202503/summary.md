# Step 15K March 2025 formal run

- Run ID: `ts15k_tradeable_move_r1_202503`
- Mode: `REALIZABLE_EA`, research only, orders disabled
- Period: 2025-03-01 through 2025-04-01
- Driver: EURUSD M1; symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Model: MT5 real ticks
- Source commit: `54b9abca11a5ba5a6d2271bcfa0854217f897bf6`
- Runtime: 708.358 seconds
- Tester ticks: 10,587,807
- Tester memory: 502 MB total (40 MB history, 256 MB tick data)
- Orders/trades: 0

## Funnel

Raw candidates 74,415; detector feature rows 21,799; persistent episodes 3,151; complete lag-valid 60-minute paths 3,103; analysis-ready 2,696; relative-state-ready 1,783; frozen high-movement selected 185.

## Reference geometry

At `TP=0.40 ATR`, `hold=900s`, `pre-TP MAE<=0.25 ATR`, 188/2,696 episodes (186 clusters) were clean: continuation 84, reversal 104, both 0. The high-movement population was 38/185 clean (20.54%) versus 77/1,598 (4.82%) in relative-ready unselected episodes.

These are path labels, not executed trades or expectancy. Results are development-only and concentrated in USDJPY. See `docs/research/tick_shock/15k_tradeable_move_cross_symbol_results.md` for the full interpretation.

## Integrity

Horizon lag limit was 30,000ms. There were 46 `CENSORED_HORIZON_LAG`, 2 end-of-data censors, zero available snapshots beyond the limit, zero invalid paths, zero capacity hits, zero drops, and zero cursor stalls. GBPUSD had 179 discarded real-tick minutes out of 30,187 tester-reported minutes and is excluded from formal normalized inference.
