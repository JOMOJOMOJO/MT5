# USDJPY Golden S2 Reconciliation

- Preset: `usdjpy_20260402_golden_method-s2-sell-breakout-active.set`
- OOS study events matching preset: `4`
- Actual EA-side OOS signals: `4`
- Fresh-breakout opportunities while state already active: `0`

## Event Reconciliation

- `2026-01-22T17:05:00` -> `2026-01-22T17:55:00`: `breakout_rejected`
  - {"refresh_attempts": [], "breakout_reasons": ["slow_slope_too_small"]}
- `2026-01-26T04:10:00` -> `2026-01-26T07:25:00`: `signal_rejected`
  - {"gate_reasons": [], "eval_reasons": ["rejection_body_below_avg"], "history": {"refresh_attempts": []}}
- `2026-02-11T03:10:00` -> `2026-02-11T04:15:00`: `signal_passes_current_logic`
  - {"refresh_attempts": []}
- `2026-02-23T01:35:00` -> `2026-02-23T02:20:00`: `signal_passes_current_logic`
  - {"refresh_attempts": []}
