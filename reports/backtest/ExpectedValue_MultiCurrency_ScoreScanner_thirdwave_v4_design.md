# ThirdWave v4 Early Reversal Design

## Premise

- v4 is a separate research mode: `RESEARCH_STRATEGY_DOW_FRACTAL_THIRD_WAVE_V4_EARLY_REVERSAL`.
- Existing ThirdWave, v2, v3, Phase2 scanner, score calculation, CTrade bridge, risk sizing, SL, TP, spread guard, timeframes, and `InpRewardR` are unchanged.
- No parameter optimization was performed. v4 uses one fixed early-reversal detector and one loose impulse-consumed guard.
- v4 remains all-symbol and both-direction. It is not XAUUSD-only, LONG-only, or SHORT-only.

## Wave Audit And v3 Findings Used

- Prior Wave Audit showed current ThirdWave was dominated by `chasing_entry` rather than `third_wave_initial`.
- v2 reduced weak structure but did not materially solve late entry location.
- v3 removed chasing labels but left only 4 of 109 comparable trades and did not improve PF or average R.
- v4 therefore tests whether the lower-timeframe reversal detector itself is too late, instead of tightening the final entry-position gate further.

## v4 Early Reversal Detector

1. Keep confirmed fractal reclaim/breakdown as a fallback reference signal.
2. Add earlier long signals: `early_higher_low`, `candle_reversal`, `micro_break`, and `momentum_turn`.
3. Add earlier short signals: `early_lower_high`, `candle_reversal`, `micro_break`, and `momentum_turn`.
4. Record `bars_since_pullback_extreme`, `bars_since_reversal_signal`, `impulse_consumed_pct`, pre-entry momentum, and reversal strength.
5. Block only clearly consumed impulses with `v4_impulse_consumed`; this is deliberately looser than v3 to avoid collapsing trade count.

## Why This Branch

- The requested hypothesis is that confirmed-fractal reversal waits too long.
- v4 directly compares early reversal signal types against current, v2, and v3 without changing reward, stop, spread, or timeframe behavior.
- The goal is diagnostic: recover enough trades versus v3 while reducing current ThirdWave's chasing-entry dominance.

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

