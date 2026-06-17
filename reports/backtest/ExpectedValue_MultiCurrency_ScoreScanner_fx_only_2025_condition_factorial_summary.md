# FX-only 2025 Condition Factorial Summary

Scope: 2025 full-year ConditionFactorial broad candidates, FX symbols only (`USDJPY,EURJPY,GBPJPY,AUDJPY,EURUSD,GBPUSD`). XAUUSD is excluded in the tester preset and again in post-processing.

No Friday stop, direction-only mode, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.

## Core Result

- Broad FX-only candidates: `63` trades
- Broad PF / avg_R / net: `0.737` / `-0.19` / `-603.67`
- LONG entries / SHORT entries: `28` / `35`
- LONG net / SHORT net: `-192.2` / `-411.47`
- `room_to_2r` ON: `28` trades, PF `1.121`, avg_R `0.079`, net `109.03`
- `room_to_2r` OFF: `35` trades, PF `0.488`, avg_R `-0.404`, net `-712.7`

## Required Answers

1. Broad candidate count: `63`.
2. Broad PF / avg_R / net: `0.737` / `-0.19` / `-603.67`.
3. LONG/SHORT entry count balance: `28` LONG vs `35` SHORT.
4. LONG/SHORT profit balance: `-192.2` LONG vs `-411.47` SHORT.
5. `room_to_2r` full-year effect: ON avg_R `0.079` vs OFF avg_R `-0.404`; ON net `109.03` vs OFF net `-712.7`.
6. Most expectancy-improving single condition: `cond_room_to_2r` with avg_R lift `0.483`.
7. Most trade-reducing condition: `cond_h4_fib_382_618` with reduction `74.6%`.
8. Least effective by avg_R lift: `cond_m15_prev_extreme_bos` with avg_R lift `0.014`.
9. Most worsening condition: `cond_h1_counter_nwave` with avg_R lift `-0.498`.
10. Best useful condition set: `cond_room_to_2r` at min_trades `20`; no positive `>=60` condition set was found.
11. Best useful set trade count: `28`, so it is below the requested fixed-BT promotion threshold of `60` trades.
12. Best set distribution: symbols `AUDJPY:1;EURJPY:3;EURUSD:4;GBPJPY:4;GBPUSD:3;USDJPY:13`, months `2025-01:4;2025-02:2;2025-03:3;2025-04:6;2025-06:1;2025-07:5;2025-08:1;2025-09:3;2025-10:1;2025-11:2`, directions `LONG:11;SHORT:17`.
13. Main LONG loss cause: `target_blocked`.
14. LONG improvement should inspect H4 bias validity, H1 pullback completion, M15 false BOS, and whether 2R room is real after entry.
15. Next MT5 fixed-BT candidate count from strict gate: `0`.
16. This is not a live or annual-promotion decision. Annual progression should wait unless a condition set keeps enough trades, positive avg_R, balanced direction exposure, and no single-symbol/month dependency.

## Gate Judgment

- No positive >=60-trade condition set was found.
- No condition set passed the strict next fixed-BT gate.
- Best symbol in broad FX candidates: `EURUSD`.
- Worst symbol in broad FX candidates: `GBPUSD`.

## Artifacts

- Candidates: [candidates CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_candidates.csv)
- All combinations: [all combinations CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_all_combinations.csv)
- Single effects: [single effects CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_single_effects.csv)
- Entry count impact: [entry count impact CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_entry_count_impact.csv)
- Expectancy impact: [expectancy impact CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_expectancy_impact.csv)
- Top combinations: [top combinations CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_top_combinations.csv)
- By symbol: [by symbol CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_by_symbol.csv)
- By month: [by month CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_by_month.csv)
- By direction: [by direction CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_by_direction.csv)
- LONG failure analysis: [LONG failure analysis CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_long_failure_analysis.csv)
- LONG failure summary: [LONG failure summary](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_long_failure_summary.md)
- Room2R recheck: [room2r recheck CSV](ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_room2r_recheck.csv)
- MT5 report: [MT5 report](ExpectedValue_MultiCurrency_ScoreScanner_fxcf2025_A_condition_factorial_candidates_report.html)
- Elapsed CSV: [elapsed CSV](ExpectedValue_MultiCurrency_ScoreScanner_fxcf2025_elapsed.csv)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_fx_only_2025_condition_factorial_compile.log)
