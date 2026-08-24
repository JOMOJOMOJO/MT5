# Step 12 fail-closed research integrity fix

Step 12 fixes Step 11 RED observations without changing fixture, expected,
Test ID, oracle, detector threshold, strategy definition, RR, stop grid,
delay/spread grid, maximum hold, or global watermark release semantics.

- `OnInit` calls complete `TSConfigValid(g_core_config)` and rejects invalid
  finite/range/mode inputs with `INIT_PARAMETERS_INCORRECT`.
- commission returns validity, typed reason, symbol, source and one-lot loss.
  Explicit zero is the only zero-cost bypass; nonzero calculation failure is
  invalid and commission is deducted once.
- CSV defaults to fresh; resume requires explicit flag/checkpoint/event/cursor.
  Identity binds period/model/broker/build/commit/EX5/schema/config and writer
  ownership is exclusive.
- event pool, pending overflow, dropped data, CopyTicks cursor stall, stale
  symbol and incomplete frontier are separately observable and fail closed to
  `VALIDATION_INVALID`.
- scenario failures are typed and direction zero is `NONE`.
- the order-only lifecycle module tracks full identity, entry/exit, partial fill,
  residual cancel, weighted prices, deal dedup and restart replay. The research
  EA still has no `OrderCheck`/`OrderSend` call.
- dead `signal_armed` and the unused baseline `mid` argument were removed.

The global watermark algorithm itself is unchanged. Evidence is in the Step 12
GREEN report, fixture integrity and behavior-preservation CSVs.
