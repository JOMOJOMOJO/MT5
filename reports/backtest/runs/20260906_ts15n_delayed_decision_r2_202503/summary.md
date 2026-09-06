# Step 15N formal March delayed-decision run

- Period: 2025-03-01 to 2025-04-01
- Driver/model: EURUSD M1 / real ticks
- Symbols: EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, USDCHF
- Mode: REALIZABLE_EA research-only; no orders; trades.csv is header-only
- Detector: frozen TAIL_V1_PERSISTENT
- Raw candidates: 74,415
- Statistical detector events: 21,799
- Medium-horizon episodes: 3,151
- Delayed checkpoint rows: 12,604
- Delayed action rows: 25,208
- Pool capacity hits: 0
- Global order violations: 0
- Dropped ticks/cursor stalls: 0/0
- Tester runtime: 0:19:12.691
- Tester memory: 503 MB (40 MB history, 256 MB tick data)
- Tester total ticks across symbols: 10,587,807
- Internal summary memory: average 31.331 MB, maximum 32 MB
- Tick quality: GBPUSD real ticks discarded/generated fallback for 179 of 30,187 minutes (0.593%); interval map unavailable, so GBPUSD is excluded from primary inference
- All-tick CSV: disabled
- One-second CSV: disabled

> This is March development research evidence, not OOS evidence and not a production trading EA.
