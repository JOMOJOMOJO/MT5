# 2026-06-05 - ThirdWave v4 Signal Quality And Shadow SL/RewardR

## Summary

- Added `InpV4ReversalSignalMode` for v4-only signal selection.
- Kept existing ThirdWave, v2, v3, v4 default, Phase2, score scanner, actual SL/TP, RewardR, spread guard, timeframes, CTrade bridge, and risk sizing unchanged.
- Added wave-audit-only shadow metadata for MidTF and LowerTF SL candidates.
- Added analyzer for fixed RewardR 1.2 / 1.3 / 1.5 and Current/MidTF/LowerTF SL shadow diagnostics.

## Evidence

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_v4_signal_shadow_compile.txt`
- Short-period summary: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_short_period_summary.md`
- Reversal signal comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_reversal_signal_comparison.csv`
- SL/RewardR shadow comparison: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_v4_signal_shadow_sl_rewardR_comparison.csv`

## Decision

- Actual v4 signal-mode BT did not beat the current ThirdWave baseline on PF or avg_R, so no branch advanced to annual BT.
- `micro_break` remains diagnostically interesting but failed as a standalone live-signal branch in the short-period test.
- LowerTF reversal SL plus 1.2R/1.3R improved shadow results for micro/candle branches, but this is a shadow-only SL-location hypothesis, not an executed logic change.
- Current SL and MidTF SL are effectively the same in this implementation; the useful next hypothesis is whether LowerTF structure SL can be implemented safely without excessive lot-size or invalid-stop side effects.

## Annual Gate

- No signal branch passed the short-period gate; annual BT was intentionally skipped.
- `v4_all_signals`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_candle_reversal_only`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_micro_break_only`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_micro_or_candle`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
- `v4_without_weak_signals`: gate_pass=False reason=no_pf_or_avgR_improvement;fx_net_worse_than_current
