# Broad FX-only 2025 8-Condition Factorial Summary

Scope: Python post-processing of existing 2025 FX-only broad candidate trades. This is not MT5 optimization and does not change EA entry logic, RewardR, SL/TP, risk, spread guard, CTrade, symbols, or direction mode.

## Source Check

- Source CSV: `ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_trades.csv`
- Source CSV rows including derived scenarios: `9776`.
- Factorial baseline rows: `3999` with `scenario == B_broad_hard_gate_reduced`.
- The previous A-F summary and CSV are consistent after filtering on `scenario`; C-F are not zero in the current regenerated artifacts.
- Column aliases used:
  - `cond_h4_ma_bias` -> `cond_h4_bias_ma`
  - `cond_h4_fib_382_618` -> `cond_h4_fib_382_618`
  - `cond_h1_counter_nwave` -> `cond_h1_counter_nwave`
  - `cond_h1_counter_wave_atr` -> `cond_h1_counter_wave_atr`
  - `cond_true_bos_level` -> `cond_true_bos_level`
  - `cond_m15_close_bos` -> `cond_m15_close_bos`
  - `cond_room_to_2r` -> `cond_room_to_2r`
  - `cond_round_or_major_obstacle_clear` -> `cond_major_or_round_room_to_2r`
- `cond_h4_fib_382_618` is derived from `h4_fib_zone == valid_h4_pullback_zone` because this diagnostic CSV has `h4_fib_retracement_pct` recorded as `0.0` for all broad rows.

## Required Answers

1. `3999` is candidate count, not combination count. Combination count is `256`.
2. 8-condition ON/OFF factorial was executed: `yes`.
3. Actual combinations evaluated: `256`.
4. Most trade-count reducing single condition: `cond_m15_close_bos` (`88` trades, `97.8`% reduction).
5. Condition whose removal keeps the largest trade count: `cond_true_bos_level` (`3999` trades when ON, smallest cut).
6. Fixed-BT candidates in 100-700 trade range: `0`. Reference candidates: `0`.
7. Best PF combination with at least 20 trades: `cond_h4_ma_bias;cond_m15_close_bos` PF `0.997`, trades `33`.
8. Best avg_R combination with at least 20 trades: `cond_h4_ma_bias;cond_m15_close_bos` avg_R `0.269`, trades `33`.
9. Best net-minus-DD balance with at least 50 trades: `cond_h1_counter_wave_atr;cond_m15_close_bos` net `-224.12`, maxDD `278.75`, PF `0.659`.
10. Best LONG improvement condition set by LONG PF delta: `cond_h4_fib_382_618;cond_h1_counter_wave_atr;cond_round_or_major_obstacle_clear`.
11. SHORT-preserving LONG improvement exists only if `SHORT net_delta` stays near or above zero; inspect the LONG improvement CSV. Top LONG rows generally need separate balance review.
11a. Strongest single avg_R lift: `cond_m15_close_bos` (`0.203`). Worst single avg_R lift: `cond_h4_ma_bias` (`-0.088`).
11b. Strongest single PF lift: `cond_h4_ma_bias` (`0.077`).
12. H4 MA bias single effect: `1431` trades, PF `0.903`, avg_R `-0.184`.
13. H4 fib single effect: `560` trades, PF `0.895`, avg_R `-0.145`.
14. H1 N-wave single effect: `1345` trades, PF `0.706`, avg_R `-0.109`.
15. H1 ATR single effect: `3506` trades, PF `0.782`, avg_R `-0.098`.
16. M15 close BOS single effect: `88` trades, PF `0.622`, avg_R `0.107`.
17. room_to_2r single effect: `3143` trades, PF `0.788`, avg_R `-0.112`.
18. Fixed-BT candidate set exists: `no`.
19. If none, reason: no 100-700 trade combination satisfies PF > 1.05, avg_R > 0, net > 0, balanced LONG/SHORT, and diversification constraints simultaneously.
20. Best 100-700 trade row: `cond_h4_fib_382_618;cond_h1_counter_wave_atr;cond_round_or_major_obstacle_clear` trades `231`, PF `0.943`, avg_R `-0.189`, net `-156.88`.
21. Best 50-100 trade row: `cond_h4_ma_bias;cond_h4_fib_382_618;cond_h1_counter_nwave;cond_h1_counter_wave_atr;cond_room_to_2r` trades `89`, PF `0.68`, avg_R `-0.123`, net `-412.0`.
22. Best 20-50 reference row: `cond_h4_ma_bias;cond_m15_close_bos` trades `33`, PF `0.997`, avg_R `0.269`, net `-0.85`. This band is diagnostic only, not a fixed-BT candidate.

