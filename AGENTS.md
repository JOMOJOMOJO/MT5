# MT5 Workspace Rules

- Treat this repository as the source of truth for shared Codex workflow.
- Prefer repo-local assets in `plugins/mt5-company/` over editing `~/.codex`, unless the change is personal or machine-specific.
- Use `.company/secretary/queue.md` for intake and routing when the user is planning, triaging, or juggling multiple threads of work.
- Save durable findings under `knowledge/` rather than leaving them only in chat or ad hoc notes.
- Prefer structured imports into `reports/backtest/runs/` before writing narrative notes into `knowledge/backtests/`.
- Keep EA code under `mql/Experts/` and shared logic under `mql/Include/`.
- Use `scripts/compile.ps1` for builds and `scripts/backtest.ps1` for tester runs when possible.
- When changing strategy behavior, connect the code change to a backtest or QA note under `.company/` or `reports/`.
- Skill identifiers should stay stable, but Japanese skill bodies and references are preferred in this repository.
