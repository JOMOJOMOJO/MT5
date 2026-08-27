# Detector feature schema v2

Version 2 adds only the dedicated `direction` column to the Step 15A feature
schema. It also introduces separate event-level files for matched-control and
strategy-funnel research:

- `detector_features.csv`: one row per statistical event after 120-second tracking.
- `control_candidates.csv`: one row per selected matched control, not every boundary.
- `control_matches.csv`: one row per representative market-cluster match attempt.
- `strategy_funnel.csv`: one row per statistical event with every predicate and
  counterfactual reachability flag.

No tick-by-tick or one-row-per-second CSV is generated. The control recorder is
a 512-point ring per symbol. Shock exclusion times are held in a bounded 64-slot
ring. A control is eligible only after a complete 120-second outcome exists.

