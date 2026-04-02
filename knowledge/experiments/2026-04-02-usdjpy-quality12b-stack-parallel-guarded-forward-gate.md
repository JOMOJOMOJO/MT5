# Forward Gate Evaluation

- Label: `usdjpy_20260402_round_continuation_long-quality12b_stack_parallel_guarded-gate`
- Status: `review`
- Baseline: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\telemetry\2026-04-02-usdjpy-quality12b-stack-parallel-guarded-baseline.json`
- Candidate: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\telemetry\2026-04-02-usdjpy-quality12b-stack-parallel-guarded-baseline.json`

## Baseline Snapshot

- Net profit: `559.23`
- Profit factor: `1.2813`
- Exit count: `144`
- Active days: `87`
- Spread blocks/day: `6.7949`

## Candidate Snapshot

- Net profit: `559.23`
- Profit factor: `1.2813`
- Exit count: `144`
- Active days: `87`
- Spread blocks/day: `6.7949`

## Checks

- `evidence_source` `review`: candidate summary appears to be built from the same telemetry source as the baseline
- `sample_exits` `pass`: candidate exits 144
- `sample_active_days` `pass`: candidate active days 87
- `net_profit` `pass`: candidate net 559.2300, baseline net 559.2300, ratio 1.0000
- `profit_factor` `pass`: candidate PF 1.2813, baseline PF 1.2813
- `kill_switches` `pass`: no daily/equity cap triggers and no loss-lock activations
- `spread_pressure` `pass`: candidate spread/day 6.7949, baseline 6.7949, ratio 1.0000
