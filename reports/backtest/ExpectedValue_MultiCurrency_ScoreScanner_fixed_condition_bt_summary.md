# Fixed Condition BT Summary

This validates fixed MT5 research modes derived from Condition Factorial post-processing. It does not run annual BT and does not optimize parameters.

## Reproduction Check

- Broad ConditionFactorial: trades `47`, PF `1.171`, avg_R `0.137`, net `239.56`.
- Fixed Room2R MT5: trades `24`, PF `1.625`, avg_R `0.37`, net `403.59`.
- Python post-processing and MT5 fixed execution are aligned if Fixed Room2R roughly matches the previous `cond_room_to_2r` subset.

## Best Fixed Set By Avg R

- Scenario: `Nested_Fixed_H4MA_M15Close_Room2R_BOTH_all_H4_H1_M15_2R`
- Trades: `3`
- PF: ``
- Avg R: `2.006`
- Net: `295.86`
- FX net: `295.86`
- XAUUSD net: `0`
- LONG net: `100.81`
- SHORT net: `195.05`
- Audit quality: `acceptable_fractal:1;clean_fractal:2`
- This is not a robust annual candidate because trade count is below the short-gate minimum of 20.

## Best Fixed Set With At Least 20 Trades

- Scenario: `Nested_Fixed_Room2R_BOTH_all_H4_H1_M15_2R`
- Trades: `24`
- PF: `1.625`
- Avg R: `0.37`
- Net: `403.59`
- FX net: `136.23`
- XAUUSD net: `267.36`
- LONG net: `-4.7`
- SHORT net: `408.29`
- Period distribution: `2025-02:3;2025-08:3;2025-10:3;2026-Q1:15`
- Symbol distribution: `AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6`
- Direction distribution: `LONG:9;SHORT:15`
- Audit quality: `acceptable_fractal:3;clean_fractal:21`

## Research Questions

1. `cond_room_to_2r` reproduced in MT5 fixed execution: yes. The MT5 fixed run is `24` trades, PF `1.625`, avg_R `0.37`, net `403.59`, matching the Python subset scale.
2. Best raw fixed set: `H4MA + M15Close + Room2R`, but only `3` trades, so it is diagnostic only.
3. Most usable fixed set: `Room2R`, because it keeps `24` trades across all four periods.
4. Period/symbol/direction balance for Room2R: periods `2025-02:3;2025-08:3;2025-10:3;2026-Q1:15`, symbols `AUDJPY:1;EURJPY:3;EURUSD:1;GBPJPY:1;GBPUSD:4;USDJPY:8;XAUUSD:6`, directions `LONG:9;SHORT:15`.
5. LONG weakness improved versus broad candidates but is not solved: Room2R LONG net `-4.7`.
6. FX weakness improved: broad FX net `-196.91` versus Room2R FX net `136.23`.
7. XAUUSD dependence remains meaningful: Room2R XAUUSD net `267.36` versus FX net `136.23`.
8. Fractal audit for Room2R is strong by current diagnostics: `acceptable_fractal:3;clean_fractal:21`.
9. Dow-flow check is represented by H4 bias + H1 pullback + M15 reversal audit columns in the fractal audit CSV.
10. `room_to_2r` is suitable as a fixed research gate for annual validation, but not yet as a universal hard gate because SHORT and XAUUSD still contribute most of the edge.
11. Next annual-BT candidate exists only for `Nested_Fixed_Room2R`; tighter fixed sets are too sparse.

## Gate Decision

- Fixed sets passing short annual-candidate gate: `1`
- Candidate for next-phase annual BT: `Nested_Fixed_Room2R_BOTH_all_H4_H1_M15_2R`.

## Artifacts

- Comparison: [comparison CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_comparison.csv)
- Trades: [trades CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_trades.csv)
- Fractal audit: [fractal audit CSV](ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_fractal_audit.csv)
- By period: [by period](ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_by_period.csv)
- By symbol: [by symbol](ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_by_symbol.csv)
- By direction: [by direction](ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_bt_by_direction.csv)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_fixed_condition_compile.log)
