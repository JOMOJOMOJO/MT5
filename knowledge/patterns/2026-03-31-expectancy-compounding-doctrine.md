# 2026-03-31 Expectancy And Compounding Doctrine

- Date: 2026-03-31
- Scope: permanent capital and promotion doctrine for this MT5 company

## Core Rules

- Win rate is not the main target. Positive expectancy is.
- Capital survival comes before raw return.
- Compounding is intentional, but only behind hard loss caps and broker-safe sizing.
- A strategy that trades more often is better only if its edge survives realistic friction and long-window validation.
- If a family cannot meet the active business objective, park it and start a cleaner branch.

## Default Risk Interpretation

- The default meaning of `3% risk` in this repository is:
  - a daily or portfolio hard-loss budget,
  - not a default single-trade risk.
- Multi-trade systems should normally risk only a fraction of that budget per trade.
- Every serious candidate should define:
  - stop distance,
  - reward multiple or payoff logic,
  - per-trade risk,
  - daily hard stop,
  - kill-switch behavior.

## Promotion Consequence

- Do not promote because the win rate looks comfortable.
- Promote because:
  - expectancy is positive after costs,
  - drawdown is survivable,
  - turnover is real in actual MT5,
  - forward behavior matches the research story.

## How To Reuse This

- Cite this note when opening a new family or rewriting the company charter.
- If a candidate intentionally breaks this doctrine, write down why the exception is justified and who approved it.
