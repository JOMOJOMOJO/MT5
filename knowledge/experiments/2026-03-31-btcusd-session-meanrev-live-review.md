# Live Ops Review

- Label: `btcusd_20260330_session_meanrev-live-review`
- Review status: `review`
- Recommended action: `review`

## Status Snapshot

- Timestamp: `2026.03.29 23:59:58`
- Heartbeat age minutes: `2266.6`
- Operator mode: `normal`
- Entry state: `ready`
- Open positions: `0`
- Spread pips: `2498.0`

## Telemetry Snapshot

- Exit count: `70`
- Profit factor: `1.488`
- Active days: `47`
- Blocked spread: `52908`

## Checks

- `heartbeat_freshness` `review`: heartbeat age 2266.6 minutes exceeds 180.0
- `operator_mode` `pass`: operator mode is normal
- `hard_blocks` `pass`: daily and equity hard blocks are inactive
- `soft_blocks` `pass`: entry_state=ready
- `spread_now` `pass`: live spread 2498.0 <= threshold 2500.0
- `forward_gate` `review`: forward gate still compares the baseline artifact to itself
- `telemetry_sample` `pass`: exits=70 active_days=47
- `telemetry_quality` `pass`: telemetry PF 1.4880, blocked_spread=52908
