# ExpectedValue Long Relative Scalper Spread Threshold Review

## Context

- Date: `2026-05-19`
- EA: `mql/Experts/ExpectedValue_LongOnly_RelativeScalper.mq5`
- Objective: build a long-only small-capital research EA while avoiding backtest ruin settings
- IS window: `2025-01-01` to `2025-12-31`
- OOS window: `2026-01-01` to `2026-04-30`

## One-Input Probe

Only one high-impact input was changed after the initial run:

- `InpMaxSpreadATR`

Reason: strict 2025 diagnostics showed `spread_atr_too_wide` was the dominant reject reason.

## Outcomes

| Setting | IS Trades | IS ExpectancyR | IS PF | IS MaxDD% | OOS run? | Verdict |
|---|---:|---:|---:|---:|---|---|
| `0.12` | 23 | +0.2203 | 1.7616 | 7.21 | yes, initial only | too sparse |
| `0.20` | 176 | -0.0177 | 0.9590 | 24.23 | yes | frequency improved, edge failed |
| `0.35` | 128 | -0.3368 | 0.4619 | 45.00 | no | rejected by DD stop |

OOS for the selected non-ruin frequency probe `0.20`:

- trades: `11`
- ExpectancyR: `-0.6064`
- PF: `0.1156`
- MaxDD: `11.47%`

## Rejected Ranges

- `Spread/ATR >= 0.35`
  - too much friction was admitted
  - max drawdown stop fired in 2025
- `Spread/ATR = 0.12`
  - acceptable quality but not aligned with the trade-count objective
- `Spread/ATR = 0.20`
  - usable as a diagnostic frequency probe
  - not usable as a promotion candidate

## Lesson

For this long-only shape, spread looseness is not the path to `5 trades/day`. The next cycle should add a structurally different long bucket or a clearer market-state split rather than relaxing the current filters.
