# Tick-shock Step 13 order observation

## Environment

- Scope: Strategy Tester-only order harness; research EA remains order-free.
- Server/build: VantageTradingLtd-Live / 6140
- Symbol/period: EURUSD / PERIOD_M1
- Account currency/trade mode: USD / 0
- Tester guard: `MQL_TESTER=true`; normal chart, demo, and live execution are rejected in `OnInit`.
- Test volume/Magic: 0.01 / 26082413
- Model/period under test: real ticks (model 4), 2025-03-03 through 2025-03-07.

## Result counts

| Status | Count |
|---|---:|
| PASS | 45 |
| UNIT_PASS | 1 |
| FAIL | 0 |
| SKIP / NOT_OBSERVED | 2 |

## Observation verdict

| Observation | Result | Evidence |
|---|---|---|
| deterministic order state | VALIDATED | Step 12 suite plus production lifecycle module used by this harness |
| OrderCheck | OBSERVED_PASS | 8 accepted checks with terminal error, retcode, margin, and free margin |
| OrderSend | OBSERVED_PASS | 8 accepted sends with order/deal/request identity |
| tester entry fill | OBSERVED_PASS | 6 full entry fills |
| tester exit fill | OBSERVED_PASS | 6 exit fills |
| server SL Long/Short | OBSERVED_PASS | deal reason SL |
| server TP Long/Short | OBSERVED_PASS | deal reason TP |
| expert time close Long/Short | OBSERVED_PASS | deal reason EXPERT |
| position fields | OBSERVED_PASS | symbol, Magic, direction, volume, time, SL, TP |
| simulated restart snapshot replay | OBSERVED_PASS | Long and Short duplicate deal replay rejected |
| actual process restart | SKIP | separate process restart was not injected |
| partial/multiple entry fill | SKIP | all six entries were one full deal |
| residual cancel | NOT_OBSERVED | no partial entry occurred |
| commission fields | OBSERVED_ZERO | 12 tester deal records; live broker commission not validated |
| harness-owned open positions at end | 0 / PASS | OnDeinit guard |

## Commission interpretation

`DEAL_COMMISSION`, `DEAL_FEE`, and `DEAL_SWAP` were read for every tester entry and
exit deal. They were all zero in this Strategy Tester run. This is
`TESTER_DEAL_FIELDS_OBSERVED_ZERO`, not evidence that the Vantage live account
charges zero commission. A nonzero live-broker round-turn commission remains
`NOT_OBSERVED` and must not be inferred.

## Safety and limits

- All 6 lifecycle cycles completed and no harness-owned position remained.
- The harness refuses initialization unless `MQL_TESTER` is true.
- The terminal's normal Algo Trading and live-trading settings were disabled before and after the run.
- No partial fill, multiple entry/exit deals, residual cancel, actual process restart, or nonzero StopsLevel was observed.
- Server SL/TP and expert time-close reasons were distinguished; a manual/client exit was not invoked and remains `NOT_OBSERVED`.
- Live broker execution is not validated by Strategy Tester evidence.
