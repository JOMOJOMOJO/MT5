# Relaxed FX-only 2025 Entry Conditions Summary

Scope: 2025 full-year FX-only nested entry candidates. XAUUSD is excluded. No Friday stop, direction limit, pair exclusion, RewardR/SL/TP/risk/spread guard change, or parameter optimization was used.

## Scenario Comparison

- A current Broad: `63` trades, PF `0.737`, avg_R `-0.19`, net `-603.67`.
- B relaxed entry: `28` trades, PF `0.792`, avg_R `-0.146`, net `-206.85`.
- C relaxed + room_to_1r: `24` trades, PF `0.815`, avg_R `-0.128`, net `-156.45`.
- D relaxed + room_to_2r: `17` trades, PF `1.091`, avg_R `0.056`, net `49.82`.
- E relaxed + room_to_2r + round/major obstacle clear: `8` trades, PF `1.206`, avg_R `0.121`, net `50.94`.

## Required Checks

1. Trade count versus current Broad: `28` vs `63`; the relaxed branch did not increase count because it keeps H4 MA bias and M15 recent-extreme BOS as hard gates.
2. PF/avg_R did not improve in relaxed base if lower than A: PF `0.792`, avg_R `-0.146`.
3. `room_to_2r` remains effective: relaxed base avg_R `-0.146` to D avg_R `0.056`.
4. LONG target-blocked should be judged in `ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_long_failure_summary.md`; top relaxed LONG failure is `chasing_entry`.
5. H1 N-wave is diagnostic only in B/C/D/E. The comparison shows whether removing it as a hard gate helped.
6. Best scenario by avg_R: `E_relaxed_room_to_2r_no_round_or_major_obstacle` with `8` trades.

## Judgment

- No relaxed condition set is ready for fixed BT promotion under the requested balance criteria.
- If B has fewer trades than A, the relaxed branch is looser than prior fixed gates but not looser than the previous Broad candidate definition because it requires H4 MA bias and M15 recent-extreme BOS.

## Artifacts

- Comparison: [comparison CSV](ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_comparison.csv)
- Trades: [trades CSV](ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_trades.csv)
- By symbol: [by symbol CSV](ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_by_symbol.csv)
- By month: [by month CSV](ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_by_month.csv)
- By direction: [by direction CSV](ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_by_direction.csv)
- LONG failure summary: [LONG failure summary](ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_2025_entry_conditions_long_failure_summary.md)
- MT5 relaxed report: [MT5 relaxed report](ExpectedValue_MultiCurrency_ScoreScanner_fxrelax2025_A_relaxed_condition_candidates_report.html)
- Compile log: [compile log](../compile/ExpectedValue_MultiCurrency_ScoreScanner_relaxed_fx_only_compile.log)
