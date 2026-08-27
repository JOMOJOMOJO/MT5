# Step 15C event-response implementation specification

## Recorder contract

The research EA shall feed each confirmed `TAIL_V1_PERSISTENT` statistical
event into a bounded response recorder before common strategy ingress. The
recorder stores fixed-horizon snapshots, online excursion extrema, first-passage
state, origin recross, causal strategy reachability, gate mask, and integrity
counters. It must not store every tick in CSV and must not mutate the production
detector or strategy state.

Each output row carries `event_id`, `market_cluster_id`,
`response_episode_id`, symbol, detector, candidate/confirmed time, direction,
trigger horizon, severity, RunId, schema version, and spec SHA-256. Snapshot
timestamps must be at or after their targets. A capacity/drop/duplicate/cursor
violation fails closed.

## Analysis contract

The independent analyzer consumes versioned CSV only. Discovery and Internal
confirmation are separate commands. Discovery writes the complete trial
registry and candidate shortlist. Confirmation requires the frozen candidate
registry SHA and rejects feature thresholds or scenario specifications not
present in that registry.

Required outputs are the event timeline/path/horizon, excursion, first-passage,
episode, gate, strategy reachability, RR-grid, conditional-bias,
multiple-testing, bootstrap, concentration, candidate, trial and parameter-diff
CSVs specified by Step 15C. Every chart has a CSV source.

## Test contract

The 42 `TS15C-*` fixtures are independent executable specifications. RED means
the production event-response API is absent; GREEN must come from the compiled
MQL harness calling that API. Expected values are produced by an independent
Python oracle and cannot be rewritten to match production. Tests cover causal
clocks, fixed horizons, irregular/same-ms/stale/missing quotes, excursions,
first passage, execution, episodes, strategy clocks, gates, split isolation,
hashing, deterministic rerun, capacity and provenance.

## Non-goals

No detector threshold, persistence rule, market-cluster rule, existing strategy,
production RR, SL grid, execution rule, commission value, or order behavior is
changed. No order API is added to the research EA.
