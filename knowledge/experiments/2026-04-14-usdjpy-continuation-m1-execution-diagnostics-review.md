# USDJPY Continuation M1 Execution Diagnostics Review

Date: 2026-04-14

## Scope

- Family: `usdjpy_20260414_trend_continuation_pullback_engine`
- Goal: keep the improved exit direction, change only entry timing
- Fixed slice:
  - `ENTRY_ON_HIGHER_LOW_BREAK only`
  - `M15 context + M5 setup + M1 execution`
  - `Tier A strict`
  - `STOP_PULLBACK_LOW`
  - `TARGET_HYBRID_PARTIAL`
  - `runner_fib_618`
  - `ea_managed`

## Matrix

- execution mode:
  - `M5_MARKET_CONFIRM`
  - `M1_MICRO_HIGH_STOP`
  - `M1_BREAK_CLOSE_CONFIRM`
  - `M1_RETEST_HOLD_CONFIRM`
- partial target:
  - `fib extension 38.2`
  - `fib extension 50.0`
- hold bars:
  - `16`
  - `24`
  - `32`
- windows:
  - train `2025-04-01 .. 2025-12-31`
  - OOS `2026-01-01 .. 2026-04-01`
  - actual `2024-11-26 .. 2026-04-01`

Total runs: `72`

## Compile / Run

- EA compile: success via `scripts/compile.ps1`
- Validation runner: `plugins/mt5-company/scripts/usdjpy_trend_continuation_m1_execution_validation.py`
- Result bundle: `reports/backtest/sweeps/2026-04-14-usdjpy-cont-m1exec/`

## Main Results

### OOS

- All execution modes in the published fixed slice: `0 trades`
- This applies only to the validation slice defined in `Scope`:
  - `ENTRY_ON_HIGHER_LOW_BREAK only`
  - `Tier A strict`
  - `STOP_PULLBACK_LOW`
  - `TARGET_HYBRID_PARTIAL`
  - `runner_fib_618`
  - `ea_managed`
- Separate tester-journal verification on `2026-04-14` showed that a broader OOS run from `2026-01-01 .. 2026-04-01` did trade materially.
  - Journal path: `C:/Users/windows/AppData/Roaming/MetaQuotes/Terminal/2FA8A7E69CED7DC259B1AD86A247F675/tester/logs/20260414.log`
  - Logged inputs there were broader than the fixed slice:
    - `InpTierMode=1`
    - `InpEntryPathMode=0`
    - `InpStopBasisMode=1`
    - `InpTargetMode=0`
    - `InpMaxHoldBars=16`
    - `InpExecutionTriggerMode=0`
  - The journal segment for that run contains `68` `market buy` log hits, which corresponds to about `34` actual entries because MT5 logs both the `CTrade::OrderSend` line and the resulting market order line.
- Therefore the earlier blanket phrasing `OOS 0 trades` should be read as `OOS 0 trades for the published fixed slice`, not as `the whole current EA has zero OOS inventory`.

### Actual best repeatable runs

- `actual-m5_market-partial382-h32`
  - report: `PF 2.83`, `net +69.95`, `4 report trades`
  - telemetry: `3 closed campaigns`, `avg realized R +0.6913`
- `actual-m1_micro_stop-partial382-h32`
  - report: `PF 2.71`, `net +65.49`, `4 report trades`
  - telemetry: `3 closed campaigns`, `avg realized R +0.6401`
- `actual-m1_break_close-partial382-h32`
  - report: `PF 0.00`, `net +28.93`, `1 trade`
  - telemetry: `1 closed campaign`, `avg realized R +0.8400`
- `actual-m1_retest_hold-*`
  - `0 trades`

### Actual aggregate by execution mode

Telemetry aggregate uses closed campaigns, not MT5 report trade count. MT5 report trades are higher because partial exits add extra deal rows.

- `m5_market`
  - `18 closed campaigns`
  - `PF 1.8412`
  - `net +195.40`
  - `avg realized R +0.3269`
  - `partial hit 16.67%`
  - `runner hit 100% of partial-hit campaigns`
- `m1_micro_stop`
  - `18 closed campaigns`
  - `PF 1.7737`
  - `net +179.71`
  - `avg realized R +0.2948`
  - `partial hit 16.67%`
  - `runner hit 100% of partial-hit campaigns`
- `m1_break_close`
  - `6 closed campaigns`
  - `PF 3.36`
  - `net +40.64`
  - `avg realized R +0.1967`
  - `partial hit 0%`
  - sparse survivor only
- `m1_retest_hold`
  - `0 campaigns`

### Actual aggregate by hold bars

- `16 bars`
  - `14 campaigns`
  - `PF 1.2241`
  - `net +38.91`
  - `avg realized R +0.0870`
- `24 bars`
  - `14 campaigns`
  - `PF 1.5619`
  - `net +87.01`
  - `avg realized R +0.1872`
- `32 bars`
  - `14 campaigns`
  - `PF 2.8909`
  - `net +289.83`
  - `avg realized R +0.6095`

Entry timing did not change this pattern. The big step-up still comes from longer hold, not from M1 trigger quality.

### Actual aggregate by partial target

- `partial382`
  - `21 campaigns`
  - `PF 2.1052`
  - `net +266.24`
  - `avg realized R +0.3757`
  - `partial hit 28.57%`
- `partial500`
  - `21 campaigns`
  - `PF 1.6207`
  - `net +149.51`
  - `avg realized R +0.2134`
  - `partial hit 0%`

`partial382` remains the only version that actually activates the partial-first logic in this slice.

## Telemetry Diagnosis

### Structural buckets

- traded phase remained `htf_up_pullback`
- traded fib depth remained `natural`
- execution-timing change did not widen or upgrade the structural pocket

### M1 timing did not create a stronger continuation filter

- `m1_micro_stop`
  - average delay from M5 setup to M1 entry: `0.333` M1 bars
  - average setup-to-entry distance: `0.267` pips
  - average breakout distance vs M5 continuation level: `-8.7` pips
- `m1_break_close`
  - average delay: `1.0` M1 bar
  - average setup-to-entry distance: `3.5` pips
  - average breakout distance vs M5 continuation level: `-9.1` pips

The negative breakout-distance numbers matter. These M1 triggers are still firing below the M5 continuation reclaim level. In practice they are not filtering for a stronger restart of the parent move. They are only adding slight delay and small price drift.

### Exit behavior on the best non-sparse runs

- `m5_market-partial382-h32`
  - exit breakdown: `runner_target 1`, `time_stop 1`, `stop_loss 1`
- `m1_micro_stop-partial382-h32`
  - exit breakdown: `runner_target 1`, `time_stop 1`, `stop_loss 1`
- The win/loss mix is effectively unchanged. `m1_micro_stop` mainly shaved profit from the runner winner.

## Decision

`Reject`

## Why reject

- OOS stayed at `0 trades` across the whole matrix.
- `M1_MICRO_HIGH_STOP` did not beat `M5_MARKET_CONFIRM` on actual. It produced similar inventory and slightly worse expectancy.
- `M1_BREAK_CLOSE_CONFIRM` only produced a sparse pocket.
- `M1_RETEST_HOLD_CONFIRM` produced no inventory.
- The telemetry explains why: the M1 triggers are not demanding a materially stronger continuation restart. They are still entering below the M5 continuation reclaim area, so time-stop dependence remains structurally the same.

## Conclusion

This family does not justify further rescue by adding more execution detail on top of the same setup logic. The entry-timing change did not create a durable improvement over the plain M5 market baseline.
