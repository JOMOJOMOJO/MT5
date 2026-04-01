# BTCUSD Session Mean-Reversion: `smalllive015` Stage

- Date: `2026-03-31`
- Family: `btcusd_20260330_session_meanrev`
- Stage: `first real-capital preset`

## Decision

- Keep `btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2` as the `demo-forward candidate`.
- Use `btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015` as the first real-capital preset after the demo-forward gate passes.

## Why

- The family still does not satisfy the original high-turnover business objective.
- But it does provide a durable, lower-turnover BTCUSD long-only branch with explicit live guard rails.
- The first real-capital step should therefore reduce per-trade equity risk rather than reuse the full demo proving preset.

## Evidence

- MT5 actual run:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-132810-116558-btcusd-20260330-session-meanrev-.json`
- Result:
  - `net +57.75`
  - `PF 1.41`
  - `70` trades
  - `max DD 0.69%`

## Operating Consequence

- No first-capital launch should use `guarded2` directly unless an override is recorded.
- The default first-capital release packet is:
  - `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.md`
- The default staged preflight is:
  - `powershell -ExecutionPolicy Bypass -File scripts/small-live-preflight.ps1`
