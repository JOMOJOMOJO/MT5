# USDJPY Golden Method Kickoff

## Thesis

- The CEO-provided `Golden Method` maps more naturally to `USDJPY` than to `BTCUSD`.
- The first repo implementation should encode the doctrine directly instead of forcing the existing BTC structure to mimic it.

## Source Of Truth

- Doctrine: `knowledge/patterns/2026-04-02-usdjpy-golden-method-spec.md`
- Validation scorecard: `knowledge/patterns/2026-04-02-usdjpy-golden-method-validation.md`

## First Prototype Scope

- Symbol: `USDJPY`
- Baseline timeframe: `M5`
- Baseline environment:
  - `EMA13`
  - `EMA100`
- Baseline entries:
  - Strategy 1 EMA13 touch in the slow-EMA trend direction
  - Strategy 2 round-number breakout, then EMA13 follow-through touch
- Baseline exits:
  - use the `10 pip / 10 pip` example only as a reference anchor
  - allow stop / target redesign if that improves expectancy and keeps doctrine fit
- Baseline risk doctrine:
  - strategy doctrine references mature `2% per trade`
  - the first capital stage is expected to start around `100 USD`
  - micro-cap override is allowed if the actual effective risk is explicit and daily hard-loss control remains active

## Why BTC Is Not The Mainline For This

- BTC research remains useful, but the Golden Method asks for:
  - pip-fixed logic,
  - FX round-number behavior,
  - Dow-style swing structure,
  - one-trade-per-day style expectations.
- That is a better fit for `USDJPY`.

## Current Status

- First `USDJPY` prototype EA scaffold is created.
- Baseline preset and `9 months train / 3 months OOS` tester configs are created.
- The prototype now supports:
  - flexible take-profit via either fixed pips or explicit `R`,
  - a documented micro-cap risk override for very small balances,
  - more than one trade per day if later setup quality supports it.
- Compile passed.
- Broker symbol check passed on the current MT5 feed:
  - `USDJPY` exists,
  - digits `3`,
  - point `0.001`,
  - minimum lot `0.01`,
  - contract size `100000`.
- On the current feed, `0.01 lot` with a `10 pip` stop risks about `0.63 USD`, so the baseline method is micro-cap viable on `100 USD` from a lot-floor perspective.
- First baseline backtests are complete and both are negative:
  - `9 months train`: `net -3402.23 / PF 0.80 / 192 trades / DD 37.87%`
  - `3 months OOS`: `net -3110.48 / PF 0.50 / 52 trades / DD 32.52%`
- The first implementation is therefore a baseline reject, not a candidate.
- The next cycle should not keep fixed `10 / 10` just because it was in the first illustration.

## Next Cycle

1. Compile the prototype.
2. Verify broker symbol and lot-floor viability on `USDJPY`.
3. Run the first `9 months train / 3 months OOS` backtests.
4. Decide whether the prototype behaves like true follow-through trading or only a loose EMA-touch system.
