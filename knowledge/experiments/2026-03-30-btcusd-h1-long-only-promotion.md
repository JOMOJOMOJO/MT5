# BTCUSD H1 Long-Only Promotion

## Summary

- `strategy-critic` judgement: the short breakout edge is not robust enough for the shared baseline.
- The baseline candidate was moved from `M30 mixed / long-only probe` to `H1 signal + H4 regime + D1 confirm` with sell-side disabled by default.
- This does not make the EA live-ready yet, but it materially improves cross-year robustness.

## Why The Direction Changed

- Mixed-direction variants could produce a positive 2025 and a positive short OOS window, but the short side kept collapsing in clustered 2026 sell sequences.
- `M30 long-only` improved 2025 quality but still lost badly in 2024.
- `H1/H4/D1 long-only` reduced the 2024 damage sharply while keeping 2025 quality high.

## Key Results

- `M30 long-only / 2025`: `net +516.26`, `PF 1.77`, `DD 1.38%`, `42 trades`
- `H1/H4/D1 long-only / 2025`: `net +294.32`, `PF 2.16`, `DD 0.82%`, `21 trades`
- `H1/H4/D1 long-only / 2024`: `net -54.79`, `PF 0.91`, `DD 2.10%`, `30 trades`
- `H1/H4/D1 long-only / 2026 Q1 OOS`: `0 trades`, `flat`

## Interpretation

- The promoted H1 candidate trades less, but the quality per trade is better.
- The system is now closer to a `bull regime participation` model than an all-weather BTCUSD model.
- `2026 Q1 flat` is acceptable for a regime-specific system, but `2024 full-year negative` means the edge is still not robust enough for live promotion.

## Decision

- Keep sell-side code for research only.
- Keep the shared baseline as `H1/H4/D1 long-only`.
- Focus the next cycle on the residual weak 2024 long entries instead of reviving short-side logic.

## Next Experiments

1. Break 2024 losses into monthly clusters and identify the recurring long failure regime.
2. Test a filter that blocks long pullbacks when the D1 regime is up but the H1 pullback happens into unstable transition structure.
3. Build a dedicated short-strategy branch separately instead of forcing it into this baseline EA.