## Single-Condition Expectancy Ranking

- `cond_m15_close_bos`: trades `88`, PF `0.622`, avg_R `0.107`, net `-394.44`, avg_R_delta `0.203`.
- `cond_true_bos_level`: trades `3999`, PF `0.826`, avg_R `-0.096`, net `-9227.62`, avg_R_delta `0.0`.
- `cond_h1_counter_wave_atr`: trades `3506`, PF `0.782`, avg_R `-0.098`, net `-10221.87`, avg_R_delta `-0.002`.
- `cond_h1_counter_nwave`: trades `1345`, PF `0.706`, avg_R `-0.109`, net `-5551.83`, avg_R_delta `-0.013`.
- `cond_room_to_2r`: trades `3143`, PF `0.788`, avg_R `-0.112`, net `-9112.41`, avg_R_delta `-0.016`.
- `cond_round_or_major_obstacle_clear`: trades `1903`, PF `0.775`, avg_R `-0.128`, net `-5551.92`, avg_R_delta `-0.032`.
- `cond_h4_fib_382_618`: trades `560`, PF `0.895`, avg_R `-0.145`, net `-734.82`, avg_R_delta `-0.049`.
- `cond_h4_ma_bias`: trades `1431`, PF `0.903`, avg_R `-0.184`, net `-1804.76`, avg_R_delta `-0.088`.

## room_to_2r Combination Checks

| enabled_conditions | trades | PF | avg_R | net | LONG net | SHORT net |
|---|---:|---:|---:|---:|---:|---:|
| cond_room_to_2r | 3143 | 0.788 | -0.112 | -9112.41 | -5744.53 | -3367.88 |
| cond_h4_ma_bias;cond_room_to_2r | 1052 | 0.84 | -0.241 | -2286.72 | -1230.27 | -1056.45 |
| cond_h4_fib_382_618;cond_room_to_2r | 418 | 0.843 | -0.174 | -849.98 | -644.53 | -205.45 |
| cond_m15_close_bos;cond_room_to_2r | 12 | 0.72 | -0.293 | -28.25 | -81.33 | 53.08 |
| cond_h4_ma_bias;cond_m15_close_bos;cond_room_to_2r | 3 | 1.286 | 0.957 | 10.17 | -35.61 | 45.78 |
| cond_h4_ma_bias;cond_room_to_2r;cond_round_or_major_obstacle_clear | 641 | 0.732 | -0.292 | -2368.44 | -762.31 | -1606.13 |

## Interpretation

- `cond_true_bos_level` is non-selective in this dataset: it keeps all 3999 baseline rows.
- `cond_m15_close_bos` improves average R but cuts the sample to 88 trades and remains PF-negative on net-money terms, so it is not a stable fixed-BT branch.
- `cond_h4_ma_bias`, `cond_h4_fib_382_618`, `cond_h1_counter_nwave`, and `cond_room_to_2r` reduce trades but do not turn the broad FX-only pool positive by themselves.
- The best LONG-improving combinations still fail the full gate because total PF/net remain negative or SHORT stays weak.
- No 100-700 trade condition set is ready for MT5 fixed-BT promotion from this 8-condition factorial pass.


## Artifacts

- all_combinations: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_all_combinations.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_all_combinations.csv)
- single_effects: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_single_effects.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_single_effects.csv)
- trade_count_impact: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_trade_count_impact.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_trade_count_impact.csv)
- expectancy_impact: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_expectancy_impact.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_expectancy_impact.csv)
- top_by_trade_band: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_top_by_trade_band.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_top_by_trade_band.csv)
- balanced_candidates: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_balanced_candidates.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_balanced_candidates.csv)
- long_improvement: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_long_improvement.csv](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_long_improvement.csv)
- metrics: [ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_metrics.json](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_8cond_factorial_metrics.json)
