# Next Action Recommendation

## A. Bugs Or Execution-Parity Issues To Fix Before EnableTrading=true Demo
1. Make virtual exit checks execution-side aware for shorts.
   - For short virtual trades, SL/TP should be evaluated against Ask-side movement, not raw Bid OHLC.
   - Current closed-bar virtual logic uses `iHigh/iLow` directly, while live sell exits are Ask-triggered.

2. Align virtual MFE/MAE and virtual close logic.
   - MFE/MAE tracking can record short MAE below `-1R` while virtual exit still closes as TP.
   - That inconsistency must be removed before virtual results are used as promotion evidence.

3. Add explicit diagnostics for actual live deal prices.
   - Log actual entry deal price, actual exit deal price, commission/swap, actual risk money, actual R, and slippage points.
   - The current diagnostics show planned Entry/SL/TP parity but do not fully explain actual deal-level R.

These are measurement/execution-parity fixes. They are not entry logic improvements.

## B. Measurement Improvements That Do Not Change Strategy Logic
- Add `ExecutionPath` column: `virtual_bar`, `virtual_tick`, `live_order`.
- Add `TriggerSide` column: `Bid`, `Ask`, or `unknown`.
- Add `PlannedR` versus `RealizedR` columns for live trades.
- Add `ExitDealPrice`, `EntryDealPrice`, `Commission`, `Swap`, `SlippagePoints`.
- Add a virtual/live parity report after each tester smoke.
- Re-run 2025 IS selected and 2026 Jan-Apr OOS after the virtual execution model is made short-side aware.

## C. Strategy Improvements Not To Touch In This Task
These may be useful later, but they would change strategy behavior and are intentionally out of scope now:
- Wider SL/TP or different R multiple.
- Spread-adjusted TP/SL placement.
- BE, partial close, or trailing.
- Session filter.
- Additional direction or volatility filters.
- Further parameter optimization.

## Decision
- Forward demo signal-only: yes, can continue.
- EnableTrading=true demo auto-execution: not yet. Add execution-parity diagnostics or correct the virtual short exit model first, then re-run the same OOS comparison.
- Production/live: no. The live smoke already shows that executable R can differ enough to erase the virtual edge.
