# USDJPY Continuation Partial-Runner Diagnostics Review

## Scope

- family: `usdjpy_20260414_trend_continuation_pullback_engine`
- objective: evaluate whether the existing `ENTRY_ON_HIGHER_LOW_BREAK` inventory can be monetized better with `partial-first + breakeven runner + time-stop diagnostics`
- fixed inputs:
  - `ENTRY_ON_HIGHER_LOW_BREAK only`
  - `M15 context + M5 setup`
  - `Tier A strict only`
  - `STOP_PULLBACK_LOW`
  - `TARGET_HYBRID_PARTIAL`

## Implementation

- EA updated at [usdjpy_20260414_trend_continuation_pullback_engine.mq5](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/mql/Experts/usdjpy_20260414_trend_continuation_pullback_engine.mq5)
- added:
  - hybrid partial target selection: `ext 38.2` vs `ext 50.0`
  - runner target selection: `fib 61.8`, `prior swing`, `fixed R`
  - exit execution mode comparison:
    - `ea_managed`
    - `server_partial_limit`
  - stop-to-breakeven after partial
  - telemetry for partial / runner / time-stop diagnostics

## Compile

- compile passed via [metaeditor.log](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/compile/metaeditor.log)

## Matrix

- validation script: [usdjpy_trend_continuation_partial_runner_validation.py](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/plugins/mt5-company/scripts/usdjpy_trend_continuation_partial_runner_validation.py)
- result bundle:
  - [results.json](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-14-usdjpy-cont-partial/results/results.json)
  - [summary.md](/c:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/MQL5/Experts/dev/reports/backtest/sweeps/2026-04-14-usdjpy-cont-partial/results/summary.md)
- windows:
  - train `2025-04-01 .. 2025-12-31`
  - OOS `2026-01-01 .. 2026-04-01`
  - actual `2024-11-26 .. 2026-04-01`
- combinations:
  - partial target: `382 / 500`
  - runner target: `fib618 / prior swing / fixed R`
  - order mode: `ea_managed / server_partial_limit`
  - max hold: `16 / 24 / 32`
- total runs: `108`

## Key Findings

### 1. Time-stop extension helped, but only in a sparse pocket

- actual aggregate by hold bars:
  - `16`: avg `PF 1.3658`, avg net `+15.93`, avg realized `R +0.0891`
  - `24`: avg `PF 1.7750`, avg net `+34.44`, avg realized `R +0.2696`
  - `32`: avg `PF 2.6517`, avg net `+77.99`, avg realized `R +0.6938`
- the improvement came mainly from better `time_stop` monetization, not from more runner hits
- aggregated actual exit PnL by hold bars:
  - `runner_target`: unchanged across `16 / 24 / 32`
  - `stop_loss`: unchanged across `16 / 24 / 32`
  - `time_stop`: became materially more positive as hold length increased

### 2. Partial-first can improve actual expectancy, but only on one small sample

- best actual run:
  - `actual-partial500-runner_prior_swing-ea_managed-h32`
  - report: `net +102.01`, `PF 3.66`, `4 trades`
  - telemetry: `3 closed campaigns`, `partial hit 33.33%`, `BE move 100%`, avg realized `R +1.0051`
- this beat the old non-partial baseline on the same `M15 x M5 / STOP_PULLBACK_LOW` slice:
  - old best baseline:
    - `fixed_r` or `fib`
    - `net +51.02`, `PF 2.29`, `3 trades`, avg realized `R +0.5393`

### 3. The runner target comparison needs interpretation

- `runner_fib618` and `runner_fixed_r` behaved the same on this slice
- `runner_prior_swing` in hybrid mode was structurally below the partial extension target, so it degraded into a `BE/time-stop runner benchmark`
- therefore the best actual `runner_prior_swing` result is not evidence that a true runner target was superior

### 4. Order mode B is weaker operationally

- `ea_managed` actual average:
  - avg `PF 2.3333`
  - avg net `+51.33`
  - avg realized `R +0.3582`
- `server_partial_limit` actual average:
  - avg `PF 1.5283`
  - avg net `+34.24`
  - avg realized `R +0.3434`
- `server_partial_limit` also failed to move the runner to breakeven reliably in telemetry (`BE move 0%` on partial-hit runs)
- on MT5 netting this approximation is operationally dirtier than EA-managed partial and should not be preferred

### 5. The family remains too sparse to promote

- train: only `2 trades` per run
- OOS: `0 trades` for every run
- actual: `4 report trades` per run, which reduced to `3 closed campaigns` in telemetry because the hybrid structure creates partial + final event sequences
- telemetry stayed structurally narrow:
  - phase: only `htf_up_pullback`
  - fib depth: only `natural`

## Verdict

- `Reject`

## Why reject

- OOS produced `0 trades` across the entire matrix, so no forward confirmation exists
- actual improvements came from a sparse `M15 x M5 / Tier A` pocket with only `3 closed campaigns`
- `32 bars` improved the monetization of time-stop inventory, but not enough to prove a durable edge
- `ea_managed` is preferable to `server_partial_limit`, but that is an execution preference, not proof of family viability

## Practical takeaway

- the hypothesis `time stop 16 was too early` looks directionally correct on this slice
- the hypothesis `partial-first can help` is also directionally correct
- neither result is promotable because the family never produced enough OOS or actual inventory on the fixed validation slice
