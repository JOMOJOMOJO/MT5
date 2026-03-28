# MT5 EA Workspace

This repository is a Git-managed workspace for building MetaTrader 5 Expert Advisors with Codex.

Shared automation and operating rules live in the repository so the workflow can move between machines without rebuilding everything in `~/.codex`.

## Shared Codex Assets

- `.agents/plugins/marketplace.json`: repo-local plugin marketplace
- `plugins/mt5-company/`: shared plugin, skills, and MCP config
- `.company/`: company-style intake, QA, and release state
- `knowledge/`: accumulated backtests, lessons learned, and reusable patterns
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
2. Implement or refactor EA code under `mql/`.
3. Compile with `scripts/compile.ps1`.
4. Run tester jobs with `scripts/backtest.ps1`.
5. Review logic with the `mq5-review` skill.
6. Import MT5 reports into `reports/backtest/runs/`.
7. Analyze losing runs with the `backtest-analysis` skill.
8. Save durable findings into `knowledge/` with the `knowledge-capture` skill or the MT5 MCP tools.
9. Prepare release notes and regression checks with the `release-manager` skill.

## Next Step

Add your first EA under `mql/Experts/<ea-name>/<ea-name>.mq5`, then point `MT5_METAEDITOR` and `MT5_TERMINAL` to your local MT5 binaries.
