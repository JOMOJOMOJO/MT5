# Broad FX-only 2025 Entry Candidates Summary

Scope: 2025 full-year FX-only nested entry candidates. XAUUSD is excluded. No Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.

## Scenario Comparison

- A current Broad: `63` trades, PF `0.737`, avg_R `-0.19`, net `-603.67`.
- B hard-gate reduced: `3999` trades, PF `0.826`, avg_R `0.0`, net `-9227.62`.
- C B + room_to_2r: `0` trades, PF ``, avg_R `0.0`, net `0`.
- D B + H4 MA bias: `0` trades, PF ``, avg_R `0.0`, net `0`.
- E B + M15 close BOS: `0` trades, PF ``, avg_R `0.0`, net `0`.
- F B + room_to_2r + H4 MA bias: `0` trades, PF ``, avg_R `0.0`, net `0`.

## Required Checks

1. Trade count versus current Broad: `3999` vs `63`.
2. `room_to_2r` effect in the wider pool: B avg_R `0.0` to C avg_R `0.0`.
3. H4 MA bias post-filter effect: B avg_R `0.0` to D avg_R `0.0`.
4. M15 close BOS post-filter effect: B avg_R `0.0` to E avg_R `0.0`.
5. LONG top failure in B: `bad_h4_bias`.
6. Best scenario by avg_R: `B_broad_hard_gate_reduced` with `3999` trades.

## Judgment

- No hard-gate-reduced condition set is ready for fixed BT promotion under the requested balance criteria.
- The hard-gate-reduced branch is intended to widen the candidate pool and relabel H4/fib/H1 N-wave/BOS/room conditions for post-processing.
- `E_broad_reduced_m15_close_bos` improves average price-R, but it is still negative on PF and net profit, so it is not a fixed-BT candidate.

## Artifacts

- Comparison: [comparison CSV](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_comparison.csv)
- Trades: [trades CSV](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_trades.csv)
- By symbol: [by symbol CSV](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_by_symbol.csv)
- By month: [by month CSV](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_by_month.csv)
- By direction: [by direction CSV](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_by_direction.csv)
- By M15 trigger: [by M15 trigger CSV](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_by_m15_trigger.csv)
- LONG failure summary: [LONG failure summary](ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_2025_entry_candidates_long_failure_summary.md)
- MT5 report: [MT5 report](ExpectedValue_MultiCurrency_ScoreScanner_fxbroad2025_A_broad_fx_entry_candidates_report.html)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_broad_fx_only_compile.log)
