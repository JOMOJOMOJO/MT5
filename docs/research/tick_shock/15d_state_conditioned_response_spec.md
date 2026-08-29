# Step 15D state-conditioned response specification

## Production contract

`TickShockStateConditionedResponse.mqh` is a bounded, order-free research
module called by the research EA and the deterministic harness. It consumes
confirmed Step 15C event state and grouped real quotes. It must not change
detector, gate, strategy or execution decisions. Schema
`tickshock-state-conditioned-response-v1` appends new files; existing CSV
column meanings remain unchanged.

The module exposes pure causal-clock, state-feature, canonical USD cluster,
path-class and executable-barrier functions plus bounded recorder contexts.
Fixed checkpoints close with the first real quote at/after target. State-machine
checkpoints use the already-observed transition clock. Output records carry
availability and causality fields and fail closed on loss or duplication.

## RED/GREEN contract

The 64 `TS15D-*` tests have independent fixtures and expected CSVs. RED is the
missing production include/API. GREEN must come from a compiled MQL harness
calling the same module used by the EA. The independent oracle does not import,
parse or translate production formulas. Expected files are frozen before the
production implementation.

## Replay and analysis contract

March replay must reproduce 21,799 events, 10,245 clusters and the frozen
strategy reachability counts with zero identity/parameter difference and zero
orders. Required compact outputs are checkpoint features, causal cluster
features, path labels, strategy-entry features and executable first passage.
The independent analyzer uses five chronological episode folds with 120-second
purges and records every trial, failed rule and discarded rule.

## Non-goals

No gate/threshold/RR/SL/delay/spread/hold/order change, no full RR grid, no
fixed-horizon inference of first touch, no locked OOS and no production EA
promotion.
