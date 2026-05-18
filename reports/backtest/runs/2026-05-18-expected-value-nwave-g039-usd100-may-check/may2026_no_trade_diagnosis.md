# g039 USD100 May 2026 No-Trade Diagnosis

Purpose: explain why a May 2026 MT5 backtest produced no trades.

## Finding

Two separate cases were observed.

1. User-side/common preflight evidence showed a blocked configuration:
   - `timeframe=M1`
   - `preflight_status=BLOCK`
   - `preflight_warnings=chart_timeframe_not_m5|drawdown_percent_guards_not_enabled`

   For `Strategy_01B_J_SHORT g039`, the EA is intended for USDJPY M5. With `EnableTrading=true` and `InpBlockUnsafeForwardDemoSettings=true`, `_Period != PERIOD_M5` causes live entries to be blocked through `unsafe_forward_demo_setting_blocked`.

2. A repo-side rerun with corrected tester period `M5` over `2026.05.01-2026.05.18` produced:
   - preflight: PASS
   - closed trades: 0
   - diagnostics rows: 123
   - reject counts:
     - `direction_filter_failed`: 66
     - `trend_alignment_filter_failed`: 27
     - `fibo_filter_failed`: 24
     - `pattern_adx_bucket_filter_failed`: 5
     - `spread_too_wide`: 1

This means May 2026 can legitimately have zero trades even with correct M5 settings, because no candidate passed the frozen g039 filters in the available tester data window.

## Evidence

- Run folder: `reports/backtest/runs/2026-05-18-expected-value-nwave-g039-usd100-may-check/`
- Preflight: `raw/preflight_20260501_000000_2026051991.csv`
- Summary: `raw/Strategy_01_NWave_ExpectedValue_USDJPY_2026051991_summary.csv`
- Diagnostics: `raw/Strategy_01_NWave_ExpectedValue_USDJPY_2026051991_diagnostics.csv`

## Operator Checklist

Before concluding that the EA has no signal, check the preflight CSV:

- `symbol=USDJPY`
- `timeframe=M5`
- `selected_strategy_mode=STRATEGY_01B_J_SHORT`
- `enable_trading=true`
- `account_currency=USD`
- `account_is_demo=true` when non-demo blocking is enabled
- `max_spread_points=30`
- `allow_only_one_position_strategy01b=true`
- `use_equity_curve_guard=true`
- `preflight_status=PASS`

If `preflight_status=BLOCK`, read `preflight_warnings` first. If it is PASS and trades are still zero, inspect `RejectReason` counts in diagnostics.
