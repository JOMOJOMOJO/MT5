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
- Default rolling review for each improved candidate:
  - latest `12 months`
  - oldest `9 months` for train / tuning
  - latest `3 months` for forward-style OOS
- Generate the split configs automatically:
  - `powershell -ExecutionPolicy Bypass -File scripts/new-rolling-12m-split.ps1 -BaseConfigPath <1y-config.ini>`

Use MT5 built-in forward optimization when you want fast screening inside the tester. Use explicit repo-managed out-of-sample single tests when you want reproducible artifacts in Git.

## Next Step

Add your first EA under `mql/Experts/<ea-name>/<ea-name>.mq5`, then point `MT5_METAEDITOR` and `MT5_TERMINAL` to your local MT5 binaries.

## Current Demo-Forward Candidate

- EA:
  - `mql/Experts/btcusd_20260330_session_meanrev.mq5`
- Preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set`
- Release packet:
  - `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md`

## Current Small-Live Staged Preset

- Preset:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set`
- Release packet:
  - `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.md`
- Role:
  - use this only after the guarded2 demo-forward gate passes,
  - use it for the first real-capital stage instead of taking the demo preset straight to full size.

## Demo-Forward Review

- Prepare the operator packet:
  - `powershell -ExecutionPolicy Bypass -File scripts/prepare-demo-forward.ps1`
- Start a unique demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-demo-forward.ps1`
- Each start writes a launch manifest in `reports/live/` so close-out can use the exact runtime preset and telemetry lineage.
- Summarize the latest telemetry run:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-forward-telemetry.ps1`
- Evaluate the promotion gate:
  - `powershell -ExecutionPolicy Bypass -File scripts/evaluate-forward-gate.ps1`
- Close the demo-forward run:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-demo-forward.ps1 -ManifestPath <launch-manifest.json>`
- Run the live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/live-preflight.ps1`
- Review live/demo operator state:
  - `powershell -ExecutionPolicy Bypass -File scripts/review-live-state.ps1`
- Apply the latest live review and leave an action artifact:
  - `powershell -ExecutionPolicy Bypass -File scripts/act-on-live-review.ps1`
- Pause, flatten, or resume the EA:
  - `powershell -ExecutionPolicy Bypass -File scripts/set-ea-operator-mode.ps1 -Mode pause`
- guarded2 and smalllive presets now emit a timed status heartbeat every `60` seconds in demo/live.

## Small-Live Handoff

- Prepare the first-capital packet:
  - `powershell -ExecutionPolicy Bypass -File scripts/prepare-small-live.ps1`
- Run the staged small-live preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/small-live-preflight.ps1`
- Start first-capital only after the staged preflight clears:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-small-live.ps1`
- Start a unique small-live telemetry cycle:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-demo-forward.ps1 -BasePresetPath reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015.set -RunLabel small-live`
- The preferred path is `start-small-live.ps1`, because it blocks launch on a failing staged preflight and also writes a launch manifest.
- Apply the latest live review and leave an action artifact:
  - `powershell -ExecutionPolicy Bypass -File scripts/act-on-live-review.ps1`
