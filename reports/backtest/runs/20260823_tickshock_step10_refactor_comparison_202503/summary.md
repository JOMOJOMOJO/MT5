# Tick-shock Step 7 causal comparison: March 2025

## Formal judgement

- `RESEARCH_PIPELINE_PARTIALLY_VALIDATED`
- `EXECUTION_MODEL_CAUSALLY_VALIDATED`
- `STRATEGY_FEASIBILITY_ESTABLISHED`
- `EDGE_UNDETERMINED`
- long OOS not performed

Only REALIZABLE_EA is used for the formal judgement. Feasibility here means causal, broker-grid-feasible shadow outcomes exist; it does not mean a deployable order EA or positive edge has been established.

## Event funnel: previous baseline versus Step 7

| Metric | Previous baseline | IDEAL | REALIZABLE |
|---|---|---|---|
| raw shock candidates | 62577 | 62577 | 62577 |
| event rows | 19 | 19 | 19 |
| valid bursts | 19 | 19 | 19 |
| valid pullbacks | 14 | 14 | 14 |
| reacceleration | 5 | 5 | 5 |
| reversal signals | 11 | 11 | 11 |

Detector/event funnel is unchanged. The previous 17 independent clusters were symbol clusters; Step 7 adds 15 cross-symbol market clusters, which are the formal statistical n.

## Execution outcome: previous baseline versus Step 7

| Metric | Previous baseline | IDEAL | REALIZABLE |
|---|---|---|---|
| valid cells | 7452 | 7128 | 7128 |
| invalid broker cells | 0 | 324 | 324 |
| TP | 1380 | 1301 | 1227 |
| SL gap | 3111 | 2840 | 2820 |
| TIME | 2961 | 2987 | 3081 |
| diagnostic ExpectancyR | -0.338143 | -0.302408 | -0.292362 |

The 324 invalid cells are broker StopsLevel failures exposed by the corrected current-Bid/Ask check. They are not threshold changes.

## IDEAL versus REALIZABLE entry

| Matched unique signal/delay decisions | Entry changed | Mean REALIZABLE-IDEAL ms | IDEAL actual delay mean | REALIZABLE actual delay mean |
|---|---|---|---|---|
| 162 | 141 | 399.500 | 276.160 | 675.660 |

IDEAL event-time entries are diagnostic only. REALIZABLE includes global merge recognition lag in signal_processing and applies the causal maximum before selecting the next same-symbol real tick.

## REALIZABLE strategy outcomes

| Strategy | Signals | Valid cells | TP | SL | TIME | ExpectancyR |
|---|---|---|---|---|---|---|
| detection_time_continuation | 19 | 2508 | 432 | 987 | 1089 | -0.319703 |
| failed_shock_reversal | 11 | 1452 | 174 | 507 | 771 | -0.196465 |
| post_burst_continuation | 19 | 2508 | 441 | 1047 | 1020 | -0.339913 |
| pullback_continuation | 5 | 660 | 180 | 279 | 201 | -0.218739 |

No strategy, stop, delay, or spread cell was selected. The overall grid mean is not a deployable strategy estimate.

## Requested delay, spread stress, and policy mask

| Requested delay | IDEAL ExpectancyR | REALIZABLE ExpectancyR |
|---|---|---|
| d0 | -0.311509 | -0.292284 |
| d100 | -0.303744 | -0.292284 |
| d250 | -0.291972 | -0.292518 |

| Spread stress | IDEAL ExpectancyR | REALIZABLE ExpectancyR |
|---|---|---|
| s100 | -0.274269 | -0.266128 |
| s125 | -0.330547 | -0.318595 |

IDEAL valid-cell policy masks: 0=2048; 1=4362; 2=706; 3=12.

REALIZABLE valid-cell policy masks: 0=2037; 1=4353; 2=717; 3=21. Policy gates remain diagnostic columns and were not used to select cells.

## Long/Short and cluster-unit statistics

| Direction | Valid cells | ExpectancyR |
|---|---|---|
| LONG | 3564 | -0.053791 |
| SHORT | 3564 | -0.530932 |

