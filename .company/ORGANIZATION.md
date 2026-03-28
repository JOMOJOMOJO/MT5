# MT5 Company

This repository uses a small company model to keep EA development organized without adding bureaucracy.

## Departments

- `secretary/`: intake, queue management, daily notes, and task routing
- `strategy/`: trading hypothesis, market assumptions, and experiment planning
- `qa/`: backtest criteria, regression checks, and validation notes
- `release/`: release readiness, parameter tracking, and handoff checks

Start at `secretary/`. Only add more departments if the workload becomes repetitive enough to justify them.

## Shared Rules

- Shared workflow belongs in Git.
- Personal secrets do not belong in `.company/`.
- Every material strategy change should connect to a QA or backtest note.
- Keep code decisions in `mql/` and operating decisions in `.company/`.
