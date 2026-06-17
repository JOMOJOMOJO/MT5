# Condition Factorial Analysis

This is a short-window diagnostic analysis. It does not optimize parameters and does not promote a new hard-gated strategy.

## Candidate Coverage

- Scenario: `Nested_ConditionFactorial_Candidates_BOTH_all_H4_H1_M15_2R`
- Candidates/trades: `47`
- PF: `1.171`
- Avg R: `0.137`
- Net: `239.56`
- Periods: `2025-02:5;2025-08:12;2025-10:5;2026-Q1:25`
- Symbols: `AUDJPY:3;EURJPY:4;EURUSD:5;GBPJPY:1;GBPUSD:6;USDJPY:17;XAUUSD:11`
- Directions: `LONG:20;SHORT:27`

## Biggest Entry Count Reducers

| condition | reduction % | on trades | on PF | on avg_R |
|---|---:|---:|---:|---:|
| cond_h4_fib_382_618 | 74.47 | 12 | 1.79 | 0.495 |
| cond_m15_close_bos | 68.09 | 15 | 1.991 | 0.526 |
| cond_room_to_2r | 48.94 | 24 | 1.624 | 0.37 |
| cond_h4_bias_ma | 38.3 | 29 | 1.536 | 0.33 |
| cond_h4_dow_bias | 34.04 | 31 | 0.967 | 0.022 |

## Best Single-Condition Expectancy Deltas

| condition | avg_R delta | PF delta | on trades | on PF | on avg_R |
|---|---:|---:|---:|---:|---:|
| cond_m15_close_bos | 0.571 | 1.091 | 15 | 1.991 | 0.526 |
| cond_room_to_1r | 0.562 | 0.89 | 36 | 1.419 | 0.269 |
| cond_h4_bias_ma | 0.503 | 0.791 | 29 | 1.536 | 0.33 |
| cond_h4_fib_382_618 | 0.481 | 0.79 | 12 | 1.79 | 0.495 |
| cond_room_to_2r | 0.476 | 0.838 | 24 | 1.624 | 0.37 |

## Worst Single-Condition Expectancy Deltas

| condition | avg_R delta | PF delta | on trades | on PF | on avg_R |
|---|---:|---:|---:|---:|---:|
| cond_h1_counter_wave_atr | -0.379 | -0.675 | 45 | 1.148 | 0.121 |
| cond_h4_dow_bias | -0.339 | -0.702 | 31 | 0.967 | 0.022 |
| cond_m15_prev_extreme_bos | -0.222 | -0.456 | 34 | 1.058 | 0.076 |
| cond_h1_counter_nwave | -0.025 | -0.044 | 34 | 1.159 | 0.13 |
| cond_h1_prev_extreme_break | 0.137 |  | 47 | 1.171 | 0.137 |

## Top Combinations With Min Trades 20

| rank | enabled conditions | trades | PF | avg_R | net | periods | symbols | directions |
|---:|---|---:|---:|---:|---:|---|---|---|
| 1 | cond_room_to_2r | 24 | 1.624 | 0.37 | 401.55 | 2025-02:3;2025-08:3;2025-10:3;2026-Q1:15 | AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6 | LONG:9;SHORT:15 |
| 2 | cond_h1_prev_extreme_break;cond_room_to_2r | 24 | 1.624 | 0.37 | 401.55 | 2025-02:3;2025-08:3;2025-10:3;2026-Q1:15 | AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6 | LONG:9;SHORT:15 |
| 3 | cond_h1_counter_wave_atr;cond_room_to_2r | 24 | 1.624 | 0.37 | 401.55 | 2025-02:3;2025-08:3;2025-10:3;2026-Q1:15 | AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6 | LONG:9;SHORT:15 |
| 4 | cond_true_bos_level;cond_room_to_2r | 24 | 1.624 | 0.37 | 401.55 | 2025-02:3;2025-08:3;2025-10:3;2026-Q1:15 | AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6 | LONG:9;SHORT:15 |
| 5 | cond_h1_prev_extreme_break;cond_h1_counter_wave_atr;cond_room_to_2r | 24 | 1.624 | 0.37 | 401.55 | 2025-02:3;2025-08:3;2025-10:3;2026-Q1:15 | AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6 | LONG:9;SHORT:15 |

## Gate Judgment

- Fixed-condition candidate sets meeting the short diagnostic gate: `0`
- Best min-trades-20 diagnostic set was `cond_room_to_2r` with `24` trades, PF `1.624`, avg_R `0.37`.
- It is not a validation candidate because balance remains weak: FX net `134.19`, XAUUSD net `267.36`, LONG net `-10.65`, SHORT net `412.2`.
- No combination cleanly passed the short diagnostic gate for MT5 annual validation.
- Keep the strongest conditions as diagnostic labels until a balanced fixed set appears.

## Artifacts

- Candidates: [candidates](ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_candidates.csv)
- All combinations: [all combinations](ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_all_combinations.csv)
- Single effects: [single effects](ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_single_effects.csv)
- Entry count impact: [entry count impact](ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_entry_count_impact.csv)
- Expectancy impact: [expectancy impact](ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_expectancy_impact.csv)
- Top combinations: [top combinations](ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_top_combinations.csv)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_condition_factorial_compile.log)
