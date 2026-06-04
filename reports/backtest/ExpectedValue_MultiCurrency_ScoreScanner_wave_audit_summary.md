# ThirdWave Wave Audit Summary

## Scope

- Strategy: `ThirdWave_regime_BOTH_all_5m_wave_audit`.
- Periods: 2025-02, 2025-08, 2025-10, and 2026-Q1.
- No parameter optimization was performed.
- Entry logic, SL/TP logic, reward R, spread guard, and Phase 2 scanner logic were not changed.
- Wave Audit is diagnostic-only and logs final entry candidates, execution-blocked candidates, and order events.

## Code Review Findings

- Higher timeframe trend uses confirmed fractal pivots on `InpContextTF`; Long requires HH/HL and Short requires LL/LH.
- Mid timeframe pullback uses confirmed fractal lows/highs on `InpPatternTF`; this makes the structure stable but can delay recognition by the fractal span.
- Lower reversal uses the last closed execution bar: Long requires close above the latest minor high and bullish body; Short requires close below the latest minor low and bearish body.
- Entry price is current Ask/Bid after the reclaim/breakdown is detected, not the reclaim/breakdown close itself.
- SL is structure-based from the mid-timeframe pullback extreme plus spread/ATR buffer; TP remains fixed `InpRewardR`.
- The audit therefore focuses on distance from pullback extreme and reclaim/breakdown to entry, because that is where late or chasing entries should show up.

## Short-Period Results

| Period | Trades | PF | Expected Payoff | Net | Avg R | Max DD % | third_wave_initial | late_entry | chasing_entry | invalid_structure |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 2025-02 | 16 | 2.293 | 23.36 | 373.68 | 0.502 | 0.99 | 0 | 0 | 15 | 0 |
| 2025-08 | 13 | 0.899 | -3.09 | -40.11 | -0.032 | 2.45 | 0 | 0 | 11 | 0 |
| 2025-10 | 20 | 1.823 | 17.26 | 345.18 | 0.378 | 1.75 | 0 | 1 | 19 | 0 |
| 2026-Q1 | 60 | 1.402 | 10.17 | 610.21 | 0.154 | 2.65 | 1 | 1 | 55 | 0 |

## Label Results

| Label | Trades | PF | Expected Payoff | Net | Avg R | Max DD % |
|---|---:|---:|---:|---:|---:|---:|
| chasing_entry | 100 | 1.456 | 11.07 | 1107.37 | 0.207 | 2.53 |
| late_entry | 2 |  | 78.42 | 156.84 | 1.57 | 0.0 |
| third_wave_initial | 1 | 0.0 | -46.62 | -46.62 | -1.001 | 0.47 |
| third_wave_middle | 5 | 2.204 | 24.2 | 120.98 | 0.514 | 0.99 |
| unclear | 1 | 0.0 | -49.61 | -49.61 | -1.007 | 0.5 |

## Direction x Label

| Direction:Label | Trades | PF | Net | Avg R |
|---|---:|---:|---:|---:|
| LONG:chasing_entry | 54 | 1.419 | 542.19 | 0.237 |
| LONG:third_wave_initial | 1 | 0.0 | -46.62 | -1.001 |
| LONG:third_wave_middle | 4 | 1.445 | 44.76 | 0.254 |
| LONG:unclear | 1 | 0.0 | -49.61 | -1.007 |
| SHORT:chasing_entry | 46 | 1.499 | 565.18 | 0.172 |
| SHORT:late_entry | 2 |  | 156.84 | 1.57 |
| SHORT:third_wave_middle | 1 |  | 76.22 | 1.556 |

## Judgement

- `third_wave_initial` was only `1` of `109` trades (`0.9%`). By this audit definition, the current ThirdWave is not primarily entering at the initial part of wave 3.
- `chasing_entry` dominated with `100` trades (`91.7%`) and still produced `1107.37` net. This means the branch is behaving more like trend-continuation momentum after structure confirmation than an early wave-3 entry model.
- The lower reversal check itself is not waiting multiple closed bars; `bars_since_reclaim_or_breakdown` is usually 1. The late/chasing classification is coming mostly from distance from pullback extreme, broad structure SL, and entry position after the move has already expanded.
- Confirmed fractal pivots stabilize the structure but introduce recognition delay. That delay is likely acceptable for trend-following continuation, but it is too slow for a strict third-wave-initial thesis.
- Long and Short are logically symmetric in the code: HH/HL plus minor-high reclaim for Long, LL/LH plus minor-low breakdown for Short. The quality gap should therefore be studied through market regime and distance metrics rather than an obvious directional coding asymmetry.
- XAUUSD is still the dominant source of samples and profit; FX sample size in this short audit is small and should not be treated as a validated common-symbol edge.

## Next Logic Candidates

- First candidate: add a pre-entry audit gate around `distance_from_pullback_extreme_to_entry_atr` or `% of impulse consumed`, then test without changing reward/SL parameters.
- Second candidate: improve the lower reversal model to detect an earlier minor HL/LH after reclaim/breakdown instead of using only a confirmed fractal reclaim.
- Third candidate: distinguish continuation-following ThirdWave from strict wave-3-initial ThirdWave as separate strategy modes, because current evidence says the existing branch is the former.
- Avoid optimizing `InpRewardR`, spread guard, or timeframe settings before deciding which of those two entry theses is actually intended.

## Artifacts

- Consolidated audit events: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_thirdwave_wave_audit.csv`
- Actual trade audit join: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_trades.csv`
- Label aggregate: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_label.csv`
- Samples for manual chart review: `reports/backtest/ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_sample_trades.csv`
