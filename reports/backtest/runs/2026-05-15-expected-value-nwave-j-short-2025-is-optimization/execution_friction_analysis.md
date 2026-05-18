# Execution Friction Analysis

## What Was Compared
The same selected J_SHORT preset was run over `2026.01.01-2026.04.30` in two paths:
- virtual diagnostic path, `EnableTrading=false`
- tester order path, `EnableTrading=true`

The comparison used `SetupId + EntryTime + Direction` as the primary match key.

## Entry and Plan Parity
For `40` matched trades, the planned trade was identical:
- Entry price: no differences
- SL: no differences
- TP: no differences
- RiskPoints: no differences

This rules out selected parameter drift, TP/SL planning drift, risk distance drift, and lot/risk planning drift as the primary reason for the negative live-smoke result.

## Exit Friction
The total virtual-to-live R change was `-7.387874R`.

R impact by bucket:
- `virtual_win_live_loss`: `3` trades, `-7.540311R`
- same-outcome material R difference: `6` trades, `-0.676046R`
- same-outcome near-equal difference: `31` trades, `-0.171517R`
- virtual-only missed live entry: `1` trade, `+1.000000R`

The three result flips explain the entire degradation. Without them, the live path would still show friction, but not the observed sign flip.

## Why Short Trades Are Exposed
All selected trades are short. In MT5, a sell position is exited by buying:
- Sell SL is triggered by Ask rising to SL.
- Sell TP is triggered by Ask falling to TP.

The virtual closed-bar check currently uses `iHigh()` and `iLow()` ranges directly. Those are Bid-side bar values in MT5 history. That creates two problems for shorts:
- Bid low can reach TP while Ask may not have reached TP.
- Bid high can differ from the Ask stop trigger path.

The diagnostics confirm this mismatch. Two virtual winners had virtual `MAE_R < -1.0`, yet virtual still closed them as TP:
- `SHORT_1769076600_158.722`: virtual `MAE_R=-1.0949`, virtual result WIN, live result LOSS.
- `SHORT_1773893100_159.671`: virtual `MAE_R=-1.0265`, virtual result WIN, live result LOSS.

This is not normal harmless spread noise. It indicates that virtual exit simulation is not execution-equivalent for short trades.

## Same-Bar Handling
`ConservativeSameBarExit=true` helps only when the same virtual bar range simultaneously touches SL and TP. It does not solve:
- tick-order differences across bars,
- Bid/Ask trigger differences,
- intrabar live stop execution before the virtual closed-bar TP check.

So conservative same-bar handling is necessary but insufficient for executable validation.

## Risk Guard Timing
Only one candidate was virtual-entered but live-rejected:
- `SHORT_1776144000_159.075`
- live reject: `entry_open_count_filter_failed`
- virtual result: LOSS
- R impact: live improved by `+1.000000R`

This occurred because the previous live position closed later than the virtual position. It is a consequence of execution-path divergence, not the primary cause of negative live smoke.

## Stop Level, Freeze Level, Lot, and Order Errors
Preflight for the live smoke:
- `StopsLevel=0`
- `FreezeLevel=0`
- `LotStep=0.01`
- `MinLot=0.01`
- `MaxLot=100`

Diagnostics:
- `live_order_send_failed=0`
- `live_position_tracking_failed=0`
- `live_sl_tp_invalid=0`
- `live_lot_invalid=0`

No evidence points to broker stop/freeze constraints or lot rounding as the cause.
