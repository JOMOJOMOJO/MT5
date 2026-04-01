# Forward Gate Evaluation

- Label: `btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2-forward-gate`
- Status: `review`
- Baseline: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\telemetry\2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json`
- Candidate: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\telemetry\2026-03-31-btcusd-session-meanrev-live035-guarded2-demo-forward.json`

## Baseline Snapshot

- Net profit: `177.86`
- Profit factor: `1.488`
- Exit count: `70`
- Active days: `47`
- Spread blocks/day: `145.7521`

## Candidate Snapshot

- Net profit: `177.86`
- Profit factor: `1.488`
- Exit count: `70`
- Active days: `47`
- Spread blocks/day: `145.7521`

## Checks

- `evidence_source` `review`: candidate summary appears to be built from the same telemetry source as the baseline
- `sample_exits` `pass`: candidate exits 70
- `sample_active_days` `pass`: candidate active days 47
- `net_profit` `pass`: candidate net 177.8600, baseline net 177.8600, ratio 1.0000
- `profit_factor` `pass`: candidate PF 1.4880, baseline PF 1.4880
- `kill_switches` `pass`: no daily/equity cap triggers and no loss-lock activations
- `spread_pressure` `pass`: candidate spread/day 145.7521, baseline 145.7521, ratio 1.0000
