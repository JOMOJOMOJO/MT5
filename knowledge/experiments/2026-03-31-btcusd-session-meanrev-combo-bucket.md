# 2026-03-31 BTCUSD Session Mean-Reversion Combo Bucket

- EA: `btcusd_20260330_session_meanrev`
- Objective: keep the profitable `asia short` core, add one additional bucket that lifts actual MT5 trade count without breaking quality.
- Skills used:
  - `statistical-edge-research`
  - `strategy-critic`
  - `systematic-ea-trader`

## Context

- The previous `NY stacked-bear short` probe looked acceptable in the Python validator but failed in MT5 HTML:
  - with stack: `net -21.40`, `PF 0.82`, `84 trades`
  - no stack: `net -266.67`, `PF 0.77`, `716 trades`
- Conclusion:
  - do not chase trade count by adding another short bucket on the same side
  - look for an orthogonal bucket instead

## New Bucket

- Added bucket:
  - `late-session long`
  - window: `20-24`
  - distance: `1.50 ATR`
  - RSI max: `35`
  - hold: `12 bars`
- The short side stayed on the proven `asia short` settings:
  - `0-8`
  - `dist 0.87`
  - `rsi 64-82`
  - `min atr pct 0.0003`

## MT5 Report-Backed Results

- Conservative baseline:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-30-212224-417653-btcusd-20260330-session-meanrev-.json`
  - `net +156.61`
  - `PF 1.75`
  - `242 trades`
  - `max DD 0.33%`

- Late long only `1.50 / 35 / hold 12`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-000035-180230-probe-late-long-15-35.json`
  - `net +50.66`
  - `PF 1.20`
  - `146 trades`
  - `max DD 0.57%`

- Combo `asia short + late long 1.20 / 35 / hold 12`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-000035-247712-probe-combo-asia-short-late-long.json`
  - `net +185.33`
  - `PF 1.37`
  - `400 trades`
  - `max DD 0.85%`

- Combo `asia short + late long 1.50 / 35 / hold 12`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-000240-833419-probe-combo-asia-short-late-long.json`
  - `net +212.61`
  - `PF 1.46`
  - `392 trades`
  - `max DD 0.69%`

- Combo `asia short + late long 1.50 / 35 / hold 14`:
  - source: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-000240-932835-probe-combo-asia-short-late-long.json`
  - `net +207.66`
  - `PF 1.44`
  - `388 trades`
  - `max DD 0.74%`

## Validator Gate

- `50k` friction-aware validator:
  - source: `reports/research/2026-03-31-combo-validate/combo_asia_short_late_long_15_35_h12_50k.json`
  - all: `6.94 trades/day`, `PF 1.38`
  - train: `7.42 trades/day`, `PF 1.48`
  - test: `7.80 trades/day`, `PF 1.30`

- `80k` friction-aware validator:
  - source: `reports/research/2026-03-31-combo-validate/combo_asia_short_late_long_15_35_h12_80k.json`
  - all: `6.21 trades/day`, `PF 1.19`
  - train: `5.99 trades/day`, `PF 1.13`
  - test: `7.80 trades/day`, `PF 1.30`

## Decision

- Promote `asia short + late long 1.50 / 35 / hold 12` as the new `higher-turnover candidate`.
- Keep the old short-only preset as the `conservative reference`.
- Do not replace the conservative baseline for live promotion yet.

## Why This Is Better

- It adds an orthogonal bucket instead of forcing more shorts into the same weak regime.
- MT5 actual `net` improved from `+156.61` to `+212.61`.
- MT5 actual `trades` improved from `242` to `392`.
- Drawdown rose, but remained below `1%` on the tested window.

## Next Step

1. Run the combo preset through a longer MT5 window and compare against the conservative short-only reference.
2. Forward-demo the combo preset separately with its own telemetry file.
3. If the combo branch weakens badly outside the current window, keep it as a secondary research branch instead of the shared live candidate.
