# MT5 EA Workspace

This repository is a Git-managed workspace for building MetaTrader 5 Expert Advisors with Codex.

Shared automation and operating rules live in the repository so the workflow can move between machines without rebuilding everything in `~/.codex`.

## Shared Codex Assets

- `.agents/plugins/marketplace.json`: repo-local plugin marketplace
- `plugins/mt5-company/`: shared plugin, skills, and MCP config
- `.company/`: company-style intake, QA, and release state
- `.company/improvement/`: company self-review, snapshots, and org-change history
- `knowledge/`: accumulated backtests, optimizations, lessons learned, and reusable patterns
- `scripts/`: repeatable compile and backtest entrypoints
- `mql/`: MQL5 source tree
- `reports/backtest/runs/`: machine-readable backtest records imported from MT5 reports

## Policy

- Shared skills belong in `plugins/mt5-company/skills/`.
- Shared MCP definitions belong in `plugins/mt5-company/.mcp.json`.
- Personal credentials and machine-only MCP servers stay in `~/.codex/config.toml`.
- EA source goes under `mql/Experts/` and reusable modules under `mql/Include/`.
- Skill names stay stable in ASCII, but the skill body can be written in Japanese.

## Basic Workflow

1. Triage work through the `company` skill and `.company/secretary/queue.md`.
2. Ask `research-director` to define the test ladder before changing code:
   short optimization/search window, locked-parameter validation window, and explicit out-of-sample window.
3. Implement or refactor EA code under `mql/`.
4. Compile with `scripts/compile.ps1`.
5. Run short-window parameter search with MT5 optimization and `scripts/optimize.ps1` when ranges are ready.
6. Freeze the candidate parameters and run single tests with `scripts/backtest.ps1`.
7. Import MT5 reports into `reports/backtest/runs/`.
8. Review logic with `mq5-review`, `strategy-critic`, `systematic-ea-trader`, and `risk-manager`.
9. Save durable findings into `knowledge/` with the `knowledge-capture` skill or the MT5 MCP tools.
10. Promote only after long validation and out-of-sample checks; use `forward-live-ops` before demo/live.
11. Periodically review the company itself with `continuous-improvement-office`, then record org, skill, and MCP diffs under `.company/improvement/`.
12. Keep `.company/improvement/org-scorecard.md`, `.company/improvement/skill-roster.md`, and `knowledge/patterns/` current so lessons are reused across EA families.

## Validation Ladder

Use both MT5 optimization and long fixed-parameter validation. They solve different problems.

- Optimization or parameter search: use a short in-sample window such as 1 week to 1 month to find promising regions quickly.
- Locked validation: re-run the selected parameters on a longer fixed window, usually 6 to 12 months.
- Explicit out-of-sample: run a separate untouched period after the validation window.
- Forward or demo: move only candidates that survive the earlier gates.

Use MT5 built-in forward optimization when you want fast screening inside the tester. Use explicit repo-managed out-of-sample single tests when you want reproducible artifacts in Git.

## Next Step

Add your first EA under `mql/Experts/<ea-name>/<ea-name>.mq5`, then point `MT5_METAEDITOR` and `MT5_TERMINAL` to your local MT5 binaries.
