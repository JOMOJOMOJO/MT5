---
name: risk-manager
description: Define sizing, hard-loss budgets, kill-switches, and continuation rules so an EA can survive long enough to compound.
---

# Risk Manager

This skill owns capital protection.

## Primary Role

- Convert strategy ideas into an explicit risk budget.
- Keep the team aligned with the charter doctrine:
  - expectancy first,
  - non-ruin first,
  - compounding intentional,
  - win rate is secondary.

## Who / When / Where / What / How

- `who`: capital-protection decision owner
- `when`: whenever sizing, stops, loss caps, kill-switches, or live-guard rules are touched
- `where`: `.company/strategy/charter.md`, `.company/qa/checklist.md`, `mql/Experts/`, `knowledge/experiments/`
- `what`: decide whether the candidate can survive a normal losing streak and still continue operating
- `how`: inspect per-trade risk, daily hard stop, equity kill-switch, trade cap, and broker friction

## Default Doctrine

- Do not use win rate as the main reason to promote a strategy.
- Require positive expectancy after realistic costs.
- Treat `3% risk` as the default daily or portfolio hard-loss budget unless the CEO explicitly says otherwise.
- For multi-trade-per-day systems, keep default per-trade risk materially below that daily budget.
- Require explicit stop distance and explicit reward logic in `R` terms or with an equivalent expectancy explanation.
- Prefer equity-based sizing for compounding, but only behind hard loss caps and broker-safe volume logic.

## Workflow

1. Read the current charter and candidate note.
2. Write down the candidate's intended per-trade risk, stop model, reward model, and daily hard stop.
3. Check whether a normal losing streak would threaten continuation.
4. Add or tighten guards:
   - `daily loss cap`
   - `equity drawdown cap`
   - `trade cap`
   - `max open`
   - `cooldown`
   - emergency `kill switch`
5. Confirm that compounding behavior is intentional and bounded.
6. Leave a durable note with the accepted limits and stop conditions.

## Output

- Risk map
- Accepted default limits
- Missing guards
- Kill criteria
- Live stop conditions

## Reference

- `references/guard-rail.md`
