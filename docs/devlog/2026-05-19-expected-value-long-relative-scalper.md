# 2026-05-19 - ExpectedValue Long-Only Relative Scalper

## Summary

- task: create a separate long-only EA for small-capital research
- EA: `ExpectedValue_LongOnly_RelativeScalper`
- status: scaffold implemented and compiled; current presets are not promoted

## Changes

- added `mql/Experts/ExpectedValue_LongOnly_RelativeScalper.mq5`
- kept the live short-only `ExpectedValue_NWave_Scalper` untouched
- implemented long-only `USDJPY / M5` continuation logic using prior `quality12b` / EMA-continuation lessons
- replaced fixed-pips filters with relative measures:
  - `Spread / ATR`
  - `EMA deviation / ATR`
  - `Body / ATR`
  - `Current ATR / ATR average`
  - recent range position `0.0-1.0`
- added ATR / recent-swing based SL, fixed `1.5R` TP, and max-hold timeout exit
- added small-capital sizing:
  - fixed lot below equity threshold
  - risk-percent lot sizing above threshold
  - broker min/max/step normalization
  - margin sufficiency block
- added safety controls:
  - daily loss stop
  - weekly loss stop
  - max DD stop
  - max consecutive losses
  - max open positions
  - total open risk cap
  - averaging-down block
  - cooldown bars
- added CSV diagnostics, summary, monthly summary, and stop-condition logs

## Evidence

- compile log: `reports/compile/ExpectedValue_LongOnly_RelativeScalper.log`
- validation summary: `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/summary.md`
- raw CSV evidence: `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/raw/`
- tester reports: `reports/backtest/runs/2026-05-19-expected-value-long-relative-scalper-initial/*.htm`

## Validation Readout

- strict `Spread/ATR=0.12`:
  - 2025 IS: `23` trades, ExpectancyR `+0.2203`, PF `1.7616`, MaxDD `7.21%`
  - rejected for turnover: far below the target cadence
- high-turnover `Spread/ATR=0.35`:
  - 2025 IS: `128` trades before drawdown stop, ExpectancyR `-0.3368`, PF `0.4619`, MaxDD `45.00%`
  - rejected because max DD stop fired
- balanced `Spread/ATR=0.20`:
  - 2025 IS: `176` trades, ExpectancyR `-0.0177`, PF `0.9590`, MaxDD `24.23%`
  - 2026 Jan-Apr OOS: `11` trades, ExpectancyR `-0.6064`, PF `0.1156`, MaxDD `11.47%`
  - rejected as an edge candidate

## Decision

No preset is approved for demo/live.

The scaffold is useful because it makes the trade-off visible:

- strict filtering preserves quality but has too few trades
- spread loosening raises trade count but can break the account
- the current long-side shape does not survive 2026 Jan-Apr OOS

Next work should start a separate long-only bucket or market-state split instead of further loosening spread.
