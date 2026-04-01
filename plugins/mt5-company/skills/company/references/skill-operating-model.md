# Skill Operating Model

This repository runs on `1 skill = 1 primary role`.

Each skill should be described with the same frame:

- `who`: who owns the decision
- `when`: when the skill is used
- `where`: which files, reports, or folders it works from
- `what`: what it is supposed to decide
- `how`: how it reaches that decision
- `output`: what artifact it leaves behind
- `handoff`: who receives the result next

## Core Flow

### `company`

- `who`: intake and routing owner
- `when`: at the start of a new thread or when work needs rerouting
- `where`: `.company/secretary/queue.md`, `.company/ORGANIZATION.md`
- `what`: choose the leanest path through the company
- `how`: reuse existing roles first, avoid unnecessary new structure
- `output`: queue updates and routing notes
- `handoff`: `research-director`, `continuous-improvement-office`, or the relevant specialist

### `research-director`

- `who`: research-plan owner
- `when`: before a new strategy family, experiment ladder, or optimization order is set
- `where`: `knowledge/experiments/`, `knowledge/optimizations/`, `reports/`
- `what`: define the next hypotheses and the order to test them
- `how`: separate logic, risk, execution, and validation questions
- `output`: a short ordered experiment plan with a promotion path
- `handoff`: `statistical-edge-research`, `systematic-ea-trader`, `strategy-critic`

### `statistical-edge-research`

- `who`: bar-data mining owner
- `when`: before heavy coding or when the team needs chart-derived entry hypotheses
- `where`: `reports/research/`, `knowledge/patterns/`, `plugins/mt5-company/scripts/statistical_edge_research.py`
- `what`: identify repeatable session, volatility, and regime biases
- `how`: mine bar data, compare train/test splits, reject weak pattern stories
- `output`: candidate tables, edge summaries, and reusable pattern notes
- `handoff`: `research-director`, `systematic-ea-trader`

### `systematic-ea-trader`

- `who`: rule-quality owner
- `when`: when a strategy idea must become explicit EA logic
- `where`: `mql/Experts/`, `reports/backtest/`, `knowledge/experiments/`
- `what`: decide whether the rules are precise, repeatable, and disciplined enough
- `how`: judge trade count, payoff shape, drawdown shape, and side-specific logic quality
- `output`: a keep, tighten, or reject judgement on the rules
- `handoff`: `strategy-critic`, `risk-manager`, `release-manager`

### `strategy-critic`

- `who`: kill-or-split owner
- `when`: after a candidate looks promising or when progress stalls
- `where`: `reports/backtest/runs/`, `knowledge/backtests/`, `knowledge/experiments/`
- `what`: decide whether the family should be kept, parked, split, or killed
- `how`: inspect weak windows, sample quality, friction, and OOS behavior
- `output`: a clear `continue`, `tighten`, `park and open new family`, or `kill` note
- `handoff`: `research-director`, `company`

### `backtest-analysis`

- `who`: MT5 report interpretation owner
- `when`: after HTML or imported tester artifacts land
- `where`: `reports/backtest/runs/`, `knowledge/backtests/`
- `what`: compare the new run against the current baseline or candidate
- `how`: use actual artifacts, not memory, and describe what improved or broke
- `output`: imported run summary and comparison note
- `handoff`: `strategy-critic`, `risk-manager`, `release-manager`

### `risk-manager`

- `who`: capital-protection owner
- `when`: whenever sizing, loss caps, kill-switches, or live guards are touched
- `where`: `.company/strategy/charter.md`, `.company/qa/checklist.md`, `mql/Experts/`, `knowledge/experiments/`
- `what`: turn a strategy into an explicit survivable risk budget
- `how`: define per-trade risk, daily hard stop, peak-to-valley kill-switch, and continuation rules
- `output`: documented limits, guard rails, and live stop criteria
- `handoff`: `release-manager`, `forward-live-ops`

### `release-manager`

- `who`: promotion-gate owner
- `when`: when a candidate moves from research toward demo or live
- `where`: `.company/release/`, `.company/qa/`, `reports/backtest/`, `knowledge/experiments/`
- `what`: decide whether the candidate is ready to move up one stage
- `how`: check artifacts, reproducibility, risk doctrine, and rollback clarity
- `output`: `promote`, `hold`, or `reject`
- `handoff`: `forward-live-ops`, `company`

### `forward-live-ops`

- `who`: demo/live monitoring owner
- `when`: after a candidate earns forward review
- `where`: telemetry CSV files, `knowledge/experiments/`, `.company/release/`
- `what`: decide whether live behavior still matches the research assumptions
- `how`: inspect rule-trigger counts, spread blocks, trade counts, slippage, and emergency procedures
- `output`: forward-review note, blocker summary, and operations playbook
- `handoff`: `risk-manager`, `research-director`

## Governance Flow

### `continuous-improvement-office`

- `who`: org-improvement owner
- `when`: when shared workflow, skills, or MCP structure changes
- `where`: `.company/improvement/`, `knowledge/company/`
- `what`: compare the current company against the previous snapshot
- `how`: capture snapshots, review diffs, and turn them into reusable knowledge
- `output`: snapshot, review, and company knowledge note
- `handoff`: `org-designer`, `talent-manager`, `executive`

### `org-designer`

- `who`: org-structure owner
- `when`: when departments, approval routes, or routing rules need redesign
- `where`: `.company/ORGANIZATION.md`, `AGENTS.md`, `README.md`
- `what`: decide how the company should be structured
- `how`: add only the minimum structure needed to improve decision quality
- `output`: organization updates and rationale
- `handoff`: `executive`, `continuous-improvement-office`

### `talent-manager`

- `who`: skill-roster owner
- `when`: when a shared skill may need to be added, merged, or removed
- `where`: `plugins/mt5-company/skills/`, `.company/improvement/skill-roster.md`
- `what`: decide whether a role is truly missing
- `how`: review overlap first, then keep, merge, add, or remove
- `output`: roster decision and change note
- `handoff`: `executive`, `continuous-improvement-office`

### `professional-trader`

- `who`: discretionary execution realism owner
- `when`: when the team wants market-fit, broker-fit, or live realism judgement
- `where`: `knowledge/experiments/`, `reports/backtest/`
- `what`: decide whether the idea still makes sense as a traded product
- `how`: inspect friction, session behavior, instrument character, and operational realism
- `output`: practical market-fit review
- `handoff`: `systematic-ea-trader`, `strategy-critic`

## Operating Rule

- Do not create a new skill until the team can state the missing role in one sentence.
- A skill owns one primary decision. It can support other work, but it should not become a vague catch-all role.
- If two skills are repeatedly making the same decision, merge the responsibility instead of growing the org.
