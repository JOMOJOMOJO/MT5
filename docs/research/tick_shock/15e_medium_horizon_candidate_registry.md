# Step 15E medium-horizon candidate registry

## Registry result

`NO_MEDIUM_HORIZON_HYPOTHESIS_FROZEN`

The machine-readable registry is
`reports/analysis/tick_shock/step15e/candidate_registry.csv`. It contains its
header and zero candidate rows.

## Frozen promotion gate

A maximum of three March-derived candidates was permitted only when all of the
following held without changing a detector, cohort, entry clock, horizon, RR
or stop rule after viewing outcomes:

1. preregistered cohort is `SR-CLEAN-001` or `SR-REV-001`;
2. horizon is at least 30 seconds;
3. at least 200 primary episodes;
4. UTC/server-day block-bootstrap 95% lower bound is above zero;
5. Holm-adjusted one-sided p-value is below 0.05;
6. mean sign is positive in all five chronological folds;
7. mean sign remains positive in every leave-one-symbol-out result; and
8. confirmed-entry mean remains positive with spread expanded to 1.25x.

No cohort/horizon passed even the positive confidence-bound requirement; none
passed the complete gate. No SL, TP or RR was inferred from March. The frozen
RR 1.2 and existing four strategy definitions were not changed and were not
used to manufacture a candidate.

## Status boundary

There is no candidate ID, no selection-validation preset and no authorized
Step 16 run. March 2025 remains development data. The correct status is
`EDGE_UNDETERMINED`, not `NO_EDGE_OBSERVED` on unseen data and not
`STRATEGY_EDGE_VALIDATED`.
