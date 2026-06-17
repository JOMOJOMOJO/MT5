# Nested N-Wave Structural BOS Short Summary

This is a fixed-rule diagnostic run. It does not use Friday stops, symbol exclusions, direction-only promotion, or parameter optimization.

## Aggregate

| scenario | trades | PF | avg_R | net | maxDD% | FX net | XAUUSD net | LONG net | SHORT net |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Nested_NWave_BreakoutQualityRouter_BOTH_all_H4_H1_M15_2R | 9 | 1.014 | -0.003 | 3.87 | 2.3 | -104.20 | 108.07 | 6.99 | -3.12 |
| Nested_NWave_ContextQualityRouterV2_BOTH_all_H4_H1_M15_2R | 19 | 1.15 | 0.101 | 82.8 | 2.64 | 39.05 | 43.75 | 69.25 | 13.55 |
| Nested_NWave_NecklineBreak_BOTH_all_H4_H1_M15_2R | 47 | 0.725 | -0.175 | -445.43 | 7.48 | -535.70 | 90.27 | -435.17 | -10.26 |
| Nested_NWave_RetestConfirmation_BOTH_all_H4_H1_M15_2R | 24 | 0.67 | -0.259 | -277.06 | 3.45 | -344.38 | 67.32 | 94.76 | -371.82 |
| Nested_NWave_StructuralBOS_BOTH_all_H4_H1_M15_2R | 13 | 0.367 | -0.543 | -342.94 | 3.43 | -342.94 | 0.00 | -242.76 | -100.18 |
| Nested_NWave_StructuralBOS_V2_BOTH_all_H4_H1_M15_2R | 4 | 0.0 | -1.004 | -198.08 | 1.98 | -198.08 | 0.00 | -149.01 | -49.07 |

## Structural BOS V2 Labels

| label | trades | PF | avg_R | net |
|---|---:|---:|---:|---:|
| clean_structural_bos_v2 | 1 | 0.0 | -1.0 | -49.07 |
| insufficient_room_to_target | 3 | 0.0 | -1.005 | -149.01 |

## Gate Decision

- Annual BT: do not proceed
- Gate reason: trade count too low
- Gate reason: v2 PF/avg_R did not beat v0
- Gate reason: v2 PF/avg_R did not beat the best comparison branch
- Gate reason: FX net is negative
- Gate reason: direction balance is weak

## Artifacts

- Comparison CSV: [short comparison](ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_short_comparison.csv)
- Trade rows: [trade rows](ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_trade_rows.csv)
- MFE/MAE/R reach: [MFE/MAE/R reach](ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_mfe_mae_r_reach.csv)
- By label: [by label](ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_by_label.csv)
- FX vs XAUUSD: [FX vs XAUUSD](ExpectedValue_MultiCurrency_ScoreScanner_nested_structural_bos_v2_fx_vs_xauusd.csv)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_structural_bos_v2_compile.log)
