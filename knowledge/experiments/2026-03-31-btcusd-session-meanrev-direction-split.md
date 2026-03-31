# 2026-03-31 BTCUSD Session Mean-Reversion Direction Split

- EA: `btcusd_20260330_session_meanrev`
- Objective:
  - stop treating the mixed long/short prototype as deployable just because the shared-window report looked strong,
  - verify which side still survives on a longer actual MT5 window,
  - decide whether this family should be promoted as `one EA`, `two separate EAs`, or `only one side`.
- Skills used:
  - `research-director`
  - `strategy-critic`
  - `systematic-ea-trader`
  - `risk-manager`
  - `backtest-analysis`

## Structural Change

- Added side-specific exit controls to the EA and validator:
  - `InpLongHoldBars`
  - `InpShortHoldBars`
  - `InpLongExitBufferATR`
  - `InpShortExitBufferATR`
  - `InpShortTrendFilterMode`
- Reason:
  - long and short buckets should not be forced through the same exit profile,
  - this also made it possible to test side-isolated candidates cleanly.

## Long-Window Actual MT5 Results

- Mixed-direction `bull37 + asia100`:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-bull37_asia100_h12.set`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-023905-568425-btcusd-20260330-session-meanrev-.json`
  - `net -13.11`
  - `PF 0.98`
  - `628 trades`
  - `max DD 2.56%`

- Mixed-direction `bull37 + nybear60`:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-bull37_nybear60_h12.set`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-024106-603925-btcusd-20260330-session-meanrev-.json`
  - `net -94.03`
  - `PF 0.84`
  - `413 trades`
  - `max DD 1.36%`

- Short-only `asia100`:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-asia100_short_h12.set`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-024540-655196-btcusd-20260330-session-meanrev-.json`
  - `net -82.52`
  - `PF 0.88`
  - `540 trades`
  - `max DD 2.76%`

- Long-only `bull37`:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12.set`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-024622-395041-btcusd-20260330-session-meanrev-.json`
  - `net +68.89`
  - `PF 1.76`
  - `88 trades`
  - `max DD 0.38%`

- Long-only `bull15_40`:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-bull15_40_long_h12.set`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-025134-579920-btcusd-20260330-session-meanrev-.json`
  - `net +62.34`
  - `PF 1.42`
  - `139 trades`
  - `max DD 0.48%`

- Long-only `bull12_45`:
  - preset: `reports/presets/btcusd_20260330_session_meanrev-bull12_45_long_h12.set`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-024913-006891-btcusd-20260330-session-meanrev-.json`
  - `net +26.10`
  - `PF 1.09`
  - `266 trades`
  - `max DD 0.77%`

## Decision

- Reject the mixed-direction session-mean-reversion candidate for live promotion.
- Reject the current short-side branch as a live candidate on this long actual window.
- Keep only the long side as the active development front.
- Promote `bull15_40 long-only` as the current `balance candidate`.
- Keep `bull37 long-only` as the `quality reference`.

## Why

- The short side still looks attractive in some validator slices, but actual MT5 does not support promotion.
- The mixed long/short variant did not survive the 1-year actual report even after direction-aware exit controls were added.
- The long side is the only branch that remained profitable in actual MT5 after the direction split.
- `bull15_40` gives a useful trade-count increase versus `bull37` while staying above `PF 1.4` with sub-`0.5%` drawdown.

## Reusable Lesson

- For same-symbol MT5 deployment, do not assume a validator that stacks long and short buckets behaves like the actual tester.
- Before combining opposing buckets into one live candidate, force a long-window actual MT5 comparison against:
  - long-only,
  - short-only,
  - mixed-direction.
- If only one side survives, split the family and stop trying to rescue the weaker side with parameter tweaks alone.

## Next Step

1. Treat `bull15_40 long-only` as the current live-candidate preset.
2. Keep `bull37 long-only` as the conservative fallback.
3. Run demo-forward telemetry on the long-only candidate and compare realized trade frequency against the 1-year actual report.
4. Park the short side until a separate actual-first research branch shows cross-year profitability.
