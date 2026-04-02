# Forward Gate Evaluation

- Label: `usdjpy_20260402_round_continuation_long-quality12b_guarded-gate`
- Status: `review`
- Baseline: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\telemetry\2026-04-02-usdjpy-quality12b-guarded-baseline.json`
- Candidate: `C:\Users\windows\AppData\Roaming\MetaQuotes\Terminal\2FA8A7E69CED7DC259B1AD86A247F675\MQL5\Experts\dev\reports\telemetry\2026-04-02-usdjpy-quality12b-guarded-baseline.json`

## Baseline Snapshot

- Net profit: `795.21`
- Profit factor: `1.4876`
- Exit count: `58`
- Active days: `53`
- Spread blocks/day: `6.5949`

## Candidate Snapshot

- Net profit: `795.21`
- Profit factor: `1.4876`
- Exit count: `58`
- Active days: `53`
- Spread blocks/day: `6.5949`

## Checks

- `evidence_source` `review`: candidate summary appears to be built from the same telemetry source as the baseline
- `sample_exits` `pass`: candidate exits 58
- `sample_active_days` `pass`: candidate active days 53
- `net_profit` `pass`: candidate net 795.2100, baseline net 795.2100, ratio 1.0000
- `profit_factor` `pass`: candidate PF 1.4876, baseline PF 1.4876
- `kill_switches` `pass`: no daily/equity cap triggers and no loss-lock activations
- `spread_pressure` `pass`: candidate spread/day 6.5949, baseline 6.5949, ratio 1.0000
