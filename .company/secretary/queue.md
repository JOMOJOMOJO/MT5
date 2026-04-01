# Secretary Queue

## Inbox

- [ ] Set `MT5_METAEDITOR` for local compilation.
- [ ] Set `MT5_TERMINAL` for tester runs.

## Active

- [ ] Run company-improvement reviews when shared org, skill, or MCP changes land.
- [ ] Keep `.company/improvement/org-scorecard.md` and `.company/improvement/skill-roster.md` current as strategy families and skills evolve.
- [ ] Keep `btcusd_20260330_session_meanrev` parked as a turnover-research family, but run `bull37_long_h12_live035_guarded2` as the current live-track candidate.
- [ ] Run demo-forward telemetry for `btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2` and compare realized behavior against the 1-year actual run.
- [ ] Use `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md` as the single source of truth for promotion, rollback, and quarterly review.
- [ ] Write at least one forward gate report with `scripts/evaluate-forward-gate.ps1` before any small-live discussion.
- [ ] After the guarded2 demo-forward gate passes, start first-capital deployment with `btcusd_20260330_session_meanrev-bull37_long_h12_smalllive015`, not the proving preset.
- [ ] Use the operator command file and status heartbeat during demo-forward so the candidate can be paused or flattened without editing the EA.
- [ ] Run `scripts/live-preflight.ps1` before any demo-forward handoff or small-live discussion.
- [ ] Run `scripts/review-live-state.ps1` during demo or small-live so operator decisions come from telemetry + gate + heartbeat, not ad hoc judgement.
- [ ] After loading the refreshed EA build in demo/live, confirm the status heartbeat refreshes every 60 seconds and clears the stale-heartbeat review state.
- [ ] Treat the recent OOS check (`2026-01-01` to `2026-03-30`) as passed on quality but still below the turnover objective for `btcusd_20260330_session_meanrev`.
- [ ] Run `scripts/small-live-preflight.ps1` before any first-capital launch.
- [ ] Use `scripts/start-small-live.ps1` so first-capital launch is blocked unless the staged preflight clears or an explicit override is accepted.
- [ ] Use `scripts/act-on-live-review.ps1` so operator actions leave a durable audit artifact.
- [ ] Use the launch manifest written by `scripts/start-demo-forward.ps1` or `scripts/start-small-live.ps1` when closing any demo/small-live run.
- [ ] Advance `live-preflight` from `review` to `pass` by replacing the baseline self-check with a real demo-forward review + gate.
- [ ] Use `scripts/start-demo-forward.ps1` so every forward cycle gets its own telemetry file instead of appending onto the baseline artifact.
- [ ] Launch `btcusd_20260331_session_pair_rr` as the new mainline family for expectancy-first, fixed-`R`, compounding-aware BTCUSD research.
- [ ] Use bar-data mining to find repeatable multi-trade-per-day entry zones before large optimization sweeps.
- [ ] Rebuild the `session_pair_rr` entry construction from fresh bar-data mining, because the first `pair / long-only / short-only` actual MT5 runs all failed.
- [ ] Validate that the next `session_pair_rr` hypothesis clears actual MT5 before more RR tuning.
- [ ] Keep one explicit mainline family and mark all others as `secondary`, `parked`, or `legacy`.
- [ ] Add a recurring quarterly review record for any family that reaches demo or live candidate status.

## Blocked

- [ ] (none)

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
- [x] Adopt expectancy-first, compounding-first, non-ruin capital doctrine as a permanent company rule.
- [x] Park `btcusd_20260330_session_meanrev` as a secondary low-turnover candidate instead of keeping it as the mainline.
- [x] Run the first actual MT5 baseline for `btcusd_20260331_session_pair_rr` and reject the initial `pair`, `long-only`, and `short-only` variants.
- [x] Promote `btcusd_20260330_session_meanrev-bull37_long_h12_live035` as the current live-track candidate under the new capital doctrine.
- [x] Compare `live035`, `guarded`, and `guarded2`, and promote `guarded2` as the more deployable live-track preset.
- [x] Add demo-forward preparation, telemetry review, and a release packet for the current `guarded2` candidate.
- [x] Add a forward gate evaluator so demo-forward promotion is judged mechanically against the baseline.
- [x] Add operator pause / flatten control and a live status heartbeat for the current `guarded2` candidate.
- [x] Restore fast, reproducible tester runs by disabling operator-control heartbeat paths inside MT5 tester mode.
- [x] Add a single-command live preflight and a readable heartbeat viewer for the current `guarded2` candidate.
- [x] Add start / close scripts so demo-forward cycles use unique telemetry artifacts and do not contaminate the baseline.
- [x] Add a staged first-capital preset, packet, and preflight so guarded2 does not go straight from demo to real capital.
- [x] Add a live-state reviewer so `continue / pause / flatten / review` is decided mechanically from telemetry, gate status, and heartbeat freshness.
- [x] Move the status heartbeat to a timer-driven live runtime path so stale-heartbeat checks are meaningful outside signal bars.
- [x] Add guarded wrappers for first-capital launch and operator-action logging.
- [x] Add launch manifests so every forward or small-live cycle has durable preset and telemetry lineage.
