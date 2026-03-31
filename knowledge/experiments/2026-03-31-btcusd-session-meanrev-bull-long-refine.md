# 2026-03-31 BTCUSD Session Mean-Reversion Bull-Long Refine

- EA: `btcusd_20260330_session_meanrev`
- Goal: improve the current live-ready branch without giving up the strong MT5 quality of the bull-filtered long add-on.
- Skills used:
  - `research-director`
  - `strategy-critic`
  - `systematic-ea-trader`
  - `backtest-analysis`

## Tested Variants

- Conservative reference:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-212224-417653-btcusd-20260330-session-meanrev-.json`
  - `net +156.61`
  - `PF 1.75`
  - `242 trades`
  - `max DD 0.33%`

- Bull-long `1.50 / RSI<=35 / hold 12`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-004127-906184-btcusd-20260330-session-meanrev-.json`
  - `net +175.23`
  - `PF 1.86`
  - `257 trades`
  - `max DD 0.34%`

- Bull-long `1.35 / RSI<=35 / hold 12`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-014647-911283-btcusd-20260330-session-meanrev-.json`
  - `net +175.23`
  - `PF 1.86`
  - `257 trades`
  - `max DD 0.34%`
  - interpretation:
    distance loosening from `1.50` to `1.35` did not change actual MT5 behavior on the tested window.

- Bull-long `1.50 / RSI<=37 / hold 12`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-014755-310346-btcusd-20260330-session-meanrev-.json`
  - `net +177.47`
  - `PF 1.83`
  - `268 trades`
  - `max DD 0.32%`

## Decision

- Promote `1.50 / RSI<=37 / bull-filter / hold 12` as the current `best-balance candidate`.
- Keep `1.50 / RSI<=35 / bull-filter / hold 12` as the `quality reference`.
- Keep the old short-only branch only as a conservative fallback, not as the current development front.

## Why

- It beat the conservative reference on all practical live-readiness axes that matter together:
  - higher `net`
  - higher `PF`
  - more `trades`
  - slightly lower `max DD`
- It also improved trade count versus the `RSI<=35` bull-long candidate while keeping PF comfortably above the conservative baseline.

## Next Step

1. Treat `reports/presets/btcusd_20260330_session_meanrev-combo15_37_bull_h12.set` as the current live-candidate preset.
2. Re-run this preset on a longer MT5 window.
3. Start forward-demo with the dedicated telemetry file if the longer window still holds.
