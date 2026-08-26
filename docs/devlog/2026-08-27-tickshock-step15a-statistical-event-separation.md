# Tick-shock Step 15A statistical/strategy event separation

The first March run of `TAIL_V1_RAW` exposed an implementation-capacity
failure: every statistical tail event was consuming the legacy heavy event
slot and its 552 scenario records. The tester journal recorded 2,742 active
event-pool exhaustion messages before the diagnostic run was stopped.

The remediation keeps the frozen detector and strategy definitions unchanged.
Statistical shocks now use bounded lightweight 120-second outcome records;
legacy state-machine/scenario allocation occurs only when the separately
reported strategy diagnostics are eligible. `TS15A-SEPARATION-001` calls the
same production eligibility function and the complete Step 15A suite remains
GREEN.

Evidence:

- `reports/backtest/runs/20260827_ts15a_tail_v1_raw_realizable_202503/tester_agent_full.log`
- `reports/tests/tick_shock/step15a_green/suite_results.csv`
- `docs/research/tick_shock/15a_detector_implementation.md`
