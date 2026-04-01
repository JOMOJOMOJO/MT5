# BTCUSD Session Mean-Reversion: 2026 Q1 OOS Review

- Date: `2026-04-01`
- Window: `2026-01-01` to `2026-03-30`
- Scope: recent out-of-sample MT5 check for current live-track and reference presets

## Ranking

- Best current deployable preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set`
  - `PF 4.11`
  - `net +92.29`
  - `15` trades
  - `max DD 0.26%`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-04-01-132317-215883-btcusd-20260330-session-meanrev-.json`
- Best pure quality reference:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12.set`
  - `PF 3.72`
  - `net +18.60`
  - `15` trades
  - `max DD 0.07%`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-04-01-132324-705153-btcusd-20260330-session-meanrev-.json`
- Best higher-turnover parked branch:
  - `reports/presets/btcusd_20260330_session_meanrev-bull15_40_long_h8_no_sun.set`
  - `PF 2.27`
  - `net +12.61`
  - `16` trades
  - `max DD 0.05%`
  - run: `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-04-01-132335-013215-btcusd-20260330-session-meanrev-.json`

## Interpretation

- The `bull37` branch remains the strongest logic inside this family.
- `guarded2` remains the correct preset to move toward demo and live because it preserves the same long-only edge while keeping explicit live controls enabled.
- The recent 3-month OOS window does not invalidate the family. Quality is still strong.
- The business weakness is still trade count.
- `15` to `16` trades across `2026-01-01` to `2026-03-30` is roughly `0.17` to `0.18` trades per day, which is far below the company objective for a higher-turnover compounding system.

## Decision

- Keep `btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2` as the current demo-forward proving preset.
- Keep `btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015` as the first real-capital staged preset.
- Do not spend more mainline research on trying to force this family into a multi-trade-per-day role.
- Use this family as a conservative secondary live-track candidate while a separate higher-turnover expectancy-first family is developed.

## Live Gate Update

- Add a mandatory recent MT5 OOS check on the latest available 3-month window before promotion.
- For the current family, a practical live-discussion gate is:
  - 1-year actual MT5: positive net, `PF >= 1.30`, `max DD <= 3.0%`, and informative sample size
  - latest 3-month OOS actual MT5: positive net, `PF >= 1.20`, and no material regime break versus the 1-year baseline
  - real demo-forward: at least one reviewed run, no unexpected rule violations, no materially worse spread or slippage regime than the tested assumptions
  - first capital: `smalllive015` only, unless an explicit override is recorded

## Next Work

- Run the real demo-forward week for `guarded2`.
- Keep this family as a quality-preserving fallback.
- Build the next mainline around a structure that can produce materially more trades without collapsing expectancy.
