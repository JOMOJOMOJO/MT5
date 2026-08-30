# Step 15F post-run F01 RED contract

- PASS: 36
- FAIL: 0
- XFAIL: 1
- XPASS: 0
- SKIP: 0
- BLOCKED: 0

Expected values are frozen independent CSV oracles. `TS15F-INTEGRITY-006`
reproduced the newly identified evaluation-order defect against the production
`TS15FBuildFeatures` path; it is classified as the single expected failure
before the implementation fix.
