# USDJPY Mainline Reset

## Decision

- Active mainline research moves from `BTCUSD` to `USDJPY`.
- `BTCUSD` remains valuable research inventory and can stay as `secondary`, but it is no longer the active mainline for the next serious cycle.

## Why

- The requested doctrine is explicitly FX-oriented:
  - pip-based stops and targets,
  - round-number breakout logic,
  - EMA13 / EMA100 environment,
  - Dow Theory plus trend-transition lines,
  - monthly trade-count expectations around one trade per day.
- The current `BTCUSD` high-turnover family improved, but it still does not match the doctrine closely and remains below the repo live gate.

## New Active Objective

- Build a `USDJPY Golden Method` family that:
  - respects the doctrine in `knowledge/patterns/2026-04-02-usdjpy-golden-method-spec.md`,
  - is measured with `knowledge/patterns/2026-04-02-usdjpy-golden-method-validation.md`,
  - targets repeatable expectancy with realistic FX friction.

## Immediate Execution Order

1. Save the doctrine and validation scorecard in durable repo knowledge.
2. Open a first EA prototype that encodes:
   - Strategy 1 EMA touch logic,
   - Strategy 2 round-number breakout follow-through logic,
   - Dow-style swing judgement,
   - volatility blocking.
3. Compile first.
4. Then run the default `9 months train / 3 months OOS` ladder.
5. Keep `BTCUSD` as secondary inventory unless a later cycle clearly proves it fits the same business goal better.
