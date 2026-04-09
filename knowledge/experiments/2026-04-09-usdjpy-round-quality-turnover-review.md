# USDJPY round quality turnover review

- Date: `2026-04-09`
- Family: `usdjpy_20260409_round_quality_guarded`
- Status: `M1/M3 same-method expansion rejected; EMA sidecar remains the only turnover path worth carrying`
- Roles applied:
  - `research-director`
  - `systematic-ea-trader`
  - `risk-manager`
  - `forward-live-ops`

## User Objective

- increase trade count from the standalone `M15` quality shell,
- allow parallel entries when multiple valid setups exist,
- move the shell toward something operable in demo/live conditions.

## Reused Lessons

- `knowledge/patterns/2026-03-31-expectancy-compounding-doctrine.md`
- `knowledge/patterns/2026-04-01-live-ready-definition.md`
- `knowledge/patterns/2026-04-01-ea-improvement-cycle.md`

## Experiment 1

- Label:
  - `stack-m1m3`
- Thesis:
  - add the same round continuation pattern on `M3` and `M1`,
  - allow `M15`, `M3`, and `M1` long buckets to coexist in parallel.
- Artifacts:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stack-m1m3.set`
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-stack-m1m3-train-9m.ini`
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-stack-m1m3-oos-3m.ini`
- Train result:
  - `2025-04-01` to `2025-12-31`
  - `net -746.13`
  - `PF 0.65`
  - `178 trades`
  - `balance DD 7.99%`
- OOS result:
  - `2026-01-01` to `2026-04-01`
  - `net -219.95`
  - `PF 0.55`
  - `50 trades`
  - `balance DD 2.22%`
- Decision:
  - reject.
- Readout:
  - turnover increased,
  - expectancy broke on both windows,
  - this is not a live-track candidate.

## Experiment 2

- Label:
  - `stack-m3-only`
- Thesis:
  - check whether `M1` was the damage source by removing it and keeping only `M15 + M3`.
- Artifacts:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stack-m3-only.set`
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-stack-m3-only-train-9m.ini`
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-stack-m3-only-oos-3m.ini`
- Train result:
  - `net -653.63`
  - `PF 0.77`
  - `227 trades`
  - `balance DD 8.01%`
- OOS result:
  - `net -242.57`
  - `PF 0.46`
  - `37 trades`
  - `balance DD 2.44%`
- Decision:
  - reject.
- Readout:
  - the problem is not only `M1`,
  - same-method lower timeframe expansion itself is poor in this family.

## Experiment 3

- Label:
  - `stack-sidecar`
- Thesis:
  - keep the `M15` quality anchor,
  - increase turnover with the repo's already-proven `EMA continuation` sidecar instead of lower timeframe same-method entries.
- Artifacts:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stack-sidecar.set`
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-stack-sidecar-train-9m.ini`
  - `reports/backtest/usdjpy_20260409_round_quality_guarded-stack-sidecar-oos-3m.ini`
- Train result:
  - `net +92.00`
  - `PF 1.06`
  - `152 trades`
  - `balance DD 2.31%`
- OOS result:
  - `net +79.25`
  - `PF 1.53`
  - `20 trades`
  - `balance DD 0.68%`
- Decision:
  - keep as the only turnover-biased branch worth carrying forward from this cycle.
- Readout:
  - trade count increased materially versus the standalone shell,
  - recent OOS remained good,
  - but long-window PF is still too soft for a live-ready claim.

## Experiment 4

- Label:
  - `stackplus`
- Thesis:
  - add `round loose` on top of the `EMA` sidecar.
- Artifact:
  - `reports/presets/usdjpy_20260409_round_quality_guarded-stackplus.set`
- Train result:
  - `net -106.79`
  - `PF 0.94`
  - `173 trades`
  - `balance DD 3.31%`
- Decision:
  - reject.

## Final Decision

- Do not promote `M1/M3` same-method round continuation into the default operating preset.
- Keep `M3` / `M1` support in code only as an experiment path, not as the default attachment path.
- The current best trade-count increase path for this shell is still:
  - `M15 quality anchor`
  - plus `M15 EMA continuation sidecar`
- This remains below the repo's `live-ready discussion` bar on the long window, so the honest label is:
  - `serious validation / demo-forward candidate at best`,
  - not `small-live staged`.

## Next 3 Sensible Experiments

1. Tighten the `EMA sidecar` so long-window PF improves without collapsing OOS trade count.
2. Review whether one of the already-existing `M15` sidecars should be ported instead of inventing new lower timeframe entries.
3. Run demo-forward only after a turnover-biased preset clears a better long-window actual baseline than `PF 1.06`.
