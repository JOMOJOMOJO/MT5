# USDJPY Golden Method Baseline Reject

## Thesis

- Start with a direct mechanical translation of the Golden Method:
  - `EMA13 / EMA100`,
  - Dow-style swing trend judgement,
  - Strategy 1 EMA13 touch,
  - Strategy 2 round-number breakout then EMA13 follow-through,
  - fixed `10 pip` stop / `10 pip` target.

## Evidence

- EA: `mql/Experts/usdjpy_20260402_golden_method.mq5`
- Preset: `reports/presets/usdjpy_20260402_golden_method-baseline.set`
- Train window: `2025-04-01` to `2025-12-31`
  - `net -3402.23 / PF 0.80 / 192 trades / DD 37.87%`
- OOS window: `2026-01-01` to `2026-04-01`
  - `net -3110.48 / PF 0.50 / 52 trades / DD 32.52%`

## What Failed

- The direct EMA-touch translation overtrades weak pullbacks instead of isolating true follow-through.
- The current Dow filter is too loose to protect against profit-taking-phase entries.
- Strategy 2 breakout logic is still too permissive and does not yet distinguish strong post-break continuation from noisy round-number interaction.
- Fixed `10 / 10` alone does not create the edge; the setup quality must improve first.

## Useful Findings

- `USDJPY` is available on the current broker feed.
- The current feed is micro-cap viable for the baseline stop model:
  - minimum lot `0.01`,
  - about `0.63 USD` risk for `10 pip` stop at `0.01 lot`.
- So the blocker is edge quality, not symbol availability or lot-floor mechanics.

## Decision

- Verdict: `baseline reject`
- Keep `USDJPY Golden Method` as the active mainline family.
- Do not revert to BTC as mainline just because the first USDJPY translation failed.
- A later rerun with flexible `1.2R` targets and micro-cap override also failed:
  - see `knowledge/experiments/2026-04-02-usdjpy-golden-method-flexible-risk-rerun.md`.

## Next Experiments

1. Tighten Strategy 1 so it only trades a clearer follow-through state:
   - stronger swing-state confirmation,
   - sharper `V-shape` pullback filter,
   - cleaner rejection at EMA13.
2. Rebuild Strategy 2 around better breakout quality:
   - stricter large-candle definition,
   - stronger no-retest / no-chop filter around round numbers,
   - session-aware preparation for London / New York conditions.
3. Add explicit volatility-state classification rather than only the simple same-zone block.
4. Run chart-mining on `USDJPY` with the generic feature lab so the next cycle is not only manual-doctrine translation.
