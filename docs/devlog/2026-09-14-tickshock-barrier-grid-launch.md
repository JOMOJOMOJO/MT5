# SL/TP grid and spaced multiple entries

User approved TP {0.40,0.50,0.68} × SL {0.25,0.40,0.55} ATR, 4-hour
safety time exit, 15-minute global spacing, no fixed concurrent count cap.
July/August is explicitly development/exit selection, not unused OOS.

New tester-only EA:
`mql/Experts/ExpectedValue_TickShockTwoStageBarrierCandidate.mq5`.
Existing time-only EA and model are retained. New execution adapter manages
individual hedging-account position identifiers, accumulates entry/exit deals,
and writes one finalized record per position. Dynamic active records are released
when reconciled. Position count and aggregate modeled SL-risk peaks are reported.
No claim is made that SL bounds realized losses in a gap or that unlimited
positions imply bounded portfolio risk. The per-trade SL-loss budget remains
min(10 USD, 0.25% current equity), rounded down to broker volume step.

Core boundaries: inward SL rounding, outward TP rounding, executable-side broker
distance, invalid inputs and 900-second minus/equal/plus boundary; 13 tests.
Dedicated synthetic order harness uses wide test-only barriers to maintain two
simultaneous positions and verifies closing one cannot accidentally close the other.
Those wide values are not a formal research cell. Production EA has no forced signals.

Initial launch recorded a preset BOM issue: harness ran at its default output
folder. The canonical runner's preset handling did not preserve the first input.
New presets use ASCII (all values are ASCII); the second run's journal confirmed
the intended folder. Original artifacts remain under `two_stage_barrier_grid_20260914`.
Second run's multiple-position harness attempted its first order at 00:00, got
retcode 10018 MARKET_CLOSED and correctly failed. The fixture was moved to January
2 at 09:00 without changing production logic; failures remain under `_20260914_r2`.

Current batch: `reports/backtest/batches/two_stage_barrier_grid_20260914_r3/`.
Runner: `tools/tick_shock/run_two_stage_barrier_grid.ps1`.
It prepares all nine settings before observing outcomes, then gates on core,
multi-position and January smoke evidence. Nonzero integrity errors stop the batch.
No best-cell selection or automatic retuning is performed. See status.json for
actual progress; this launch log is not a claim of completed nine-run validation.

Implementation review followed `mq5-review` for ticket identity, brokerage
constraints, fill/close accounting and failure states. Research parameters follow
`docs/research/tick_shock/two_stage_barrier_grid_preregistration.md`.

## Launch confirmation, 22:24 JST

r3 core 13/13 PASS; multi-position 7/7 PASS, 2 concurrent positions, all records
reconciled and none remaining. January smoke 4 real tester trades, all 14 integrity
checks PASS, errors/remaining/unreconciled all zero. EA/core/multi compiles each
reported 0 errors / 0 warnings. Formal cell TP0.40/SL0.25 started at 22:23:48 JST;
eight further cells are already fixed in saved presets. No formal profitability
result is claimed at launch. The batch stops on any subsequent integrity failure.
