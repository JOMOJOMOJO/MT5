# Tick-shock Step 13: Strategy Tester order observation

## Scope and safety

This step observed the order harness only. The research EA remains order-free and
contains no `OrderCheck` or `OrderSend` call. The harness returns `INIT_FAILED`
unless `MQL_TESTER` is true. The run used dedicated Magic `26082413`, EURUSD's
minimum volume `0.01`, local agents only, optimization off, and no DLLs. Normal
terminal Algo Trading and live-trading settings were disabled before and after
the run; no matching terminal process remained afterward.

The tester account was USD 10,000 at 1:100 on `VantageTradingLtd-Live`, build
6140. Account login is intentionally not stored. The run was EURUSD M1, real
ticks/model 4, from 2025-03-03 through 2025-03-07.

## Preconditions

- Step 12 deterministic suite rerun: PASS 81, FAIL 0, XFAIL 0, XPASS 0,
  SKIP 9, BLOCKED 0.
- Research EA plus all 11 Tick-shock harnesses: 0 errors, 0 warnings.
- The 51 order-related Step 3 fixture/expected files match their manifest
  SHA-256 values; changed 0, missing 0.
- Exact source, EX5, terminal, MetaEditor, preset, and tester-config hashes are
  in `reports/tests/tick_shock/step13_order_observation/source_hashes.txt`.

## Observations

| Item | Long | Short | Classification |
|---|---|---|---|
| OrderCheck | PASS | PASS | 6 entry and 2 time-close checks accepted; terminal error, retcode, margin, and free margin recorded |
| OrderSend | PASS | PASS | 6 entry and 2 time-close sends accepted; order/deal/request identity recorded |
| Full entry fill | PASS | PASS | six one-deal full fills |
| Multiple entry deals | NOT_OBSERVED | NOT_OBSERVED | do not count as PASS |
| Partial fill | NOT_OBSERVED | NOT_OBSERVED | no `DONE_PARTIAL` and no multiple entry deal |
| Residual cancel | NOT_OBSERVED | NOT_OBSERVED | no residual volume existed |
| Server SL | PASS | PASS | exit reason `DEAL_REASON_SL` |
| Server TP | PASS | PASS | exit reason `DEAL_REASON_TP` |
| Expert time close | PASS | PASS | exit reason `DEAL_REASON_EXPERT` |
| Manual/client close | NOT_OBSERVED | NOT_OBSERVED | not invoked; not conflated with expert/server reasons |
| Position identity/fields | PASS | PASS | symbol, Magic, direction, volume, entry time, price, SL, TP |
| Snapshot restore and duplicate replay | SIMULATED_PASS | SIMULATED_PASS | production lifecycle module rejected the replay without changing aggregates |
| Actual process restart | NOT_OBSERVED | NOT_OBSERVED | not promoted to PASS |
| Multiple exit deals | NOT_OBSERVED | NOT_OBSERVED | each exit used one deal |

Harness result was PASS 45, UNIT_PASS 1, FAIL 0, and SKIP 2. All six lifecycle
cycles completed. The end guard observed zero harness-owned open positions.

## Commission

All six entries and six exits exposed `DEAL_COMMISSION`, `DEAL_FEE`, and
`DEAL_SWAP`. Every field was zero. Each Long/Short × SL/TP/TIME round trip was
therefore `TESTER_DEAL_FIELDS_OBSERVED_ZERO`, using source
`MT5_STRATEGY_TESTER_HISTORY_DEAL_FIELDS`.

This does not establish a zero Vantage live-broker commission. Nonzero live
round-turn commission remains `NOT_OBSERVED`, and Step 14 must distinguish the
tester observation from deployable cost evidence.

## Symbol and broker constraints

EURUSD reported digits 5, point/tick size 0.00001, tick value 1 USD, contract
size 100,000, volume minimum/step 0.01, StopsLevel 0, FreezeLevel 0, and filling
mode bitmask 2. Because StopsLevel and FreezeLevel were zero, nonzero broker
distance behavior remains `NOT_OBSERVED`.

## Verdict

- deterministic order state: `VALIDATED`
- tester order request: `OBSERVED_PASS`
- tester full fill: `OBSERVED_PASS`
- server barriers Long/Short: `OBSERVED_PASS`
- expert time close Long/Short: `OBSERVED_PASS`
- tester deal commission fields: `OBSERVED_ZERO`
- actual partial fill/residual cancel: `NOT_OBSERVED`
- simulated restart snapshot: `SIMULATED_PASS`
- actual process restart: `NOT_OBSERVED`
- live broker execution and live commission: `NOT_VALIDATED`

Step 14 inputs are the summary, observation CSVs, tester journal/report,
source hashes, symbol specifications, and this document. Step 12 results were
not rewritten; observation upgrades are isolated in
`observation_test_status.csv`.
