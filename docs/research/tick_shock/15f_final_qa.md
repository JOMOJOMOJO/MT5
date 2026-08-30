# Step 15F final QA

## Verdict

- Step 15E audit: `STEP15E_DIRECTION_AND_COVERAGE_AUDIT_PASSED`
- feature study: `CAUSAL_CONTEXT_FEATURES_CHARACTERIZED_ON_DEVELOPMENT_DATA`
- pattern: `NO_CONTEXT_CONDITIONED_PATTERN_SUPPORTED`
- candidate: `NO_CONTEXT_RULE_HYPOTHESIS_FROZEN`
- specificity: `CONTEXT_SIGNAL_NOT_SHOCK_SPECIFIC`
- cost: `COST_MODEL_INCOMPLETE`
- expectancy: `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- edge: `EDGE_UNDETERMINED`
- promotion: `PRODUCTION_NOT_ELIGIBLE`

Step 15F is complete and stops at March development characterization. No
selection validation, locked OOS, long OOS, optimization, production EA or
order work is authorized.

## Evidence gates

The deterministic suite has 313 PASS, 0 FAIL, 0 XFAIL, 0 XPASS, 9 SKIP and 0
BLOCKED. The nine SKIPs retain the previously documented terminal-only or
unobserved scope; none is reclassified as PASS. Seventeen compile targets have
0 errors and 0 warnings. The independent Step 15F oracle has 37 rows and zero
differences.

The formal accepted run is r3, generated from source commit
`26faf274b87b882745a9a62bfb521fea08d9bf7f`. Its source, EX5 and terminal
hashes are saved beside the run. The r2 run is rejected evidence because F01
was absent. The F01 production-path contract changed from XFAIL to PASS without
changing its expected file.

Regression comparison reports zero differences for detector events (21,799),
episodes (3,151), Step 15D paths (21,799), strategy funnel (21,799),
medium-horizon responses (28,359) and market clusters (10,245). Strategy and
execution parameter differences are zero. Episode future reads, backdates,
drops, capacity losses and duplicate IDs are zero. Production orders are zero.

## Data and statistical QA

The 3,151 episodes reconcile to 417 GBPUSD fallback exclusions and 2,734
primary episodes. The accepted feature output has 6,302 decision rows. Of
these, 3,902 rows contain all 36 features; three additional primary rows have a
partial feature set and are handled only by fold-local imputation/missing
indicators. Stale/invalid rows are not treated as complete.

The control repository has 6,254 anchors and 12,508 decision rows. Matching is
one-to-one without outcome-based selection. Day-block confidence intervals for
every shock-minus-control difference cross zero.

Five chronological expanding folds keep complete episodes and cluster blocks
together with 15-minute purge/embargo. All preprocessing and finite
hyperparameter selection are training-only. The strongest point estimate is
+0.062832 spread multiples, but its confidence lower bound is -0.024420,
Holm-adjusted p is 1.0, and one outer fold is negative. Shock-added features do
not improve the strongest context-only cell. Candidate count is therefore
zero.

## Partial and unavailable evidence

GBPUSD has 179 generated-fallback minutes among 30,187 tester minutes. Because
the affected interval map is unavailable, all 417 GBPUSD episodes remain out
of primary inference. The EA observed 30,188 GBPUSD M1 boundaries; this is a
different counter and is not rewritten to match the tester denominator.

UTC/DST session mapping is unverified, so server-hour fields remain diagnostic.
Actual commission and additional slippage are not established for all six
symbols. Formal net expectancy is blank; positive spread-only point estimates
must not be promoted as an edge.

## Reproducibility

The feature spec hash is
`074C40B21F804CEDB414FA0C75DD1A101B7DF808F6254000B641C134C282B597`;
the model-family hash is
`29A00C165566C46E7102D6B4C6AC14482DCA88E8F4ABAAB8B5DE2E388A60C338`;
the seed is 20260831. Python 3.11.9, pandas 3.0.1, NumPy 2.4.4, SciPy 1.17.1
and scikit-learn 1.9.0 were used. Source/fixture, output and large-local
artifact hashes are recorded under `reports/qa/tick_shock/step15f/`.
