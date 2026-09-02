# Step 15H final QA

## Gates

- Step 15H production-path tests: 46 PASS / 0 FAIL / 0 XFAIL / 0 XPASS / 0 SKIP / 0 BLOCKED
- Independent oracle: 8 PASS / 0 FAIL
- Compile: research EA plus 15 harness targets, all 0 errors / 0 warnings
- Formal run causal checks: 9 PASS / 0 FAIL
- Step 15G behavior comparison: 3 artifacts PASS, semantic differences 0
- Strategy order calls: 0; trade rows: 0
- Manifest final rollup: 3,376 rows / 2,897 unique paths / duplicate artifact IDs 0 / latest-path SHA mismatches 0

## Causal invariants

There are no duplicate snapshot/path keys, entries before processing, reused signal quotes, future feature sources, or realized RR values below 1.2. `t0` is the processing time when persistent confirmation became usable. Entry remains the first strictly later same-symbol tick after the selected delay. Horizons remain anchored to `t0` and delay does not extend them.

## Evidence interpretation

Primary has 1,818 episodes and 1,709 market clusters after complete GBPUSD exclusion and quality/path exclusions. This misses the preregistered 2,500/2,000 support gate. The unfiltered C2 policy value is negative and no trained family has a stable positive lower bound with sufficient coverage. Zero-selection policies are not counted as evidence of improvement.

## Verdict

- `NO_DETECTION_TIME_CONTINUATION_FILTER_SUPPORTED`
- `NO_CONTINUATION_FILTER_HYPOTHESIS_FROZEN`
- `INCONCLUSIVE_SAMPLE_SIZE`
- `COST_MODEL_INCOMPLETE`
- `FORMAL_NET_EXPECTANCY_UNAVAILABLE`
- `EDGE_UNDETERMINED`
- `PRODUCTION_NOT_ELIGIBLE`

Step 15H ends here. No long OOS, optimization, new feature family, or production promotion is authorized by this result.
