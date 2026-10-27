# Independent causal and formula audit

Engineering result: **PASS**. The preregistered shape-recognition gate: **FAIL**.
These are separate findings. No trading filter, profit comparison or new-period
test follows from this failed recognition gate.

## Independent reconstruction

`independent_recompute.py` imports neither the root implementation nor MQL logic.
It uses Decimal arithmetic, the complete original lower-pivot event streams, and
the frozen selected-case identities. It accesses no profit, exit or outcome
fields. Every selected pivot must precede evaluation by event sequence and be
known by evaluation time; source times lie strictly inside fixed W1 anchors.

All 440 original ORDER snapshots reproduced the root status, normalized pivot
sequence and numeric result (absolute tolerance below 1e-9). SIGNAL and ORDER
results were identical for all 440 snapshots. The statuses are 247 CHOPPY,
107 CLEAN and 86 UNAVAILABLE.

Frozen blind annotations were hash-checked before use. The independent 60-case
matrix exactly reproduced the frozen root result:

| Human annotation | Metric CLEAN | Metric CHOPPY | UNAVAILABLE |
|---|---:|---:|---:|
| CLEAN | 13 | 17 | 5 |
| CHOPPY | 2 | 19 | 4 |

Class recall is 13/35 = 37.14% for CLEAN and 19/25 = 76% for CHOPPY.
The minimum class recall therefore fails the fixed 70% criterion. UNAVAILABLE
cases remain in the denominator. Total agreement is 32/60.

See `independent_recompute.json` for all case-level values and source hashes.

## Engineering-only guard alignment

The original Python script was copied to `python_pre_guard.py`; its SHA256
matches `features.json`'s frozen script hash. Subsequent input validation was
aligned with MQL: anchor availability/source time, direction, positive finite
prices, pivot availability/source time, chronology and same-bar H/L ambiguity.
No threshold, anchor, valid path or classifier formula changed.

`guard_verification.json` confirms all 440 statuses, spans, adverse sums, ratios,
paths and normalized counts stayed exactly identical. Nineteen synthetic guard
checks passed. Frozen `features.json` and `agreement.json` were not rewritten.

For invalid/ambiguous inputs, error names now match MQL. UNAVAILABLE raw-count
semantics now count the processed prefix through the first invalid observation,
matching MQL; this changes 83 unavailable diagnostic counts only. The frozen
experiment files retain their original full eligible raw-count values and
original ambiguity reason. This presentation/diagnostic change does not change
any status, numeric classifier result or gate.

## Source and period preservation

The fixed plan hash and all 12 protected production files remained unchanged.
`protected_baseline.json` and the parent baseline independently protect the
original MQ5, EX5 and ten existing headers. The new diagnostic file/header are
separate artifacts.

`period_inventory.json` records 146 Wave33 tester configuration files, without
outcome inspection. Existing non-2020 QA periods were already used in prior
development; no untouched-period evidence was found. The failed gate stopped
the work before any performance or new-period test. Protected 2026 market data
were not accessed.

`packet_coverage_inventory.json` separately identifies original image-window
clipping in V037 and V059. The new metric uses complete source history, so these
chart limitations are not treated as missing metric coverage.