| Market clusters | Mean cluster outcome | Median | Min | Max | Positive cluster means |
|---|---|---|---|---|---|
| 15 | -0.242732 | -0.398433 | -1.054015 | 1.038895 | 3 |

These cluster values average correlated scenario cells inside each market cluster. With only 15 clusters they are descriptive, not an edge proof.

## Causal invariants

| Invariant | Checked | Violations | Status |
|---|---|---|---|
| entry_quote_msc >= signal_event_msc + requested_delay_ms | 7128 | 0 | PASS |
| entry_quote_msc >= signal_processing_msc + submit_latency_ms | 7128 | 0 | PASS |
| entry_quote_msc >= entry_eligible_msc | 7128 | 0 | PASS |
| entry_quote_msc > signal_event_msc | 7128 | 0 | PASS |
| stale Detection boundary fill = 0 | 2508 | 0 | PASS |
| reversal signal equals invalidation time | 1518 | 0 | PASS |
| realized RR >= requested RR (1.2) | 7128 | 0 | PASS |
| global order violation = 0 | 1 | 0 | PASS |
| duplicate event = 0 | 19 | 0 | PASS |
| market cluster integrity | 19 | 0 | PASS |
| CSV and summary reconciliation | 8023 | 0 | PASS |

Formal causal invariant violations: **0**.

## Tick quality, commission, memory, and files

- generated fallback: GBPUSD 179 / 30,187 minutes (0.5930%); other symbols have no discard warning, which is not proof of all-real coverage
- commission: 0.0 configured, source `ORDER_HARNESS_REQUIRED`; net R is not verified with actual account commission
- REALIZABLE memory: average 10.000 MB, max 10 MB
- REALIZABLE events.csv: 5149628 bytes / 19 rows
- REALIZABLE summary.csv: 216649 bytes / 1184 rows
- trade CSV: 0 rows / 15 bytes; research EA sent no orders
- runtime: IDEAL 353.297 seconds; REALIZABLE 360.797 seconds
- one-second ring: 904 per symbol; tick ring: 8192 per symbol
- tick discard: `older_than_5000ms_or_capacity_8192`; global pending `capacity=65536;max_observed=319;capacity_hits=0`
- structured REALIZABLE CSV volume: 5368636 bytes/month; linear estimate 64423632 bytes/year and 193270896 bytes/three years if event density and schema stay similar
- retaining both modes would approximately double structured CSV volume to 128847264 bytes/year
- no raw tick CSV or per-second time-series CSV was emitted

## Step 8 handoff

- `docs/research/tick_shock/00_artifact_manifest.md`
- `reports/tests/tick_shock/step06_post_fix_green_report.md`
- `reports/tests/tick_shock/step06_post_fix_results.csv`
- `C:/Users/windows/AppData/Local/Temp/tickshock_step10_ideal_ae9c74fdf2994196a4cf68e4021bebcb/summary.md`
- `C:/Users/windows/AppData/Local/Temp/tickshock_step10_ideal_ae9c74fdf2994196a4cf68e4021bebcb/events.csv`
- `C:/Users/windows/AppData/Local/Temp/tickshock_step10_ideal_ae9c74fdf2994196a4cf68e4021bebcb/summary.csv`
- `C:/Users/windows/AppData/Local/Temp/tickshock_step10_ideal_ae9c74fdf2994196a4cf68e4021bebcb/reconciliation.md`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/summary.md`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/events.csv`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/summary.csv`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_realizable_202503/reconciliation.md`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_comparison_202503/comparison.csv`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_comparison_202503/causal_invariants.csv`
- `reports/backtest/runs/20260823_tickshock_step10_refactor_comparison_202503/summary.md`
- `tools/tick_shock/reconcile_causal_runs.py`

## Decision

The causal execution model passes this March replay and now produces broker-feasible shadow outcomes. Research should continue at the next review step, but this evidence does not yet justify automatically starting long OOS: the formal independent sample is 15 market clusters and actual commission/order lifecycle evidence is incomplete. There is no basis for promotion, optimization, or a positive-edge claim.
