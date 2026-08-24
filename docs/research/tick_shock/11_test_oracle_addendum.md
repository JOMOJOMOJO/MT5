# Step 11 independent test oracle addendum

Expected values in this addendum are derived from validation contracts and
ledger arithmetic, not by invoking production code.

## Configuration

A probability/efficiency ratio is finite and in `[0,1]`; percentages are finite
and in `[0,100]`; entry/exit slippage and commission are finite and non-negative;
execution mode is one of the two declared enum values. Any violation makes the
configuration invalid and production `OnInit` returns
`INIT_PARAMETERS_INCORRECT`.

## Commission

For a one-lot SL loss of 100 account-currency units and a configured round-turn
commission of 7, commission R is `7 / 100 = 0.07`. With gross R `1.00`, net R is
`1.00 - 0.07 = 0.93`; the deduction count is exactly one. If the loss calculation
fails while configured commission is nonzero, no denominator exists: the result
is invalid with `CALCULATION_FAILED`, never a zero-cost result. Evidence retains
symbol, configured source, and absolute one-lot SL loss.

## Run identity and integrity

A fresh run has no continuation authority. Existing data with the same RunId is
a fresh-run collision. Resume needs all three: explicit resume mode, checkpoint,
and cursor. Identity changes in period, model, broker/server, terminal build,
source commit, EX5 hash, schema, or configuration are distinct runs. Only one
writer may own a path. A full event pool, pending overflow, cursor saturation,
tick drop/stall, stale frontier, or incomplete frontier is observable and makes
formal validation `VALIDATION_INVALID`.

## Status and direction

Invalid target construction, risk, direction, tick size, broker stop, and broker
target are distinct enum results. Integer direction zero means `NONE`; treating
it as SHORT violates three-way direction semantics.

## Order ledger

Deal ticket is the idempotency key. Replaying the same `0.04` lot entry deal
leaves filled volume `0.04`, deal count `1`, duplicate count `1`. A mismatched
request/order/symbol/Magic deal is rejected. Entry and exit `0.04` lot deals have
separate weighted aggregates and counts. Restoring a snapshot preserves seen
deal tickets, so replay after restart is also idempotent.

All numeric tolerances are declared in the expected CSVs. Boundary ticks at
999/1000/1001 ms establish minus-one/equal/plus-one coverage; blank sentinels are
not numeric zero.
