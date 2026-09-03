# Step 15K validation

## Gates

| check | result | evidence |
|---|---|---|
| research EA compile | PASS: 0 errors / 0 warnings | `reports/backtest/runs/20260903_ts15k_tradeable_move_r1_202503/compile.log` |
| post-shock harness compile/run | PASS: 0/0; 11/11 | terminal journal and Step 15K execution record |
| deterministic MQL component runner | PASS | `tools/tick_shock/run_mql_harnesses.ps1 -Phase step15h` |
| Python suite | PASS 407 / FAIL 0 / SKIP 9 | `tools/tick_shock/run_python_tests.py` |
| aggregate runner phase | FAIL | `run_all_tests.ps1` does not accept `step15h`; no result was reclassified |
| independent oracle | PASS 20 / FAIL 0 | `reports/analysis/tick_shock/step15k/independent_oracle.csv` |
| production behavior comparison | PASS; unintended differences 0 | `reports/analysis/tick_shock/step15k/behavior_comparison.csv` |
| orders/trades | PASS: 0 | formal run `trades.csv` |

## Causal and data-integrity results

- pre-t0 entry quote: 0
- future ATR/feature read: 0
- duplicate episode ID: 0
- invalid entry Bid/Ask: 0
- `AVAILABLE` horizon with lag >30,000ms: 0
- horizon-lag censored: 46
- end-of-data censored: 2
- post-shock invalid paths: 0
- event-pool/pending/track capacity hit: 0
- dropped ticks/cursor stalls: 0
- market-cluster ID missing: 0

The all-runner phase mismatch is a tooling defect, not a strategy result. The component runners executed the intended suite, but the aggregate orchestration check remains FAIL until a later scoped tooling change.
## Behavior preservation

Compared with the Step 15J baseline, detector rows (21,799, 52 compared columns) and persistent episodes (3,151, 38 columns) match exactly. Of 3,151 excursion rows, 3,103 complete rows match across 90 legacy columns. The 48 unmatched rows are the intended 46 horizon-lag censors plus two end-of-data/status outcomes; added target/quote/lag/status columns are intentional evidence changes.

## Tick provenance

GBPUSD records 179 generated-fallback minutes out of 30,187 tester-reported minutes. The EA observed 30,188 M1 minutes. Because the discarded interval map is unavailable, all 417 GBPUSD episodes are retained in raw evidence but excluded from formal normalized inference.
