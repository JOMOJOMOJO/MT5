# 2026-03-31 BTCUSD Session Mean-Reversion Risk/Reward Scan

- Scope: test whether the current BTCUSD M5 session family becomes stronger when converted to explicit fixed `ATR stop + reward multiple` exits.
- Motivation:
  - risk management matters,
  - but the wrong exit model can destroy a real edge even when the entry looks valid.

## What Was Tested

- Data-first session candidates were used as the entry side:
  - late-session long mean reversion
  - NY-session short under bear trend
- Exit style:
  - fixed ATR stop
  - fixed reward multiple target
  - capped holding window
  - spread and slippage assumptions included in the scan

## Result

- The combined high-frequency pair produced many trades, but fixed reward exits were weak out of sample.
- The best combined result in the scan was still only around break-even level, not live-ready.
- The current long branch also failed to show a strong fixed-RR edge when isolated.

## Decision

- Do not force this family into a fixed-RR template just because the money-management story sounds attractive.
- Keep using strong loss caps, trade caps, and execution guards.
- Let the exit model match the entry family:
  - for this mean-reversion branch, the evidence still favors mean/time exits over naive fixed reward targets.

## Reusable Lesson

- Risk management is primary, but it does not replace edge selection.
- A valid edge plus disciplined risk control beats a weak edge wrapped in a clean-looking reward ratio.
