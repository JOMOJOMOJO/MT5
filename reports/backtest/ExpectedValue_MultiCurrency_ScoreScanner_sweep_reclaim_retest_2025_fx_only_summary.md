# Sweep/Reclaim/Retest 2025 FX-only Summary

Scope: 2025 full-year FX-only. XAUUSD is excluded via `InpSymbols`; no Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard/CTrade change, or parameter optimization was used.

## Scenario Comparison

| scenario | trades | PF | avg_R | net | maxDD | LONG net | SHORT net | reached_1R_pct | reached_2R_pct |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| A_current_broad_fx_only | 63 | 0.737 | -0.19 | -603.67 | 1184.23 | -192.2 | -411.47 | 49.21 | 26.98 |
| B_broad_hard_gate_reduced | 3999 | 0.826 | -0.096 | -9227.62 | 10064.01 | -5687.01 | -3540.61 | 50.24 | 28.53 |
| C_sweep_reclaim_only | 1815 | 0.833 | -0.069 | -6672.82 | 7714.65 | -3488.56 | -3184.26 | 49.48 | 28.98 |
| D_bos_retest_only | 1635 | 0.798 | -0.142 | -6856.0 | 7227.03 | -3732.11 | -3123.89 | 48.81 | 29.91 |
| E_first_pullback_after_reclaim_only | 2888 | 0.837 | -0.064 | -8188.47 | 9197.42 | -3726.08 | -4462.39 | 48.72 | 28.53 |
| F_combined_new_triggers | 3897 | 0.818 | -0.041 | -9190.93 | 10291.04 | -4401.43 | -4789.5 | 49.86 | 27.71 |
| G_combined_new_triggers_room_to_2r | 2586 | 0.854 | -0.033 | -4846.47 | 5935.29 | -2248.34 | -2598.13 | 50.73 | 29.43 |
| H_combined_new_triggers_h4_ma_bias | 1391 | 0.798 | -0.128 | -3808.69 | 4296.78 | -2169.68 | -1639.01 | 48.45 | 25.52 |
| I_combined_new_triggers_h4_ma_room_to_2r | 831 | 0.881 | -0.127 | -1322.41 | 1962.97 | -813.57 | -508.84 | 49.46 | 27.8 |

## Judgment

- Best by avg_R: `G_combined_new_triggers_room_to_2r` with `2586` trades, PF `0.854`, avg_R `-0.033`, net `-4846.47`.
- No fixed-BT candidate exists under the requested balance criteria. High-PF low-count subsets remain reference only.
- Combined trigger distribution: `bos_retest:888;first_pullback_after_reclaim:1414;sweep_reclaim:1595`.
- Combined losing failure distribution: `bad_h4_context:1366;bos_retest_failed:88;chasing_entry:26;first_pullback_failed:123;other:295;sweep_reclaim_no_follow_through:92;target_blocked_before_1r:251;target_blocked_before_2r:306;target_too_far_after_1r:207`.

## Artifacts

- Comparison: [comparison CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_comparison.csv)
- Trades: [trades CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_trades.csv)
- By trigger: [by trigger CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_trigger.csv)
- By failure type: [by failure type CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_failure_type.csv)
- By direction: [by direction CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_direction.csv)
- By symbol: [by symbol CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_symbol.csv)
- By month: [by month CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_month.csv)
- By session: [by session CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_by_session.csv)
- Room-to-2R interaction: [room2r interaction CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_room2r_interaction.csv)
- H4 context interaction: [H4 context interaction CSV](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_h4_context_interaction.csv)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_compile.log)
- C sweep reclaim MT5 report: [report HTML](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_C_sweep_reclaim_only_report.html)
- D BOS retest MT5 report: [report HTML](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_D_bos_retest_only_report.html)
- E first pullback MT5 report: [report HTML](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_E_first_pullback_report.html)
- F combined triggers MT5 report: [report HTML](ExpectedValue_MultiCurrency_ScoreScanner_sweep_reclaim_retest_2025_fx_only_F_combined_new_triggers_report.html)
