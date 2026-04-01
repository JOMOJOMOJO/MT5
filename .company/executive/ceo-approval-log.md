# CEO Approval Log

shared skill, shared MCP, 部署構成の変更はここに残して正式採用とする。

## Pending

- Date:
- Proposal:
- Requested by:
- Impact:
- Decision: pending

## Approved

- Date: 2026-04-02
- Proposal: Pivot the active mainline from BTCUSD to a new USDJPY Golden Method family, save the CEO-provided doctrine and validation scorecard as durable repo knowledge, and create the first prototype EA plus repo-managed preset and tester configs for that family.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `.company/secretary/queue.md`
  - `.company/qa/checklist.md`
  - `.company/release/checklist.md`
  - `knowledge/patterns/2026-04-02-usdjpy-golden-method-spec.md`
  - `knowledge/patterns/2026-04-02-usdjpy-golden-method-validation.md`
  - `knowledge/company/2026-04-02-usdjpy-mainline-reset.md`
  - `knowledge/experiments/2026-04-02-usdjpy-golden-method-kickoff.md`
  - `mql/Experts/usdjpy_20260402_golden_method.mq5`
  - `reports/presets/usdjpy_20260402_golden_method-baseline.set`
  - `reports/backtest/usdjpy_20260402_golden_method-train-9m.ini`
  - `reports/backtest/usdjpy_20260402_golden_method-oos-3m.ini`

- Date: 2026-04-01
- Proposal: Formalize repo-wide git branch strategy and publish workflow, document the reusable EA improvement cycle and live-ready definition, add micro-cap lot-floor viability as a permanent gate, and let Codex manage branch / commit / push flow under the documented rules.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `.company/git/branch-strategy.md`
  - `scripts/git-start-task.ps1`
  - `scripts/git-publish-task.ps1`
  - `AGENTS.md`
  - `.company/ORGANIZATION.md`
  - `.company/strategy/charter.md`
  - `.company/qa/checklist.md`
  - `.company/release/checklist.md`
  - `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`
  - `knowledge/patterns/2026-04-01-live-ready-definition.md`
  - `knowledge/company/2026-04-01-git-governance-and-live-ready-definition.md`
  - `.company/improvement/reviews/2026-04-01-140500-git-governance-and-live-ready-definition-review.md`

- Date: 2026-04-01
- Proposal: Add a repo-wide plateau review and strategy-family switch protocol so the company stops retuning structurally mismatched families, parks quality-positive but objective-negative families, and opens a new family quickly when the mainline stalls.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `AGENTS.md`
  - `.company/strategy/charter.md`
  - `.company/strategy/family-lifecycle.md`
  - `.company/qa/checklist.md`
  - `.company/release/checklist.md`
  - `.company/secretary/queue.md`
  - `plugins/mt5-company/skills/company/references/skill-operating-model.md`
  - `plugins/mt5-company/scripts/evaluate_strategy_plateau.py`
  - `scripts/review-strategy-plateau.ps1`
  - `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`
  - `knowledge/patterns/2026-04-01-strategy-plateau-switch-protocol.md`
  - `knowledge/experiments/2026-04-01-btcusd-session-meanrev-plateau-review.md`
  - `knowledge/company/2026-04-01-strategy-plateau-governance.md`
  - `.company/improvement/reviews/2026-04-01-150000-strategy-plateau-governance-review.md`

- Date: 2026-03-31
- Proposal: Adopt expectancy-first, compounding-first, non-ruin capital doctrine as permanent repo policy; treat `3% risk` as the default daily or portfolio hard-loss budget instead of default single-trade risk; park `btcusd_20260330_session_meanrev` as a secondary candidate; and start a new mainline EA family `btcusd_20260331_session_pair_rr`.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `AGENTS.md`
  - `.company/strategy/charter.md`
  - `.company/qa/checklist.md`
  - `.company/release/checklist.md`
  - `.company/ORGANIZATION.md`
  - `.company/secretary/queue.md`
  - `plugins/mt5-company/skills/company/references/skill-operating-model.md`
  - `plugins/mt5-company/skills/risk-manager/SKILL.md`
  - `knowledge/patterns/2026-03-31-expectancy-compounding-doctrine.md`
  - `knowledge/experiments/2026-03-30-btcusd-session-meanrev-live-ops.md`
  - `knowledge/experiments/2026-03-31-btcusd-session-pair-rr-kickoff.md`
  - `mql/Experts/btcusd_20260331_session_pair_rr.mq5`
  - `reports/presets/btcusd_20260331_session_pair_rr-baseline.set`
  - `reports/backtest/btcusd_20260331_session_pair_rr-baseline-1y.ini`

- Date: 2026-03-31
- Proposal: Formalize the org scorecard, skill-roster discipline, operating review rhythm, and reusable research-rules knowledge so the company can self-improve without adding redundant roles.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `.company/ORGANIZATION.md`
  - `.company/improvement/org-scorecard.md`
  - `.company/improvement/skill-roster.md`
  - `.company/improvement/operating-rhythm.md`
  - `.company/qa/checklist.md`
  - `.company/secretary/queue.md`
  - `knowledge/patterns/2026-03-31-ea-research-reuse-rules.md`
  - `AGENTS.md`
  - `README.md`

- Date: 2026-03-30
- Proposal: Add the `improvement` department, the `continuous-improvement-office` skill, and company snapshot history for org, skill, and MCP changes.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `.company/improvement/`
  - `plugins/mt5-company/skills/continuous-improvement-office/`
  - `plugins/mt5-company/scripts/company_snapshot.py`
  - `plugins/mt5-company/scripts/mt5_mcp_server.py`
  - `README.md`
  - `AGENTS.md`

- Date: 2026-03-30
- Proposal: Add the `market-intelligence` department and the `statistical-edge-research` skill for MT5 bar-data mining, session analysis, and hypothesis-to-EA workflows.
- Requested by: CEO
- Decision: approved
- Effective files:
  - `plugins/mt5-company/skills/statistical-edge-research/`
  - `plugins/mt5-company/scripts/statistical_edge_research.py`
  - `plugins/mt5-company/skills/company/references/departments.md`
  - `AGENTS.md`

## Rejected

- Date:
- Proposal:
- Requested by:
- Reason:
