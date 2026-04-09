# USDJPY Mainline Demo-Forward Handoff

## Decision

- `quality12b_guarded` is the active `USDJPY / M15 / long-only` operational mainline for this cycle.
- Reusable lesson from `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`:
  - keep `quality` and `turnover` separate,
  - do not force a quality-first family into a high-turnover role.
- Reviewed against `.company/improvement/org-scorecard.md` before this promotion step so the cycle leaves `knowledge reuse`, `validation coverage`, and `queue discipline` visible.

## Fresh Actual MT5 Rerun

- Long-window actual (`2025-04-01` to `2025-12-31`):
  - `net +914.94`
  - `PF 1.56`
  - `60` trades
  - `balance DD 2.91%`
- Recent OOS (`2026-01-01` to `2026-04-01`):
  - `net +113.20`
  - `PF 2.17`
  - `9` trades
  - `balance DD 0.80%`
- Result:
  - `demo-forward candidate ready to launch`

## Canonical Commands

- Preflight:
  - `powershell -ExecutionPolicy Bypass -File scripts/usdjpy-mainline-live-preflight.ps1`
- Start:
  - `powershell -ExecutionPolicy Bypass -File scripts/start-usdjpy-mainline-demo-forward.ps1`
- Close:
  - `powershell -ExecutionPolicy Bypass -File scripts/close-usdjpy-mainline-demo-forward.ps1 -ManifestPath <launch-manifest.json>`

## Canonical Files

- Release packet:
  - `.company/release/usdjpy_20260402_round_continuation_long-quality12b_guarded.md`
- Preset:
  - `reports/presets/usdjpy_20260402_round_continuation_long-quality12b_guarded.set`
- Telemetry baseline:
  - `reports/telemetry/2026-04-02-usdjpy-quality12b-guarded-baseline.json`
- Forward gate baseline:
  - `reports/forward/2026-04-02-usdjpy-quality12b-guarded-forward-gate.json`
- Operator file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_operator.txt`
- Status file:
  - `FILE_COMMON/mt5_company_usdjpy_20260402_round_continuation_long_status.txt`
