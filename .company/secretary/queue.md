# Secretary Queue

## Inbox

- [ ] Set `MT5_METAEDITOR` for local compilation.
- [ ] Set `MT5_TERMINAL` for tester runs.

## Active

- [ ] Stand up repo-local company workflow for MT5 EA development.
- [ ] Add optimization workflow, governance rules, and org roles for the MT5 company model.
- [ ] Run company-improvement reviews when shared org, skill, or MCP changes land.
- [ ] Narrow the BTCUSD redesign from "mixed-direction prototype" to "cross-year robust long-only live candidate".
- [ ] Analyze the weak 2024 BTCUSD months and derive a long-side regime filter for the H1/H4/D1 candidate.
- [ ] Make H1 metadata-backed runs the canonical lineage and phase older M1 imports into legacy status.
- [ ] Decide whether the short side should become a separate EA instead of staying inside the BTCUSD long baseline.

## Blocked

- [ ] Waiting for local `MT5_METAEDITOR` and `MT5_TERMINAL` paths.

## Done

- [x] Create repo-local Codex plugin, marketplace, and skill scaffold.
- [x] Create the first EA under `mql/Experts/`.
- [x] Add the first tester config at `reports/backtest/tester.ini`.
- [x] Switch tester configs to repo-managed preset files instead of implicit MT5 last-used inputs.
- [x] Fix the first EA review issues around `CopyBuffer` handling and magic-number isolation.
- [x] Compile `mql/Experts/btcusd_20260124.mq5` successfully with MetaEditor.
- [x] Run the first MT5 backtest and save the HTML report into the repo.
- [x] Import the first MT5 report into `reports/backtest/runs/`.
- [x] Improve the first BTCUSD week-1 setup so it produces actual trades, not just a clean zero-trade report.
- [x] Add long validation and explicit OOS configs for the first BTCUSD EA.
- [x] Add the improvement department and company snapshot history for org, skill, and MCP changes.
- [x] Convert company snapshots into reusable knowledge under `knowledge/company/`.
- [x] Redesign `btcusd_20260124` into an asymmetric regime model and recover positive week/1M/OOS runs.
- [x] Kill the shared short-side baseline and promote an H1/H4/D1 long-only candidate for BTCUSD.
- [x] Add report-sidecar metadata and rebuildable backtest catalog support.
