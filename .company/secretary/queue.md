# Secretary Queue

## Inbox

- [ ] Set `MT5_METAEDITOR` for local compilation.
- [ ] Set `MT5_TERMINAL` for tester runs.

## Active

- [ ] Stand up repo-local company workflow for MT5 EA development.
- [ ] Add optimization workflow, governance rules, and org roles for the MT5 company model.
- [ ] Run company-improvement reviews when shared org, skill, or MCP changes land.
- [ ] Keep `.company/improvement/org-scorecard.md` and `.company/improvement/skill-roster.md` current as strategy families and skills evolve.
- [ ] Narrow the BTCUSD redesign from "mixed-direction prototype" to "cross-year robust long-only live candidate".
- [ ] Analyze the weak 2024 BTCUSD months and derive a long-side regime filter for the H1/H4/D1 candidate.
- [ ] Make H1 metadata-backed runs the canonical lineage and phase older M1 imports into legacy status.
- [ ] Decide whether the parked short side should be retired or relaunched as a completely separate actual-first EA project.
- [ ] Promote the `btcusd_20260330_session_meanrev` no-Friday / skip-03 candidate from Python validation into an MT5 report-backed candidate.
- [ ] Diagnose why MT5 command-line tester stopped auto-starting after 2026-03-30 14:53.
- [ ] Run demo-forward telemetry for `btcusd_20260330_session_meanrev-bull15_40_long_h8_no_sun` and compare realized trade frequency against the 1-year actual result.
- [ ] Compare `bull15_40 h8 no_sun` versus `bull37 long-only` after the first demo-forward week and keep only one current live candidate.
- [ ] Add a recurring quarterly review record for live candidates and keep the cadence in release notes.
- [ ] Execute a 1-week demo-forward run with `liveguards-mid` and archive runtime rule-trigger stats.
- [ ] Review `mt5_company_btcusd_20260330_session_meanrev_bull15_40_long_h8_no_sun.csv` after the first demo-forward week and summarize blocker frequencies.
- [ ] Rework the surviving long-only branch for higher turnover without breaking actual PF, instead of reviving mixed-direction combos.
- [ ] Search for a second long-only bucket or regime control instead of adding more weekday exclusions to the same late-session bucket.
- [ ] Derive a regime control for the surviving late-session long edge instead of adding new NY time-of-day buckets.

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
- [x] Add statistical-edge research plus a session mean-reversion prototype for BTCUSD M5.
- [x] Add a Python validator fallback for the session mean-reversion EA when MT5 CLI tester is unstable.
- [x] Add slippage / execution-gap assumptions to the Python validator for the session-mean-reversion candidate.
- [x] Add weekday / blocked-hour filters and promote a stronger BTCUSD M5 short-only baseline.
- [x] Implement balance-based daily-loss-cap blocking in the Python validator.
- [x] Extend the validator candidate to 80k BTCUSD bars and record that the current family still breaks in 2025 summer regimes.
- [x] Separate seasonality from chart-pattern effects and add ATR% / distance / RSI-cap regime controls.
- [x] Promote a new 80k/50k-balanced short candidate (`dist 0.87 / rsi 64-82`) that restores ~5 trades/day on 80k while keeping PF > 1.
- [x] Implement live-guard controls in EA/validator (daily trade cap, losing-streak cooldown, optional equity DD cap) and validate the `liveguards-mid` profile.
- [x] Publish a live operations playbook for `btcusd_20260330_session_meanrev`.
- [x] Re-run MT5 HTML report-backed validation for `short_dist=0.87 / rsi 64-82` profile and archive under canonical lineage.
- [x] Re-run MT5 HTML report-backed validation for `liveguards-mid` and compare with validator output.
- [x] Add runtime telemetry export for `entry/exit/loss_lock/daily_summary` so forward-demo can be audited.
- [x] Add a reusable telemetry summarizer and archive the MT5 baseline plus the rejected `spread3500` probe as knowledge.
- [x] Probe wider spread gates in MT5 and reject `max_spread_pips=3000` / `3500` as live-candidate promotions.
- [x] Add a second NY short bucket to EA/validator and reject it as a baseline promotion after MT5 report-backed comparison.
- [x] Reject the `NY stacked short` bucket after MT5 report-backed probes even though the Python validator looked acceptable.
- [x] Promote `asia short + late long 1.50 / RSI<=35 / hold 12` as the current higher-turnover candidate preset for `btcusd_20260330_session_meanrev`.
- [x] Formalize org scorecard, skill-roster discipline, and reusable research rules so the company can improve itself without adding unnecessary roles.
- [x] Refine the bull-filtered long branch and promote `1.50 / RSI<=37 / hold 12` as the current best-balance MT5 candidate.
- [x] Add side-specific hold/exit controls plus short trend filter to the session-mean-reversion EA and validator.
- [x] Run a direction split on the 1-year actual MT5 window and confirm that only the long side survives for `btcusd_20260330_session_meanrev`.
- [x] Promote `bull15_40 long-only` as the current balance candidate and keep `bull37 long-only` as the conservative reference.
- [x] Probe the Sunday filter plus shorter hold on the surviving long-only branch and promote `bull15_40 h8 no_sun` as the operations live-candidate.
- [x] Reject the `bull15_40 h8 no_sun_no_tue` weekday-tightening probe after actual MT5 comparison.
- [x] Fix the long-path import failure in `mt5_backtest_tools.py` so report bundles copy cleanly without `--no-copy`.
- [x] Reject the NY second-long-bucket expansion before actual MT5 because the long-window train slice broke.
