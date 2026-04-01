# USDJPY Golden Method Spec

## Purpose

- Make `USDJPY` the active mainline research symbol for the next serious cycle.
- Translate the CEO-provided "Golden Method" into a rule set that can be tested, improved, and audited inside this repo.
- Keep the original intent visible so future tuning does not drift away from the source doctrine.

## Why USDJPY, Not BTCUSD

- The requested method is explicitly `pip`-based and assumes round-number structure that is natural for a major FX pair.
- The requested method uses `EMA13 / EMA100`, round numbers, and monthly trade-count expectations that map more naturally to `USDJPY` than to `BTCUSD`.
- The `10 pip / 10 pip` examples are treated as reference illustrations, not permanent constraints.
- `BTCUSD` stays as `secondary` knowledge and research inventory, but the active mainline for this doctrine is `USDJPY`.

## Permanent Doctrine For This Family

- Use `EMA13` and `EMA100` as the baseline environment lines.
- The periods may be tuned later, but any deviation from `13 / 100` must be recorded explicitly.
- Use Dow Theory for trend judgement:
  - trend / no-trend is decided by recent swing highs and swing lows,
  - not by EMA slope alone.
- Use the three trend phases as a required concept:
  - accumulation,
  - follow-through,
  - profit-taking.
- Entries should target the `follow-through` phase.
- Entries during the `profit-taking` phase should be treated as lower-quality or invalid unless a later experiment proves otherwise.
- Define a `trend transition line` from the latest pullback high or pullback low so the follow-through zone is visually and programmatically explicit.

## Volatility Doctrine

- Volatility analysis is not optional for this family.
- The market should be classified into four states:
  - large range / large movement,
  - small range / large movement,
  - large range / small movement,
  - small range / small movement.
- The primary target state is `large range / large movement`.
- Do not trade casually inside a repeated `50 pip` zone.
- If the market keeps interacting inside the same `50 pip` zone, prefer waiting for a meaningful round-number break before considering Strategy 2.
- Check chart-axis expansion or an equivalent programmatic volatility proxy before treating a setup as high quality.

## Operating Targets

- Minimum operating target: at least `1 trade per day` on average.
- Preferred operating target: `2+ trades per day` if the edge survives realistic FX friction.
- Aim for `20+ trades per month` when the market offers valid conditions.
- Use `65%` win rate as a reference target, not as the sole promotion gate.
- Use `13 wins / 7 losses` pace as a narrative benchmark, not as a hard optimization target.
- Use `monthly +12%` only as a rough reference, never as a forced monthly mandate.
- Annual expectancy after costs matters more than any one month.

## Capital Doctrine For This Family

- Intended launch assumption: the first capital stage is around `100 USD`.
- Strategy doctrine: `2% max loss per trade` is the mature reference rule for the method.
- Micro-cap exception:
  - when capital is very small, strict `2%` adherence may be relaxed if broker lot granularity or practical execution would otherwise cripple the method,
  - but the actual effective risk must be explicit,
  - and daily hard-loss control must still stay active.
- Repo doctrine still applies:
  - capital survival comes first,
  - daily or portfolio hard-loss caps remain mandatory,
  - the first real-capital preset may still use lower risk than the full doctrine if deployment safety requires it.
- A strategy that cannot express sane size on the intended broker and capital is not deployable.

## Strategy 1 Baseline

### Long

- `EMA100` is rising.
- Price had been rising, then pulls back and touches `EMA13`.
- Enter long at the EMA13 touch event.
- The `10 pip / 10 pip` example is a reference anchor only.
- Actual stop and target may be tuned, widened, tightened, or converted to an explicit `R` model if the candidate performs better that way.

### Short

- `EMA100` is falling.
- Price had been falling, then rallies back and touches `EMA13`.
- Enter short at the EMA13 touch event.
- The `10 pip / 10 pip` example is a reference anchor only.
- Actual stop and target may be tuned, widened, tightened, or converted to an explicit `R` model if the candidate performs better that way.

### Shape Note

- A sharp `V-shape` pullback is preferred.
- A slow `grinding` pullback is lower quality and should be filtered when possible.

## Strategy 2 Baseline

- A round number is broken by a large directional candle.
- Then trade the follow-up `EMA13` pattern in the breakout direction.
- Do not count repeated round-number interaction within about half a day as a valid breakout.
- Large breakout candle baseline:
  - body at least `4 pips`,
  - body visually dominant versus nearby candles,
  - very small wick relative to the body.
- Fake-break avoidance:
  - if price already reaches the midpoint toward the next round-number zone before the EMA13 retest, the delayed setup is lower quality and should normally be skipped.

## Mental And Journaling Doctrine

- Use probability thinking.
- Use defensive thinking.
- Keep losses small and let valid profits work.
- Backtesting and journaling are part of the edge, not optional habits.

## Translation To Repo Validation

- Source doctrine stays human-readable in this file.
- EA candidates must map the doctrine to explicit rules:
  - EMA environment,
  - Dow swing logic,
  - follow-through filters,
  - transition-line logic,
  - volatility state filter,
  - round-number logic,
  - flexible stop / target logic,
  - fixed-pip or explicit `R` exits,
  - risk sizing.
- Every serious candidate must be checked against this document before promotion or rejection.
