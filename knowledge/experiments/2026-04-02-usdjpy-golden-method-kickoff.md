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
  - `10 pip` stop
  - `10 pip` target
- Baseline risk doctrine:
  - strategy doctrine references `2% per trade`
  - deployment risk may still be reduced later for first-capital use

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
- Compile passed.
- Broker symbol check passed on the current MT5 feed:
  - `USDJPY` exists,
  - digits `3`,
  - point `0.001`,
  - minimum lot `0.01`,
  - contract size `100000`.
- On the current feed, `0.01 lot` with a `10 pip` stop risks about `0.63 USD`, so the baseline method is micro-cap viable on `100 USD` from a lot-floor perspective.

## Next Cycle

1. Compile the prototype.
2. Verify broker symbol and lot-floor viability on `USDJPY`.
3. Run the first `9 months train / 3 months OOS` backtests.
4. Decide whether the prototype behaves like true follow-through trading or only a loose EMA-touch system.
