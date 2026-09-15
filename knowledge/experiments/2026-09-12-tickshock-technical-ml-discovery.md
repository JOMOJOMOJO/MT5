# Technical ML: frequency can be retained without acquiring sufficient edge

January–April2025 development data; frozen shock detector, real Bid/Ask labels,
RR1 geometry grid. Expanding February–April evaluation, past-only calibration,
unchanged calibrated model into next month. No EA or new MT5 run.

Six estimator families × three targets × two feature variants × five geometries
× three folds =540 fold configurations,3,240 policies.1,996 policies maintained
>=200 trades in each month;3 were pooled positive after hypothetical extra0.2pip;
none was positive in all three months. No conditional May/June run was authorized
by the preregistered gate; these months had already been observed in an earlier study.

The pooled-EV best frequency-qualified cell (Random Forest net-R regression,
1ATR symmetric barriers) produced844 trades,+0.008234R/trade,PF1.0198,20.422R
closed-trade DD. February was negative; excluding AUDUSD erased the pooled gain.
The stability-ranked Extra Trees cell kept218/437/377 trades but primaryEV≈0.
Its quote-side EV was+0.01566R before additional cost,+0.00683R at0.1pip, and
-0.00199R at0.2pip. These are selected development cells, not unbiased estimates.

Reusable lesson: frequency calibration addresses score/count drift, not whether
the estimated payoff survives cost and regime/currency dependence. Preserve
fitting/calibration separation and always expose requested versus realized count.
Direct net-R models accounted for TIME payoffs better than the tested TP-first
probability plus unconditional-payoff conversion; this is bounded evidence,
not a universal ranking of algorithms. Do not make another fine threshold sweep
on these same months to manufacture acceptance.

Evidence: [Japanese readout](../../docs/research/tick_shock/technical_ml_discovery_readout_ja.md),
[completion](../../reports/analysis/tick_shock/technical_ml_discovery_20260911/completion.json),
[positive-cell accounting](../../reports/analysis/tick_shock/technical_ml_discovery_20260911/positive_pooled_cells.csv).
