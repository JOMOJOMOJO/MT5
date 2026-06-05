# ThirdWave v4 Reversal Signal Quality And Shadow SL/RewardR Diagnostics

## Scope

- Short-period only: 2025-02, 2025-08, 2025-10, and 2026-Q1.
- Existing ThirdWave, v2, v3, v4, Phase2, score scanner, CTrade bridge, actual SL/TP, spread guard, timeframe settings, and `InpRewardR` were not changed.
- `InpV4ReversalSignalMode` controls only the v4 research branch; default `V4_SIGNAL_ALL` preserves prior v4 behavior.
- RewardR 1.2 / 1.3 / 1.5 and Current/MidTF/LowerTF SL are shadow diagnostics only. Actual orders still use the configured live SL/TP.
- Shadow exits are evaluated on M5 OHLC from MT5. Same-bar TP/SL overlap is marked `same_bar_ambiguous` and treated conservatively, not as a win.

## Signal Mode Result

| variant | trades | PF | avg_R | net | FX net | XAU net | chasing % | good label % |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| current_thirdwave | 109 | 1.491 | 0.224 | 1288.96 | 241.33 | 1047.63 | 91.7 | 5.5 |
| v4_all_signals | 194 | 1.306 | 0.13 | 1600.37 | 145.16 | 1455.21 | 87.6 | 6.2 |
| v4_micro_break_only | 68 | 1.028 | 0.027 | 53.9 | 46.88 | 7.02 | 85.3 | 8.8 |
| v4_candle_reversal_only | 123 | 1.384 | 0.144 | 1255.69 | 137.29 | 1118.40 | 87.8 | 7.3 |
| v4_micro_or_candle | 142 | 1.447 | 0.185 | 1643.28 | 136.48 | 1506.80 | 85.9 | 8.5 |
| v4_without_weak_signals | 166 | 1.415 | 0.182 | 1825.83 | 26.76 | 1799.07 | 86.7 | 7.2 |

## Shadow Diagnostic Highlights

- Shadow baseline check: `current_thirdwave / CURRENT_SL / 1.5R` produced PF `1.467`, avg_R `0.206`, net `1214.98`. This is close enough to the actual short-period baseline for sensitivity diagnostics, but it remains an M5 OHLC approximation.
- `micro_break_only` actual aggregate: PF `1.028`, avg_R `0.027`, trades `68`.
- `candle_reversal_only` actual aggregate: PF `1.384`, avg_R `0.144`, trades `123`.
- `micro_or_candle` actual aggregate: PF `1.447`, avg_R `0.185`, trades `142`.

Top shadow SL/RewardR combinations by avg_R:
- `v4_micro_break_only` / `LOWER_TF_REVERSAL_SL` / `1.2R`: PF `1.624`, avg_R `0.285`, valid trades `57`, ambiguous `0`.
- `v4_micro_or_candle` / `LOWER_TF_REVERSAL_SL` / `1.2R`: PF `1.829`, avg_R `0.283`, valid trades `121`, ambiguous `0`.
- `v4_micro_or_candle` / `LOWER_TF_REVERSAL_SL` / `1.3R`: PF `1.77`, avg_R `0.282`, valid trades `121`, ambiguous `0`.
- `v4_without_weak_signals` / `LOWER_TF_REVERSAL_SL` / `1.3R`: PF `1.636`, avg_R `0.247`, valid trades `145`, ambiguous `0`.
- `v4_without_weak_signals` / `LOWER_TF_REVERSAL_SL` / `1.5R`: PF `1.583`, avg_R `0.241`, valid trades `145`, ambiguous `0`.
- `v4_without_weak_signals` / `LOWER_TF_REVERSAL_SL` / `1.2R`: PF `1.651`, avg_R `0.241`, valid trades `145`, ambiguous `0`.
- `v4_without_weak_signals` / `CURRENT_SL` / `1.5R`: PF `1.555`, avg_R `0.235`, valid trades `166`, ambiguous `0`.
- `v4_without_weak_signals` / `MID_TF_STRUCTURE_SL` / `1.5R`: PF `1.555`, avg_R `0.235`, valid trades `166`, ambiguous `0`.

## Interpretation

- Actual signal-mode BT did not promote a v4 signal branch: every v4 branch failed to improve PF or avg_R over `current_thirdwave`, and every branch reduced FX net versus the current baseline.
- The earlier `micro_break` strength inside all-signal v4 did not survive isolation. `v4_micro_break_only` finished near flat, so it should not be promoted as a standalone entry signal.
- `micro_or_candle` and `without_weak_signals` improved net profit, but the improvement was mostly XAUUSD-driven and came with lower PF/avg_R than the current ThirdWave baseline.
- RewardR-only shadow does not justify changing the live TP. The stronger diagnostic finding is that `LOWER_TF_REVERSAL_SL` plus 1.2R/1.3R improves shadow avg_R for micro/candle branches, but this is a separate SL-location hypothesis and was not executed as live logic.
- Current SL and MidTF SL are effectively equivalent in this implementation; the meaningful shadow contrast is Current/MidTF versus LowerTF reversal structure.

## Annual Gate

- No branch passed the short-period annual gate. Annual BT was not run.
- `v4_all_signals`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_candle_reversal_only`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_micro_break_only`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_micro_or_candle`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_without_weak_signals`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current

## Files

- Comparison CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_reversal_signal_comparison.csv`
- RewardR shadow CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_rewardR_shadow_comparison.csv`
- SL shadow CSV: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_sl_rewardR_comparison.csv`
- Raw shadow diagnostics: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_shadow_sl_diagnostics.csv`
