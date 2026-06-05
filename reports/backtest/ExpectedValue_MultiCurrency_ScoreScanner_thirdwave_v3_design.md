# ThirdWave v3 Entry Timing Design

## Premise

- v3 is a separate research mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V3_ENTRY_TIMING`.
- Existing ThirdWave, regime ThirdWave, Phase2 scanner, score calculation, CTrade bridge, risk sizing, SL, TP, and `InpRewardR` are unchanged.
- No parameter optimization was performed. The gates are fixed from the prior Wave Audit distribution.
- v3 remains all-symbol and both-direction. It is not XAUUSD-only, LONG-only, or SHORT-only.

## Wave Audit Findings Used

- Prior Wave Audit showed current ThirdWave was dominated by `chasing_entry` rather than `third_wave_initial`.
- v2 reduced weak structure but did not materially change the wave-position label distribution.
- v3 therefore gates final entries by wave-position label, reclaim distance, pullback-extreme distance, and pre-entry momentum exhaustion.

## v3 Filters

1. `v3_wave_position_invalid`: block invalid, range-noise, or unclear wave-position labels.
2. `v3_reclaim_chase_too_far`: block candidates more than 0.60 ATR from reclaim/breakdown or more than two bars after reclaim/breakdown.
3. `v3_pullback_entry_too_far`: block candidates more than 2.50 ATR or 65% of impulse away from the pullback extreme.
4. `v3_momentum_exhausted`: block candidates with consecutive directional bars, large recent move, and entry near recent extreme.
5. `v3_late_entry` / `v3_chasing_entry`: block labels that are already classified as late or chasing.

## Why These Three

- They directly test the entry-location hypothesis.
- They do not encode symbol, direction, session, month, RewardR, stop, spread, or timeframe parameters.
- They are intentionally coarse and fixed; no parameter search was performed.

## Prior Evidence Snapshot

### ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_label.csv

| wave_audit_label | trades | wins | losses | win_rate | net_profit |
|---|---|---|---|---|---|
| chasing_entry | 100 | 48 | 52 | 48.0 | 1107.37 |
| late_entry | 2 | 2 | 0 | 100.0 | 156.84 |
| third_wave_initial | 1 | 0 | 1 | 0.0 | -46.62 |
| third_wave_middle | 5 | 3 | 2 | 60.0 | 120.98 |
| unclear | 1 | 0 | 1 | 0.0 | -49.61 |

### ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_entry_distance.csv

| entry_distance_band | trades | wins | losses | win_rate | net_profit |
|---|---|---|---|---|---|
| 0.75-1.00ATR | 2 | 1 | 1 | 50.0 | 24.49 |
| 1.00-1.50ATR | 7 | 4 | 3 | 57.14 | 146.71 |
| 1.50-2.00ATR | 7 | 4 | 3 | 57.14 | 145.08 |
| 2.00-3.00ATR | 38 | 17 | 21 | 44.74 | 178.47 |
| 3.00ATR+ | 55 | 27 | 28 | 49.09 | 794.21 |

### ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_pullback_depth.csv

| pullback_depth_band | trades | wins | losses | win_rate | net_profit |
|---|---|---|---|---|---|
| 18-25 | 7 | 5 | 2 | 71.43 | 244.96 |
| 25-38.2 | 11 | 5 | 6 | 45.45 | 170.01 |
| 38.2-50 | 20 | 9 | 11 | 45.0 | 140.36 |
| 50-61.8 | 21 | 10 | 11 | 47.62 | 240.25 |
| 61.8-75 | 22 | 12 | 10 | 54.55 | 457.43 |
| 75-90 | 28 | 12 | 16 | 42.86 | 35.95 |

### ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_sl_atr.csv

| sl_atr_band | trades | wins | losses | win_rate | net_profit |
|---|---|---|---|---|---|
| 0.75-1.00 | 2 | 1 | 1 | 50.0 | 24.49 |
| 1.00-1.25 | 1 | 0 | 1 | 0.0 | -48.78 |
| 1.25-1.50 | 4 | 2 | 2 | 50.0 | 31.99 |
| 1.50-2.00 | 9 | 6 | 3 | 66.67 | 308.58 |
| 2.00+ | 93 | 44 | 49 | 47.31 | 972.68 |

### ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_direction.csv

| direction | trades | wins | losses | win_rate | net_profit |
|---|---|---|---|---|---|
| LONG | 60 | 28 | 32 | 46.67 | 490.72 |
| SHORT | 49 | 25 | 24 | 51.02 | 798.24 |

### ExpectedValue_MultiCurrency_ScoreScanner_wave_audit_by_symbol.csv

| symbol | trades | wins | losses | win_rate | net_profit |
|---|---|---|---|---|---|
| EURJPY | 1 | 1 | 0 | 100.0 | 75.07 |
| EURUSD | 3 | 2 | 1 | 66.67 | 110.22 |
| GBPUSD | 3 | 1 | 2 | 33.33 | -21.29 |
| USDJPY | 11 | 5 | 6 | 45.45 | 77.33 |
| XAUUSD | 91 | 44 | 47 | 48.35 | 1047.63 |
