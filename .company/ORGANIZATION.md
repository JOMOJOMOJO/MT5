# MT5 Company

This repository uses a small company model to keep EA development organized without adding bureaucracy.

The company should improve itself, but it should stay lean. The default answer is not "add another role". The default answer is:

1. reuse existing roles better,
2. capture what was learned,
3. add structure only when the current structure is clearly losing decision quality.

## Departments

- `secretary/`: intake, queue management, daily notes, and task routing
- `strategy/`: trading hypothesis, market assumptions, and experiment planning
- `qa/`: backtest criteria, regression checks, and validation notes
- `release/`: release readiness, parameter tracking, and handoff checks
- `improvement/`: org review, skill/MCP governance, and self-improvement records
- `executive/`: CEO approval routes for root policy changes

Start at `secretary/`. Only add more departments if the workload becomes repetitive enough to justify them.

## Shared Rules

- Shared workflow belongs in Git.
- Branch and publish discipline belongs in `.company/git/branch-strategy.md`.
- Personal secrets do not belong in `.company/`.
- Every material strategy change should connect to a QA or backtest note.
- Keep code decisions in `mql/` and operating decisions in `.company/`.
- Permanent capital doctrine belongs in `.company/strategy/charter.md` and must not be overridden casually inside one EA family.
- The default company stance is `expectancy first`, `non-ruin first`, `compounding intentional`.
- Before adding a new shared skill, review `.company/improvement/skill-roster.md`.
- Before promoting a candidate toward live, review `.company/improvement/org-scorecard.md`.
- When a family no longer matches the active objective, mark it `parked` instead of pretending it is still the mainline.
- Every org or workflow improvement should leave reusable knowledge under `knowledge/company/` or `knowledge/patterns/`.
