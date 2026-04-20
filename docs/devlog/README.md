# Devlog

`docs/devlog/` stores task-level development logs for this repo.

Use this directory when a task produced a decision that should be easy to review later without replaying the full chat:

- EA logic changed
- validation direction changed
- a meaningful option was rejected
- a failed run produced a concrete next move
- a branch of work needs a short audit trail

Keep each entry short. A devlog is not the primary evidence store.

Primary evidence should stay in existing repo areas:

- `reports/` for backtest, forward, optimization, charts, and screenshots
- `knowledge/` for durable internal findings and reusable doctrine
- `.company/` for governance, QA, release, and operating policy

Each devlog should link to the smallest useful set of supporting files instead of copying them.

Suggested filename:

- `YYYY-MM-DD-short-topic.md`
