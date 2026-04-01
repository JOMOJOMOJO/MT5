# Strategy Plateau Switch Protocol

- Date: `2026-04-01`
- Scope: repo-wide rule for stopping over-tuning and switching to a new strategy family

## Why

- AI makes iteration cheap.
- Cheap iteration is useful only if the repo can also stop weak families quickly.
- Without a plateau rule, the team keeps polishing a structure that no longer matches the business objective.

## Signals That A Family Has Plateaued

- three serious cycles without meaningful objective improvement
- positive quality but persistent failure on the active objective
- recurring explanation of failure by parameter tweaks instead of a clear market behavior
- indicator stacking starts growing faster than evidence quality
- the same weakness keeps returning in actual MT5 or OOS

## Default Response

- If the family still has quality:
  - keep it as `secondary` or `parked`
  - record why it no longer fits the main objective
  - start a new family
- If the family no longer has quality:
  - kill it
  - keep only the lessons

## Mainline Rule

- The repo should keep one explicit `mainline` family.
- A family is not allowed to stay mainline just because it was expensive to build.
- If plateau review says `park_secondary_and_open_new_family`, the replacement work starts immediately.

## Automation

- Run a plateau review after each serious cycle.
- Keep the review artifact in Git.
- Update the queue with:
  - whether the family continues,
  - whether a new family must be opened,
  - and what type of research should start next.
