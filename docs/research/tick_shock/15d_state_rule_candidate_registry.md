# Step 15D state-rule candidate registry

March 2025 is development-only. Six preregistered low-complexity trials plus
the explicit no-trade concept were evaluated with five chronological folds and
120-second purge. Exact fold thresholds and every evaluated trial are in
`reports/analysis/tick_shock/step15d/trial_registry.csv`; none were deleted.

## Freeze decision

No candidate is frozen for unused-period selection validation.

`SR-CLEAN-001` and `SR-REV-001` had statistically supported, sign-stable
development label lift, but failed executable Bid/Ask screening at one local
sigma (direction-maintaining rates 0.748% and 0.695%). The remaining four
rules failed multiplicity, stability, support, or outcome availability. Adding
conditions or changing barriers after observing these results is prohibited.

The machine-readable registry is
`reports/analysis/tick_shock/step15d/state_rule_candidates.csv`. Its canonical
spec hashes are retained even for rejected rules so later work cannot quietly
resurrect or modify them without a new preregistration.

Formal registry status:

- `NO_STATE_CONDITIONED_PATTERN_SUPPORTED`
- `NO_STATE_RULE_HYPOTHESIS_PROMOTED`
- `EDGE_UNDETERMINED`

The next authorized action is to stop Step 15D. A new study would require a
fresh pre-analysis plan; it must not reuse March as unused validation or begin
RR optimization automatically.
