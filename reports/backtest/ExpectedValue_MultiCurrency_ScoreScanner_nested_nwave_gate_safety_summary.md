# Nested N-Wave Gate Safety Check

## Scope

- Diagnostic-only review of the existing Nested short-period runs.
- No EA logic, order bridge, SL/TP, RewardR, timeframe, spread guard, risk sizing, or parameters were changed.
- No annual backtests were run.
- Fixed gate candidates only; no threshold search was performed.

## Close Strength Direction Normalization

`breakout_close_strength` from the previous decomposition is already direction-normalized:

- LONG: close near bar high gives a high score.
- SHORT: close near bar low gives a high score.

This was confirmed by reconstructing raw high-side/low-side close position. The new CSV keeps both `breakout_close_strength_raw` and `breakout_close_strength_directional` so the distinction is explicit.

- 2025-10 winning trades kept by directional close strength >= 0.60: 0 / 7
- 2026-Q1 losing trades classified as false breakout: 30 / 45
- 2026-Q1 losing trades classified as target too far: 10 / 45

## Gate Safety Matrix Highlights

| gate | useful read |
|---|---|
| breakout_close_strength_directional >= 0.60 | removed 33 2026-Q1 losers; removed 7 2025-10 winners; unsafe because it removed all 2025-10 winners |
| exclude immediate false breakout | removed 18 2026-Q1 losers; removed 0 2025-10 winners; strongest diagnostic effect, but not live-safe as a hindsight exclusion |
| virtual delayed retest confirmation | removed 37 2026-Q1 losers; removed 5 2025-10 winners; too selective for a direct gate, useful only as a separate delayed-entry design |

## Retest Quality Distribution

| retest_quality | trades |
|---|---:|
| no_retest_break_and_go | 26 |
| return_inside_and_fail | 18 |
| deep_retest_but_reclaim | 16 |
| immediate_full_false_break | 16 |
| unclear | 8 |
| shallow_retest_then_go | 6 |

## true_clean_candidate_v0

`true_clean_candidate_v0` is diagnostic only. It requires clean/initial label, directional close strength >= 0.60, no false break, entry distance <= 0.40 ATR, SL ATR < 2.0, and H4 mid-zone pullback.

- candidates: 0
- net: 0.0
- PF: 
- avg_R: 0.0

The proxy is strict and did not produce enough evidence to promote as-is. It is useful mainly because it proves the current `clean_nested_nwave_entry` label is too loose.

## Judgement

1. `breakout_close_strength` was direction-normalized. The previous close-strength direction concern does not invalidate the failure diagnosis.
2. The fixed `>= 0.60` close-strength gate is not safe: it removes all 2025-10 winners in this sample.
3. 2R distance is a secondary issue. `target_too_far` exists, but false breakout and weak follow-through are larger.
4. `clean_nested_nwave_entry` is not human-clean. It needs breakout quality and retest behavior checks before it can become a promotion label.
5. A simple false-break hindsight exclusion is not a live-safe gate. The safer design is a delayed retest-confirmation branch.
6. The first v2 diagnostic branch should not use the 0.60 close-strength gate. The safer next test is a separate retest-confirmation branch, with close strength retained as a diagnostic score only.
7. Nested v2 has limited research value. If retest confirmation cannot reduce 2025-02 and 2026-Q1 false breaks without erasing 2025-10, Nested should be parked.

## Outputs

- Gate safety matrix: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_gate_safety_matrix.csv`
- Directional close strength: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_directional_close_strength.csv`
- Retest quality: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_retest_quality.csv`
- true clean proxy: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_nested_nwave_true_clean_candidate_v0.csv`
