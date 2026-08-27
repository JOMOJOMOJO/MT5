# Step 15A matched-control specification and evidence boundary

## Frozen rule

The rule was registered before any V1 March result was read. For one
representative event per market cluster, select the closest earlier boundary
with the same symbol, four-hour server-time bucket, trigger horizon, estimator,
and volatility regime. The boundary must not cross the adjusted 99.0 threshold,
must be more than 120 seconds from every shock/market cluster, and must have a
complete 120-second outcome. A missing exact match remains unmatched; matching
dimensions and distance are never relaxed.

The primary event-minus-control outcomes are absolute returns at 1 and 3
seconds and 120-second realized volatility. Secondary outcomes are 10/30/120
second absolute return, MFE, MAE, spread change, tick activity, quote-reversion
ratio, and cluster duration. Inference is by chronological stationary block
bootstrap over market clusters, 10,000 replicates, mean block length four,
seed 20260826. Primary p-values use Holm correction over the predeclared family;
secondary diagnostics use BH FDR at q=0.05.

## Actual Step 15A evidence boundary

The four completed March run files contain every statistical event and its
120-second outcome, but they do not contain non-event boundary outcomes. The
closest eligible controls therefore cannot be reconstructed exactly from the
archived run artifacts without replaying the ticks through a separately
specified control-boundary recorder. Using another detector's events or
post-hoc relaxed matches would violate the frozen rule.

Consequently, `step15a_matched_control_results.csv` and
`step15a_cluster_bootstrap.csv` report `NOT_ESTIMABLE` for every comparison.
This is a fail-closed research result: no detector may pass the locked-
validation selection gate in Step 15A. The detector formulas and March outputs
are not changed to conceal this missing evidence.

Any later control-recorder replay must receive a new evidence task, preserve
the frozen detector IDs and specification hash, archive non-event boundary
provenance, and rerun the same March window before candidate selection is
reconsidered.
