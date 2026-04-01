# 2026-03-31 BTCUSD Session Mean-Reversion Live Hardening

- EA: `btcusd_20260330_session_meanrev`
- Candidate:
  - `reports/presets/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.set`
- Skills used:
  - `forward-live-ops`
  - `risk-manager`
  - `release-manager`

## What Changed

- Added operator control file support:
  - `normal`
  - `pause`
  - `flatten`
- Added live status heartbeat output under `FILE_COMMON`.
- Disabled operator control and status heartbeat automatically inside MT5 tester / optimization runs.
- Added repo scripts to:
  - set operator mode,
  - read the live heartbeat,
  - start a unique demo-forward cycle,
  - close a demo-forward cycle into summary + gate + preflight,
  - prepare demo-forward,
  - summarize telemetry,
  - evaluate the forward gate mechanically,
  - run a single-command live preflight.

## Files

- EA:
  - `mql/Experts/btcusd_20260330_session_meanrev.mq5`
- Operator script:
  - `scripts/set-ea-operator-mode.ps1`
- Status / release docs:
  - `.company/release/btcusd_20260330_session_meanrev-bull37_long_h12_live035_guarded2.md`
  - `knowledge/experiments/2026-03-30-btcusd-session-meanrev-live-ops.md`

## Why

- The main remaining gap to live was no operator-grade stop path inside the repo workflow.
- A demo or small-live candidate should be pausable and flattenable without editing code or detaching the EA.
- The operator should also be able to inspect the current state quickly from a single heartbeat file.
- Forward cycles also need isolated telemetry artifacts. Reusing the baseline telemetry file risks mixing tester history with true demo-forward evidence.

## Verification

- Compile:
  - `reports/compile/metaeditor.log`
  - `Result: 0 errors, 0 warnings`
- Fresh 1-year actual import after hardening:
  - `reports/backtest/runs/btcusd-20260330-session-meanrev/btcusd/m5/2026-03-31-131610-294712-btcusd-20260330-session-meanrev-.json`
  - `net +177.86 / PF 1.49 / 70 trades / max DD 1.58%`
- Operator command file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_operator.txt`
- Status heartbeat file:
  - `FILE_COMMON/mt5_company_btcusd_20260330_session_meanrev_status.txt`
- Live preflight:
  - `scripts/live-preflight.ps1`
  - current result: `review`
  - reason: the forward gate is still based on the baseline self-check, not real demo-forward evidence.
- Forward cycle scripts:
  - `scripts/start-demo-forward.ps1`
  - `scripts/close-demo-forward.ps1`
  - smoke-tested on the baseline telemetry path and correctly returned `review`, not `pass`.

## Current Read

- The candidate is more deployable operationally than before.
- The remaining real-world gate is still time-based demo-forward evidence, not another backtest tweak.
- Tester reproducibility was restored by disabling the live heartbeat path during tester runs.
