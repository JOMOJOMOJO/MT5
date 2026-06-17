# FX-only 2025 LONG Failure Summary

- LONG trades: `28`
- LONG losing trades: `20`
- LONG net: `-192.2`
- LONG avg_R: `-0.138`

## Failure Type Breakdown

| failure_type | trades | net | avg_R | avg_MFE_R | avg_MAE_R | reached_1R_pct | symbols | months |
|---|---:|---:|---:|---:|---:|---:|---|---|
| target_blocked | 13 | -644.29 | -1.007 | 0.528 | 1.294 | 15.38 | AUDJPY:1;EURJPY:1;EURUSD:1;GBPUSD:2;USDJPY:8 | 2025-02:1;2025-04:1;2025-06:2;2025-08:4;2025-09:1;2025-10:2;2025-11:1;2025-12:1 |
| chasing_entry | 5 | -242.41 | -1.006 | 1.14 | 1.284 | 80.0 | EURUSD:1;GBPJPY:1;GBPUSD:1;USDJPY:2 | 2025-03:1;2025-07:1;2025-09:1;2025-10:1;2025-11:1 |
| other | 2 | -101.56 | -1.006 | 0.266 | 1.288 | 0.0 | EURUSD:1;USDJPY:1 | 2025-07:1;2025-08:1 |

## Diagnostic Reading

- `target_blocked` means the candidate passed the broad structure but lacked room to 2R, so `room_to_2r` is directly relevant.
- `pullback_not_finished` and `m15_false_bos` point to timing/structure confirmation rather than reward or risk sizing.
- This is post-trade diagnosis only; no entry rule, TP, SL, risk, spread guard, or symbol/direction filter was changed.
