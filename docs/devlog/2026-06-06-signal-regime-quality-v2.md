# 2026-06-06 - Signal / Regime Quality v2 Diagnostic

## Summary

- EA: `mql/Experts/ExpectedValue_MultiCurrency_ScoreScanner.mq5`
- Task: diagnose why `v4_micro_or_candle + LowerTF SL + 1.2R` failed in 2024 while improving in 2025 and 2026YTD.
- Scope: analysis and reporting only. No EA behavior, order bridge, SL/TP, RewardR, timeframe, or parameter changes were made.

## Evidence

- Compile log: `reports/compile/ExpectedValue_MultiCurrency_ScoreScanner_signal_regime_quality_v2_compile.txt`
- Summary: `reports/backtest/signal_regime_quality_v2_summary.md`
- Master comparison: `reports/backtest/regime_quality_master_comparison.csv`
- Period aggregate: `reports/backtest/regime_quality_by_period.csv`
- Symbol aggregate: `reports/backtest/regime_quality_by_symbol.csv`
- Direction aggregate: `reports/backtest/regime_quality_by_direction.csv`
- Regime aggregate: `reports/backtest/regime_quality_by_regime.csv`
- Reversal signal aggregate: `reports/backtest/regime_quality_by_reversal_signal.csv`
- 2024 breakdown: `reports/backtest/2024_failure_breakdown.md`
- 2025/2026 breakdown: `reports/backtest/2025_2026_success_breakdown.md`
- Next candidates: `reports/backtest/next_filter_candidates.md`

## Verification

- Compile result: `0 errors, 0 warnings`
- Analyzer: `scripts/analyze_multicurrency_score_scanner_signal_regime_quality_v2.py`
- Input set: existing annual LowerTF SL feasibility reports for 2024, 2025, and 2026YTD.
- Output sample: 2,756 actual trades and 34,801 final/blocked/order candidate rows were classified.

## Findings

- The LowerTF SL branch is not ready for promotion. Annual combined PF and average R remain close to the current ThirdWave baseline.
- The 2024 failure is not explained by one simple XAUUSD-only or direction-only issue. XAUUSD flipped from positive to negative, and both long and short exposure deteriorated.
- In 2024, the largest damage clusters were candle reversal entries, normal SL-width entries, early trend-age buckets, high/mid ATR percentile buckets, and deep pullback buckets.
- The 2025 improvement was mostly XAUUSD and long-side driven; FX remained weak.
- The 2026YTD improvement was more FX and short-side driven, especially in the server 08-15 session. That differs from the 2025 success pattern.

## Decision

- Do not continue RewardR or SL tuning next. The evidence points to signal/regime quality as the unresolved problem.
- Keep the LowerTF SL branch as a diagnostic branch, not as a live candidate.
- The next testable branch should be a fixed Regime Quality Gate diagnostic based on trend age, trend-strength proxy, ATR percentile, pullback quality, and SL-width buckets.
- Stop the next branch if it improves only XAUUSD, only one direction, or fewer than two of the three annual windows.
