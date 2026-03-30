# BTCUSD M5 pattern-vs-season diagnosis

## Objective

- Determine whether the weak `2025-06` to `2025-09` period is pure seasonality or a repeatable chart regime.
- Promote controls that are explainable and reproducible across windows.

## Result

- The weak period is better explained by chart regime than by calendar label.
- Losing trades cluster when:
  - volatility is low-to-mid (`ATR%` relatively low),
  - and short entries are too far above `EMA20` (large `gap_atr`).
- This led to explicit regime controls instead of month-based filters:
  - `short_max_dist`
  - `short_min_atr_pct` / `short_max_atr_pct`
  - `short_rsi_max`

## Candidate Metrics

- Robust candidate (80k):
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_10_66_85_h14_stop40_exit30_spread2500_maxdist3_atrmin4_slip250_80k.json`
  - train: `3.88 trades/day`, `PF 1.15`
  - test: `5.47 trades/day`, `PF 1.48`
  - all: `4.15 trades/day`, `PF 1.27`
- Same logic on 50k:
  - file: `reports/research/2026-03-30-session-meanrev-validate/short_no_fri_skip3_0_8_10_66_85_h14_stop40_exit30_spread2500_maxdist3_atrmin4_slip250_50k.json`
  - train: `4.80 trades/day`, `PF 1.57`
  - test: `5.47 trades/day`, `PF 1.48`
  - all: `4.70 trades/day`, `PF 1.52`

## Interpretation

- Reproducibility improved versus the earlier 80k failure.
- Trade frequency is still below the 5/day target on the long window.
- Next step should be a new entry construction, not only threshold tuning.

## Next Actions

- Keep this candidate as the robustness baseline for comparisons.
- Build and test an alternative entry construction under the same friction assumptions.
- Keep quarterly review cadence in release notes for any live/paper-live promotion.
